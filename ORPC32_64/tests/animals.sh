#!/bin/sh
set -eu
# These fixtures use the runtime shipped with the source package.
unset OCG_RUNTIME_DIR
compiler=$1
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
run_dir=$(mktemp -d)
trap 'rm -rf "$run_dir"' EXIT HUP INT TERM
cp "$root"/tests/animals/* "$root/ocg_runtime.h" "$run_dir/"
cd "$run_dir"
# The supplied PROCEDURE* leaf syntax and ASSERT(cond,code) use Astrobe mode.
if ! "$compiler" Compile Zoo.Mod/ab > compile.log 2>&1; then cat compile.log; exit 1; fi
cc=${CC:-cc}
# The original source has unused locals; keep ABI mismatches fatal.
flags='-std=c11 -O2 -Werror=incompatible-pointer-types -Werror=int-conversion'
link_flags=''
if [ "${SANITIZE:-0}" = 1 ]; then flags="$flags -g -fsanitize=address,undefined"; link_flags='-fsanitize=address,undefined'; fi
make -f Zoo.mk "CC=$cc" "CFLAGS=$flags" "LDFLAGS=$link_flags" EXTRA_OBJS=emb_putchar.o > make.log 2>&1 || { cat make.log; exit 1; }
ASAN_OPTIONS=detect_leaks=0 ./Zoo > actual.txt
python3 - <<'PY'
from pathlib import Path
expected=Path('expected.txt').read_text().rstrip('\n')
actual=Path('actual.txt').read_text()
assert actual == expected, (actual,expected)
PY
echo 'PASS: original Animals.zip sources translate, build and produce the expected Zoo output'
