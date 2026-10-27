#!/usr/bin/env python3
"""Check exact dynamic types for whole-record assignment to VAR parameters."""
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
flags = '-std=c11 -O2 -Wall -Wextra -Werror'
if os.environ.get('SANITIZE') == '1':
    flags += ' -g -fsanitize=address,undefined'

with tempfile.TemporaryDirectory() as directory:
    work = Path(directory)
    shutil.copy(root / 'ocg_runtime.h', work)
    (work / 'AssignAPI.Mod').write_text('''MODULE AssignAPI;
TYPE R0* = RECORD i*: INTEGER END;
  R1* = RECORD (R0) j*: INTEGER END;
  R2* = RECORD (R1) k*: INTEGER END;
  P0* = POINTER TO R0;
  P1* = POINTER TO R1;
  Holder* = RECORD child*: R0 END;
  ExtendedHolder* = RECORD (Holder) extra*: INTEGER END;
PROCEDURE Exchange*(from: R0; VAR to: R0);
BEGIN to := from END Exchange;
PROCEDURE Exchange1*(from: R1; VAR to: R1);
BEGIN to := from END Exchange1;
PROCEDURE Forward*(from: R0; VAR to: R0);
BEGIN Exchange(from, to) END Forward;
PROCEDURE Field*(VAR to: R0);
BEGIN to.i := 19 END Field;
PROCEDURE Child*(from: R0; VAR to: Holder);
BEGIN to.child := from END Child;
PROCEDURE Guarded*(from: R1; VAR to: R0);
BEGIN to(R1) := from END Guarded;
PROCEDURE CaseAssign*(from: R1; VAR to: R0);
BEGIN CASE to OF R1: to := from END END CaseAssign;
END AssignAPI.
''')
    (work / 'AssignUse.Mod').write_text('''MODULE AssignUse;
IMPORT A := AssignAPI;
TYPE External = RECORD (A.R0) x: INTEGER END;
VAR s0, r0: A.R0; s1, r1: A.R1; s2, r2: A.R2;
  p: A.P0; q: A.P1; holder: A.ExtendedHolder; ext: External;
PROCEDURE Run*(which: INTEGER);
BEGIN s0.i := 11; s1.i := 21; s1.j := 22;
  s2.i := 31; s2.j := 32; s2.k := 33;
  CASE which OF
    0:
      A.Exchange(s0, r0); ASSERT(r0.i = 11);
      A.Exchange(s1, r0); ASSERT(r0.i = 21);
      A.Exchange1(s1, r1); ASSERT((r1.i = 21) & (r1.j = 22));
      A.Exchange1(s2, r1); ASSERT((r1.i = 31) & (r1.j = 32));
      A.Forward(s0, r0); ASSERT(r0.i = 11);
      A.Field(r1); ASSERT(r1.i = 19);
      A.Child(s0, holder); ASSERT(holder.child.i = 11);
      A.Guarded(s1, r1); A.CaseAssign(s1, r1);
      ASSERT((r1.i = 21) & (r1.j = 22));
      r0 := s1; ASSERT(r0.i = 21);
      NEW(q); q.j := 55; p := q; p^ := s0;
      ASSERT((p IS A.P1) & (q.i = 11) & (q.j = 55))
  | 1: A.Exchange(s0, r1)
  | 2: A.Exchange(s1, r1)
  | 3: A.Forward(s0, r1)
  | 4: NEW(q); p := q; A.Exchange(s0, p^)
  | 5: A.Guarded(s1, r2)
  | 6: A.CaseAssign(s1, r2)
  | 7: A.Exchange(s0, ext)
  END
END Run;
END AssignUse.
''')
    (work / 'assignment_driver.c').write_text('''#include "AssignUse.h"
int main(int argc,char **argv) {
  O_AssignUse__init();
  O_AssignUse_Run(argc>1 ? atoi(argv[1]) : 0);
  return 0;
}
''')

    def run(args):
        result = subprocess.run(args, cwd=work, env=env, text=True,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        assert result.returncode == 0, (args, result.returncode, result.stdout)
        return result.stdout

    # Separate invocations exercise imported signatures and runtime type tags.
    run([compiler, 'Compile', 'AssignAPI.Mod/s'])
    run([compiler, 'Compile', 'AssignUse.Mod/s'])
    run(shlex.split(os.environ.get('CC', 'cc')) + shlex.split(flags) +
        ['AssignAPI.c', 'AssignUse.c', 'assignment_driver.c', '-lm', '-o', 'checks'])
    run(['./checks', '0'])
    for case in range(1, 8):
        result = subprocess.run(['./checks', str(case)], cwd=work, env=env,
                                text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        assert result.returncode != 0, (case, result.stdout)
        assert 'Oberon trap: VAR record assignment type' in result.stdout, (case, result.stdout)

print('PASS: exact-type VAR record assignment, derived-source slices, field writes, '
      'forwarding, pointer actuals, guarded/CASE targets, external extensions, and 7 assignment traps')
