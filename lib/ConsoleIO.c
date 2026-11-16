/* Non-blocking terminal bytes for o2c. Single-threaded use, as in ORTool0. */
#ifndef _POSIX_C_SOURCE
#define _POSIX_C_SOURCE 200809L
#endif
#define MODULE_ConsoleIO
#include "_OGCC.h"
#include <stdlib.h>
#include <stdio.h>

static int opened, pending = -1, input_end;

#ifdef _WIN32
#include <conio.h>
/* Windows console fallback. POSIX provides the non-blocking TX guarantee. */
int ConsoleIO_Open(void) { opened = 1; return 1; }
void ConsoleIO_Close(void) { opened = 0; }
static int read_byte(void) { return _kbhit() ? _getch() : -1; }
static int tx_ready(void) { return 1; }
int ConsoleIO_Write(int ch)
{
    if (!opened) return -3;
    return _putch(ch & 255) == EOF ? -3 : 1;
}
#else
#include <unistd.h>
#include <fcntl.h>
#include <poll.h>
#include <termios.h>
#include <signal.h>
#include <errno.h>

static struct termios saved_term;
static int terminal_changed;
static volatile sig_atomic_t active_fd = -1, active_flags;
static const int signals[] = { SIGINT, SIGTERM, SIGHUP, SIGQUIT, SIGPIPE };
#define NSIGNALS (sizeof signals / sizeof signals[0])
static struct sigaction saved_actions[NSIGNALS];
static int installed[NSIGNALS];

void ConsoleIO_Close(void)
{
    size_t i;
    if (active_fd >= 0) {
        (void)fcntl(active_fd, F_SETFL, active_flags);
        active_fd = -1;
    }
    if (terminal_changed) {
        (void)tcsetattr(STDIN_FILENO, TCSANOW, &saved_term);
        terminal_changed = 0;
    }
    for (i = 0; i < NSIGNALS; ++i) {
        if (installed[i]) {
            (void)sigaction(signals[i], &saved_actions[i], NULL);
            installed[i] = 0;
        }
    }
    opened = 0;
}

static void on_signal(int sig)
{
    ConsoleIO_Close();
    /* The previous default disposition is restored; preserve signal exit. */
    (void)raise(sig);
}

int ConsoleIO_Open(void)
{
    struct termios term;
    struct sigaction action;
    size_t i;
    if (opened) return 1;
    if (isatty(STDIN_FILENO)) {
        if (tcgetattr(STDIN_FILENO, &saved_term) < 0) return 0;
        term = saved_term;
        /* Keep ISIG (Ctrl-C) and output processing. Deliver all 8 input bits. */
        term.c_lflag &= ~(ICANON | ECHO | ECHONL | IEXTEN);
        term.c_iflag &= ~(ICRNL | INLCR | IGNCR | ISTRIP | IXON | IXOFF | PARMRK);
        term.c_cc[VMIN] = 1;
        term.c_cc[VTIME] = 0;
        if (tcsetattr(STDIN_FILENO, TCSANOW, &term) < 0) return 0;
        terminal_changed = 1;
    }
    sigemptyset(&action.sa_mask);
    action.sa_handler = on_signal;
    action.sa_flags = 0;
    for (i = 0; i < NSIGNALS; ++i) {
        if (sigaction(signals[i], NULL, &saved_actions[i]) == 0 &&
            saved_actions[i].sa_handler == SIG_DFL &&
            sigaction(signals[i], &action, NULL) == 0)
            installed[i] = 1;
    }
    opened = 1;
    return 1;
}

/* Change O_NONBLOCK only around our syscall. stdout is also used by the
   simulator's stdio diagnostics. dup() would still share its status flags.
   The host is single-threaded; do not concurrently use these descriptors. */
static int transfer(int fd, unsigned char *ch, int output)
{
    int flags, result, error;
    ssize_t n;
    flags = fcntl(fd, F_GETFL);
    if (flags < 0) return -3;
    active_flags = flags;
    active_fd = fd;
    if (!(flags & O_NONBLOCK) && fcntl(fd, F_SETFL, flags | O_NONBLOCK) < 0) {
        active_fd = -1;
        return -3;
    }
    n = output ? write(fd, ch, 1) : read(fd, ch, 1);
    error = errno;
    result = n == 1 ? 1 : (n == 0 && !output ? -2 : -3);
    if (n < 0 && (error == EAGAIN || error == EWOULDBLOCK || error == EINTR))
        result = 0;
    if (!(flags & O_NONBLOCK) && fcntl(fd, F_SETFL, flags) < 0) return -3;
    active_fd = -1;
    return result;
}

static int read_byte(void)
{
    unsigned char ch;
    int result = transfer(STDIN_FILENO, &ch, 0);
    return result == 1 ? ch : (result == 0 ? -1 : result);
}

static int tx_ready(void)
{
    struct pollfd fd;
    fd.fd = STDOUT_FILENO;
    fd.events = POLLOUT;
    fd.revents = 0;
    return poll(&fd, 1, 0) > 0 && (fd.revents & POLLOUT) &&
           !(fd.revents & (POLLERR | POLLHUP | POLLNVAL));
}

int ConsoleIO_Write(int value)
{
    unsigned char ch = (unsigned char)value;
    int result;
    if (!opened) return -3;
    result = transfer(STDOUT_FILENO, &ch, 1);
    return result < 0 ? -3 : result;
}
#endif

static void fill_rx(void)
{
    int ch;
    if (pending >= 0 || input_end) return;
    ch = read_byte();
    if (ch >= 0) pending = ch;
    else if (ch == -2 || ch == -3) input_end = ch;
}

int ConsoleIO_Status(void)
{
    if (!opened) return 0;
    fill_rx();
    return (pending >= 0 ? 1 : 0) | (tx_ready() ? 2 : 0);
}

int ConsoleIO_Read(void)
{
    int ch;
    if (!opened) return -3;
    fill_rx();
    ch = pending;
    if (ch >= 0) pending = -1;
    else if (input_end) ch = input_end;
    return ch;
}

void _init_ConsoleIO(void)
{
    (void)add_module("ConsoleIO");
    /* Native read/write and the debugger's stdio must not maintain separate
       hidden buffers or reorder UART bytes and simulator diagnostics.
       o2c initializes this module before executing the main module body. */
    (void)setvbuf(stdin, NULL, _IONBF, 0);
    (void)setvbuf(stdout, NULL, _IONBF, 0);
    (void)atexit(ConsoleIO_Close);
}
