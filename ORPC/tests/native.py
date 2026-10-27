#!/usr/bin/env python3
"""Check pointer-sized scalars, literals, symbols, arithmetic and raw addresses."""
import ctypes
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile

compiler = str(Path(sys.argv[1]).resolve())
root = Path(__file__).resolve().parent.parent
word = ctypes.sizeof(ctypes.c_void_p)
bits = word * 8
maximum = (1 << (bits-1))-1
minimum_hex = f'{1 << (bits-1):X}H'
maximum_hex = f'{maximum:X}H'
one_real = '3FF0000000000000R' if word == 8 else '3F800000R'
three_bits = '4008000000000000H' if word == 8 else '40400000H'
precision = '1.0000000000000002' if word == 8 else '1.0000001192092896'
subnormal = '5.0E-324' if word == 8 else '1.0E-45'
huge_real = '1.7976931348623157E308' if word == 8 else '3.4028234663852886E38'
huge_bits = '7FEFFFFFFFFFFFFFH' if word == 8 else '7F7FFFFFH'
large = 4294967297 if word == 8 else 1073741825
shift = 40 if word == 8 else 20
env = dict(os.environ, ASAN_OPTIONS='detect_leaks=0')
env.pop('OCG_RUNTIME_DIR', None)
flags = '-std=c11 -O2 -Wall -Wextra -Werror'
ldflags = ''
if os.environ.get('SANITIZE') == '1':
    flags += ' -g -fsanitize=address,undefined'
    ldflags = '-fsanitize=address,undefined'

