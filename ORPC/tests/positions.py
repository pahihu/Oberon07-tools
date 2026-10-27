#!/usr/bin/env python3
"""Trap locations survive imported and nested calls without shared state."""
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import tempfile

compiler = str(Path(sys.argv[1]).resolve())
root = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory() as directory:
    work = Path(directory)
    shutil.copy(root / 'ocg_runtime.h', work)
    (work / 'LocationValue.Mod').write_text('''MODULE LocationValue;
PROCEDURE Value*(): INTEGER;
BEGIN ASSERT(TRUE); RETURN 2 END Value;
END LocationValue.
''')
    cases = [
        ('answer := a[LocationValue.Value()]', 'index'),
        ('ASSERT(LocationValue.Value() = 0)', 'ASSERT/type guard'),
        ('answer := 7 DIV (LocationValue.Value()-2)', 'DIV divisor must be positive'),
        ('CASE LocationValue.Value() OF 0: answer := 0 END', 'CASE'),
    ]
    env = dict(os.environ)
    env.pop('OCG_RUNTIME_DIR', None)
    for statement, reason in cases:
        source = ('MODULE LocationMain; IMPORT LocationValue;\n'
                  'VAR a*: ARRAY 2 OF INTEGER; answer*: INTEGER;\n'
                  f'BEGIN {statement}\nEND LocationMain.\n')
        (work / 'LocationMain.Mod').write_text(source)
        result = subprocess.run([compiler, 'Compile', 'LocationMain.Mod/b'], cwd=work,
                                env=env, text=True, capture_output=True)
        assert result.returncode == 0 and 'compilation FAILED' not in result.stdout, result.stdout
        cc = shlex.split(os.environ.get('CC', 'cc'))
        subprocess.run(cc + ['-std=c11', '-O2', '-Wall', '-Wextra', '-Werror',
                             'LocationMain.c', 'LocationValue.c', '-lm', '-o', 'check'],
                       cwd=work, check=True)
        result = subprocess.run([str(work / 'check')], cwd=work, text=True, capture_output=True)
        assert result.returncode != 0
        match = re.search(r'Oberon trap: (.*) in module (\w+) at position (\d+)', result.stderr)
        assert match and match[1] == reason and match[2] == 'LocationMain', result.stderr
        position = int(match[3])
        assert source.index('BEGIN') <= position < len(source), (position, source)
        generated = (work / 'LocationMain.c').read_text()
        assert re.search(r'"LocationMain",\s*' + str(position) + r'\)', generated), generated

print('PASS: runtime trap module and ORS.Pos metadata, nested/imported calls, ASSERT, bounds, DIV and CASE')
