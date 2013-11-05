/*
 * Authors:
 *  Landon Fuller <landonf@plausiblelabs.com>
 *  Damian Morris <damian@moso.com.au>
 *  Andreas Linde <mail@andreaslinde.de>
 *
 * Copyright (c) 2008-2013 Plausible Labs Cooperative, Inc.
 * Copyright (c) 2010 MOSO Corporation, Pty Ltd.
 * Copyright (c) 2012-2013 HockeyApp, Bit Stadium GmbH.
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

#import <CrashReporter/CrashReporter.h>

#import "BITCrashReportTextFormatter.h"

/*
 * XXX: The ARM64 CPU type, and ARM_V7S and ARM_V8 Mach-O CPU subtypes are not
 * defined in the Mac OS X 10.8 headers.
 */
#ifndef CPU_SUBTYPE_ARM_V7S
# define CPU_SUBTYPE_ARM_V7S 11
#endif

#ifndef CPU_TYPE_ARM64
#define CPU_TYPE_ARM64 (CPU_TYPE_ARM | CPU_ARCH_ABI64)
#endif

#ifndef CPU_SUBTYPE_ARM_V8
# define CPU_SUBTYPE_ARM_V8 13
#endif


/**
 * Sort PLCrashReportBinaryImageInfo instances by their starting address.
 */
static NSInteger bit_binaryImageSort(id binary1, id binary2, void *context) {
  uint64_t addr1 = [binary1 imageBaseAddress];
  uint64_t addr2 = [binary2 imageBaseAddress];
  
  if (addr1 < addr2)
    return NSOrderedAscending;
  else if (addr1 > addr2)
    return NSOrderedDescending;
  else
    return NSOrderedSame;
}


/**
 * Formats PLCrashReport data as human-readable text.
 */
@implementation BITCrashReportTextFormatter


/**
 * Formats the provided @a report as human-readable text in the given @a textFormat, and return
 * the formatted result as a string.
 *
 * @param report The report to format.
 * @param textFormat The text format to use.
 *
 * @return Returns the formatted result on success, or nil if an error occurs.
 */
