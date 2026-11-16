# ORTool0 ESP8266 TCP UART emulator

The host-side `TCPNet.Mod` emulates the ESP-AT protocol used by the supplied
ComsTime guest's `TCPNet.Mod` and `TCPUART.Mod`. These are separate modules in
separate programs: keep the guest sources in the guest package and the emulator
sources in `Oberon07-tools/Oberon0`. The guest needs no changes.

`TCPSockets.Mod`/`TCPSockets.c` wrap real TCP sockets. The C wrapper uses POSIX
sockets on Linux/macOS and Winsock on Windows. DNS runs in detached native worker
threads; connect, send and receive run non-blocking on the simulator thread.
No network/DNS wait suspends the simulated CPU or coroutine scheduler.

## Installation and build

Copy the included `Oberon0` tree over the repository's directory, then rebuild
ORTool0 using its existing o2c feature-64bit-port environment. The archive also
contains the preceding ConsoleIO terminal support and its simulator integration.
`ORTool0-TCPNet.patch` applies the combined changes to the base Git commit listed
in `BASE_COMMIT.txt`; copy the supplied files instead when ConsoleIO is already
installed.

The updated Makefile adds `-pthread` to compilation/linking on Linux and macOS,
and `-lws2_32` to linking under MinGW (`OS=Windows_NT`). No other network library
is needed. If building manually, retain the normal dynamic-export flags:

```sh
# Linux
cd Oberon0
o2c --cflags -pthread --ldflags '-Wl,--export-dynamic -pthread' -M -O ORTool0
# macOS
o2c --cflags -pthread --ldflags -pthread -M -O ORTool0
# Windows, in the existing MinGW/o2c environment
o2c --ldflags '-Wl,--export-all-symbols -lws2_32' -M -O ORTool0
```

Use the repository's normal source search/redirection configuration. Both
`.Mod` files and their external `.c` implementation must be searchable by o2c.
If linking ORTool0 from another Makefile, add the same platform-specific flags.

Run guest images as usual; there is no additional enable switch:

```sh
./ORTool0 Execute YourProgram.bin/ai
```

`/a` is useful for network applications because guest timeouts then use host
elapsed milliseconds. Without `/a`, timers use simulated 12 MHz cycles, so their
relationship to host network time depends on simulator speed. `/i` retains the
existing clock-interrupt option. Socket operation happens only when the guest
issues AT commands. The second UART is independent of the serial console UART.

## Register interface

| Byte address | Word address inside RISC.Mod | Read | Write |
| --- | --- | --- | --- |
| -20 | -5 | Bit 0 rxRdy, bit 1 txRdy | Ignored; no defined control bits |
| -24 | -6 | Next byte, or zero if RX empty | One byte if txRdy; otherwise ignored |

RX-ready means a byte is queued. TX-ready means the emulated ESP can accept
another UART byte: it clears during connection establishment, while a completed
send payload is being delivered, and when the RX response queue has insufficient
space. There are no artificial RX or TX delay counters on this UART. The first
UART keeps its existing delayTxCounter.

RISC.Mod services the emulator on register access and at least once per 12,000
simulated clocks while executing instructions. ORTool0 resets it before execution
and closes all links when execution returns. A direct host-side user of RISC.Execute
should likewise call TCPNet.Reset before execution and TCPNet.Close afterwards.

## Emulated AT subset

| Command | Behavior |
| --- | --- |
| AT | OK |
| ATE0 / ATE1 | Disable/enable command echo; default enabled |
| AT+CWMODE=1 | Station mode acknowledged |
| AT+CIPMODE=0 | Command mode acknowledged |
| AT+CIPMUX=1 | Five-link mode acknowledged |
| AT+CIPDINFO=0 | IPD without peer address acknowledged |
| AT+CIPRECVMODE=0 | Active receive mode acknowledged |
| AT+CWJAP="ssid","password" | Virtual association; WIFI CONNECTED, WIFI GOT IP, OK |
| AT+CIPSTART=id,"TCP","host",port | Async host connect; id,CONNECT then OK, or ERROR |
| AT+CIPSEND=id,length | OK and `> ` prompt, followed by exactly length binary bytes; SEND OK/FAIL |
| AT+CIPCLOSE=id | Close host socket; id,CLOSED then OK |
| AT+CWQAP | Close links and report WIFI DISCONNECT, OK |
| AT+RST | Reset command/connection state and report OK, ready |

