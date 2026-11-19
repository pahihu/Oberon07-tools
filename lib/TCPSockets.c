/* Portable, single-simulator-thread TCP and IPv4 UDP sockets; background DNS only.
   Resolver storage is static and protected by one process-local lock. */
#ifndef _POSIX_C_SOURCE
#define _POSIX_C_SOURCE 200809L
#endif
#define MODULE_TCPSockets
#include "_OGCC.h"
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#ifdef _WIN32
/* Windows and o2c both define CHAR, with different signedness. Keep the
   native header typedef separate within this translation unit. */
#define CHAR TCPSockets_WindowsCHAR
#include <winsock2.h>
#include <ws2tcpip.h>
#include <wspiapi.h>
#include <windows.h>
#undef CHAR
typedef SOCKET socket_t;
#define BAD_SOCKET INVALID_SOCKET
#define close_socket closesocket
static CRITICAL_SECTION lock;
#define LOCK() EnterCriticalSection(&lock)
#define UNLOCK() LeaveCriticalSection(&lock)
static int socket_error(void) { return WSAGetLastError(); }
static int busy(int e) { return e == WSAEWOULDBLOCK || e == WSAEINPROGRESS || e == WSAEALREADY || e == WSAEINTR; }
static uint32_t milliseconds(void) { return (uint32_t)GetTickCount(); }
static int nonblocking(socket_t s) { u_long one = 1; return ioctlsocket(s, FIONBIO, &one); }
#ifndef inet_pton
WSAAPI int inet_pton(int Family, const char *pszAddrString, void* pAddrBuf);
#endif
#else
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/select.h>
#include <netdb.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <pthread.h>
#include <time.h>
typedef int socket_t;
#define BAD_SOCKET (-1)
#define close_socket close
static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;
#define LOCK() ((void)pthread_mutex_lock(&lock))
#define UNLOCK() ((void)pthread_mutex_unlock(&lock))
static int socket_error(void) { return errno; }
static int busy(int e) { return e == EWOULDBLOCK || e == EAGAIN || e == EINPROGRESS || e == EALREADY || e == EINTR; }
static uint32_t milliseconds(void) {
    struct timespec ts;
    (void)clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint32_t)((uint64_t)ts.tv_sec * 1000 + ts.tv_nsec / 1000000);
}
static int nonblocking(socket_t s) {
    int flags = fcntl(s, F_GETFL);
    if (flags < 0 || fcntl(s, F_SETFL, flags | O_NONBLOCK) < 0) return -1;
    /* Do not inherit sockets across exec. */
    flags = fcntl(s, F_GETFD);
    if (flags >= 0) (void)fcntl(s, F_SETFD, flags | FD_CLOEXEC);
    return 0;
}
#endif

#ifndef INADDR_LOOPBACK
#define INADDR_LOOPBACK (0x7f000001u)
#endif

#define LINKS 5
#define CONNECT_TIMEOUT 10000u
#define UDP_MAX 1460
/* resolver state: 0 idle, 1 running, 2 finished, 3 abandoned.
   A canceled running resolver retains its slot until getaddrinfo returns. */
typedef struct {
    int resolver_state, resolver_error;
    char host[256], service[8];
    struct addrinfo *addresses, *next;
    socket_t socket;
    int phase; /* 0 idle/failed, 1 resolving, 2 connecting, 3 TCP, 4 UDP */
    uint32_t started;
    struct sockaddr_in peer;
    int accepted;
    int udp_mode; /* ESP-AT peer update policy */
} Link;
static Link links[LINKS];
static int initialized, available;
static socket_t listener = BAD_SOCKET;

static void resolve(Link *p)
{
    struct addrinfo hints, *addresses = NULL;
    int error;
    memset(&hints, 0, sizeof hints);
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_protocol = IPPROTO_TCP;
    error = getaddrinfo(p->host, p->service, &hints, &addresses);
    LOCK();
    if (p->resolver_state == 3) {
        if (addresses) freeaddrinfo(addresses);
        p->resolver_state = 0;
    } else {
        p->addresses = addresses;
        p->resolver_error = error;
        p->resolver_state = 2;
    }
    UNLOCK();
}
#ifdef _WIN32
static DWORD WINAPI resolver_thread(LPVOID arg) { resolve((Link *)arg); return 0; }
#else
static void *resolver_thread(void *arg) { resolve((Link *)arg); return NULL; }
#endif

