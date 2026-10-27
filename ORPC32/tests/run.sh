#!/bin/sh
set -eu
# These fixtures use the runtime shipped with the source package.
unset OCG_RUNTIME_DIR
if [ "$#" -ne 1 ]; then echo "usage: $0 /absolute/path/to/ORPC" >&2; exit 2; fi
compiler=$1
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
run_dir=$(mktemp -d)
trap 'rm -rf "$run_dir"' EXIT HUP INT TERM
cp "$root"/tests/*.Mod "$root"/tests/*.c "$root/ocg_runtime.h" "$run_dir/"
cd "$run_dir"
ulimit -c 0
if ! "$compiler" Compile Basic.Mod/s Records.Mod/s Client.Mod/s Expressions.Mod/s Deep.Mod/s DeepClient.Mod/s Bytes.Mod/s Traps.Mod/s Aliases.Mod/s AliasClient.Mod/s AliasUser.Mod/s > compile.log 2>&1; then cat compile.log; exit 1; fi
if grep -q 'compilation FAILED' compile.log; then cat compile.log; exit 1; fi
for m in Basic Records Client Expressions Deep DeepClient Bytes Traps Aliases AliasClient AliasUser; do test -s "$m.c"; test -s "$m.h"; test -s "$m.csmb"; done
if grep -q 'O_Basic_hidden|O_Expressions_Tick' Basic.h Expressions.h; then echo "private declaration leaked"; exit 1; fi
cc=${CC:-cc}
flags='-std=c11 -O2 -Wall -Wextra -Werror'
if [ "${SANITIZE:-0}" = 1 ]; then flags="$flags -g -fsanitize=address,undefined"; fi
# Word splitting is intentional for conventional compiler flags.
$cc $flags Basic.c Records.c Client.c Expressions.c Deep.c DeepClient.c Bytes.c Aliases.c AliasClient.c AliasUser.c main.c -lm -o checks
ASAN_OPTIONS=detect_leaks=0 ./checks
$cc $flags Traps.c o7traps.c -lm -o o7traps
for n in 0 1 2 3 4 5 6; do
  if ASAN_OPTIONS=detect_leaks=0 ./o7traps "$n" > trap.log 2>&1; then echo "trap $n did not fire"; exit 1; fi
  if ! grep -q 'Oberon trap:' trap.log; then cat trap.log; echo "unexpected crash in trap $n"; exit 1; fi
done
"$compiler" Compile Unsupported.Mod/s > unsupported.log 2>&1 || :
if test -e Unsupported.c; then echo "RISC intrinsic incorrectly accepted"; exit 1; fi
if ! grep -q 'RISC-specific operation' unsupported.log; then cat unsupported.log; exit 1; fi
echo 'PASS: 11 modules, C11 -O2 -Wall -Wextra -Werror, 7 runtime traps, unsupported-intrinsic rejection'

"$root/tests/build.sh" "$compiler"

"$root/tests/externals.sh" "$compiler"

python3 "$root/tests/makefile.py" "$compiler"

"$root/tests/references.sh" "$compiler"

"$root/tests/animals.sh" "$compiler"

python3 "$root/tests/runtime.py" "$compiler"

python3 "$root/tests/anonymous.py" "$compiler"

python3 "$root/tests/recordassignment.py" "$compiler"
