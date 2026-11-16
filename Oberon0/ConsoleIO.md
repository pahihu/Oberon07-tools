# Non-blocking terminal UART

`ConsoleIO.Mod` is an o2c external Oberon-2 module with its implementation in
`ConsoleIO.c`, following the same wrapping convention as `lib/Kernal.Mod`.
The POSIX implementation uses termios, poll and non-blocking read/write. It
requires no additional library and allocates no heap memory.

## Interface

| Call | Result |
| --- | --- |
| `Open()` | 1 on success, 0 on failure; repeated calls are harmless |
| `Close` | Restore terminal settings and installed signal handlers |
| `Status()` | Bit 0 = RX byte available; bit 1 = host output writable |
| `Read()` | 0..255, -1 = no data, -2 = EOF, -3 = error |
| `Write(ch)` | 1 = written, 0 = would block/interrupted, -3 = error |

Call Open before using the interface, then Close after use. Poll Status before
reading or writing. A standalone caller must retry the same output byte after
Write returns 0. There is no output queue. Read returns promptly even without
a preceding status read. Status buffers at most one RX byte, so repeated polls
do not lose input; reading NUL is distinguishable from no input. EOF/error
clears RX readiness once any already-buffered byte is consumed.

On macOS and Linux, terminal input is delivered immediately without Enter or
local echo. CR and LF and high-bit bytes are preserved. ISIG remains enabled:
Ctrl-C still interrupts the host rather than being sent to the guest.
Redirected stdin/stdout, including pipes, are supported. File descriptor
blocking flags are restored after every native I/O call, including busy calls.
This interface is intended for a single-threaded host: descriptor flags and
terminal state are process-wide resources. O_NONBLOCK does not guarantee
bounded storage latency for redirected regular files.

The module initializes stdin/stdout as unbuffered before main-module execution.
This prevents stdio from hiding input from native reads or reordering simulator
diagnostics and UART output. Avoid simultaneous consumers of stdin; a byte
already cached by an Oberon formatted-input parser belongs to that parser.

Normal process exit restores terminal state through atexit. With default signal
dispositions, SIGINT, SIGTERM, SIGHUP, SIGQUIT and SIGPIPE restore it before
terminating with the original signal. Existing custom/ignored dispositions are
left alone; custom termination handlers should call Close. SIGKILL cannot run
cleanup. Job-control suspension is not handled: close before suspending the
host. A Windows console fallback uses _kbhit/_getch/_putch; non-blocking output
and redirected Windows handles are outside this implementation's guarantees.

## ORTool0 integration

Copy the included `Oberon0` files into the same directory of the repository and
rebuild ORTool0 using the usual o2c environment and Makefile. o2c compiles and
links ConsoleIO.c through the external module declaration. Makefile.dep includes
both new module source files so changes trigger rebuilding.

- At word address -13 (byte address -52), bit 0 rxRdy reflects actual RX status.
  There is no delayRxCounter.
- Bit 1 txRdy requires both a writable host output and delayTxCounter = 0.
- At word address -14 (byte address -56), reads never wait; empty/EOF/error reads
  return zero. Check rxRdy to distinguish these from an actual NUL byte.
- Writes send all eight bits and start the existing DelayTX simulation only
  when the host accepts the byte. As with a UART without a TX FIFO, guest code
  must respect txRdy. Writes while busy are ignored. Host errors/interruption
  do not start the delay counter.
- The existing /a option still sets DelayTX to zero; host readiness still applies.
- UART output goes straight to stdout and is no longer copied to Oberon.Log.
  Other simulator diagnostics retain their existing logging behavior.
- Execution opens/closes the console. Debugger prompts and legacy ReadInt
  temporarily restore cooked terminal input.

## Validation

From Oberon0, with a checkout of the specified o2c branch available:

```sh
python3 tests/test_console_io.py /path/to/o2c/system
python3 tests/test_uart_sim.py ./ORTool0
```

The backend tests compile the actual C implementation with a minimal runtime
registration stub, then exercise empty input, repeated status polling, NUL and
high-bit bytes, EOF, full-pipe output backpressure, immediate PTY input without
Enter/echo, descriptor flags, and terminal restoration on exit/signals.
The simulator test runs a small RISC5 binary that polls both ready bits and
echoes ASCII, NUL, 0x80 and 0xFF through the memory-mapped UART.

Validated on Linux x86-64 with o2c feature-64bit-port. macOS uses the same POSIX
implementation; macOS and Windows execution were not available for testing.
