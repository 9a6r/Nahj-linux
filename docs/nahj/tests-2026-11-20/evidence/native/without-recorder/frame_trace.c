/* Test instrumentation only. Never part of the boot payload. */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

FILE *fopen64(const char *path, const char *mode) {
    static FILE *(*original)(const char *, const char *);
    static int fd = -1;
    if (!original) original = dlsym(RTLD_NEXT, "fopen64");
    if (strstr(path, "/themes/nahj/") && strstr(path, ".bmp")) {
        const char *output = getenv("NAHJ_TIMING_PATH");
        if (fd < 0 && output) fd = open(output, O_WRONLY | O_CREAT | O_APPEND, 0644);
        if (fd >= 0) {
            struct timespec t;
            char line[256];
            clock_gettime(CLOCK_MONOTONIC, &t);
            int n = snprintf(line, sizeof line, "%.9f\t%s\n", t.tv_sec + t.tv_nsec/1e9, strrchr(path, '/') + 1);
            if (n > 0 && n < (int)sizeof line) (void)write(fd, line, n);
        }
    }
    return original(path, mode);
}
