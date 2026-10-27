#!/usr/bin/env python3
"""Check Makefile runtime selection and dependency tracking."""
import os
from pathlib import Path
import shlex
import subprocess
import sys
import tempfile
import time

compiler = str(Path(sys.argv[1]).resolve())
root = Path(__file__).resolve().parent.parent
runtime = (root / 'ocg_runtime.h').read_bytes()
make = shlex.split(os.environ.get('MAKE', 'make'))
cc = os.environ.get('CC', 'cc')
flags = '-std=c11 -O2 -Wall -Wextra -Werror'
link_flags = ''
if os.environ.get('SANITIZE') == '1':
    flags += ' -g -fsanitize=address,undefined'
    link_flags = '-fsanitize=address,undefined'

for folder in [None, '', 'runtime', 'shared runtime', 'rt$cash#tag', "rt'quote"]:
    with tempfile.TemporaryDirectory() as directory:
        work = Path(directory)
        env = dict(os.environ, ASAN_OPTIONS='detect_leaks=0')
        env.pop('OCG_RUNTIME_DIR', None)
        source = work / 'RuntimeMain.Mod'
        source.write_text('MODULE RuntimeMain; BEGIN ASSERT(TRUE) END RuntimeMain.\n')
        if folder:
            selected = work / folder
            selected.mkdir()
            header = selected / 'ocg_runtime.h'
            header.write_bytes(runtime)
            # A selected shared runtime must take precedence over a local copy.
            (work / 'ocg_runtime.h').write_text('#error wrong local runtime header selected\n')
            env['OCG_RUNTIME_DIR'] = str(selected)
        else:
            header = work / 'ocg_runtime.h'
            header.write_bytes(runtime)
            if folder == '':
                env['OCG_RUNTIME_DIR'] = ''

        def run(command, success=True):
            result = subprocess.run(command, cwd=work, env=env, text=True,
                                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            if (result.returncode == 0) != success:
                raise AssertionError(f'{command}: {result.returncode}\n{result.stdout}')
            return result.stdout

        run([compiler, 'Compile', 'RuntimeMain.Mod/b'])
        # Extra C sources need the selected directory on the include search path.
        (work / 'runtime_probe.c').write_text(
            '#include <ocg_runtime.h>\nint runtime_probe(void) { return 0; }\n')
        command = make + ['-f', 'RuntimeMain.mk', f'CC={cc}',
                          f'CFLAGS={flags}', f'LDFLAGS={link_flags}',
                          'EXTRA_OBJS=runtime_probe.o']
        run(command)
        run(['./RuntimeMain'])
        stamp = (work / 'RuntimeMain.o').stat().st_mtime_ns
        executable = (work / 'RuntimeMain').stat().st_mtime_ns
        run(command)
        assert (work / 'RuntimeMain.o').stat().st_mtime_ns == stamp
        assert (work / 'RuntimeMain').stat().st_mtime_ns == executable

        # Whole-second separation also supports macOS's older make versions.
        next_second = (max(stamp, executable) // 1_000_000_000 + 1) * 1_000_000_000
        while time.time_ns() <= next_second:
            time.sleep(0.02)
        header.write_bytes(runtime + b'\n#error selected runtime change was detected\n')
        output = run(command, success=False)
        assert 'selected runtime change was detected' in output, output
        assert (work / 'RuntimeMain').stat().st_mtime_ns == executable

print('PASS: runtime environment directory, unset/empty local fallback, shared-header precedence, '
      'escaped directories, no-op builds, and runtime-header dependencies')