+ (NSString *)stringValueForCrashReport:(BITPLCrashReport *)report crashReporterKey:(NSString *)crashReporterKey {
	NSMutableString* text = [NSMutableString string];
	boolean_t lp64 = true; // quiesce GCC uninitialized value warning
  
	/* Header */
	
  /* Map to apple style OS nane */
  NSString *osName;
  switch (report.systemInfo.operatingSystem) {
    case PLCrashReportOperatingSystemMacOSX:
      osName = @"Mac OS X";
      break;
    case PLCrashReportOperatingSystemiPhoneOS:
      osName = @"iPhone OS";
      break;
    case PLCrashReportOperatingSystemiPhoneSimulator:
      osName = @"Mac OS X";
      break;
    default:
      osName = [NSString stringWithFormat: @"Unknown (%d)", report.systemInfo.operatingSystem];
      break;
  }
  
  /* Map to Apple-style code type, and mark whether architecture is LP64 (64-bit) */
  NSString *codeType = nil;
  {
    /* Attempt to derive the code type from the binary images */
    for (BITPLCrashReportBinaryImageInfo *image in report.images) {
      /* Skip images with no specified type */
      if (image.codeType == nil)
        continue;
      
      /* Skip unknown encodings */
      if (image.codeType.typeEncoding != PLCrashReportProcessorTypeEncodingMach)
        continue;
      
      switch (image.codeType.type) {
        case CPU_TYPE_ARM:
          codeType = @"ARM";
          lp64 = false;
          break;
          
        case CPU_TYPE_ARM64:
          codeType = @"ARM-64";
          lp64 = true;
          break;
          
        case CPU_TYPE_X86:
          codeType = @"X86";
          lp64 = false;
          break;
          
        case CPU_TYPE_X86_64:
          codeType = @"X86-64";
          lp64 = true;
          break;
          
        case CPU_TYPE_POWERPC:
          codeType = @"PPC";
          lp64 = false;
          break;
          
        default:
          // Do nothing, handled below.
          break;
      }
      
      /* Stop immediately if code type was discovered */
      if (codeType != nil)
        break;
    }
    
    /* If we were unable to determine the code type, fall back on the legacy architecture value. */
    if (codeType == nil) {
      switch (report.systemInfo.architecture) {
        case PLCrashReportArchitectureARMv6:
        case PLCrashReportArchitectureARMv7:
          codeType = @"ARM";
          lp64 = false;
          break;
        case PLCrashReportArchitectureX86_32:
          codeType = @"X86";
          lp64 = false;
          break;
        case PLCrashReportArchitectureX86_64:
          codeType = @"X86-64";
          lp64 = true;
          break;
        case PLCrashReportArchitecturePPC:
          codeType = @"PPC";
          lp64 = false;
          break;
        default:
          codeType = [NSString stringWithFormat: @"Unknown (%d)", report.systemInfo.architecture];
          lp64 = true;
          break;
      }
    }
  }
  
  {
    NSString *reporterKey = @"???";
    if (crashReporterKey && [crashReporterKey length] > 0)
      reporterKey = crashReporterKey;
    
    NSString *hardwareModel = @"???";
    if (report.hasMachineInfo && report.machineInfo.modelName != nil)
      hardwareModel = report.machineInfo.modelName;
    
    NSString *incidentIdentifier = @"???";
    if (report.uuidRef != NULL) {
      incidentIdentifier = (NSString *) CFBridgingRelease(CFUUIDCreateString(NULL, report.uuidRef));
    }
    
    [text appendFormat: @"Incident Identifier: %@\n", incidentIdentifier];
    [text appendFormat: @"CrashReporter Key:   %@\n", reporterKey];
    [text appendFormat: @"Hardware Model:      %@\n", hardwareModel];
  }
  
  /* Application and process info */
  {
    NSString *unknownString = @"???";
    
    NSString *processName = unknownString;
    NSString *processId = unknownString;
    NSString *processPath = unknownString;
    NSString *parentProcessName = unknownString;
    NSString *parentProcessId = unknownString;
    
    /* Process information was not available in earlier crash report versions */
    if (report.hasProcessInfo) {
      /* Process Name */
      if (report.processInfo.processName != nil)
        processName = report.processInfo.processName;
      
      /* PID */
      processId = [[NSNumber numberWithUnsignedInteger: report.processInfo.processID] stringValue];
      
      /* Process Path */
      if (report.processInfo.processPath != nil) {
        processPath = report.processInfo.processPath;
        
        /* Remove username from the path */
        if ([processPath length] > 0)
          processPath = [processPath stringByAbbreviatingWithTildeInPath];
        if ([processPath length] > 0 && [[processPath substringToIndex:1] isEqualToString:@"~"])
          processPath = [NSString stringWithFormat:@"/Users/USER%@", [processPath substringFromIndex:1]];
      }
      
      /* Parent Process Name */
      if (report.processInfo.parentProcessName != nil)
        parentProcessName = report.processInfo.parentProcessName;
      
      /* Parent Process ID */
      parentProcessId = [@(report.processInfo.parentProcessID) stringValue];
    }
    
    [text appendFormat: @"Process:         %@ [%@]\n", processName, processId];
    [text appendFormat: @"Path:            %@\n", processPath];
    [text appendFormat: @"Identifier:      %@\n", report.applicationInfo.applicationIdentifier];
    [text appendFormat: @"Version:         %@\n", report.applicationInfo.applicationVersion];
    [text appendFormat: @"Code Type:       %@\n", codeType];
    [text appendFormat: @"Parent Process:  %@ [%@]\n", parentProcessName, parentProcessId];
  }
  
  [text appendString: @"\n"];
  
  /* System info */
  {
    NSString *osBuild = @"???";
    if (report.systemInfo.operatingSystemBuild != nil)
      osBuild = report.systemInfo.operatingSystemBuild;
    
    [text appendFormat: @"Date/Time:       %@\n", report.systemInfo.timestamp];
    [text appendFormat: @"OS Version:      %@ %@ (%@)\n", osName, report.systemInfo.operatingSystemVersion, osBuild];
    [text appendFormat: @"Report Version:  104\n"];
  }
  
  [text appendString: @"\n"];
  
  /* Exception code */
  [text appendFormat: @"Exception Type:  %@\n", report.signalInfo.name];
  [text appendFormat: @"Exception Codes: %@ at 0x%" PRIx64 "\n", report.signalInfo.code, report.signalInfo.address];
  
  for (BITPLCrashReportThreadInfo *thread in report.threads) {
    if (thread.crashed) {
      [text appendFormat: @"Crashed Thread:  %ld\n", (long) thread.threadNumber];
      break;
    }
  }
  
  [text appendString: @"\n"];
  
  /* Uncaught Exception */
  if (report.hasExceptionInfo) {
    [text appendFormat: @"Application Specific Information:\n"];
    [text appendFormat: @"*** Terminating app due to uncaught exception '%@', reason: '%@'\n",
     report.exceptionInfo.exceptionName, report.exceptionInfo.exceptionReason];
    
    [text appendString: @"\n"];
  }
  
  /* If an exception stack trace is available, output an Apple-compatible backtrace. */
  if (report.exceptionInfo != nil && report.exceptionInfo.stackFrames != nil && [report.exceptionInfo.stackFrames count] > 0) {
    BITPLCrashReportExceptionInfo *exception = report.exceptionInfo;
    
    /* Create the header. */
    [text appendString: @"Last Exception Backtrace:\n"];
    
    /* Write out the frames. In raw reports, Apple writes this out as a simple list of PCs. In the minimally
     * post-processed report, Apple writes this out as full frame entries. We use the latter format. */
    for (NSUInteger frame_idx = 0; frame_idx < [exception.stackFrames count]; frame_idx++) {
      BITPLCrashReportStackFrameInfo *frameInfo = [exception.stackFrames objectAtIndex: frame_idx];
      [text appendString: [[self class] bit_formatStackFrame: frameInfo frameIndex: frame_idx report: report lp64: lp64]];
    }
    [text appendString: @"\n"];
  }
  
  /* Threads */
  BITPLCrashReportThreadInfo *crashed_thread = nil;
  NSInteger maxThreadNum = 0;
  for (BITPLCrashReportThreadInfo *thread in report.threads) {
    if (thread.crashed) {
      [text appendFormat: @"Thread %ld Crashed:\n", (long) thread.threadNumber];
      crashed_thread = thread;
    } else {
      [text appendFormat: @"Thread %ld:\n", (long) thread.threadNumber];
    }
    for (NSUInteger frame_idx = 0; frame_idx < [thread.stackFrames count]; frame_idx++) {
      BITPLCrashReportStackFrameInfo *frameInfo = [thread.stackFrames objectAtIndex: frame_idx];
      [text appendString: [[self class] bit_formatStackFrame: frameInfo frameIndex: frame_idx report: report lp64: lp64]];
    }
    [text appendString: @"\n"];
    
    /* Track the highest thread number */
    maxThreadNum = MAX(maxThreadNum, thread.threadNumber);
  }
  
  /* Registers */
  if (crashed_thread != nil) {
    [text appendFormat: @"Thread %ld crashed with %@ Thread State:\n", (long) crashed_thread.threadNumber, codeType];
    
    int regColumn = 0;
    for (BITPLCrashReportRegisterInfo *reg in crashed_thread.registers) {
      NSString *reg_fmt;
      
      /* Use 32-bit or 64-bit fixed width format for the register values */
      if (lp64)
        reg_fmt = @"%6s: 0x%016" PRIx64 " ";
      else
        reg_fmt = @"%6s: 0x%08" PRIx64 " ";
      
      /* Remap register names to match Apple's crash reports */
      NSString *regName = reg.registerName;
      if (report.machineInfo != nil && report.machineInfo.processorInfo.typeEncoding == PLCrashReportProcessorTypeEncodingMach) {
        BITPLCrashReportProcessorInfo *pinfo = report.machineInfo.processorInfo;
        cpu_type_t arch_type = pinfo.type & ~CPU_ARCH_MASK;
        
        /* Apple uses 'ip' rather than 'r12' on ARM */
        if (arch_type == CPU_TYPE_ARM && [regName isEqual: @"r12"]) {
          regName = @"ip";
        }
      }
      [text appendFormat: reg_fmt, [regName UTF8String], reg.registerValue];
      
      regColumn++;
      if (regColumn == 4) {
        [text appendString: @"\n"];
        regColumn = 0;
      }
    }
    
    if (regColumn != 0)
      [text appendString: @"\n"];
    
    [text appendString: @"\n"];
  }
  
  /* Images. The iPhone crash report format sorts these in ascending order, by the base address */
  [text appendString: @"Binary Images:\n"];
  for (BITPLCrashReportBinaryImageInfo *imageInfo in [report.images sortedArrayUsingFunction: bit_binaryImageSort context: nil]) {
    NSString *uuid;
    /* Fetch the UUID if it exists */
    if (imageInfo.hasImageUUID)
      uuid = imageInfo.imageUUID;
    else
      uuid = @"???";
    
    /* Determine the architecture string */
    NSString *archName = [[self class] bit_archNameFromImageInfo:imageInfo];
    
    /* Determine if this is the main executable or an app specific framework*/
    NSString *binaryDesignator = @" ";
    NSString *imagePath = [imageInfo.imageName stringByStandardizingPath];
    NSString *appBundleContentsPath = [[report.processInfo.processPath stringByDeletingLastPathComponent] stringByDeletingLastPathComponent];
    
    if ([imagePath isEqual: report.processInfo.processPath] || [imagePath hasPrefix:appBundleContentsPath])
      binaryDesignator = @"+";
    
    /* base_address - terminating_address [designator]file_name arch <uuid> file_path */
    NSString *fmt = nil;
    if (lp64) {
      fmt = @"%18#" PRIx64 " - %18#" PRIx64 " %@%@ %@  <%@> %@\n";
    } else {
      fmt = @"%10#" PRIx64 " - %10#" PRIx64 " %@%@ %@  <%@> %@\n";
    }
    
    /* Remove username from the image path */
    NSString *imageName = @"";
    if (imageInfo.imageName && [imageInfo.imageName length] > 0)
      imageName = [imageInfo.imageName stringByAbbreviatingWithTildeInPath];
    if ([imageName length] > 0 && [[imageName substringToIndex:1] isEqualToString:@"~"])
      imageName = [NSString stringWithFormat:@"/Users/USER%@", [imageName substringFromIndex:1]];
    
    [text appendFormat: fmt,
     imageInfo.imageBaseAddress,
     imageInfo.imageBaseAddress + (MAX(1, imageInfo.imageSize) - 1), // The Apple format uses an inclusive range
     binaryDesignator,
     [imageInfo.imageName lastPathComponent],
     archName,
     uuid,
     imageName];
  }
  
  
  return text;
}