void TCPSockets_Close(int id)
{
    Link *p;
    if (!initialized || id < 0 || id >= LINKS) return;
    p = &links[id];
    if (p->socket != BAD_SOCKET) close_socket(p->socket);
    p->socket = BAD_SOCKET;
    p->phase = 0;
    p->accepted = 0;
    LOCK();
    if (p->resolver_state == 1) p->resolver_state = 3;
    else if (p->resolver_state != 3) {
        if (p->addresses) freeaddrinfo(p->addresses);
        p->addresses = p->next = NULL;
        p->resolver_state = 0;
    }
    UNLOCK();
}

void TCPSockets_StopListener(void)
{
    int i;
    if (listener != BAD_SOCKET) close_socket(listener);
    listener = BAD_SOCKET;
    for (i = 0; i < LINKS; ++i) {
        if (links[i].accepted) TCPSockets_Close(i);
    }
}

int TCPSockets_Listen(int port)
{
    struct sockaddr_in address;
    socket_t s;
    if (!available || port < 1 || port > 65535 || listener != BAD_SOCKET) return -1;
    s = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (s == BAD_SOCKET) return -1;
#ifndef _WIN32
    { int one = 1; (void)setsockopt(s, SOL_SOCKET, SO_REUSEADDR, &one, sizeof one); }
#endif
    memset(&address, 0, sizeof address);
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    address.sin_port = htons((uint16_t)port);
    if (nonblocking(s) != 0 ||
        bind(s, (const struct sockaddr *)&address, sizeof address) != 0 ||
        listen(s, 1) != 0) {
        close_socket(s);
        return -1;
    }
    listener = s;
    return 0;
}

int TCPSockets_Accept(void)
{
    int i, id = -1;
    socket_t s;
    if (listener == BAD_SOCKET) return -1;
    for (i = 0; i < LINKS; ++i) {
        if (links[i].accepted) return -1;
        if (id < 0 && links[i].phase == 0) id = i;
    }
    if (id < 0) return -1;
    s = accept(listener, NULL, NULL);
    if (s == BAD_SOCKET) return -1;
    if (nonblocking(s) != 0) { close_socket(s); return -1; }
#ifdef SO_NOSIGPIPE
    { int one = 1; (void)setsockopt(s, SOL_SOCKET, SO_NOSIGPIPE, &one, sizeof one); }
#endif
    links[id].socket = s;
    links[id].phase = 3;
    links[id].accepted = 1;
    return id;
}

void TCPSockets_CloseAll(void)
{
    int i;
    TCPSockets_StopListener();
    for (i = 0; i < LINKS; ++i) TCPSockets_Close(i);
}

int TCPSockets_Start(int id, const unsigned char *host, int port)
{
    Link *p;
    size_t n;
    int result = 0;
#ifdef _WIN32
    HANDLE thread;
#else
    pthread_t thread;
    pthread_attr_t attr;
#endif
    if (!available || id < 0 || id >= LINKS || port < 1 || port > 65535) return -1;
    n = strlen((const char *)host);
    if (!n || n >= sizeof links[0].host) return -1;
    p = &links[id];
    if (p->phase) return -1;
    LOCK();
    if (p->resolver_state != 0) { UNLOCK(); return -1; }
    memcpy(p->host, host, n + 1);
    /* Avoid stdio/compiler runtime prototype collisions. */
    {
        unsigned int value = (unsigned int)port;
        char reversed[6];
        int i = 0, j = 0;
        do { reversed[i++] = (char)('0' + value % 10); value /= 10; } while (value);
        while (i) p->service[j++] = reversed[--i];
        p->service[j] = 0;
    }
    p->resolver_state = 1;
    p->resolver_error = 0;
    p->started = milliseconds();
    p->phase = 1;
#ifdef _WIN32
    thread = CreateThread(NULL, 0, resolver_thread, p, 0, NULL);
    if (thread) CloseHandle(thread); else result = -1;
#else
    if (pthread_attr_init(&attr) != 0) result = -1;
    else {
        if (pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED) != 0 ||
            pthread_create(&thread, &attr, resolver_thread, p) != 0) result = -1;
        (void)pthread_attr_destroy(&attr);
    }