IDs are 0..4, ports 1..65535, and send lengths 1..1460. Quotes, commas and
backslashes escaped by the guest are decoded. DNS hostnames, numeric IPv4, and
numeric IPv6 addresses are accepted by the host resolver. All resolved addresses
are tried until one connects or the overall ten-second host deadline expires.
A DNS call exceeding that deadline is abandoned without blocking the simulator.
Its slot cannot be reused until the background resolver returns; an early reuse
attempt receives ERROR, and a later attempt can succeed.

Command lines are bounded to 511 bytes including optional CR, excluding LF;
overlong/invalid lines are discarded through LF and receive ERROR. Unsupported
commands, UDP/server/transparent/passive modes, invalid IDs and invalid parameters
receive ERROR. This is the guest driver's ESP-AT subset, not full ESP firmware.

No real Wi-Fi configuration is changed: association starts virtually connected,
and CWJAP succeeds for syntactically valid credentials. Host networking decides
which TCP peers are reachable. Reset does not emit unsolicited boot noise.
AT+RST is recognized only in command mode: inside an incomplete CIPSEND payload
its bytes are payload, matching the guest's documented recovery limitation.

Received socket data becomes binary `+IPD,<id>,<length>:` frames. Payloads retain
all eight bits, including NUL, CR/LF, `>` and AT-looking text. Remote EOF/errors
produce id,CLOSED after any previously received data. Each read takes at most
512 socket bytes; TCP remains a stream, with no message-boundary guarantees.

The emulator has an 8192-byte RX ring, a 512-byte command buffer, a 1460-byte
send buffer and a 512-byte socket-read buffer. It stops reading sockets when
response space is scarce, applying TCP backpressure rather than dropping data.
The supplied guest's independent 512-byte receive rings can still overflow if
its application does not receive promptly. SEND OK means the full payload was
accepted by the host socket, not that the remote application consumed it.

## Validation

On Linux x86-64, compiled with the specified o2c branch and tested:

- Original ConsoleIO tests and RISC5 console echo regression.
- AT initialization, quoting, malformed/overlong commands and recovery.
- Five simultaneous real TCP links, hostname fallback, close and slot reuse.
- Binary payloads, fragmented command/payload input and 1460-byte sends.
- Connection refusal, DNS failure, remote close, virtual disconnect and reset.
- The unmodified supplied guest TCPNet/TCPUART and coroutine scheduler, compiled
  with numeric-CASE ORP and linked by ORL: a real RISC5 guest exchanges every byte
  value with a delayed localhost server and confirms another task keeps running.

TCPSockets.c cross-compiles with strict warnings for macOS Intel/ARM64 and
Windows x86/x64. macOS/Windows runtime execution was not available here.

To reproduce, build the test bridge with `tests` on o2c's module-source search
path (the generated executable should be named TCPHostTest):

```sh
o2c --cflags -pthread --ldflags -pthread -M TCPHostTest
python3 tests/test_tcpnet.py ./TCPHostTest
python3 tests/test_console_io.py /path/to/o2c/system
python3 tests/test_uart_sim.py ./ORTool0
python3 tests/test_tcp_guest.py /path/to/ORP /path/to/ORL ./ORTool0 /path/to/pkg
```

For the bridge on Windows use `--ldflags -lws2_32` instead of pthread flags.
The guest test chooses its own localhost port and passes it through ORTool0's
existing `/w` switch register. It copies the original guest modules into a
private temporary directory, compiles TCPMMIOTest and runs it with `/ai`.