/**
 * Returns an array of app UUIDs and their architecture
 * As a dictionary for each element
 *
 * @param report The report to format.
 *
 * @return Returns the formatted result on success, or nil if an error occurs.
 */
+ (NSArray *)arrayOfAppUUIDsForCrashReport:(BITPLCrashReport *)report {
	NSMutableArray* appUUIDs = [NSMutableArray array];
  
  /* Images. The iPhone crash report format sorts these in ascending order, by the base address */
  for (BITPLCrashReportBinaryImageInfo *imageInfo in [report.images sortedArrayUsingFunction: bit_binaryImageSort context: nil]) {
    NSString *uuid;
    /* Fetch the UUID if it exists */
    if (imageInfo.hasImageUUID)
      uuid = imageInfo.imageUUID;
    else
      uuid = @"???";
    
    /* Determine the architecture string */
    NSString *archName = [[self class] bit_archNameFromImageInfo:imageInfo];
    
    /* Determine if this is the app executable or app specific framework */
    NSString *imagePath = [imageInfo.imageName stringByStandardizingPath];
    NSString *appBundleContentsPath = [[report.processInfo.processPath stringByDeletingLastPathComponent] stringByDeletingLastPathComponent];
    NSString *imageType = @"";
    
    if ([imageInfo.imageName isEqual: report.processInfo.processPath]) {
      imageType = @"app";
    } else {
      imageType = @"framework";
    }
    
    if ([imagePath isEqual: report.processInfo.processPath] || [imagePath hasPrefix:appBundleContentsPath]) {
      [appUUIDs addObject:@{kBITBinaryImageKeyUUID: uuid, kBITBinaryImageKeyArch: archName, kBITBinaryImageKeyType: imageType}];
    }
  }
  
  
  return appUUIDs;
}

