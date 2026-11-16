#!/usr/bin/env python3
"""Protocol and real-socket tests against the Oberon TCPNet emulator.
Usage: python3 tests/test_tcpnet.py /path/to/TCPHostTest
"""
from pathlib import Path
import os
import re
import select
import socket
import subprocess
import sys
import threading
import time
import unittest

EXE = str(Path(sys.argv.pop(1)).resolve())

class EchoServer:
    def __init__(self):
        self.listener = socket.socket()
        self.listener.bind(('127.0.0.1', 0))
        self.port = self.listener.getsockname()[1]
        self.listener.listen(8)
        self.listener.settimeout(.1)
        self.stop = threading.Event()
        self.peers = []
        self.thread = threading.Thread(target=self.run, daemon=True)
        self.thread.start()

    def run(self):
        while not self.stop.is_set():
            try:
                peer, _ = self.listener.accept()
            except socket.timeout:
                continue
            except OSError:
                break
            self.peers.append(peer)
            threading.Thread(target=self.echo, args=(peer,), daemon=True).start()

    def echo(self, peer):
        try:
            while not self.stop.is_set():
                data = peer.recv(4096)
                if not data:
                    break
                peer.sendall(data)
        except OSError:
            pass
        finally:
            peer.close()

    def close(self):
        self.stop.set()
        self.listener.close()
        for peer in self.peers:
            try: peer.shutdown(socket.SHUT_RDWR)
            except OSError: pass
        self.thread.join(timeout=1)

class ESPTest(unittest.TestCase):
    def setUp(self):
        self.server = EchoServer()
        self.addCleanup(self.server.close)
        self.child = subprocess.Popen([EXE], stdin=subprocess.PIPE,
                                      stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                      bufsize=0)
        self.addCleanup(self.close_child)
        self.buffer = bytearray()
        self.command(b'ATE0')

    def close_child(self):
        self.child.terminate()
        self.child.wait(timeout=3)
        for stream in (self.child.stdin, self.child.stdout, self.child.stderr):
            stream.close()

    def write(self, data):
        self.child.stdin.write(data)

    def fill(self, timeout=3):
        self.assertTrue(select.select([self.child.stdout], [], [], timeout)[0],
                        f'UART timeout, buffered {self.buffer!r}')
        data = os.read(self.child.stdout.fileno(), 16384)
        self.assertTrue(data, f'bridge exited {self.child.poll()}')
        self.buffer.extend(data)

    def until(self, marker, timeout=3):
        deadline = time.monotonic() + timeout
        while marker not in self.buffer:
            remaining = deadline - time.monotonic()
            self.assertGreater(remaining, 0, repr(self.buffer))
            self.fill(remaining)
        end = self.buffer.index(marker) + len(marker)
        result = bytes(self.buffer[:end]); del self.buffer[:end]
        return result

    def command(self, data, expected=b'\r\nOK\r\n'):
        self.write(data + b'\r\n')
        return self.until(expected)

    def open(self, link=0, host=b'127.0.0.1'):
        answer = self.command(b'AT+CIPSTART=%d,"TCP","%s",%d' %
                              (link, host, self.server.port))
        self.assertIn(b'%d,CONNECT\r\n' % link, answer)

    def send(self, link, data):
        self.write(b'AT+CIPSEND=%d,%d\r\n' % (link, len(data)))
        self.until(b'> ')
        self.write(data)
        # SEND OK may precede or follow incoming frames.
        self.until(b'SEND OK\r\n')

    def receive(self, link, size):
        result = bytearray()
        while len(result) < size:
            self.until(b'+IPD,%d,' % link)
            header = self.until(b':')
            n = int(header[:-1])
            while len(self.buffer) < n:
                self.fill()
            result.extend(self.buffer[:n]); del self.buffer[:n]
        return bytes(result)

    def test_init_join_and_rejection(self):
        for command in (b'AT', b'AT+CWMODE=1', b'AT+CIPMODE=0', b'AT+CIPMUX=1',
                        b'AT+CIPDINFO=0', b'AT+CIPRECVMODE=0'):
            self.command(command)
        answer = self.command(b'AT+CWJAP="ssid\\,a\\\"b","pass\\\\word"')
        self.assertIn(b'WIFI GOT IP', answer)
        for command in (b'AT+BOGUS', b'AT+CIPMUX=0', b'AT+CIPSTART=5,"TCP","localhost",80',
                        b'AT+CIPSEND=0,1', b'AT+CIPCLOSE=0', b'AT+CWJAP="bad',
                        b'AT+CIPSTART=x', b'AT\x00junk', b'x' * 600):
            self.command(command, b'\r\nERROR\r\n')
        self.command(b'AT')  # parser recovered after an overlong line

    def test_binary_payload_and_remote_close(self):
        self.open()
        data = bytes(range(256)) + b'\r\nAT+CIPCLOSE=0\r\n>+IPD,0,99:\x00'
        self.send(0, data)
        self.assertEqual(self.receive(0, len(data)), data)
        for peer in self.server.peers:
            peer.shutdown(socket.SHUT_RDWR)
        self.until(b'0,CLOSED\r\n')
        self.command(b'AT+CIPSEND=0,1', b'\r\nERROR\r\n')

    def test_five_links_hostname_and_reuse(self):
        for i in range(5):
            self.open(i, b'localhost')
        self.command(b'AT+CIPSTART=0,"TCP","localhost",80', b'\r\nERROR\r\n')
        for i in range(5):
            data = bytes([i, 0, 255])
            self.send(i, data)
            self.assertEqual(self.receive(i, len(data)), data)
        for i in range(5):
            answer = self.command(b'AT+CIPCLOSE=%d' % i)
            self.assertIn(b'%d,CLOSED' % i, answer)
        self.open(0)

    def test_fragmented_command_and_maximum_send(self):
        self.open()
        for part in (b'AT+CIP', b'SEND=0,', b'1460\r', b'\n'):
            self.write(part)
        self.until(b'> ')
        data = (bytes(range(256)) * 6)[:1460]
        # Deliberately fragment the UART payload; no command parsing inside it.
        for start in range(0, len(data), 17):
            self.write(data[start:start+17])
        self.until(b'SEND OK\r\n')
        self.assertEqual(self.receive(0, len(data)), data)

    def test_refused_connection_disconnect_reset(self):
        probe = socket.socket(); probe.bind(('127.0.0.1', 0))
        port = probe.getsockname()[1]; probe.close()
        self.command(b'AT+CIPSTART=0,"TCP","127.0.0.1",%d' % port,
                     b'\r\nERROR\r\n')
        self.open()
        answer = self.command(b'AT+CWQAP')
        self.assertIn(b'WIFI DISCONNECT', answer)
        self.command(b'AT+CIPSTART=0,"TCP","127.0.0.1",%d' % self.server.port,
                     b'\r\nERROR\r\n')
        self.command(b'AT+CWJAP="virtual",""')
        self.open()
        self.command(b'AT+RST')
        self.until(b'ready\r\n')
        self.command(b'ATE0')
        self.open()

if __name__ == '__main__':
    unittest.main()
