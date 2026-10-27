# OCG: Oberon-07 to C11

`OCG.Mod` is an Oberon-2 code generator for the supplied compiler. It generates
one `Module.c` and one `Module.h` for each source module. Headers declare
exported procedures and variables, together with the types needed to use them.
Private procedures and module variables have C `static` linkage.

The existing RISC backend is left intact. The accompanying compiler is named
`ORPC`, so it can coexist with `ORP`.

## Files

- `OCG.Mod`: C backend, expression trees, statement IR, branch fixups, C layout.
- `OCGTarget.Mod`: native scalar widths, constant arithmetic and real conversion.
- `ORPC.Mod`: supplied parser adapted to OCG, with declaration/scope hooks.
- `ORS.Mod`: supplied updated scanner accepting embedded source underscores.
- `OCB.Mod`: supplied ORB adapted to native C symbol files (`.csmb`).
- `OCGBuild.Mod`: import-header scanning and dependency ordering for `/b`.
- `OCGMake.Mod`: generates the main module's GNU make build file.
- `OCGFiles.Mod`: preserves timestamps of unchanged generated text.
- `OCGPos.Mod`: position writer using the C backend's statement counter.
- `ocg_runtime.h`: shared C11 runtime; no separate runtime C file is needed.
- `Makefile.ocg`: build target for the existing repository/toolchain.
- `ORPC.patch`, `OCB.patch`: changes relative to the uploaded parser/symbol table.
- `tests/`: language, module-interface and runtime-trap regression tests.

## Build

