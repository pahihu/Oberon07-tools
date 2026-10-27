#!/usr/bin/env python3
"""Exercise anonymous names, imported records and the supplied C build repro."""
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile

compiler = str(Path(sys.argv[1]).resolve())
root = Path(__file__).resolve().parent.parent
env = dict(os.environ, ASAN_OPTIONS='detect_leaks=0')
env.pop('OCG_RUNTIME_DIR', None)
make = shlex.split(os.environ.get('MAKE', 'make'))
flags = '-std=c11 -O2 -Wall -Wextra -Werror'
ldflags = ''
if os.environ.get('SANITIZE') == '1':
    flags += ' -g -fsanitize=address,undefined'
    ldflags = '-fsanitize=address,undefined'


def run(args):
    result = subprocess.run(args, cwd=work, env=env, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    assert result.returncode == 0, (args, result.returncode, result.stdout)
    return result.stdout


with tempfile.TemporaryDirectory() as directory:
    work = Path(directory)
    shutil.copy(root / 'ocg_runtime.h', work)
    # Cross decimal digit boundaries and the old two-byte encoding's 254 boundary.
    declarations = ''.join(
        f'P{i}{"*" if i == 299 else ""} = POINTER TO RECORD value*: INTEGER END;\n'
        for i in range(300))
    (work / 'AnonTypes.Mod').write_text('MODULE AnonTypes;\nTYPE\n' + declarations + '''
  Anon_0* = RECORD value*: INTEGER END;
  Node* = POINTER TO RECORD value*: INTEGER; next*: Node END;
  Base = RECORD END;
  Derived* = RECORD (Base) value*: INTEGER END;
  Private = RECORD value: INTEGER END;
VAR p*, q*: POINTER TO RECORD value*: INTEGER END;
  a*, b*: RECORD value*: INTEGER END;
  hidden*: Private;
PROCEDURE ReadHidden*(r: Private): INTEGER;
BEGIN RETURN r.value END ReadHidden;
BEGIN NEW(p); p.value := 42; q := p;
  a.value := 12; b.value := 13; hidden.value := 17
END AnonTypes.
''')
    (work / 'AnonMain.Mod').write_text('''MODULE AnonMain;
IMPORT A := AnonTypes;
VAR p: A.P299; n: A.Node; d: A.Derived; r: A.Anon_0;
BEGIN NEW(p); p.value := 99; ASSERT(p.value = 99);
  ASSERT(A.p = A.q); ASSERT(A.q.value = 42);
  ASSERT((A.a.value = 12) & (A.b.value = 13));
  NEW(n); n.next := n; n.value := 23; ASSERT(n.next.value = 23);
  d.value := 5; r.value := 7; ASSERT(d.value+r.value = 12);
  ASSERT(A.ReadHidden(A.hidden) = 17)
END AnonMain.
''')
    run([compiler, 'Compile', 'AnonMain.Mod/b'])
    header = (work / 'AnonTypes.h').read_text()
    for i in [0, 9, 10, 99, 100, 253, 254, 299]:
        assert f'O_AnonTypes__Anon{i};' in header, i
    assert 'O_AnonTypes_Anon_0;' in header
    command = make + ['-f', 'AnonMain.mk', f'CC={os.environ.get("CC", "cc")}',
                      f'CFLAGS={flags}', f'LDFLAGS={ldflags}']
    run(command)
    run(['./AnonMain'])
    # Re-import .csmb files in a separate translation invocation as well.
    (work / 'AnonSymbol.Mod').write_text('''MODULE AnonSymbol;
IMPORT A := AnonTypes;
PROCEDURE Check*;
BEGIN ASSERT(A.q.value = 42); ASSERT(A.ReadHidden(A.hidden) = 17)
END Check;
END AnonSymbol.
''')
    run([compiler, 'Compile', 'AnonSymbol.Mod/s'])
    run(shlex.split(os.environ.get('CC', 'cc')) + shlex.split(flags) +
        ['-c', 'AnonSymbol.c', '-o', 'AnonSymbol.o'])
    (work / 'InvalidName.Mod').write_text(
        'MODULE InvalidName; TYPE _Anon0 = RECORD END; END InvalidName.\n')
    rejected = subprocess.run([compiler, 'Compile', 'InvalidName.Mod/s'],
                              cwd=work, env=env, text=True,
                              stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    assert rejected.returncode != 0, rejected.stdout
    assert not (work / 'InvalidName.c').exists()

with tempfile.TemporaryDirectory() as directory:
    work = Path(directory)
    for path in (root / 'tests/anonymous').glob('*.Mod'):
        shutil.copy(path, work)
    shutil.copy(root / 'ocg_runtime.h', work)
    shutil.copy(root / 'tests/animals/emb_putchar.c', work)
    run([compiler, 'Compile', 'AnonRecTest.Mod/ab'])
    # The original repro contains raw RISC stack/descriptor introspection;
    # verify C compilation/linking here, not execution of that target-specific code.
    run(make + ['-f', 'AnonRecTest.mk', f'CC={os.environ.get("CC", "cc")}',
                'CFLAGS=-std=c11 -O2 -Werror=incompatible-pointer-types -Werror=int-conversion',
                'EXTRA_OBJS=emb_putchar.o'])
    assert (work / 'AnonRecTest').exists()

print('PASS: underscore-prefixed anonymous C names through 300 records, embedded source underscores, '
      'leading source underscore rejection, imported anonymous variables, '
      'recursive pointers, private bases/parameters, symbol imports, and original AnonRecTest C build')
