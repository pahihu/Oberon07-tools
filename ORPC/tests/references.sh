#!/bin/sh
set -eu
# These fixtures use the runtime shipped with the source package.
unset OCG_RUNTIME_DIR
compiler=$1
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
run_dir=$(mktemp -d)
trap 'rm -rf "$run_dir"' EXIT HUP INT TERM
cp "$root"/tests/reference/*.Mod "$root/ocg_runtime.h" "$run_dir/"
cd "$run_dir"
if ! "$compiler" Compile ReferenceMain.Mod/b > compile.log 2>&1; then cat compile.log; exit 1; fi
cc=${CC:-cc}
flags='-std=c11 -O2 -Wall -Wextra -Werror'
link_flags=''
if [ "${SANITIZE:-0}" = 1 ]; then flags="$flags -g -fsanitize=address,undefined"; link_flags='-fsanitize=address,undefined'; fi
make -f ReferenceMain.mk "CC=$cc" "CFLAGS=$flags" "LDFLAGS=$link_flags" > make.log 2>&1 || { cat make.log; exit 1; }
ASAN_OPTIONS=detect_leaks=0 ./ReferenceMain
# Exercise imported signatures in an independent compiler invocation.
"$compiler" Compile ReferenceBridge.Mod/s ReferenceMain.Mod/s > imports.log 2>&1
$cc $flags -c ReferenceBridge.c ReferenceMain.c
# Each of these attempts must be rejected by the Oberon parser.
for operation in open fixed record forward_open forward_fixed forward_record; do
  case "$operation" in
    open) header='PROCEDURE Bad(a: ARRAY OF INTEGER);'; body='a[0] := 1' ;;
    fixed) header='PROCEDURE Bad(a: R.Fixed);'; body='a[0] := 1' ;;
    record) header='PROCEDURE Bad(r: R.Rec);'; body='r.n := 1' ;;
    forward_open) header='PROCEDURE Bad(a: ARRAY OF INTEGER);'; body='R.WriteOpen(a)' ;;
    forward_fixed) header='PROCEDURE Bad(a: R.Fixed);'; body='R.WriteFixed(a)' ;;
    forward_record) header='PROCEDURE Bad(r: R.Rec);'; body='R.WriteRec(r)' ;;
  esac
  printf 'MODULE BadReference; IMPORT R := ReferenceABI; %s BEGIN %s END Bad; END BadReference.\n' "$header" "$body" > BadReference.Mod
  if "$compiler" Compile BadReference.Mod/s > failure.log 2>&1; then echo "read-only violation accepted: $operation"; exit 1; fi
  grep -q 'read-only' failure.log
  if test -e BadReference.c; then echo 'invalid read-only mutation emitted'; exit 1; fi
done
# Open-to-open copying checks actual source/destination lengths.
cat > ArrayOverflow.Mod <<'MOD'
MODULE ArrayOverflow;
IMPORT R := ReferenceABI;
VAR dst: ARRAY 1 OF INTEGER; src: R.Fixed;
BEGIN R.CopyOpen(dst, src)
END ArrayOverflow.
MOD
"$compiler" Compile ArrayOverflow.Mod/b > overflow.log 2>&1
make -f ArrayOverflow.mk "CC=$cc" "CFLAGS=$flags" "LDFLAGS=$link_flags" > overflow-make.log 2>&1 || { cat overflow-make.log; exit 1; }
ulimit -c 0
if ASAN_OPTIONS=detect_leaks=0 ./ArrayOverflow > trap.log 2>&1; then echo 'array length overflow accepted'; exit 1; fi
grep -q 'Oberon trap: array length' trap.log
echo 'PASS: reference-only structured parameters, read-only and VAR forwarding, fixed/open arrays, records, callbacks, alias visibility, length checks, and read-only rejection'
