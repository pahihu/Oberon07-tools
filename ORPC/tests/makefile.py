#!/usr/bin/env python3
"""Check make decisions using executed compiler calls and stable-output timestamps."""
import os
from pathlib import Path
import shutil
import json
import shlex
import subprocess
import sys
import tempfile
import time

compiler = str(Path(sys.argv[1]).resolve())
root = Path(__file__).resolve().parent.parent
cc = shlex.split(os.environ.get('CC', 'cc'))
make = shlex.split(os.environ.get('MAKE', 'make'))
coarse_times = os.environ.get('O7_TEST_COARSE_MTIME') == '1'
NS_PER_SECOND = 1_000_000_000
flags = '-std=c11 -O2 -Wall -Wextra -Werror'
link_flags = ''
if os.environ.get('SANITIZE') == '1':
    flags += ' -g -fsanitize=address,undefined'
    link_flags = '-fsanitize=address,undefined'
env = dict(os.environ, ASAN_OPTIONS='detect_leaks=0')
env.pop('OCG_RUNTIME_DIR', None)

def prepare_recorder(work):
    """Record executed compiler calls, independently of filesystem timestamps."""
    wrapper = work / 'o7cc.py'
    wrapper.write_text(r"""#!/usr/bin/env python3
import json
import os
import sys
record = (json.dumps(sys.argv[1:]) + '\n').encode()
fd = os.open(os.environ['O7_TEST_CC_LOG'], os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o600)
try:
    os.write(fd, record)
finally:
    os.close(fd)
command = json.loads(os.environ['O7_TEST_REAL_CC']) + sys.argv[1:]
os.execvp(command[0], command)
""")
    wrapper.chmod(0o755)


def compiler_calls():
    log = work / 'compiler-calls.jsonl'
    return [json.loads(line) for line in log.read_text().splitlines()] if log.exists() else []


