//
//  CFileSystemShims.c
//  swift-file-system
//
//  C shims for system calls not available through Swift's platform overlays.
//

#include "CFileSystemShims.h"

#ifdef __linux__

#define _GNU_SOURCE
#include <fcntl.h>
#include <errno.h>
#include <unistd.h>
#include <sys/syscall.h>

// RENAME_NOREPLACE may not be defined in older headers
#ifndef RENAME_NOREPLACE
#define RENAME_NOREPLACE (1 << 0)
#endif

// renameat2 syscall number varies by architecture
#ifndef SYS_renameat2
#if defined(__x86_64__)
#define SYS_renameat2 316
#elif defined(__aarch64__)
#define SYS_renameat2 276
#elif defined(__arm__)
#define SYS_renameat2 382
#else
#define SYS_renameat2 -1
#endif
#endif

int atomicfilewrite_renameat2_noreplace(
    const char *from,
    const char *to,
    int32_t *out_errno
) {
#if SYS_renameat2 > 0
    int result = (int)syscall(SYS_renameat2, AT_FDCWD, from, AT_FDCWD, to, RENAME_NOREPLACE);
    if (result == -1) {
        *out_errno = errno;
        return -1;
    }
    *out_errno = 0;
    return 0;
#else
    // Syscall not available on this architecture
    *out_errno = ENOSYS;
    return -1;
#endif
}

// SYS_getrandom syscall number varies by architecture
#ifndef SYS_getrandom
#if defined(__x86_64__)
#define SYS_getrandom 318
#elif defined(__aarch64__)
#define SYS_getrandom 278
#elif defined(__arm__)
#define SYS_getrandom 384
#else
#define SYS_getrandom -1
#endif
#endif

long atomicfilewrite_getrandom(
    void *buffer,
    size_t length,
    unsigned int flags
) {
#if SYS_getrandom > 0
    return syscall(SYS_getrandom, buffer, length, flags);
#else
    // Syscall not available on this architecture
    errno = ENOSYS;
    return -1;
#endif
}

#endif // __linux__
