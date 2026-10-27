#!/bin/sh
set -eu
# These fixtures use the runtime shipped with the source package.
unset OCG_RUNTIME_DIR
compiler=$1
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
run_dir=$(mktemp -d)
trap 'rm -rf "$run_dir"' EXIT HUP INT TERM
mkdir "$run_dir/src"
cp "$root"/tests/build/*.Mod "$run_dir/src/"
cp "$root/ocg_runtime.h" "$run_dir/"
cd "$run_dir"
# Quoted path exercises sibling-directory lookup. No source or C symbols
# exist in the output directory before this command.
if ! "$compiler" Compile '"src/BuildMain.Mod"/b' > build.log 2>&1; then cat build.log; exit 1; fi
for m in BuildBase BuildLeft BuildRight BuildMain; do
  test -s "$m.c"; test -s "$m.h"; test -s "$m.csmb"
  if [ "$(grep -c "compiling $m" build.log)" -ne 1 ]; then cat build.log; exit 1; fi
done
test "$(grep -l '^int main(void)' Build*.c | wc -l)" -eq 1
grep -q '^int main(void)' BuildMain.c
cc=${CC:-cc}
flags='-std=c11 -O2 -Wall -Wextra -Werror'
if [ "${SANITIZE:-0}" = 1 ]; then flags="$flags -g -fsanitize=address,undefined"; fi
$cc $flags BuildBase.c BuildLeft.c BuildRight.c BuildMain.c -lm -o program
ASAN_OPTIONS=detect_leaks=0 ./program
# /b refreshes interfaces without /s, including on a second build.
if ! "$compiler" Compile '"src/BuildMain.Mod"/b' > rebuild.log 2>&1; then cat rebuild.log; exit 1; fi
# A normal compile immediately after a build in the same invocation must
# retain library behavior (no C main).
if ! "$compiler" Compile '"src/BuildMain.Mod"/b' '"src/NotMain.Mod"/s' > mixed.log 2>&1; then cat mixed.log; exit 1; fi
if grep -q '^int main(void)' NotMain.c; then exit 1; fi
for scenario in CycleA Missing Wrong BadRoot; do
  if "$compiler" Compile "\"src/$scenario.Mod\"/b" > failure.log 2>&1; then cat failure.log; echo "unexpected success: $scenario"; exit 1; fi
  if test -e "$scenario.c"; then echo "failed root was emitted: $scenario"; exit 1; fi
  case "$scenario" in
    CycleA) grep -q 'cyclic import' failure.log ;;
    Missing) grep -q 'NoSuchSource' failure.log ;;
    Wrong) grep -q 'module name does not match' failure.log ;;
    BadRoot) grep -q 'compilation FAILED' failure.log ;;
  esac
done
if "$compiler" Compile Nonexistent.Mod/b > failure.log 2>&1; then echo 'missing root incorrectly accepted'; exit 1; fi
# Search configured source directories after sibling lookup fails.
mkdir remote
mv src/RemoteBase.Mod remote/
cat > paths.red <<'REDIR'
*.Mod = src; remote
*.csmb = .
REDIR
if ! ORPRED=paths.red "$compiler" Compile RemoteMain.Mod/b > remote.log 2>&1; then cat remote.log; exit 1; fi
$cc $flags RemoteBase.c RemoteMain.c -lm -o remote-program
ASAN_OPTIONS=detect_leaks=0 ./remote-program
echo 'PASS: /b import graph, shared dependency, aliases, SYSTEM, sibling and configured source paths, root main, rebuild, mixed flags, and failure diagnostics'