with tempfile.TemporaryDirectory() as directory:
    work = Path(directory)
    shutil.copy(root / 'ocg_runtime.h', work)
    (work / 'NativeBase.Mod').write_text(f'''MODULE NativeBase;
IMPORT SYSTEM;
CONST Max* = {maximum_hex}; Min* = {minimum_hex}; Large* = {large};
  Three* = 3.0; One* = {one_real}; Precise* = {precision};
  Tiny* = {subnormal}; Huge* = {huge_real};
  WrapAdd* = Max+1; WrapSub* = Min-1; WrapMul* = Max*2;
TYPE Rec* = RECORD ch*: CHAR; n*: INTEGER; r*: REAL; s*: SET END;
  P* = POINTER TO Rec;
  Callback* = PROCEDURE(n: INTEGER): INTEGER;
VAR rec*: Rec; value*: INTEGER;
PROCEDURE Inc*(n: INTEGER): INTEGER;
BEGIN RETURN n+1 END Inc;
PROCEDURE Many*(a,b,c,d,e,f,g,h,i,j: INTEGER): INTEGER;
BEGIN RETURN a+b+c+d+e+f+g+h+i+j END Many;
END NativeBase.
''')
    (work / 'NativeRoot.Mod').write_text(f'''MODULE NativeRoot;
IMPORT B := NativeBase, SYSTEM;
VAR n, a, e, shift: INTEGER; r, m: REAL; p, q: B.P; cb: B.Callback;
  source, destination: ARRAY 3 OF INTEGER; s: SET;
BEGIN
  ASSERT(SYSTEM.SIZE(INTEGER) = {word}); ASSERT(SYSTEM.SIZE(REAL) = {word});
  ASSERT(SYSTEM.SIZE(B.P) = {word}); ASSERT(SYSTEM.SIZE(SET) = 4);
  ASSERT(SYSTEM.SIZE(B.Rec) = {5*word});
  ASSERT((SYSTEM.SIZE(CHAR) = 1) & (SYSTEM.SIZE(BYTE) = 1));
  ASSERT(B.Large = {large}); ASSERT(B.Max = {maximum});
  ASSERT((B.WrapAdd = B.Min) & (B.WrapSub = B.Max) & (B.WrapMul = -2));
  ASSERT(-B.Min = B.Min);
  ASSERT(B.Three = 3.0); ASSERT(B.One = 1.0); ASSERT(B.Precise > 1.0);
  ASSERT(SYSTEM.VAL(INTEGER, B.Three) = {three_bits});
  ASSERT(SYSTEM.VAL(INTEGER, B.Tiny) = 1);
  ASSERT(SYSTEM.VAL(INTEGER, B.Huge) = {huge_bits});
  r := B.Precise; ASSERT(r > 1.0);
  r := SYSTEM.VAL(REAL, {three_bits}); ASSERT(r = 3.0);
  ASSERT(SYSTEM.VAL(INTEGER, r) = {three_bits});
  n := B.Max; INC(n); ASSERT(n = B.Min); DEC(n); ASSERT(n = B.Max);
  n := B.Max; n := n*2; ASSERT(n = -2);
  shift := {shift}; ASSERT(LSL(1, shift) = LSL(1, {shift}));
  ASSERT(ASR(B.Min, {bits-1}) = -1);
  ASSERT(ROR(1, 1) = B.Min); ASSERT(LSR(B.Min, {bits-1}) = 1);
  n := 1; e := 1; ASSERT(ROR(n,e) = B.Min);
  e := {bits}; ASSERT(ROR(n,e) = n); ASSERT(LSL(n,e) = n);
  r := 1.5; PACK(r, {bits-4}); UNPK(r, e); ASSERT((r = 1.5) & (e = {bits-4}));
  m := -1.5; ASSERT(FLOOR(m) = -2); ASSERT(ABS(m) = 1.5);
  n := {large}; a := SYSTEM.ADR(n); SYSTEM.GET(a, e); ASSERT(e = n);
  SYSTEM.PUT(a, B.Max); ASSERT(n = B.Max);
  r := B.Precise; a := SYSTEM.ADR(r); SYSTEM.GET(a, m); ASSERT(m = B.Precise);
  SYSTEM.PUT(a, B.Three); ASSERT(r = 3.0);
  a := SYSTEM.ADR(n);
  n := B.Min; ASSERT(SYSTEM.BIT(a, {bits-1}));
  source[0] := {large}; source[1] := B.Max; source[2] := B.Min;
  SYSTEM.COPY(SYSTEM.ADR(source), SYSTEM.ADR(destination), 3);
  ASSERT((destination[0] = {large}) & (destination[1] = B.Max) & (destination[2] = B.Min));
  NEW(p); p.n := {large}; p.r := B.Precise; a := ORD(p);
  q := SYSTEM.VAL(B.P, a); ASSERT((q = p) & (q.n = {large}) & (q.r > 1.0));
  a := ORD(B.Inc); cb := SYSTEM.VAL(B.Callback, a); ASSERT(cb(41) = 42);
  ASSERT(B.Many(1,2,3,4,5,6,7,8,9,10) = 55);
  s := {{0..31}}; ASSERT(ORD(s) = SYSTEM.VAL(INTEGER, s));
  s := {{0}}; e := 1; ASSERT(31 IN ROR(s,e)); ASSERT(ROR({{0}},1) = {{31}});
  n := {large}; CASE n OF {large}: n := -1 | -2: n := 0 END; ASSERT(n = -1)
END NativeRoot.
''')

    def run(args, success=True):
        result = subprocess.run(args, cwd=work, env=env, text=True,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        assert (result.returncode == 0) == success, (args, result.returncode, result.stdout)
        return result.stdout

    run([compiler, 'Compile', 'NativeBase.Mod/as'])
    # Independent symbol import checks full-width INTEGER and REAL constants.
    run([compiler, 'Compile', 'NativeRoot.Mod/as'])
    run([compiler, 'Compile', 'NativeRoot.Mod/ab'])
    run(shlex.split(os.environ.get('MAKE', 'make')) + ['-f', 'NativeRoot.mk',
        f'CC={os.environ.get("CC", "cc")}', f'CFLAGS={flags}', f'LDFLAGS={ldflags}'])
    run(['./NativeRoot'])

    (work / 'runtime_checks.c').write_text('''#include "ocg_runtime.h"
#include <assert.h>
int main(int argc,char **argv) {
  ocg_int lo=OCG_INT_MIN, hi=OCG_INT_MAX;
  switch(argc>1 ? atoi(argv[1]) : 0) {
  case 0:
    assert(ocg_addv(hi,-1)==hi-1); assert(ocg_subv(lo,-1)==lo+1);
    assert(ocg_mulv(lo,1)==lo); assert(ocg_mulv(lo,0)==0);
    assert(ocg_mulv(lo/2,2)==lo); assert(ocg_mulv(hi/2,2)==hi-1);
    assert(ocg_add(hi,1)==lo && ocg_sub(lo,1)==hi && ocg_mul(hi,2)==-2);
    assert(ocg_floor((ocg_real_t)lo)==lo); return 0;
  case 1: (void)ocg_addv(hi,1); break;
  case 2: (void)ocg_subv(lo,1); break;
  case 3: (void)ocg_mulv(hi,2); break;
  case 4: (void)ocg_mulv(lo,-1); break;
  case 5: (void)ocg_abs(lo); break;
  case 6: (void)ocg_floor(-(ocg_real_t)lo); break;
  case 7: (void)ocg_floor(NAN); break;
  }
  return 0;
}
''')
    run(shlex.split(os.environ.get('CC', 'cc')) + shlex.split(flags) +
        ['runtime_checks.c', '-lm', '-o', 'runtime_checks'])
    run(['./runtime_checks', '0'])
    for case in range(1, 8):
        output = run(['./runtime_checks', str(case)], success=False)
        assert 'Oberon trap:' in output, (case, output)

    for name, expression in [('BadInteger', str(maximum+1)),
                             ('BadReal', '1.0E9999'),
                             ('BadFloor', f'FLOOR({maximum+1}.0)'),
                             ('BadFold', f'{maximum_hex}+1')]:
        directive = '(*$V+*)' if name == 'BadFold' else ''
        (work / f'{name}.Mod').write_text(
            f'MODULE {name}; {directive} CONST bad = {expression}; END {name}.\n')
        run([compiler, 'Compile', f'{name}.Mod/s'], success=False)

    # Reject symbols produced for a different native scalar width.
    symbols = work / 'NativeBase.csmb'
    saved = symbols.read_bytes()
    changed = bytearray(saved)
    width = 8 + saved[8:].index(0) + 2
    changed[width] = 4 if word == 8 else 8
    symbols.write_bytes(changed)
    output = run([compiler, 'Compile', 'NativeRoot.Mod/as'], success=False)
    assert 'C symbol word size changed' in output, output

print(f'PASS: {bits}-bit INTEGER/REAL/address ABI, wide literals and symbols, IEEE precision/range, '
      'wraparound and checked arithmetic, shifts, layout, raw memory, pointer/callback conversions, '
      'large CASE labels, many parameters, diagnostics and symbol-width rejection')