Use the `feature-64bit-port` branch of `pahihu/o2c` and the dependencies in
`pahihu/Oberon07-tools`, as for `make numcase`. Configure o2c's source, object,
and symbol search paths to include the repository's `lib` and `Oberon07`
directories and the o2c standard library. Select the appropriate `System.Mod`
for the host (the repository's `make l64`, for example).

Copy this package into `Oberon07-tools/Oberon07`, without replacing its original
`ORG.Mod`, `ORP.Mod`, or `ORB.Mod`. Then:

```sh
make -f Makefile.ocg
./ORPC Compile MyModule.Mod/s
```

`/s` permits creation/replacement of the module's C symbol file, following the
original compiler's symbol-file policy. Compile imported modules first. For
several files in dependency order:

```sh
./ORPC Compile Base.Mod/s Client.Mod/s
```

On Linux, the makefile supplies `--ldflags -Wl,--export-dynamic` unless the
repository environment already sets `DYNEXPORT`. This is needed for the
existing `Oberon.Run` command lookup. If using a custom redirection file:

```sh
make -f Makefile.ocg O2CFLAGS='-M --redir /absolute/path/to/o2c.red'
```

Keep `ocg_runtime.h` on the C compiler's include path. Link all generated module
C files and the math library:

```sh
cc -std=c11 -O2 -I. Base.c Client.c main.c -lm -o app
```

## Translate a complete program

Pass `/b` on the main module source:

```sh
./ORPC Compile Main.Mod/b
make -f Main.mk
./Main
```

`/b` scans the complete transitive IMPORT graph, translates each module once in
import-before-importer order, and creates/refreshes `.csmb` files automatically
(no `/s` is needed). Aliased imports use the actual module name; the built-in
pseudo-module `SYSTEM` requires no source. Import headers are scanned with ORS,
so comments, including nested comments, do not introduce false dependencies.

Dependency sources are named `ImportedModule.Mod`. Lookup first checks the
importing source's directory, then the existing `ORPRED` source-search paths
(and current-directory behavior). Quoted source paths are accepted by the
existing command scanner, e.g. `./ORPC Compile '"src/Main.Mod"/b'`.
Every non-SYSTEM dependency must have source available; an existing `.csmb`
alone is insufficient. Cycles, missing/empty sources and imported module-name
mismatches are reported before translation. Translation errors stop the build
before the root is emitted.

Only the requested main module receives:

```c
int main(void) {
    O_Main__init();
    return 0;
}
```

Its initializer initializes imports and executes the main module's BEGIN body.
Dependencies retain library behavior. Without `/b`, no C `main` is emitted.
`/b` translates the graph and writes `Main.mk`, where `Main` is the declared
main module name. The graph limit is 1,024 modules per root. Output files are
written in the compiler's current working directory, as with ordinary translation.

## Generated Makefile and incremental builds

`Main.Mod/b` produces `Main.mk` alongside the C sources. Its default target is
an executable named `Main` (or `Main$(EXEEXT)` if an executable suffix is set).
Use GNU make, a POSIX shell, and GCC or a compatible C compiler:

```sh
make -f Main.mk
make -f Main.mk -j4
make -f Main.mk clean
```

The makefile includes the complete module list, one `.o` file per module, and
explicit prerequisites for each module's own header, all transitive import
headers, and the selected `ocg_runtime.h`. The C compiler also writes `.d` dependency files
using `-MMD -MP`, so additional C headers are tracked.

After the initial `/b`, **editing an Oberon `.Mod` file and running make is
sufficient**. The makefile first reruns the recorded ORPC `/b` command, updates
the import graph, and then resumes the native build. Original compiler option
suffixes and the ORPC executable path are retained. A changed import list
regenerates the object/link lists, including removal of obsolete imports.
Missing sources and translation failures stop make before C compilation/linking.

ORPC compares generated `.c`, `.h` and `.mk` files with the existing bytes and
keeps timestamps when contents are unchanged. Consequently:

- A body-only Oberon edit recompiles the module whose C implementation changed.
- An interface/header change recompiles its module and affected importers.
- Editing a generated C file directly recompiles its own object.
- Changes to `ocg_runtime.h` recompile all generated module objects.
- A no-op make performs no compilation or linking. Repeating `/b` without
  changing inputs also preserves generated-file timestamps.

ORPC still translates the complete source graph during a regeneration; the C
compilation stage is incremental. A source-triggered regeneration refreshes
the makefile timestamp to avoid repeating it on every subsequent make. The
link target depends on the makefile as well as its objects, so graph/link-list
changes trigger relinking even when remaining object timestamps did not change.

Compiler and linker settings can be supplied on the make command line:

```sh
make -f Main.mk CC=gcc CFLAGS='-O2 -std=c11 -Wall -Wextra'
make -f Main.mk EXTRA_OBJS=my_library.o LDLIBS='-lMyLib -lm'
```

The environment variable `OCG_RUNTIME_DIR` selects the directory containing
`ocg_runtime.h` when make is invoked:

```sh
export OCG_RUNTIME_DIR=/path/to/shared/runtime
make -f Main.mk
# A command-line make assignment works too:
make -f Main.mk OCG_RUNTIME_DIR=/path/to/shared/runtime
```

If the variable is unset or empty, the local directory (`.`) is used. Values
are literal directory paths; spaces and shell-special characters are quoted.
The C compilation rule adds this directory with `-I`, including for `EXTRA_OBJS`.
The selected header is used both as a make prerequisite and as the C include,
even if an older local `ocg_runtime.h` exists. Generated headers accept an
`OCG_RUNTIME_HEADER` compiler macro for that purpose; without it, direct C
compilation retains the normal `#include "ocg_runtime.h"` behavior. When
switching runtime directories in an existing native build, run `make clean`
with the same makefile before rebuilding.

`CPPFLAGS`, `LDFLAGS`, `LDLIBS`, `EXEEXT`, `ORPC`, and `EXTRA_OBJS` are supported.
The generic C object rule can compile extra local C implementations such as
`my_library.c` when `EXTRA_OBJS=my_library.o` is supplied. `clean` removes the
program's generated objects, all dependency files in `DEPS` (including those
for `EXTRA_OBJS`), and executable; it keeps translated
C sources, headers, symbol files, the makefile, and extra library objects.
`clobber` runs `clean` and also removes the build's modules' generated `.c`,
`.h`, `.csmb`, and `.pos` files. It preserves the runtime header, handwritten
C files, Oberon sources, and generated makefile. Run ORPC with `/b` again
before rebuilding after `clobber`.
Run make in the directory containing the generated outputs.

## C interface and initialization

For `MODULE Counter` with `VAR count*: INTEGER` and `PROCEDURE Step*`, the header
exposes `int32_t O_Counter_count` on 32-bit hosts or
`int64_t O_Counter_count` on 64-bit hosts, and `void O_Counter_Step(void)`.

Call `O_Counter__init()` before using the module. The double underscore separates
this generated entry point from a source procedure named `init`.

```c
#include "Counter.h"
int main(void) {
    O_Counter__init();
    O_Counter_Step();
    return 0;
}
```

Initialization invokes imported module initializers first and executes the
module body once. It is intended for single-threaded startup; applications
should finish initialization before starting worker threads. Ordinary translation
leaves the entry point to the application; `/b` emits the wrapper shown above.

C names are prefixed with `O_Module_`; nested declarations receive an additional
scope number. Headers also contain supporting typedefs, record initialization
helpers, and runtime type descriptors. Public type aliases are emitted too.

