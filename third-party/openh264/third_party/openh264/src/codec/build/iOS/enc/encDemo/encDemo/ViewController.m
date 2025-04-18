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

extern int EncMain(int argc, char **argv);

#import "ViewController.h"


@interface ViewController ()

@end

@implementation ViewController
@synthesize statusText=statusText_;

- (void)viewDidLoad
{
    [super viewDidLoad];
    statusText_.text = @"Status: Ready for Go";
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (IBAction) buttonPressed:(id)sender
{
    NSBundle * bundle = [NSBundle mainBundle];
    NSString * encCfg = [bundle pathForResource:@"welsenc_ios" ofType:@"cfg"];
    NSString * dlayerCfg = [bundle pathForResource:@"layer2" ofType:@"cfg"];
    NSString * yuvFile = [bundle pathForResource:@"CiscoVT2people_320x192_12fps" ofType:@"yuv"];
    NSString * bsfile = [NSString stringWithFormat:@"%@/%@", [self getPathForWrite], @"test.264"];
    NSLog(@"WELS_INFO: enc config file: %@, yuv file %@", encCfg, yuvFile);
    const char * argv[] = {
        "dummy",
        [encCfg UTF8String],
        "-org",
        [yuvFile UTF8String],
        "-bf",
        [bsfile UTF8String],
        "-numl",
        "1",
        "-lconfig",
        "0",
        [dlayerCfg UTF8String],
    };
    NSLog(@"WELS_INFO: enc config file: %@", encCfg);
    EncMain(sizeof(argv)/sizeof(argv[0]), (char**)&argv[0]);
    statusText_.text = @"Status: Test Over";
}

- (NSString*) getPathForWrite {
    NSArray * pathes =  NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString * documentDirectory = [pathes objectAtIndex:0];
    return documentDirectory;
}


@end
