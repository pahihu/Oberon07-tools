#include <stdio.h>
#include <stdlib.h>
#include <sys/time.h>
#include <sys/types.h>
#include <pwd.h>
#include <unistd.h>

int main(int argc,char*argv[])
{
    struct timeval tv;

    printf("sizeof(time_t)=%ld\n", sizeof(time_t));
    printf("sizeof(suseconds_t)=%ld\n", sizeof(suseconds_t));
    printf("sizeof(uid_t)=%ld\n", sizeof(uid_t));
    printf("sizeof(gid_t)=%ld\n", sizeof(gid_t));

    return 0;
}