## External C procedures and functions

Place a C symbol string after the Oberon name (and its export asterisk, if any):

```oberon
PROCEDURE MyFunc* ["MyLib_MyFunc"] (x: INTEGER);
PROCEDURE MyResult* ["MyLib_MyResult"] (x: INTEGER): INTEGER;
PROCEDURE Notify ["MyLib_Notify"];
```

These are complete declarations. Each ends with one semicolon and has no local
declarations, BEGIN/body, RETURN, or `END MyFunc`. They can be interspersed with
ordinary procedure definitions. Both parameterless routines and routines with
parameters are supported, along with function results. External declarations
also work within a procedure's local declaration section.

A call `MyFunc(42)` emits a direct `MyLib_MyFunc(42)` call. No Oberon-name C
wrapper or implementation is generated. Function values, callback arguments and
callback results use the same exact C function identifier.

For exported declarations, the module header contains an `extern` prototype
for the C symbol and a macro alias for the usual C API name, for example:

```c
extern void MyLib_MyFunc(int64_t x); /* 64-bit target; int32_t on 32-bit */
#define O_Module_MyFunc MyLib_MyFunc
```

The C name is retained in `.csmb`, so `OtherModule.MyFunc(...)` also calls the
external C function directly, even when compiling the importing module in a
separate invocation. Procedure constants can re-export an imported external
function as well. Private external declarations appear only in their module's
C file. A public prototype does not imply a C implementation: link the object
or library that defines `MyLib_MyFunc` yourself.

External functions use the native OCG C ABI. INTEGER and REAL are `int32_t`
and `float` on 32-bit targets, or `int64_t` and `double` on 64-bit targets.
VAR scalar parameters are pointers. ARRAY and RECORD parameters
are always pointers: those declared without VAR are read-only and have const-
qualified pointees in C; VAR structured parameters are writable. Each open-array
parameter expands to an element pointer and an `ocg_int` length (the native INTEGER type). Procedure types become C function
pointers. The external implementation must match the generated prototype;
this facility does not infer native-library signatures, varargs or alternate
calling conventions. Only nonempty C identifiers are accepted as symbol names;
C11 keywords and malformed identifiers produce compiler diagnostics.

**Rebuild C symbol files after this update.** The `.csmb` format is now version
2 to retain external names. Version 1 imports are rejected with a rebuild
message. `/b` rebuilds the complete source graph automatically; otherwise,
retranslate imported modules with `/s` before their clients.

## Implementation and ABI

| Native target | INTEGER | REAL | Address |
| --- | --- | --- | --- |
| 32-bit | `int32_t` | `float` (IEEE binary32) | 32 bits |
| 64-bit | `int64_t` | `double` (IEEE binary64) | 64 bits |

- The runtime aliases these scalar types as `ocg_int`, `ocg_uint` and
  `ocg_real_t`. SET remains `uint32_t` with elements 0..31; SET shifts/rotates
  retain their 32-bit width. BOOLEAN, CHAR and BYTE occupy one byte. BYTE
  arithmetic uses INTEGER-width intermediate values.
- Pointers and procedure pointers use native C representations. This is a
  **native backend**, not a cross compiler: compile the emitted C for the same
  pointer width as the running Oberon compiler. Generated headers check it.
- Records carry a runtime type tag at their start. Record extension embeds the
  base record as the first member. Field selection, `IS`, type guards, VAR
  records, heap allocation and record assignment respect that representation.
  Assignment preserves the destination record's dynamic tag.
  Whole-record assignment to a VAR record parameter additionally requires its
  dynamic type to equal its static type; a derived actual passed as VAR Base
  traps before copying. The source may still have a derived type, and field
  updates through VAR Base remain valid. This check follows the `T` type-check
  option, like explicit type guards.
- C structure offsets and sizes are finalized before symbol export. `.csmb`
  files preserve those sizes, including hidden fields. C symbol files are
  separate from RISC `.smb` files; never substitute one for the other. Rebuild
  C symbols and clients when changing host architecture or record layout.
  Symbol format version 3 preserves native-width constant bits and records
  the word size; old versions and mismatched widths are rejected.
- ARRAY and RECORD parameters are always passed by reference. Without VAR,
  they are read-only; with VAR, they are read-write. The parser rejects writes
  through read-only parameters, including passing them on to VAR formals.
  C signatures use const-qualified pointers for read-only structured formals.
  Fixed arrays use pointers to array typedefs; records use pointers to records.
  Open arrays use element pointers plus native `ocg_int` counts. Forwarding an open
  array forwards both its existing data pointer and its actual count, including
  through imported procedures and callbacks. It never takes the address of an
  open-array pointer. Scalar VAR parameters are pointers as before.