def before_mutation():
    """GNU make on macOS can compare only whole seconds, even on APFS.

    Wait for the wall clock to pass every existing output's second before
    changing an input. Do not fake future timestamps: that can cause the
    generated makefile's regeneration rule to loop or report clock skew.
    """
    latest = max((p.stat().st_mtime_ns for p in work.rglob('*') if p.is_file()), default=0)
    next_second = (latest // NS_PER_SECOND + 1) * NS_PER_SECOND
    deadline = time.monotonic() + 5
    while time.time_ns() <= next_second:
        if time.monotonic() >= deadline:
            raise AssertionError('test files have future timestamps; check the system clock')
        time.sleep(0.02)


with tempfile.TemporaryDirectory() as directory:
    work = Path(directory)
    (work / 'src').mkdir()
    for path in (root / 'tests/build').glob('Build*.Mod'):
        shutil.copy(path, work / 'src' / path.name)
    shutil.copy(root / 'ocg_runtime.h', work)

    def run(args, success=True):
        call_env = dict(env, O7_TEST_CC_LOG=str(work / 'compiler-calls.jsonl'),
                        O7_TEST_REAL_CC=json.dumps(cc))
        result = subprocess.run(args, cwd=work, env=call_env, text=True,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        if (result.returncode == 0) != success:
            raise AssertionError(f'{args}: {result.returncode}\n{result.stdout}')
        if coarse_times:
            # Simulate coarse filesystems on Linux as an additional regression mode.
            for path in work.rglob('*'):
                if path.is_file():
                    stat = path.stat()
                    mtime = stat.st_mtime_ns // NS_PER_SECOND * NS_PER_SECOND
                    os.utime(path, ns=(stat.st_atime_ns, mtime))
        return result.stdout

    prepare_recorder(work)
    command = make + ['-f', 'BuildMain.mk', '-j4', 'CC=./o7cc.py',
               f'CFLAGS={flags}', f'LDFLAGS={link_flags}']
    modules = ['BuildBase', 'BuildLeft', 'BuildRight', 'BuildMain']

    def snapshot():
        return {'times': {m: (work / (m + '.o')).stat().st_mtime_ns for m in modules},
                'calls': len(compiler_calls())}

    def check_changed(before, expected):
        calls = compiler_calls()[before['calls']:]
        compiled = [Path(args[args.index('-o')+1]).stem
                    for args in calls if '-c' in args and '-o' in args]
        actual = set(compiled)
        assert actual == set(expected) and len(compiled) == len(actual), (actual, expected, calls)
        run(['./BuildMain'])

    def edit(path, before, after):
        before_mutation()
        file = work / path
        text = file.read_text()
        assert before in text, before
        file.write_text(text.replace(before, after))

    run([compiler, 'Compile', '"src/BuildMain.Mod"/b'])
    text = (work / 'BuildMain.mk').read_text()
    assert 'TARGET := BuildMain$(EXEEXT)' in text
    assert 'BuildMain.o: BuildMain.c $(OCG_RUNTIME_DEP) BuildMain.h BuildLeft.h BuildBase.h BuildRight.h' in text
    run(command)
    run(['./BuildMain'])
    initial = snapshot()
    executable = (work / 'BuildMain').stat().st_mtime_ns
    run(command)
    assert snapshot() == initial
    assert (work / 'BuildMain').stat().st_mtime_ns == executable

    # A repeated /b preserves all identical generated outputs, including .mk.
    outputs = [p for p in work.iterdir() if p.suffix in {'.c', '.h', '.mk'}]
    output_times = {p: p.stat().st_mtime_ns for p in outputs}
    run([compiler, 'Compile', '"src/BuildMain.Mod"/b'])
    assert all(p.stat().st_mtime_ns == t for p, t in output_times.items())
    run(command)
    assert snapshot() == initial
    assert (work / 'BuildMain').stat().st_mtime_ns == executable

    # Source body edit: make retranslates, but only that module's C changes.
    headers = {p: p.stat().st_mtime_ns for p in work.glob('*.h')}
    edit('src/BuildBase.Mod', 'INC(order)', 'order := order+1')
    log = run(command)
    assert 'compiling BuildBase' in log
    check_changed(initial, ['BuildBase'])
    assert all(p.stat().st_mtime_ns == t for p, t in headers.items())
    after_body = snapshot()
    run(command)
    assert snapshot() == after_body

    # Branch interface edit: rebuild its importer, but leave siblings alone.
    before = snapshot()
    edit('src/BuildLeft.Mod', 'BEGIN B.Advance',
         'VAR extra*: INTEGER;\nBEGIN B.Advance')
    run(command)
    check_changed(before, ['BuildLeft', 'BuildMain'])

    # Shared interface edit: all transitive importers depend on its header.
    before = snapshot()
    edit('src/BuildBase.Mod', 'VAR order*: INTEGER;',
         'VAR order*: INTEGER; other*: INTEGER;')
    run(command)
    check_changed(before, modules)

    # Adding and subsequently deleting a source/import updates the link graph.
    (work / 'src/BuildExtra.Mod').write_text(
        'MODULE BuildExtra; VAR value*: INTEGER; BEGIN value := 9 END BuildExtra.\n')
    before = snapshot()
    edit('src/BuildMain.Mod', 'S := SYSTEM;', 'S := SYSTEM, X := BuildExtra;')
    edit('src/BuildMain.Mod', 'ASSERT(B.order=4)',
         'ASSERT(B.order=4); ASSERT(X.value=9)')
    run(command)
    check_changed(before, ['BuildMain', 'BuildExtra'])
    assert (work / 'BuildExtra.o').exists()
    assert 'BuildExtra' in (work / 'BuildMain.mk').read_text()
    before = snapshot()
    edit('src/BuildMain.Mod', ', X := BuildExtra', '')
    edit('src/BuildMain.Mod', '; ASSERT(X.value=9)', '')
    (work / 'src/BuildExtra.Mod').unlink()
    log = run(command)
    check_changed(before, ['BuildMain'])
    assert 'BuildExtra' not in (work / 'BuildMain.mk').read_text()
    link_line = next(line for line in log.splitlines() if '-o BuildMain ' in line)
    assert 'BuildExtra.o' not in link_line

    # Explicit transitive dependencies still work if compiler .d files vanish.
    for path in work.glob('*.d'):
        path.unlink()
    before = snapshot()
    before_mutation()
    os.utime(work / 'BuildBase.h', None)
    run(command)
    check_changed(before, modules)

    # Editing a C file directly rebuilds its own object and relinks.
    before = snapshot()
    before_mutation()
    with (work / 'BuildRight.c').open('a') as stream:
        stream.write('\n/* C-only change */\n')
    run(command)
    check_changed(before, ['BuildRight'])

    # Standard .d tracking adds dependencies outside the Oberon import graph.
    before_mutation()
    (work / 'custom.h').write_text('#define CUSTOM_MARKER 1\n')
    with (work / 'BuildRight.c').open('a') as stream:
        stream.write('#include "custom.h"\n')
    run(command)
    before = snapshot()
    before_mutation()
    (work / 'custom.h').write_text('#define CUSTOM_MARKER 2\n')
    run(command)
    check_changed(before, ['BuildRight'])

    # Runtime header changes invalidate every generated translation unit.
    before = snapshot()
    before_mutation()
    os.utime(work / 'ocg_runtime.h', None)
    run(command)
    check_changed(before, modules)

    # clean removes owned build products and leaves generated sources intact.
    run(command + ['clean'])
    assert all(not (work / (m + '.o')).exists() for m in modules)
    assert all((work / (m + '.c')).exists() for m in modules)
    assert (work / 'BuildMain.mk').exists()
    run(command)
    run(['./BuildMain'])

    # clobber also removes translation outputs, scoped to this module graph.
    for module in modules:
        (work / (module + '.pos')).write_text('position data\n')
    (work / 'handwritten.c').write_text('/* keep */\n')
    (work / 'handwritten.h').write_text('/* keep */\n')
    run(command + ['clobber'])
    for module in modules:
        for suffix in ['.c', '.h', '.csmb', '.pos', '.o', '.d']:
            assert not (work / (module + suffix)).exists(), (module, suffix)
    assert not (work / 'BuildMain').exists()
    for name in ['handwritten.c', 'handwritten.h', 'ocg_runtime.h', 'BuildMain.mk',
                 'src/BuildMain.Mod']:
        assert (work / name).exists(), name
    run(command + ['clobber'])  # Repeated cleanup tolerates absent outputs.
    run([compiler, 'Compile', '"src/BuildMain.Mod"/b'])
    run(command)
    run(['./BuildMain'])

    # Failed translation must stop make before compilation/linking proceeds.
    executable = (work / 'BuildMain').stat().st_mtime_ns
    edit('src/BuildMain.Mod', 'S := SYSTEM;', 'S := SYSTEM, MissingModule;')
    log = run(command, success=False)
    assert 'MissingModule' in log
    assert (work / 'BuildMain').stat().st_mtime_ns == executable

# Generated make syntax and shell arguments also survive common path characters.
for folder in ['src space', 'src#hash', 'src$cash', "src'quote"]:
    with tempfile.TemporaryDirectory() as directory:
        work = Path(directory)
        source_dir = work / folder
        source_dir.mkdir()
        for path in (root / 'tests/build').glob('Build*.Mod'):
            shutil.copy(path, source_dir / path.name)
        shutil.copy(root / 'ocg_runtime.h', work)
        (work / 'bin: space').mkdir()
        local_compiler = work / 'bin: space/ORPC'
        shutil.copy(compiler, local_compiler)
        prepare_recorder(work)
        argument = f'"{folder}/BuildMain.Mod"/b'
        run([str(local_compiler), 'Compile', argument])
        generated = (work / 'BuildMain.mk').read_text()
        definition = next(line for line in generated.splitlines() if line.startswith('ORPC ?='))
        assert 'bin: space/ORPC' in definition and '\\:' not in definition, definition
        dependency = next(line for line in generated.splitlines() if line.startswith('OCG_RUNTIME_DEP :='))
        assert '\\:' not in dependency, dependency
        run(command)
        run(['./BuildMain'])
        edit(f'{folder}/BuildBase.Mod', 'INC(order)', 'order := order+1')
        run(command)
        run(['./BuildMain'])

# Path() preserves colons in both SOURCES and the emitted source rules.
with tempfile.TemporaryDirectory() as directory:
    work = Path(directory)
    (work / 'src:colon').mkdir()
    for path in (root / 'tests/build').glob('Build*.Mod'):
        shutil.copy(path, work / 'src:colon' / path.name)
    run([compiler, 'Compile', '"src:colon/BuildMain.Mod"/b'])
    generated = (work / 'BuildMain.mk').read_text()
    sources = next(line for line in generated.splitlines() if line.startswith('SOURCES :='))
    assert 'src:colon/BuildMain.Mod' in sources and '\\:' not in sources, sources
    assert 'src:colon/BuildMain.Mod:\n' in generated
    assert 'src\\:colon' not in generated

print('PASS: generated makefile, executable name, parallel/no-op builds, compiler-call tracking, stable outputs, '
      'body/interface/C/header edits, transitive dependencies, graph updates, clean/clobber, escaped paths, and failure handling')