+ (NSString *)bit_archNameFromImageInfo:(BITPLCrashReportBinaryImageInfo *)imageInfo
{
  NSString *archName = @"???";
  if (imageInfo.codeType != nil && imageInfo.codeType.typeEncoding == PLCrashReportProcessorTypeEncodingMach) {
    switch (imageInfo.codeType.type) {
      case CPU_TYPE_ARM:
        /* Apple includes subtype for ARM binaries. */
        switch (imageInfo.codeType.subtype) {
          case CPU_SUBTYPE_ARM_V6:
            archName = @"armv6";
            break;
            
          case CPU_SUBTYPE_ARM_V7:
            archName = @"armv7";
            break;
            
          case CPU_SUBTYPE_ARM_V7S:
            archName = @"armv7s";
            break;
            
          default:
            archName = @"arm-unknown";
            break;
        }
        break;
        
      case CPU_TYPE_ARM64:
        /* Apple includes subtype for ARM64 binaries. */
        switch (imageInfo.codeType.subtype) {
          case CPU_SUBTYPE_ARM_ALL:
            archName = @"arm64";
            break;
            
          case CPU_SUBTYPE_ARM_V8:
            archName = @"arm64";
            break;
            
          default:
            archName = @"arm64-unknown";
            break;
        }
        break;
        
      case CPU_TYPE_X86:
        archName = @"i386";
        break;
        
      case CPU_TYPE_X86_64:
        archName = @"x86_64";
        break;
        
      case CPU_TYPE_POWERPC:
        archName = @"powerpc";
        break;
        
      default:
        // Use the default archName value (initialized above).
        break;
    }
  }
  
  return archName;
}