#endif
    if (result) { p->resolver_state = 0; p->phase = 0; }
    UNLOCK();
    return result;
}

static void release_addresses(Link *p)
{
    LOCK();
    if (p->addresses) freeaddrinfo(p->addresses);
    p->addresses = p->next = NULL;
    p->resolver_state = 0;
    UNLOCK();
}

static int try_address(Link *p)
{
    int result, error;
    struct addrinfo *a;
    while ((a = p->next) != NULL) {
        p->next = a->ai_next;
        p->socket = socket(a->ai_family, a->ai_socktype, a->ai_protocol);
        if (p->socket == BAD_SOCKET) continue;
#ifndef _WIN32
        if (p->socket >= FD_SETSIZE) { close_socket(p->socket); p->socket = BAD_SOCKET; continue; }
#ifdef SO_NOSIGPIPE
        { int one = 1; (void)setsockopt(p->socket, SOL_SOCKET, SO_NOSIGPIPE, &one, sizeof one); }
#endif
#endif
        if (nonblocking(p->socket) == 0) {
            result = connect(p->socket, a->ai_addr, (int)a->ai_addrlen);
            if (result == 0) { p->phase = 3; release_addresses(p); return 1; }
            error = socket_error();
            if (busy(error)) { p->phase = 2; return 0; }
        }
        close_socket(p->socket);
        p->socket = BAD_SOCKET;
    }
    release_addresses(p);
    p->phase = 0;
    return -1;
}

int TCPSockets_Poll(int id)
{
    Link *p;
    fd_set wr, ex;
    struct timeval zero;
    int state, result, error = 0;
#ifdef _WIN32
    int length = sizeof error;
#else
    socklen_t length = sizeof error;
#endif
    if (id < 0 || id >= LINKS) return -1;
    p = &links[id];
    if (p->phase == 3) return 1;
    if (!p->phase) return -1;
    if ((uint32_t)(milliseconds() - p->started) >= CONNECT_TIMEOUT) {
        TCPSockets_Close(id); return -1;
    }
    if (p->phase == 1) {
        LOCK(); state = p->resolver_state; UNLOCK();
        if (state != 2) return 0;
        if (p->resolver_error) { TCPSockets_Close(id); return -1; }
        p->next = p->addresses;
        return try_address(p);
    }
    FD_ZERO(&wr); FD_ZERO(&ex);
    FD_SET(p->socket, &wr); FD_SET(p->socket, &ex);
    zero.tv_sec = 0; zero.tv_usec = 0;
    result = select((int)(p->socket + 1), NULL, &wr, &ex, &zero);
    if (result == 0 || (result < 0 && busy(socket_error()))) return 0;
    if (result > 0 && getsockopt(p->socket, SOL_SOCKET, SO_ERROR, (char *)&error, &length) == 0 && !error) {
        p->phase = 3; release_addresses(p); return 1;
    }
    close_socket(p->socket); p->socket = BAD_SOCKET;
    return try_address(p);
}

int TCPSockets_Send(int id, unsigned char *data, int offset, int count)
{
    int n, flags = 0;
    if (id < 0 || id >= LINKS || links[id].phase != 3 || offset < 0 || count < 0 || count > 1460 || offset > 1460 - count) return -1;
#ifdef MSG_NOSIGNAL
    flags = MSG_NOSIGNAL;
#endif
    n = (int)send(links[id].socket, (const char *)data + offset, count, flags);
    if (n < 0) return busy(socket_error()) ? 0 : -1;
    return n;
}

