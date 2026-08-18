#ifndef __DEBUG_H_
#define __DEBUG_H_

#include <time.h>
#include "stdarg.h"
#include "stdio.h"

static void dbgPrint(const char* fmt, ...) {
#ifndef NDEBUG
    va_list arguments;
    va_start(arguments, fmt);
    fprintf(stderr, fmt, arguments);
#endif
}

static void logFormattedWrite(void* log, const char* fmt, ...) {
    char buffer[80];
    time_t rawtime;
    tm* timeinfo;

    time(&rawtime);
    timeinfo = localtime(&rawtime);
    strftime(buffer, 80, "%d-%m-%Y %H:%M:%S", timeinfo);

    va_list arguments;
    va_start(arguments, fmt);
    printf("%s: ", buffer);
    vprintf(
        fmt, arguments); // FIX: was printf(fmt, arguments) - must be vprintf!
    printf("\n");
    va_end(arguments);
}

#endif //__DEBUG_H_