/**
 * Format a stack frame for display in a thread backtrace.
 *
 * @param frameInfo The stack frame to format
 * @param frameIndex The frame's index
 * @param report The report from which this frame was acquired.
 * @param lp64 If YES, the report was generated by an LP64 system.
 *
 * @return Returns a formatted frame line.
 */
+ (NSString *)bit_formatStackFrame: (BITPLCrashReportStackFrameInfo *) frameInfo
                        frameIndex: (NSUInteger) frameIndex
                            report: (BITPLCrashReport *) report
                              lp64: (BOOL) lp64
{
  /* Base image address containing instrumention pointer, offset of the IP from that base
   * address, and the associated image name */
  uint64_t baseAddress = 0x0;
  uint64_t pcOffset = 0x0;
  NSString *imageName = @"\?\?\?";
  NSString *symbolString = nil;
  
  BITPLCrashReportBinaryImageInfo *imageInfo = [report imageForAddress: frameInfo.instructionPointer];
  if (imageInfo != nil) {
    imageName = [imageInfo.imageName lastPathComponent];
    baseAddress = imageInfo.imageBaseAddress;
    pcOffset = frameInfo.instructionPointer - imageInfo.imageBaseAddress;
  }
  
  /* Make sure UTF8/16 characters are handled correctly */
  NSInteger offset = 0;
  NSInteger index = 0;
  for (index = 0; index < [imageName length]; index++) {
    NSRange range = [imageName rangeOfComposedCharacterSequenceAtIndex:index];
    if (range.length > 1) {
      offset += range.length - 1;
      index += range.length - 1;
    }
    if (index > 32) {
      imageName = [NSString stringWithFormat:@"%@... ", [imageName substringToIndex:index - 1]];
      index += 3;
      break;
    }
  }
  if (index-offset < 36) {
    imageName = [imageName stringByPaddingToLength:36+offset withString:@" " startingAtIndex:0];
  }
  
  /* If symbol info is available, the format used in Apple's reports is Sym + OffsetFromSym. Otherwise,
   * the format used is imageBaseAddress + offsetToIP */
  NSString *imagePath = [imageInfo.imageName stringByStandardizingPath];
  NSString *appBundleContentsPath = [[report.processInfo.processPath stringByDeletingLastPathComponent] stringByDeletingLastPathComponent];
  
  if (frameInfo.symbolInfo != nil &&
      ![imagePath isEqual: report.processInfo.processPath] &&
      ![imagePath hasPrefix:appBundleContentsPath]) {
    NSString *symbolName = frameInfo.symbolInfo.symbolName;
    
    /* Apple strips the _ symbol prefix in their reports. Only OS X makes use of an
     * underscore symbol prefix by default. */
    if ([symbolName rangeOfString: @"_"].location == 0 && [symbolName length] > 1) {
      switch (report.systemInfo.operatingSystem) {
        case PLCrashReportOperatingSystemMacOSX:
        case PLCrashReportOperatingSystemiPhoneOS:
        case PLCrashReportOperatingSystemiPhoneSimulator:
          symbolName = [symbolName substringFromIndex: 1];
          break;
          
        default:
          NSLog(@"Symbol prefix rules are unknown for this OS!");
          break;
      }
    }
    
    
    uint64_t symOffset = frameInfo.instructionPointer - frameInfo.symbolInfo.startAddress;
    symbolString = [NSString stringWithFormat: @"%@ + %" PRId64, symbolName, symOffset];
  } else {
    symbolString = [NSString stringWithFormat: @"0x%" PRIx64 " + %" PRId64, baseAddress, pcOffset];
  }
  
  /* Note that width specifiers are ignored for %@, but work for C strings.
   * UTF-8 is not correctly handled with %s (it depends on the system encoding), but
   * UTF-16 is supported via %S, so we use it here */
  return [NSString stringWithFormat: @"%-4ld%-35S 0x%0*" PRIx64 " %@\n",
          (long) frameIndex,
          (const uint16_t *)[imageName cStringUsingEncoding: NSUTF16StringEncoding],
          lp64 ? 16 : 8, frameInfo.instructionPointer,
          symbolString];
}

@end
