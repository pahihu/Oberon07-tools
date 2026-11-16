#!/usr/bin/env python3
"""End-to-end UART test. Usage: python3 tests/test_uart_sim.py ./ORTool0"""
from pathlib import Path
import select
import struct
import subprocess
import sys
import tempfile

exe = str(Path(sys.argv[1]).resolve())
# A binary image reserves the first eight words for startup/header fields.
# Poll rxRdy, read a byte, poll txRdy, write that byte, HALT.
code = [0xE7000007] + [0] * 7 + [
    0x5100FFC8,  # MOV R1,-56 (UART data byte address)
    0x80100004,  # LDR R0,R1,4 (status)
    0x40040001,  # AND R0,R0,1
    0xE1FFFFFD,  # BEQ back to RX status read
    0x82100000,  # LDR R2,R1,0 (data)
    0x80100004,  # LDR R0,R1,4 (status)
    0x40040002,  # AND R0,R0,2
    0xE1FFFFFD,  # BEQ back to TX status read
    0xA2100000,  # STR R2,R1,0 (data)
    0xE7FFFFFF,  # HALT
]
with tempfile.TemporaryDirectory() as temp:
    Path(temp, 'Echo.bin').write_bytes(struct.pack('<%dI' % len(code), *code))
    for byte in (b'A', b'\x00', b'\x80', b'\xff'):
        child = subprocess.Popen([exe, 'Execute', 'Echo.bin'], cwd=temp,
                                 stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                 stderr=subprocess.PIPE, bufsize=0)
        try:
            # Read diagnostics until the image is loaded and RX polling starts.
            prefix = bytearray()
            while b'load Echo.bin\n' not in prefix:
                assert select.select([child.stdout], [], [], 3)[0], 'load timed out'
                ch = child.stdout.read(1)
                assert ch, 'simulator exited before loading'
                prefix.extend(ch)
            assert child.poll() is None, 'simulator did not wait for RX'
            output, errors = child.communicate(byte, timeout=3)
            assert child.returncode == 0, (output, errors)
            assert output.startswith(byte + b'\n#clks='), output
            assert not errors, errors
        finally:
            if child.poll() is None:
                child.kill()
                child.wait()
print('UART simulator: ASCII, NUL, 0x80 and 0xFF passed')
