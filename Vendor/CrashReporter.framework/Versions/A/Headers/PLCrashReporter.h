/*
 * Author: Landon Fuller <landonf@plausiblelabs.com>
 *
 * Copyright (c) 2008-2009 Plausible Labs Cooperative, Inc.
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

/**
 * @ingroup functions
 *
 * Prototype of a callback function used to execute additional user code with signal information as provided
 * by PLCrashReporter. Called upon completion of crash handling, after the crash report has been written to disk.
 *
 * @param info The signal info.
 * @param uap The crash's threads context.
 * @param context The API client's supplied context value.
 *
 * @sa @ref async_safety
 * @sa PLCrashReporter::setPostCrashCallbacks:
 */
typedef void (*PLCrashReporterPostCrashSignalCallback)(siginfo_t *info, ucontext_t *uap, void *context);

/**
 * @ingroup types
 *
 * This structure contains callbacks supported by PLCrashReporter to allow the host application to perform
 * additional tasks prior to program termination after a crash has occured.
 *
 * @sa @ref async_safety
 */
typedef struct PLCrashReporterCallbacks {
    /** The version number of this structure. If not one of the defined version numbers for this type, the behavior
     * is undefined. The current version of this structure is 0. */
    uint16_t version;
    
    /** An arbitrary user-supplied context value. This value may be NULL. */
    void *context;

    /** The callback used to report caught signal information. In version 0 of this structure, all crashes will be
     * reported via this function. */
    PLCrashReporterPostCrashSignalCallback handleSignal;
} PLCrashReporterCallbacks;

@interface PLCrashReporter : NSObject {
@private
    /** YES if the crash reporter has been enabled */
    BOOL _enabled;

    /** Application identifier */
    NSString *_applicationIdentifier;

    /** Application version */
    NSString *_applicationVersion;

    /** Path to the crash reporter internal data directory */
    NSString *_crashReportDirectory;
}

+ (PLCrashReporter *) sharedReporter;

- (BOOL) hasPendingCrashReport;

- (NSData *) loadPendingCrashReportData;
- (NSData *) loadPendingCrashReportDataAndReturnError: (NSError **) outError;

- (BOOL) purgePendingCrashReport;
- (BOOL) purgePendingCrashReportAndReturnError: (NSError **) outError;

- (BOOL) enableCrashReporter;
- (BOOL) enableCrashReporterAndReturnError: (NSError **) outError;

- (void) setCrashCallbacks: (PLCrashReporterCallbacks *) callbacks;

@end