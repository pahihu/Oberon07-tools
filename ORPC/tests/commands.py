#!/usr/bin/env python3
"""Exercise compiler-generated ModuleInfo tables through an indirect import."""
import os
from pathlib import Path
import shlex
import subprocess
import sys
import tempfile
import time

compiler = str(Path(sys.argv[1]).resolve())
runtime = Path(__file__).resolve().parents[1]
make = shlex.split(os.environ.get("MAKE", "make"))
env = dict(os.environ, OCG_RUNTIME_DIR=str(runtime))

modules = {
    "CommandLeaf": """MODULE CommandLeaf;
VAR calls*: INTEGER;

PROCEDURE Hidden;
BEGIN INC(calls, 100)
END Hidden;

PROCEDURE Run*;
BEGIN INC(calls); IF calls < 0 THEN Hidden END
END Run;

PROCEDURE Argument*(x: INTEGER);
BEGIN INC(calls, x)
END Argument;

PROCEDURE Result*(): INTEGER;
BEGIN RETURN calls
END Result;

PROCEDURE Foreign* ["test_foreign"];
END CommandLeaf.
""",
    "ModuleInfo": """MODULE ModuleInfo;
TYPE
  Module* = POINTER TO ModDesc;
  ModuleName* = ARRAY 32 OF CHAR;
  Command* = PROCEDURE;
  ModDesc* = RECORD
    name*: ModuleName;
    next*: Module;
    cmd*, ent*: INTEGER
  END;
VAR root*: Module;

PROCEDURE Root ["comstime_module_root"](): Module;
PROCEDURE Lookup ["comstime_module_command"](index: INTEGER; VAR name: ModuleName): Command;

PROCEDURE At*(index: INTEGER; VAR name: ModuleName): Command;
BEGIN RETURN Lookup(index, name)
END At;

BEGIN root := Root()
END ModuleInfo.
""",
    "CommandBridge": """MODULE CommandBridge;
IMPORT Leaf := CommandLeaf, ModuleInfo;

PROCEDURE Check*(wanted: ARRAY OF CHAR);
VAR m: ModuleInfo.Module; c: ModuleInfo.Command; name: ModuleInfo.ModuleName;
BEGIN
  m := ModuleInfo.root;
  ASSERT((m.name = "CommandLeaf") & (m.cmd = 0) & (m.ent = 1));
  c := ModuleInfo.At(m.cmd, name);
  ASSERT((c # NIL) & ((name = wanted) OR (name = "Run_New"))); c;
  ASSERT(Leaf.calls = 1);
  c := ModuleInfo.At(-1, name); ASSERT(c = NIL);
  c := ModuleInfo.At(2, name); ASSERT(c = NIL);
  m := m.next;
  ASSERT((m.name = "ModuleInfo") & (m.cmd = 1) & (m.ent = 1));
  m := m.next;
  ASSERT((m.name = "CommandBridge") & (m.cmd = 1) & (m.ent = 1));
  m := m.next;
  ASSERT((m.name = "CommandApp") & (m.cmd = 1) & (m.ent = 2) & (m.next = NIL));
  c := ModuleInfo.At(m.cmd, name);
  ASSERT((c # NIL) & (name = "MainCommand")); c
END Check;
END CommandBridge.
""",
    "CommandApp": """MODULE CommandApp;
IMPORT CommandBridge;
VAR called: BOOLEAN;

PROCEDURE MainCommand*;
BEGIN called := TRUE
END MainCommand;

BEGIN CommandBridge.Check("Run"); ASSERT(called)
END CommandApp.
""",
}

with tempfile.TemporaryDirectory() as directory:
    work = Path(directory)

    def run(*args):
        result = subprocess.run(args, cwd=work, env=env, text=True,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        assert result.returncode == 0, result.stdout

    def write(name, content):
        (work / (name + ".Mod")).write_text(content)

    for module, source in modules.items():
        write(module, source)
    translate = (compiler, "Compile", "CommandApp.Mod/b")
    build = make + ["-f", "CommandApp.mk", "-j4", "CFLAGS=-std=c11 -O2 -Wall -Wextra -Werror"]
    run(*translate)
    run(*build)
    run("./CommandApp")
    root = work / "CommandApp.c"
    generated = root.read_text()
    timestamp = root.stat().st_mtime_ns
    run(*translate)
    assert root.stat().st_mtime_ns == timestamp
    assert 'static O_ModuleInfo_ModDesc ocg_modules[]' in generated
    assert 'O_CommandLeaf_Run' in generated
    assert all(f'O_CommandLeaf_{name}' not in generated
               for name in ("Hidden", "Argument", "Result", "Foreign"))
    assert not (work / "commands.c").exists()

    # Leave the root source alone. The generated makefile must refresh its table.
    next_second = int((work / "CommandApp.mk").stat().st_mtime) + 1
    time.sleep(max(0, next_second - time.time() + 0.02))
    leaf = modules["CommandLeaf"].replace("Run", "Run_New")
    write("CommandLeaf", leaf)
    run(*build)
    run("./CommandApp")
    assert 'O_CommandLeaf_Run_New' in root.read_text()
    assert '"Run",' not in root.read_text()

    # Cortex uses the same graph and command extraction, with target-width integers.
    irq = "PROCEDURE Tick* [15]; BEGIN END Tick;\n"
    write("CommandLeaf", leaf.replace("END CommandLeaf.", irq + "END CommandLeaf."))
    run(compiler, "Compile", "CommandApp.Mod/bm0")
    assert 'O_CommandLeaf_Run_New' in root.read_text()
    assert 'O_CommandLeaf_Tick' not in root.read_text()
    assert 'comstime_module_command(ocg_int number, O_ModuleInfo_ModuleName *name)' in root.read_text()
    assert '#define OCG_CORTEX_M 1' in (work / "CommandApp.h").read_text()

    # A provider with no commands still links and initializes its module list.
    run(compiler, "Compile", "ModuleInfo.Mod/b")
    run(*[arg.replace("CommandApp", "ModuleInfo") for arg in build])
    run("./ModuleInfo")

    # An unrelated module named ModuleInfo does not opt in.
    write("ModuleInfo", "MODULE ModuleInfo; END ModuleInfo.\n")
    run(compiler, "Compile", "ModuleInfo.Mod/b")
    assert "ocg_modules" not in (work / "ModuleInfo.c").read_text()

print("PASS: command tables, indirect ModuleInfo import, 64-bit native lookup, Cortex-M emission, refresh and stable output")
