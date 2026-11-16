#!/usr/bin/env python3
"""Run the original guest TCPNet through the CPU/MMIO against a real TCP peer.
Usage: python3 tests/test_tcp_guest.py ORP ORL ORTool0 /path/to/pkg
Requires the numeric-CASE ORP compiler and the unmodified supplied guest modules.
"""
from pathlib import Path
import shutil
import socket
import subprocess
import sys
import tempfile
import threading
import time

orp, orl, simulator = [str(Path(p).resolve()) for p in sys.argv[1:4]]
pkg = Path(sys.argv[4]).resolve()
sources = ['Main', 'Machine', 'UART', 'Out', 'MainDebug', 'Timers', 'Storage',
           'Coroutines', 'WatchDog', 'DateTime', 'COberon', 'TCPUART', 'TCPNet']
server = socket.socket()
server.bind(('127.0.0.1', 0))
server.listen(1)
server.settimeout(15)
port = server.getsockname()[1]
errors = []

def peer():
    try:
        connection, _ = server.accept()
        with connection:
            connection.settimeout(10)
            data = bytearray()
            while len(data) < 256:
                chunk = connection.recv(256 - len(data))
                assert chunk, 'guest closed early'
                data.extend(chunk)
            assert data == bytes(range(256)), data
            # Guest's coroutine must sleep while other scheduler tasks run.
            time.sleep(.05)
            connection.sendall(data)
    except BaseException as error:
        errors.append(error)
    finally:
        server.close()

thread = threading.Thread(target=peer, daemon=True)
thread.start()
with tempfile.TemporaryDirectory() as folder:
    temp = Path(folder)
    for name in sources:
        shutil.copyfile(pkg / (name + '.Mod'), temp / (name + '.Mod'))
    shutil.copyfile(Path(__file__).parent / 'guest/TCPMMIOTest.Mod', temp / 'TCPMMIOTest.Mod')
    result = subprocess.run([orp, 'Compile', *[n + '.Mod/as' for n in sources],
                             'TCPMMIOTest.Mod/as'], cwd=temp, capture_output=True, timeout=30)
    output = result.stdout + result.stderr
    assert result.returncode == 0 and b'FAILED' not in output and b'error' not in output, output.decode(errors='replace')
    result = subprocess.run([orl, 'Link', 'TCPMMIOTest/i'], cwd=temp,
                            capture_output=True, timeout=15)
    assert result.returncode == 0 and (temp / 'TCPMMIOTest.bin').is_file(), result.stdout
    result = subprocess.run([simulator, 'Execute', 'TCPMMIOTest.bin/aiw', str(port)],
                            cwd=temp, stdin=subprocess.DEVNULL, capture_output=True, timeout=20)
    output = result.stdout + result.stderr
    print(output.decode(errors='replace'))
    assert result.returncode == 0 and b'TCPMMIOTest PASS' in output and b'TRAP' not in output, output
thread.join(timeout=2)
assert not errors, errors
print('Real guest scheduler + TCPNet + MMIO + host TCP passed')
