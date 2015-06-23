/*
 * Author: Gwynne Raskind <gwraskin@microsoft.com>
 *
 * Copyright (c) 2015 HockeyApp, Bit Stadium GmbH.
 * All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */

#import <Foundation/Foundation.h>
#import "HockeySDKNullability.h"

typedef struct {
    const void * __nullable exception;
    const char * __nullable exception_type_name;
    const char * __nullable exception_message;
    uint32_t exception_frames_count;
    const uintptr_t * __nonnull exception_frames;
} BITCrashUncaughtCXXExceptionInfo;

typedef void (*BITCrashUncaughtCXXExceptionHandler)(
    const BITCrashUncaughtCXXExceptionInfo * __nonnull info
);

@interface BITCrashUncaughtCXXExceptionHandlerManager : NSObject

+ (void)addCXXExceptionHandler:(nonnull BITCrashUncaughtCXXExceptionHandler)handler;
+ (void)removeCXXExceptionHandler:(nonnull BITCrashUncaughtCXXExceptionHandler)handler;

@end