- Calls, operand snapshots and Boolean branches preserve evaluation order and
  short-circuiting. Nested procedures are lifted to file scope with unique
  names. Nonlocal variable access remains rejected, as in the supplied parser.
- IF/ELSIF, WHILE/ELSIF, REPEAT, FOR, numeric CASE (ranges and ELSE), type CASE,
  recursion, callbacks, sets, fixed/open arrays, strings and multiline hex
  string literals are supported through the original scanner/parser.
  Literal assignment copies every byte reported by the scanner, including
  embedded zeros. Quoted literals include their terminating zero; hex literals
  have no implicit terminator and can fill a CHAR array exactly.
- Integer arithmetic wraps at the native width by default; requested overflow checks
  use checked helpers. DIV/MOD implement floor division for positive divisors.
  Bounds, pointer, guard and assertion checks use the parser's option flags.
  String-copy and open-array-copy length validation remains enabled. Whole-array
  copying from an open array copies its actual element count after checking
  that the destination has sufficient capacity; it leaves any trailing
  destination elements untouched.
- As in the supplied ORG, NIL satisfies pointer type tests. Dereferencing NIL
  still traps when pointer checks are enabled.
- `SYSTEM.SIZE` reports the native emitted layout, rather than the RISC layout.
  Scalar INTEGER/REAL `SYSTEM.VAL` uses bit reinterpretation, not numeric
  conversion. Decimal REAL literals use the host C library's correctly rounded
  conversion, including native subnormal values. Hex `R` literals contain the
  native REAL's bits (eight hex digits on 32-bit, sixteen on 64-bit).
- `SYSTEM.ADR`, pointer/procedure `ORD` and pointer/procedure `SYSTEM.VAL`
  preserve full native addresses. GET/PUT use the operand's native C type;
  BIT tests a native INTEGER word and COPY counts native INTEGER-sized words.
  INTEGER shifts and rotates use 32 or 64 bits, with counts modulo that width.
- Allocation defaults to `calloc`; there is no automatic garbage collector in
  the generated application. Override `OCG_ALLOC(n)` and `OCG_FREE(p)` together
  when integrating a collector or another allocator.

The parser hooks are needed because ORG's original instruction offsets do not
identify C declarations or procedure scopes. `SetModule`, `BeginProc`,
`SelectProc`, `SaveConst`, `Freeze`, and `Seal` provide that information. The
ordinary ORG operation entry points remain recognizable in OCG.

## Explicit limitations

- RISC registers, carry flags, PSR operations, LED control, `H`, `COND`, `ADC`,
  `SBC`, `UML`, and interrupt calling conventions have no portable C equivalent.
  These produce compiler diagnostics. Leaf procedures use ordinary C calls.
- Exported string constants are rejected because the supplied symbol format
  does not retain their bytes/length. Local string constants work.
- Imported libraries must also be translated by ORPC or implemented with the
  generated C ABI. Existing RISC binaries and o2c's own C runtime modules do
  not automatically provide compatible implementations of Oberon-07 imports.
- Statement storage is limited to 65,535 entries per compilation. C output is
  intentionally direct and uses labels/gotos for the parser's branch interface.
- This package preserves the supplied language extensions and parser checks;
  it does not add closures, method dispatch, or other Oberon-2 source features
  to the Oberon-07 input language.

## Verification

```sh
make -f Makefile.ocg test
# Optional AddressSanitizer and UndefinedBehaviorSanitizer:
SANITIZE=1 ./tests/run.sh /absolute/path/to/ORPC
```