int TCPSockets_Receive(int id, unsigned char *data, int count)
{
    int n;
    if (id < 0 || id >= LINKS || links[id].phase != 3 || count < 1 || count > 512) return -1;
    n = (int)recv(links[id].socket, (char *)data, count, 0);
    if (n < 0) return busy(socket_error()) ? 0 : -1;
    return n == 0 ? -1 : n;
}

static int ipv4(struct sockaddr_in *address, const unsigned char *host, int port)
{
    memset(address, 0, sizeof *address);
    address->sin_family = AF_INET;
    address->sin_port = htons((uint16_t)port);
    return inet_pton(AF_INET, (const char *)host, &address->sin_addr) == 1;
}

int TCPSockets_UDPStart(int id, const unsigned char *host, int port, int local, int mode)
{
    Link *p;
    socket_t s;
    struct sockaddr_in address, peer;
    int one = 1;
    if (!available || id < 0 || id >= LINKS || port < 1 || port > 65535 ||
        local < 0 || local > 65535 || mode < 0 || mode > 2 || !ipv4(&peer, host, port)) return -1;
    p = &links[id];
    if (p->phase) return -1;
    s = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    if (s == BAD_SOCKET) return -1;
    memset(&address, 0, sizeof address);
    address.sin_family = AF_INET;
    address.sin_port = htons((uint16_t)local);
    if (nonblocking(s) != 0 ||
        setsockopt(s, SOL_SOCKET, SO_BROADCAST, (const char *)&one, sizeof one) != 0 ||
        bind(s, (const struct sockaddr *)&address, sizeof address) != 0) {
        close_socket(s);
        return -1;
    }
    p->socket = s;
    p->peer = peer;
    p->udp_mode = mode;
    p->phase = 4;
    return 0;
}

int TCPSockets_UDPSend(int id, unsigned char *data, int count, const unsigned char *host, int port)
{
    struct sockaddr_in peer;
    int n;
    if (id < 0 || id >= LINKS || links[id].phase != 4 || count < 1 || count > UDP_MAX) return -1;
    peer = links[id].peer;
    if (host[0] && (port < 1 || port > 65535 || !ipv4(&peer, host, port))) return -1;
    n = (int)sendto(links[id].socket, (const char *)data, count, 0,
                    (const struct sockaddr *)&peer, sizeof peer);
    if (n < 0) return busy(socket_error()) ? 0 : -1;
    return n == count ? 1 : -1;
}

int TCPSockets_UDPReceive(int id, unsigned char *data, unsigned char *peer)
{
    struct sockaddr_in source;
    unsigned char packet[UDP_MAX + 1];
    int n, error;
    Link *p;
#ifdef _WIN32
    int length = sizeof source;
#else
    socklen_t length = sizeof source;
#endif
    if (id < 0 || id >= LINKS || links[id].phase != 4) return -1;
    p = &links[id];
    n = (int)recvfrom(p->socket, (char *)packet, sizeof packet, 0,
                      (struct sockaddr *)&source, &length);
    if (n < 0) {
        error = socket_error();
#ifdef _WIN32
        if (error == WSAEMSGSIZE || error == WSAECONNRESET) return 0;
#else
        if (error == ECONNREFUSED) return 0;
#endif
        return busy(error) ? 0 : -1;
    }
    if (n > UDP_MAX) return 0;
    if (p->udp_mode > 0) {
        if (p->udp_mode == 1 && (source.sin_addr.s_addr != p->peer.sin_addr.s_addr ||
                                source.sin_port != p->peer.sin_port)) p->udp_mode = 0;
        p->peer = source;
    }
    memcpy(data, packet, (size_t)n);
    memcpy(peer, &source.sin_addr.s_addr, 4);
    memcpy(peer + 4, &source.sin_port, 2);
    return n + 1;
}

void _init_TCPSockets(void)
{
    int i;
    (void)add_module("TCPSockets");
#ifdef _WIN32
    { WSADATA data; InitializeCriticalSection(&lock); available = WSAStartup(MAKEWORD(2,2), &data) == 0; }
#else
    available = 1;
#endif
    for (i = 0; i < LINKS; ++i) links[i].socket = BAD_SOCKET;
    initialized = 1;
    (void)atexit(TCPSockets_CloseAll);
}
