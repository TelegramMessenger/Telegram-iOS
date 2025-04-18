/*!
 * \copy
 *     Copyright (c)  2013, Cisco Systems
 *     All rights reserved.
 *
 *     Redistribution and use in source and binary forms, with or without
 *     modification, are permitted provided that the following conditions
 *     are met:
 *
 *        * Redistributions of source code must retain the above copyright
 *          notice, this list of conditions and the following disclaimer.
 *
 *        * Redistributions in binary form must reproduce the above copyright
 *          notice, this list of conditions and the following disclaimer in
 *          the documentation and/or other materials provided with the
 *          distribution.
 *
 *     THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 *     "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 *     LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 *     FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
 *     COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
 *     INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 *     BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 *     LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 *     CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 *     LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
 *     ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 *     POSSIBILITY OF SUCH DAMAGE.
 *
 */

#import <UIKit/UIKit.h>

#import "DEMOAppDelegate.h"

extern int DecMain (int argc, char* argv[]);

//redirect NSLog and stdout to logfile
void redirectLogToDocumentFile() {
  NSArray* path = NSSearchPathForDirectoriesInDomains (NSDocumentDirectory, NSUserDomainMask, YES);
  NSString* document = [path objectAtIndex:0];
  NSString* fileName = [NSString stringWithFormat:@"decPerf.log"];
  NSString* logPath = [document stringByAppendingPathComponent:fileName];

  NSFileManager* defaultManager = [NSFileManager defaultManager];
  [defaultManager removeItemAtPath:logPath error:nil];

  freopen ([logPath cStringUsingEncoding:NSASCIIStringEncoding], "a+", stdout);
  freopen ([logPath cStringUsingEncoding:NSASCIIStringEncoding], "a+", stderr);
}


//run auto test to get encoder performance
int AutoTestDec() {


  NSString* document = [[NSString alloc] init];
  NSArray* paths = NSSearchPathForDirectoriesInDomains (NSDocumentDirectory, NSUserDomainMask, YES);
  if ([paths count] == 0) {
    NSLog (@"could not find document path");
    return 2;
  }
  document = [paths objectAtIndex:0];


  NSString* decFilePath = [document stringByAppendingString:@"/DecoderPerfTestRes"];
  NSFileManager* manage = [NSFileManager defaultManager];

  NSString* outYuvPath = [decFilePath stringByAppendingString:@"/yuv"];
  [manage removeItemAtPath:outYuvPath error:nil];
  [manage createDirectoryAtPath:outYuvPath withIntermediateDirectories:YES attributes:nil error: nil];


  NSArray* bitstreams = [manage subpathsAtPath:decFilePath];
  if (bitstreams == nil) {
    NSLog (@"could not find any bitstream under decoderperfpath");
    return 1;
  }

  redirectLogToDocumentFile(); //output to console, just comment this line

  for (int caseNO = 0; caseNO < [bitstreams count]; caseNO++) {

    NSString* caseName = [bitstreams objectAtIndex:caseNO];
    if ([caseName  isEqual: @"yuv"]) {
      break;
    }
    NSString* bitstream = [decFilePath stringByAppendingString:@"/"];
    bitstream = [bitstream stringByAppendingString:caseName];
    NSString* yuvFileName = [caseName stringByAppendingString:@".yuv"];
    NSString* tmpyuvFileName = [outYuvPath stringByAppendingString:@"/"];
    yuvFileName = [tmpyuvFileName stringByAppendingString:yuvFileName];

    [manage createFileAtPath:yuvFileName contents:nil attributes:nil];

    const char* argvv[] = {
      "decConsole.exe",
      [bitstream UTF8String],
      [yuvFileName UTF8String]
    };
    DecMain (sizeof (argvv) / sizeof (argvv[0]), (char**)&argvv[0]);
    [manage removeItemAtPath:yuvFileName error:nil];//FOR limited devices spaces
    fflush (stdout); // flush the content of stdout instantly
  }


  return 0;
}

int main (int argc, char* argv[]) {
  //***For auto testing of decoder performance, call auto test here, if you not want to do auto test, you can comment it manualy

  if (AutoTestDec() == 0)
    NSLog (@"Auto testing running sucessfully");
  else
    NSLog (@"Auto testing running failed");
  abort();
  //********

  @autoreleasepool {
    return UIApplicationMain (argc, argv, nil, NSStringFromClass ([DEMOAppDelegate class]));
  }
}
