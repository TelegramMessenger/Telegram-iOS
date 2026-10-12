//
//   Copyright 2013 Pixar
//
//   Licensed under the terms set forth in the LICENSE.txt file available at
//   https://opensubdiv.org/license.
//

#include "../far/error.h"

#include <cassert>
#include <cstdarg>
#include <cstdio>

namespace OpenSubdiv {
namespace OPENSUBDIV_VERSION {

namespace Far {

//
//  Statics for the publicly assignable callbacks and the methods to
//  assign them (disable static assignment warnings when doing so):
//
static ErrorCallbackFunc errorFunc = 0;
static WarningCallbackFunc warningFunc = 0;

#ifdef __INTEL_COMPILER
#pragma warning disable 1711
#endif

void SetErrorCallback(ErrorCallbackFunc func) {
    errorFunc = func;
}

void SetWarningCallback(WarningCallbackFunc func) {
    warningFunc = func;
}

#ifdef __INTEL_COMPILER
#pragma warning enable 1711
#endif


//
//  The default error and warning callbacks eventually belong in the
//  internal namespace:
//
void Error(ErrorType err, const char *format, ...) {

    static char const * errorTypeLabel[] = {
        "No Error",
        "Fatal Error",
        "Coding Error (internal)",
        "Coding Error",
        "Error"
    };

    assert(err!=FAR_NO_ERROR);

    char message[10240];
    va_list argptr;
    va_start(argptr, format);
    vsnprintf(message, 10240, format, argptr);
    va_end(argptr);

    if (errorFunc) {
        errorFunc(err, message);
    } else {
        printf("%s: %s\n", errorTypeLabel[err], message);
    }
}

void Warning(const char *format, ...) {

    char message[10240];
    va_list argptr;
    va_start(argptr, format);
    vsnprintf(message, 10240, format, argptr);
    va_end(argptr);

    if (warningFunc) {
        warningFunc(message);
    } else {
        fprintf(stdout, "Warning: %s\n", message);
    }
}

} // end namespace

} // end namespace OPENSUBDIV_VERSION
} // end namespace OpenSubdiv
