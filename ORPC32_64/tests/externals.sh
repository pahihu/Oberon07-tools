#!/bin/sh
set -eu
# These fixtures use the runtime shipped with the source package.
unset OCG_RUNTIME_DIR
compiler=$1
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
run_dir=$(mktemp -d)
trap 'rm -rf "$run_dir"' EXIT HUP INT TERM
cp "$root"/tests/external/* "$root/ocg_runtime.h" "$run_dir/"
cd "$run_dir"
if ! "$compiler" Compile ForeignMain.Mod/b > compile.log 2>&1; then cat compile.log; exit 1; fi
cc=${CC:-cc}
flags='-std=c11 -O2 -Wall -Wextra -Werror'
if [ "${SANITIZE:-0}" = 1 ]; then flags="$flags -g -fsanitize=address,undefined"; fi
$cc $flags Foreign.c ForeignExport.c ForeignMain.c my_library.c -lm -o external-program
ASAN_OPTIONS=detect_leaks=0 ./external-program
make -f ForeignMain.mk "CC=$cc" "CFLAGS=$flags" "LDFLAGS=${flags#-std=c11}" EXTRA_OBJS=my_library.o > make.log 2>&1 || { cat make.log; exit 1; }
ASAN_OPTIONS=detect_leaks=0 ./ForeignMain
# clean removes dependencies for both translated modules and extra C objects.
for dependency in Foreign.d ForeignExport.d ForeignMain.d my_library.d; do test -s "$dependency"; done
make -f ForeignMain.mk EXTRA_OBJS=my_library.o clean > clean.log 2>&1 || { cat clean.log; exit 1; }
for dependency in Foreign.d ForeignExport.d ForeignMain.d my_library.d; do
  if test -e "$dependency"; then echo "clean left $dependency"; exit 1; fi
done
test -s my_library.o
$cc $flags Foreign.c c_api.c my_library.c -lm -o c-api
ASAN_OPTIONS=detect_leaks=0 ./c-api
# Imported names survive a separate compiler invocation reading only .csmb.
"$compiler" Compile ForeignMain.Mod/s > second.log 2>&1
$cc $flags -c ForeignMain.c
if ! grep -q 'MyLib_SetValue(' ForeignMain.c; then echo 'foreign call was not direct'; exit 1; fi
if grep -q 'O_Foreign_SetValue(' ForeignMain.c; then echo 'wrapper call was generated'; exit 1; fi
if ! grep -q '^extern void MyLib_SetValue(' Foreign.h; then echo 'missing exported external prototype'; exit 1; fi
if grep -q 'MyLib_Local' Foreign.h; then echo 'private external prototype leaked'; exit 1; fi
if grep -E '^(static )?(void|int32_t|float) MyLib_.*\{' Foreign.c; then echo 'foreign definition was emitted'; exit 1; fi
# Empty, malformed and reserved C identifiers are rejected.
for c_symbol in '' '9bad' 'foo-bar' 'for'; do
  printf 'MODULE BadExternal; PROCEDURE P ["%s"] (); END BadExternal.\n' "$c_symbol" > BadExternal.Mod
  if "$compiler" Compile BadExternal.Mod/s > failure.log 2>&1; then cat failure.log; exit 1; fi
  grep -q 'invalid external C function identifier' failure.log
  if test -e BadExternal.c; then echo 'invalid foreign declaration emitted'; exit 1; fi
done
# A declaration must still have its single header terminator.
printf 'MODULE BadExternal; PROCEDURE P ["NoBody"] () END BadExternal.\n' > BadExternal.Mod
if "$compiler" Compile BadExternal.Mod/s > failure.log 2>&1; then exit 1; fi
grep -q 'no ;' failure.log
# The symbol format changed: old files fail cleanly with a rebuild diagnostic.
python3 - <<'PYCODE'
from pathlib import Path
p=Path('Foreign.csmb'); data=bytearray(p.read_bytes()); version=8+data[8:].index(0)+1; data[version]=1; p.write_bytes(data)
PYCODE
if "$compiler" Compile ForeignMain.Mod/s > old-version.log 2>&1; then echo 'old symbol version incorrectly accepted'; exit 1; fi
grep -q 'C symbol format changed; rebuild imported modules' old-version.log
echo 'PASS: header-only external routines/functions, direct and imported calls, callbacks, VAR/open-array/REAL ABI, nested aliases, C exports, and invalid-name diagnostics'
