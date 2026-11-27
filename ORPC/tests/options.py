#!/usr/bin/env python3
"""Check ORPC's uppercase per-input flags and their C output."""
from pathlib import Path
import subprocess
import sys
import tempfile

compiler = Path(sys.argv[1]).resolve()
runtime = Path(__file__).resolve().parents[1]
source = """MODULE {module};
TYPE Base = RECORD value: INTEGER END;
     Extended = RECORD (Base) extra: INTEGER END;
     PBase = POINTER TO Base; PExtended = POINTER TO Extended;
VAR pointer: PBase; callback: PROCEDURE;
    number: INTEGER; array: ARRAY 4 OF INTEGER;
{directive}
PROCEDURE Checks*;
BEGIN
  ASSERT(number > 0);
  number := pointer(PExtended).extra + number;
  array[number] := number;
  callback;
  CASE number OF 1: number := 2 END
END Checks;
PROCEDURE Copy*(VAR dst: ARRAY OF CHAR; src: ARRAY OF CHAR);
BEGIN dst := src; dst := "a"
END Copy;
BEGIN
  ASSERT(number = 0);
  array[number] := number + 1
END {module}.
"""
markers = {
    "A": ")==(0),",
    "K": "ocg_stack_check_at(",
    "P": "ocg_nonnull_at(",
    "T": "ocg_is(",
    "V": "ocg_addv_at(",
    "X": "ocg_index_at(",
}
defaults = {"A", "P", "T", "X"}


def run(*args, **kwargs):
    result = subprocess.run(args, cwd=work, capture_output=True, text=True, **kwargs)
    assert result.returncode == 0, (args, result.stdout, result.stderr)
    return result.stdout


def write(name, directive=""):
    (work / (name + ".Mod")).write_text(source.format(module=name, directive=directive))


def verify(name, expected):
    code = (work / (name + ".c")).read_text()
    for flag, marker in markers.items():
        assert (marker in code) == (flag in expected), (name, flag, code)
    for marker in ('ocg_fail("CASE"', "ocg_arraycopy_at(", "ocg_string_at("):
        assert (marker in code) == ("X" in expected), (name, marker, code)
    assert (" != (NULL)" in code) == ("P" in expected), code
    if "X" not in expected:
        assert code.count("memmove(") == 2, code
    if "K" in expected:
        assert code.count("ocg_stack_check_at(") == 3, code
        assert code.count("__attribute__((noinline))") == 3, code


with tempfile.TemporaryDirectory() as tmp:
    work = Path(tmp)
    write("Options")
    for flag in "ACKPTVX":
        run(compiler, "Compile", "Options.Mod/s" + flag)
        expected = defaults - ({"P", "T", "X"} if flag == "C" else {flag})
        if flag in "KV":
            expected.add(flag)
        verify("Options", expected)

    write("Next")
    run(compiler, "Compile", "Options.Mod/sACKV", "Next.Mod/s")
    verify("Options", {"K", "V"})
    verify("Next", defaults)

    write("Options", "(*$C+*)(*$A+*)")
    run(compiler, "Compile", "Options.Mod/sAC")
    verify("Options", defaults)

    write("Options", "(*$P+*)(*$K-*)(*$V-*)")
    write("Sibling")
    (work / "Graph.Mod").write_text("MODULE Graph; IMPORT Options, Sibling; END Graph.\n")
    run(compiler, "Compile", "Graph.Mod/bACKV")
    verify("Options", {"P"})
    verify("Sibling", {"K", "V"})
    makefile = (work / "Graph.mk").read_text()
    assert "/bACKV" in makefile and "ocg_stack_runtime.o" in makefile, makefile
    run("make", "-f", "Graph.mk", f"OCG_RUNTIME_DIR={runtime}")
    run(work / "Graph")

    (work / "UncheckedCase.Mod").write_text("""MODULE UncheckedCase;
VAR value*: INTEGER;
BEGIN
  value := 2;
  CASE value OF 1: value := 0 END;
  ASSERT(value = 2)
END UncheckedCase.
""")
    run(compiler, "Compile", "UncheckedCase.Mod/bX")
    run("make", "-f", "UncheckedCase.mk", f"OCG_RUNTIME_DIR={runtime}")
    run(work / "UncheckedCase")

    (work / "ArmProbe.Mod").write_text("""MODULE ArmProbe;
IMPORT SYSTEM;
VAR number*: INTEGER; real*: REAL;
BEGIN
  number := 1; real := 0.5;
  ASSERT(SYSTEM.SIZE(INTEGER) = 4)
END ArmProbe.
""")
    run(compiler, "Compile", "ArmProbe.Mod/bv5K")
    header = (work / "ArmProbe.h").read_text()
    assert "sizeof(void *) == 4" in header and "OCG_CORTEX_M" not in header, header
    assert "int32_t" in header and "float" in header, header
    makefile = (work / "ArmProbe.mk").read_text()
    assert "/bv5K" in makefile and "arm-linux-gnueabi-" in makefile, makefile
    assert "LDSCRIPT" not in makefile and "ocg_stack_runtime.o" in makefile, makefile
    (work / "ocg_stack_runtime.o").unlink()
    commands = run("make", "-n", "-f", "ArmProbe.mk", "CC=arm-cc",
                   f"OCG_RUNTIME_DIR={runtime}").splitlines()
    cc_commands = [line for line in commands if line.startswith("arm-cc ")]
    assert len(cc_commands) == 3, commands
    assert all("-march=armv5te -marm -mfloat-abi=soft" in line for line in cc_commands), commands
    for flags, diagnostic in (("bv7", "expected v5"), ("bv5m0", "cannot combine"),
                              ("bm0v5", "cannot combine")):
        result = subprocess.run([compiler, "Compile", "ArmProbe.Mod/" + flags],
                                cwd=work, capture_output=True, text=True)
        assert result.returncode != 0 and diagnostic in result.stdout, result.stdout

print("PASS: ORPC uppercase options, per-input defaults, graph, source directives and ARMv5TE")
