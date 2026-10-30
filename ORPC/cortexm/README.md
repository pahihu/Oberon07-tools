# Coroutines

A few constraints matter:
- Call coro_transfer() from Thread mode, with from identifying the currently executing coroutine.
- All coroutines use the same stack selection—MSP or PSP—and privilege level. Interrupts may run normally, but must not switch coroutines through this function.
- When Thread mode uses MSP, the coroutine stack must also have room for interrupt handlers and exception frames.
- The function preserves ordinary callee-saved registers, including floating-point registers when enabled. It does not provide separate interrupt-mask, CONTROL, or floating-point control settings per coroutine.
- Stack size is your responsibility; creation checks only that the descriptor and initial context fit.
- Normally, proc should loop and yield. Here, returning from it enters an infinite loop.
The switch saves 36 bytes without hardware floating point, or 100 bytes with it, plus whatever stack space the coroutine’s own calls require.
