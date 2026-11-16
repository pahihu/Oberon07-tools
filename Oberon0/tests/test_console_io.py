#!/usr/bin/env python3
"""Exercise the real POSIX backend in subprocesses (Linux/macOS).
Usage: python3 tests/test_console_io.py /path/to/o2c/system
Only Python 3 and a C compiler are required; no installed Oberon compiler.
"""
import fcntl
import os
from pathlib import Path
import pty
import select
import signal
import subprocess
import sys
import tempfile
import termios
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
SYSTEM = Path(sys.argv.pop(1)).resolve()
DRIVER = r'''
#include "_OGCC.h"
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
ModuleId add_module(const char name[]) { (void)name; return 1; }
extern void _init_ConsoleIO(void), ConsoleIO_Close(void);
extern int ConsoleIO_Open(void), ConsoleIO_Status(void);
extern int ConsoleIO_Read(void), ConsoleIO_Write(int);
int main(int argc, char **argv) {
    int i, c, r, before, after;
    _init_ConsoleIO();
    before = fcntl(0, F_GETFL);
    if (!ConsoleIO_Open() || !ConsoleIO_Open()) return 10;
    if (argc > 1 && strcmp(argv[1], "full") == 0) {
        before = fcntl(1, F_GETFL);
        r = ConsoleIO_Write(65);
        after = fcntl(1, F_GETFL);
        fprintf(stderr, "FULL %d %d %d\n", ConsoleIO_Status(), r, before == after);
    } else if (argc > 1 && strcmp(argv[1], "signal") == 0) {
        fprintf(stderr, "OPEN\n");
        for (;;) pause();
    } else {
        fprintf(stderr, "OPEN %d %d\n", ConsoleIO_Status(), ConsoleIO_Read());
        /* Polling must not consume or duplicate input, including NUL/0xff. */
        for (i = 0; i < 3; ++i) {
            do { r = ConsoleIO_Status(); } while (!(r & 1));
            if (!(ConsoleIO_Status() & 1)) return 11;
            c = ConsoleIO_Read();
            fprintf(stderr, "RX %d\n", c);
            do { r = ConsoleIO_Write(c); } while (r == 0);
            if (r != 1) return 12;
        }
        fprintf(stderr, "END %d %d\n", ConsoleIO_Read(), fcntl(0, F_GETFL) == before);
    }
    /* Test atexit cleanup; no explicit Close here. */
    return 0;
}
'''


def line(stream, timeout=3):
    # Unbuffered stderr avoids buffered readline hiding data from select.
    result = bytearray()
    end = time.monotonic() + timeout
    while not result.endswith(b'\n'):
        remaining = end - time.monotonic()
        if remaining <= 0 or not select.select([stream], [], [], remaining)[0]:
            raise AssertionError(f'child timed out: {bytes(result)!r}')
        ch = os.read(stream.fileno(), 1)
        if not ch:
            raise AssertionError(f'child exited early: {bytes(result)!r}')
        result.extend(ch)
    return bytes(result)


class ConsoleTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        driver = Path(cls.temp.name) / 'driver.c'
        driver.write_text(DRIVER)
        cls.exe = str(Path(cls.temp.name) / 'console-test')
        subprocess.run([os.environ.get('CC', 'cc'), '-std=c99', '-Wall', '-Wextra',
                        '-Werror', '-I' + str(SYSTEM), str(driver),
                        str(ROOT / 'ConsoleIO.c'), '-o', cls.exe], check=True)

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def start(self, *args, **kwargs):
        p = subprocess.Popen([self.exe, *args], stderr=subprocess.PIPE,
                             bufsize=0, **kwargs)
        self.addCleanup(self.stop, p)
        return p

    @staticmethod
    def stop(p):
        if p.poll() is None:
            p.kill()
            p.wait()
        for stream in (p.stdin, p.stdout, p.stderr):
            if stream:
                stream.close()

    def test_pipe_empty_bytes_eof(self):
        p = self.start(stdin=subprocess.PIPE, stdout=subprocess.PIPE)
        self.assertEqual(line(p.stderr), b'OPEN 2 -1\n')
        p.stdin.write(b'\x00\x80\xff')
        p.stdin.close()
        for value in (0, 128, 255):
            self.assertEqual(line(p.stderr), f'RX {value}\n'.encode())
        self.assertEqual(line(p.stderr), b'END -2 1\n')
        self.assertEqual(p.stdout.read(), b'\x00\x80\xff')
        self.assertEqual(p.wait(timeout=3), 0)

    def test_pty_no_enter_no_echo_and_restore(self):
        master, slave = pty.openpty()
        self.addCleanup(os.close, master)
        self.addCleanup(os.close, slave)
        saved = termios.tcgetattr(slave)
        p = self.start(stdin=slave, stdout=subprocess.PIPE)
        self.assertEqual(line(p.stderr), b'OPEN 2 -1\n')
        active = termios.tcgetattr(slave)
        self.assertFalse(active[3] & (termios.ICANON | termios.ECHO))
        self.assertTrue(active[3] & termios.ISIG)
        os.write(master, b'A\x00\xff')
        for value in (65, 0, 255):
            self.assertEqual(line(p.stderr), f'RX {value}\n'.encode())
        self.assertEqual(line(p.stderr), b'END -1 1\n')
        self.assertEqual(p.stdout.read(), b'A\x00\xff')
        self.assertEqual(p.wait(timeout=3), 0)
        self.assertEqual(termios.tcgetattr(slave), saved)
        self.assertFalse(select.select([master], [], [], 0)[0], 'input was echoed')

    def test_full_output_pipe_does_not_block(self):
        rd, wr = os.pipe()
        self.addCleanup(os.close, rd)
        self.addCleanup(os.close, wr)
        original = fcntl.fcntl(wr, fcntl.F_GETFL)
        fcntl.fcntl(wr, fcntl.F_SETFL, original | os.O_NONBLOCK)
        try:
            while True:
                os.write(wr, b'x' * 4096)
        except BlockingIOError:
            pass
        fcntl.fcntl(wr, fcntl.F_SETFL, original)
        p = self.start('full', stdin=subprocess.DEVNULL, stdout=wr)
        self.assertEqual(line(p.stderr), b'FULL 0 0 1\n')
        self.assertEqual(p.wait(timeout=3), 0)
        self.assertEqual(fcntl.fcntl(wr, fcntl.F_GETFL), original)

    def test_signal_restores_terminal(self):
        for sig in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP, signal.SIGQUIT):
            with self.subTest(sig=sig):
                master, slave = pty.openpty()
                try:
                    saved = termios.tcgetattr(slave)
                    p = self.start('signal', stdin=slave, stdout=subprocess.DEVNULL)
                    self.assertEqual(line(p.stderr), b'OPEN\n')
                    p.send_signal(sig)
                    self.assertEqual(p.wait(timeout=3), -sig)
                    self.assertEqual(termios.tcgetattr(slave), saved)
                finally:
                    os.close(master)
                    os.close(slave)


if __name__ == '__main__':
    unittest.main()
