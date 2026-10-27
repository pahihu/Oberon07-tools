#!/usr/bin/env python3
"""Build Cortex-M firmware with Arm GNU GCC; run it under QEMU when available."""
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile

compiler = str(Path(sys.argv[1]).resolve())
root = Path(__file__).resolve().parent.parent
cc = os.environ.get('ARM_CC') or shutil.which('arm-none-eabi-gcc')
if not cc:
    print('SKIP: Cortex-M tests require arm-none-eabi-gcc (or ARM_CC)')
    sys.exit(0)
cc = shutil.which(cc) or str(Path(cc).resolve())
prefix = cc[:-3] if cc.endswith('gcc') else 'arm-none-eabi-'
nm = os.environ.get('ARM_NM', prefix+'nm')
objdump = os.environ.get('ARM_OBJDUMP', prefix+'objdump')
qemu = os.environ.get('QEMU_ARM') or shutil.which('qemu-system-arm')
env = dict(os.environ)
env.pop('OCG_RUNTIME_DIR', None)
make = shlex.split(os.environ.get('MAKE', 'make'))

for core, machine in [(0,'microbit'), (3,'lm3s6965evb'), (4,'mps2-an386'), (7,'mps2-an500')]:
    with tempfile.TemporaryDirectory() as directory:
        work = Path(directory)
        for path in (root / 'tests/cortex').iterdir():
            shutil.copy(path, work)
        for name in ['ocg_runtime.h', 'ocg_cortex.h']:
            shutil.copy(root / name, work)
        if core != 0:
            path = work / 'ArmOps.Mod'
            path.write_text(path.read_text().replace('END Registers;', '''
  SYSTEM.LDREG(23, 0); n := SYSTEM.REG(23); ASSERT(n=0);
  SYSTEM.LDREG(24, 0); n := SYSTEM.REG(24); ASSERT(n=0)
END Registers;''').replace('n := SYSTEM.REG(15)\n', 'n := SYSTEM.REG(15);\n'))

        def run(args, success=True, timeout=30):
            result = subprocess.run(args, cwd=work, env=env, text=True,
                                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                    timeout=timeout)
            assert (result.returncode == 0) == success, (args, result.returncode, result.stdout)
            return result.stdout

        run([compiler, 'Compile', f'ArmMain.Mod/bm{core}'])
        header = (work / 'ArmOps.h').read_text()
        assert 'int32_t O_ArmOps_' in header and 'float O_ArmOps_' in header
        assert 'sizeof(void *) == 4' in header
        # Separate invocation must reconstruct the target ABI and IRQ attributes.
        run([compiler, 'Compile', f'ArmOps.Mod/sm{core}'])
        cppflags = os.environ.get('ARM_CPPFLAGS', '')+' -include test_board.h'
        command = make+['-f', 'ArmMain.mk', f'CC={cc}', f'CPPFLAGS={cppflags}',
                        'CFLAGS=-O2 -std=gnu11 -ffreestanding -fomit-frame-pointer -Wall -Wextra -Werror',
                        'LDFLAGS=-nostdlib -Wl,--gc-sections', 'LDLIBS=-lgcc',
                        'LDSCRIPT=test.ld', 'STARTUP_OBJS=startup.o', 'EXTRA_OBJS=board.o']
        run(command)
        symbols = run([nm, 'ArmMain'])
        assert 'OCG_IRQ_5_Handler' in symbols and 'OCG_Exception_15_Handler' in symbols
        assert symbols.count(' ocg_arm_cpu') == 1
        assembly = run([objdump, '-d', 'ArmOps.o']).lower()
        assert 'cpsid' in assembly and 'cpsie' in assembly
        assert 'mrs' in assembly and 'msr' in assembly
        assert 'ocg_exception_15_handler' in assembly or 'o_armops_interrupt' in assembly
        if qemu:
            run([qemu, '-M', machine, '-nographic', '-monitor', 'none', '-serial', 'none',
                 '-semihosting-config', 'enable=on,target=native', '-kernel', 'ArmMain'], timeout=15)

        # C compiler defaults and board integration remain explicit in the makefile.
        text = (work / 'ArmMain.mk').read_text()
        assert f'-mcpu=cortex-m{core}' in text
        assert 'CC = $(CROSS_COMPILE)gcc' in text
        assert 'LDSCRIPT' in text and 'STARTUP_OBJS' in text
        assert 'startup.S' in (work / 'startup.d').read_text()
        run(command+['clean'])
        assert not (work / 'startup.d').exists() and not (work / 'board.d').exists()

        for name, body in [
            ('BadRegister', 'VAR n: INTEGER; BEGIN n := SYSTEM.REG(99)'),
            ('BadCond', 'VAR b: BOOLEAN; BEGIN b := SYSTEM.COND(16)'),
            ('BadPSR', 'BEGIN SYSTEM.LDPSR(2)'),
            ('BadIRQ', 'PROCEDURE Handler [240]; BEGIN END Handler;'),
        ]:
            (work / f'{name}.Mod').write_text(f'MODULE {name}; IMPORT SYSTEM; {body} END {name}.\n')
            run([compiler, 'Compile', f'{name}.Mod/sm{core}'], success=False)
        if core == 0:
            (work / 'BadM0.Mod').write_text(
                'MODULE BadM0; IMPORT SYSTEM; VAR n: INTEGER; BEGIN n := SYSTEM.REG(23) END BadM0.\n')
            output = run([compiler, 'Compile', 'BadM0.Mod/sm0'], success=False)
            assert 'register unavailable on Cortex-M0' in output
        # A same-width symbol from a different core must not silently import.
        data = bytearray((work / 'ArmOps.csmb').read_bytes())
        target = 8+data[8:].index(0)+3
        data[target] = 3 if core == 0 else 1
        (work / 'ArmOps.csmb').write_bytes(data)
        output = run([compiler, 'Compile', f'ArmMain.Mod/sm{core}'], success=False)
        assert 'C symbol target changed' in output

print('PASS: Arm GNU GCC Cortex-M0/M3/M4/M7 firmware, 32-bit scalar/symbol ABI, '
      'SYSTEM intrinsics, IRQ aliases/prologues, board makefile integration and diagnostics'
      + ('; QEMU execution includes real SysTick IRQs and status preservation' if qemu else ' (QEMU unavailable)'))
