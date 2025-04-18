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

#import "AppDelegate.h"

extern int EncMain (int argc, char** argv);

//redirect NSLog and stdout to logfile
void redirectLogToDocumentFile() {
  NSArray* path = NSSearchPathForDirectoriesInDomains (NSDocumentDirectory, NSUserDomainMask, YES);
  NSString* document = [path objectAtIndex:0];
  NSString* fileName = [NSString stringWithFormat:@"encPerf.log"];
  NSString* logPath = [document stringByAppendingPathComponent:fileName];

  NSFileManager* defaultManager = [NSFileManager defaultManager];
  [defaultManager removeItemAtPath:logPath error:nil];

  freopen ([logPath cStringUsingEncoding:NSASCIIStringEncoding], "a+", stdout);
  freopen ([logPath cStringUsingEncoding:NSASCIIStringEncoding], "a+", stderr);
}

//to judge whether the path is needed case path
bool IsOneDeptDir (NSString* path) {
  BOOL isDir = NO;
  BOOL isOneDeptDir = NO;
  NSFileManager* fileManager = [NSFileManager defaultManager];
  NSArray* dirPathArray = [fileManager subpathsAtPath:path];
  if ([dirPathArray count] == 0 || dirPathArray == nil)
    isOneDeptDir = NO;
  else {
    for (NSString * dirPath in dirPathArray) {
      NSString* tmpPath = [path stringByAppendingString:@"/"];
      tmpPath = [tmpPath stringByAppendingString:dirPath];
      [fileManager fileExistsAtPath:tmpPath isDirectory:&isDir];
      if (isDir) {
        isOneDeptDir = YES;
        break;
      }
    }
  }
  return isOneDeptDir;
}

//run auto test to get encoder performance
int AutoTestEnc() {
  NSString* document = [[NSString alloc] init];
  NSArray* paths = NSSearchPathForDirectoriesInDomains (NSDocumentDirectory, NSUserDomainMask, YES);
  if ([paths count] == 0) {
    NSLog (@"could not find document path");
    return 2;
  }
  document = [paths objectAtIndex:0];

  NSString* encFilePath = [document stringByAppendingString:@"/EncoderPerfTestRes"];
  NSFileManager* manage = [NSFileManager defaultManager];

  NSArray* cases = [manage subpathsAtPath:encFilePath];
  if (cases == nil) {
    NSLog (@"could not find any test case under encoderperftest");
    return 1;

  }
  redirectLogToDocumentFile();
  NSMutableArray* dirArray = [[NSMutableArray alloc] init];
  for (NSString * casePath in cases) {

    NSString* path = [encFilePath stringByAppendingPathComponent:casePath];
    if (IsOneDeptDir (path)) {
      [dirArray addObject:casePath];
    }

  }
  for (int caseNO = 0; caseNO < [dirArray count]; caseNO++) {

    NSString* caseName = [dirArray objectAtIndex:caseNO];
    NSString* caseFilePath = [encFilePath stringByAppendingString:@"/"];
    caseFilePath = [caseFilePath stringByAppendingString:caseName];
    [manage changeCurrentDirectoryPath:[caseFilePath stringByExpandingTildeInPath]];

    NSString* welscfg = [caseFilePath stringByAppendingString:@"/welsenc.cfg"];
    NSString* layercfg = [caseFilePath stringByAppendingString:@"/layer2.cfg"];
    NSString* yuvFilePath = [caseFilePath stringByAppendingString:@"/yuv"];
    NSString* bitFilePath = [caseFilePath stringByAppendingString:@"/bit"];
    [manage removeItemAtPath:bitFilePath error:nil];
    [manage createDirectoryAtPath:bitFilePath withIntermediateDirectories:YES attributes:nil error:nil];


    NSArray* files = [manage subpathsAtPath:yuvFilePath];

    [manage changeCurrentDirectoryPath:[bitFilePath stringByExpandingTildeInPath]];

    for (int i = 0; i < [files count]; i++) {
      NSString* yuvFileName = [files objectAtIndex:i];
      NSString* bitFileName = [yuvFileName stringByAppendingString:@".264"];

      NSString*  bitFileNamePath = [bitFilePath stringByAppendingString:@"/"];
      bitFileName = [bitFileNamePath stringByAppendingString:bitFileName];


      [manage createFileAtPath:bitFileName contents:nil attributes:nil];
      [manage changeCurrentDirectoryPath:[yuvFilePath stringByExpandingTildeInPath]];
      const char* argvv[] = {
        "dummy",
        [welscfg UTF8String],
        "-org",
        [yuvFileName UTF8String],
        "-bf",
        [bitFileName UTF8String],
        "-numl",
        "1",
          "-lconfig",
          "0",
        [layercfg UTF8String]
      };

      NSLog (@"WELS_INFO: enc config file: %@", welscfg);
      NSLog (@"WELS_INFO: enc yuv file: %@", yuvFileName);
      EncMain (sizeof (argvv) / sizeof (argvv[0]), (char**)&argvv[0]);
      fflush (stdout); // flush the content of stdout instantly
    }

  }


  return 0;
}


int main (int argc, char* argv[]) {


  //***For auto testing of encoder performance, call auto test here, if you not want to do auto test, you can comment it manualy

  if (AutoTestEnc() == 0)
    NSLog (@"Auto testing running sucessfully");
  else
    NSLog (@"Auto testing running failed");
  abort();
  //************************
  @autoreleasepool {
    return UIApplicationMain (argc, argv, nil, NSStringFromClass ([AppDelegate class]));
  }
}