Validated on Linux x86-64 with GCC, C11, `-O2 -Wall -Wextra -Werror`, both
sanitizers enabled. The suite translates and links 11 modules; exercises
exports, aliases and re-exports, native imported sizes, BYTE arithmetic,
recursive/indirect calls, nested procedures, record extension and assignment,
arrays, strings, multiline hex strings, control flow, short-circuiting and
operand evaluation order; and verifies seven runtime traps plus rejection of
a RISC intrinsic. An external-function suite links separately implemented C
routines/functions and verifies local/imported calls, callbacks and callback
results, VAR/open-array/REAL parameters, header exports, private declarations,
nested declarations, re-exports, separate-invocation imports, invalid C names,
missing semicolons and rejection of old symbol files. The additional build suite checks a diamond import graph,
shared-dependency deduplication, aliases, SYSTEM, nested comments, sibling and
configured source paths, exactly one root C main, executable initialization
order, rebuilds, mixing `/b` and ordinary compilation, and errors for cycles,
missing sources, name mismatches and invalid dependencies. A makefile suite
records actual compiler invocations and checks stable output timestamps under
parallel builds: no-op builds,
repeated `/b`, source body/interface changes, C/header edits, transitive includes,
new/removed modules, extra headers, runtime headers, cleanup, compiler failure,
and source/compiler paths containing spaces, hashes, dollar signs or quotes.
The trap driver is named `tests/o7traps.c` so it cannot collide with the
`Traps.c` generated from `Traps.Mod` on case-insensitive filesystems. When
updating an older checkout, remove the old `tests/traps.c` driver. Mutation
tests wait past the previous outputs' whole-second timestamp, supporting make
versions that do not compare nanoseconds. Compiler-call recording also avoids
assuming that a rebuilt object must receive a different nanosecond timestamp.
To additionally simulate whole-second file timestamps on a finer-resolution
filesystem, set `O7_TEST_COARSE_MTIME=1` when running the suite.

The structured-parameter suite checks fixed/open arrays and records across
local calls, import boundaries and callbacks, read-only alias visibility,
VAR mutation, forwarding, partial array copies, oversized-copy traps and
read-only-write rejection. The supplied Animals.zip sources are included
unchanged in `tests/animals`; their Zoo program is built and its complete
output checked. That test uses `/ab` for the example's Astrobe leaf syntax and
links `emb_putchar.o` from the included stdout adapter.

The runtime-location suite checks unset/empty local fallback, shared-header
selection with a conflicting local copy, escaped directory names, no-op builds,
and dependency tracking when the selected shared header changes.

The TestReals.zip RBIT lookup-table regression is covered in `Deep.Mod`,
including leading/embedded zeros, preserved destination tails and exact-size
hex literals. TestReals's REAL formatting/bit-manipulation library assumes
32-bit IEEE REAL and must be adapted before use with the 64-bit scalar ABI.
The previous low-address-stack workaround for ADR is no longer required.

Anonymous records receive deterministic `_Anon0`, `_Anon1`, ... names. Their
leading underscore prevents collisions with source identifiers. The included
updated `ORS.Mod` accepts embedded underscores in source identifiers while
rejecting them in the first position. The scanner dispatches a leading
underscore to its identifier validation instead of silently skipping it.
The anonymous-record
suite checks 300 such names, exported anonymous variables, recursive pointers,
imported private base initialization and private record parameters, including
a separate symbol-file import. It also translates, compiles and links all
sources from AnonRecTest.zip unchanged (in `tests/anonymous`), using the stdout
adapter. Execution of the original example uses raw RISC stack/descriptor
introspection, including uninitialized raw addresses, which is outside this
portable C ABI. The suite compiles/links that original repro and executes
separate portable anonymous-record tests.
Rebuild ORPC and retranslate dependent modules with `/b` after this update;
existing generated headers and symbol files must match the native scalar ABI.
Replace `ocg_runtime.h` and rebuild external C implementations as well. Code
using fixed IEEE bit masks, INTEGER limits or 32-bit C function signatures
needs corresponding changes when moving to the 64-bit ABI.

The record-assignment suite checks exact-type VAR destinations, source slicing,
field updates, forwarding, pointer actuals, type guards, type CASE narrowing,
extensions defined in an importing module and seven expected assignment traps.

The native-width suite checks full-width literals and independent symbol
imports, IEEE precision/subnormal/maximum values, constant and runtime
arithmetic, overflow traps, wide shifts/CASE labels, record layout, memory
access through ADR, pointer/callback address round trips, many-argument
procedures and mismatched symbol widths. The full suite passes with address
and undefined-behavior sanitizers on the 64-bit Linux host. The 32-bit runtime
branch was compiled as i386 code; this host cannot execute 32-bit binaries,
so a complete 32-bit compiler/runtime execution test remains platform-dependent.

Sanitizer leak detection is disabled by the test runner;
NEW uses manual allocation by default.

Toolchain revisions used:

- o2c `feature-64bit-port`: `8c8f1960fa11e2b8c0e41e4631bc1648efae1704`
- Oberon07-tools: `a90ac128dd30814fb2f04f33fa9be938dcf0effb`

ORPC and OCB derive from the uploaded `orp.zip`; ORS is the user's updated
scanner supplied with the underscore change, extended for native numeric literals. Support modules come from the
supplied repository. Original author/provenance comments are
retained in the adapted source files.
