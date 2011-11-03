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

#ifdef __APPLE__
#import <AvailabilityMacros.h>
#endif

#import "PLCrashReporter.h"
#import "PLCrashReport.h"
#import "PLCrashReportTextFormatter.h"

/**
 * @defgroup functions Crash Reporter Functions Reference
 */

/**
 * @defgroup types Crash Reporter Data Types Reference
 */

/**
 * @defgroup constants Crash Reporter Constants Reference
 */

/**
 * @internal
 * @defgroup plcrash_internal Crash Reporter Internal Documentation
 */

/**
 * @defgroup enums Enumerations
 * @ingroup constants
 */

/**
 * @defgroup globals Global Variables
 * @ingroup constants
 */

/**
 * @defgroup exceptions Exceptions
 * @ingroup constants
 */

/* Exceptions */
extern NSString *PLCrashReporterException;

/* Error Domain and Codes */
extern NSString *PLCrashReporterErrorDomain;

/**
 * NSError codes in the Plausible Crash Reporter error domain.
 * @ingroup enums
 */
typedef enum {
    /** An unknown error has occured. If this
     * code is received, it is a bug, and should be reported. */
    PLCrashReporterErrorUnknown = 0,
    
    /** An Mach or POSIX operating system error has occured. The underlying NSError cause may be fetched from the userInfo
     * dictionary using the NSUnderlyingErrorKey key. */
    PLCrashReporterErrorOperatingSystem = 1,

    /** The crash report log file is corrupt or invalid */
    PLCrashReporterErrorCrashReportInvalid = 2,
} PLCrashReporterError;


/* Library Imports */
#import "PLCrashReporter.h"
#import "PLCrashReport.h"
#import "PLCrashReportTextFormatter.h"

/**
 * @mainpage Plausible Crash Reporter
 *
 * @section intro_sec Introduction
 *
 * Plausile CrashReporter implements in-process crash reporting on the iPhone and Mac OS X.
 *
 * The following features are supported:
 *
 * - Implemented as an in-process signal handler.
 * - Does not interfer with debugging in gdb..
 * - Handles both uncaught Objective-C exceptions and fatal signals (SIGSEGV, SIGBUS, etc).
 * - Full thread state for all active threads (backtraces, register dumps) is provided.
 *
 * If your application crashes, a crash report will be written. When the application is next run, you may check for a
 * pending crash report, and submit the report to your own HTTP server, send an e-mail, or even introspect the
 * report locally.
 *
 * @section intro_encoding Crash Report Format
 *
 * Crash logs are encoded using <a href="http://code.google.com/p/protobuf/">google protobuf</a>, and may be decoded
 * using the provided PLCrashReport API. Additionally, the include plcrashutil handles conversion of binary crash reports to the 
 * symbolicate-compatible iPhone text format.
 *
 * @section doc_sections Documentation Sections
 * - @subpage example_usage_iphone
 * - @subpage error_handling
 * - @subpage async_safety
 */

/**
 * @page example_usage_iphone Example iPhone Usage
 *
 * @code
 * //
 * // Called to handle a pending crash report.
 * //
 * - (void) handleCrashReport {
 *     PLCrashReporter *crashReporter = [PLCrashReporter sharedReporter];
 *     NSData *crashData;
 *     NSError *error;
 *     
 *     // Try loading the crash report
 *     crashData = [crashReporter loadPendingCrashReportDataAndReturnError: &error];
 *     if (crashData == nil) {
 *         NSLog(@"Could not load crash report: %@", error);
 *         goto finish;
 *     }
 *     
 *     // We could send the report from here, but we'll just print out
 *     // some debugging info instead
 *     PLCrashReport *report = [[[PLCrashReport alloc] initWithData: crashData error: &error] autorelease];
 *     if (report == nil) {
 *         NSLog(@"Could not parse crash report");
 *         goto finish;
 *     }
 *     
 *     NSLog(@"Crashed on %@", report.systemInfo.timestamp);
 *     NSLog(@"Crashed with signal %@ (code %@, address=0x%" PRIx64 ")", report.signalInfo.name,
 *           report.signalInfo.code, report.signalInfo.address);
 *     
 *     // Purge the report
 * finish:
 *     [crashReporter purgePendingCrashReport];
 *     return;
 * }
 * 
 * // from UIApplicationDelegate protocol
 * - (void) applicationDidFinishLaunching: (UIApplication *) application {
 *     PLCrashReporter *crashReporter = [PLCrashReporter sharedReporter];
 *     NSError *error;
 *     
 *     // Check if we previously crashed
 *     if ([crashReporter hasPendingCrashReport])
 *         [self handleCrashReport];
    
 *     // Enable the Crash Reporter
 *     if (![crashReporter enableCrashReporterAndReturnError: &error])
 *         NSLog(@"Warning: Could not enable crash reporter: %@", error);
 *         
 * }
 * @endcode
 * 
 */

/**
 * @page error_handling Error Handling Programming Guide
 *
 * Where a method may return an error, Plausible Crash Reporter provides access to the underlying
 * cause via an optional NSError argument.
 *
 * All returned errors will be a member of one of the below defined domains, however, new domains and
 * error codes may be added at any time. If you do not wish to report on the error cause, many methods
 * support a simple form that requires no NSError argument.
 *
 * @section error_domains Error Domains, Codes, and User Info
 *
 * @subsection crashreporter_errors Crash Reporter Errors
 *
 * Any errors in Plausible Crash Reporter use the #PLCrashReporterErrorDomain error domain, and and one
 * of the error codes defined in #PLCrashReporterError.
 */

/**
 * @page async_safety Async-Safe Programming Guide
 *
 * Plausible CrashReporter provides support for executing an application specified function in the context of the
 * crash reporter's signal handler, after the crash report has been written to disk. This was a regularly requested
 * feature, and provides the ability to implement application finalization in the event of a crash. However, writing
 * code intended for execution inside of a signal handler is exceptionally difficult, and is not recommended.
 *
 * @section program_flow Program Flow and Signal Handlers
 *
 * When the signal handler is called the normal flow of the program is interrupted, and your program is an unknown
 * state. Locks may be held, the heap may be corrupt (or in the process of being updated), and your signal
 * handler may invoke a function that was being executed at the time of the signal. This may result in deadlocks,
 * data corruption, and program termination.
 *
 * @section functions Async-Safe Functions
 *
 * A subset of functions are defined to be async-safe by the OS, and are safely callable from within a signal handler. If
 * you do implement a custom post-crash handler, it must be async-safe. A table of POSIX-defined async-safe functions
 * and additional information is available from the
 * <a href="https://www.securecoding.cert.org/confluence/display/seccode/SIG30-C.+Call+only+asynchronous-safe+functions+within+signal+handlers">CERT programming guide - SIG30-C</a>
 *
 * Most notably, the Objective-C runtime itself is not async-safe, and Objective-C may not be used within a signal
 * handler.
 *
 * @sa PLCrashReporter::setCrashCallbacks:
 */