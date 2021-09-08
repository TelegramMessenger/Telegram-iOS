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

#define ENDLESS_LOOP   //define to do the performance testing
#define NO_OUTPUT_MODE //define to disable the output yuv file

extern int DecMain(int argc, char * argv[]);

#import "DEMOViewController.h"
#import "DEMOViewControllerShowResource.h"

@interface DEMOViewController ()

@end

@implementation DEMOViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    //Add the testing codes
    self.resFileArray = [[NSMutableArray alloc] init];
    self.selectedRow = 0;
    [self updateResourceArray];
    //Init the status indication window
    _statusIndication = [[UIAlertView alloc] initWithTitle: @"Decoding" message: @"Waiting the decoding" delegate: self cancelButtonTitle: @"Cancel" otherButtonTitles: nil];
    if  ([self.resFileArray count] > self.selectedRow)
        self.currentSelectedFileTF.text = [[self.resFileArray objectAtIndex:self.selectedRow] lastPathComponent];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)startDecoderAll:(id)sender {
    bEnableFlag = YES;
    [_statusIndication show];
    [NSThread detachNewThreadSelector:@selector(processDecoderAll) toTarget:self withObject:nil];
}

- (IBAction)startDecoderOne:(id)sender {
    bEnableFlag = YES;
    [_statusIndication show];
    [NSThread detachNewThreadSelector:@selector(processDecoderOne) toTarget:self withObject:nil];
}
- (void)processDecoderAll
{
    [self updateResourceArray];
    if (YES == [self DoDecoderAll]) {
            [self performSelectorOnMainThread:@selector(showAlertWnd) withObject:nil waitUntilDone:NO];
    }
}
- (void)processDecoderOne
{
    if (YES == [self DoDecoderOne:self.selectedRow]) {
        [self performSelectorOnMainThread:@selector(showAlertWnd) withObject:nil waitUntilDone:NO];
    }
}

- (void)showAlertWnd
{
    [_statusIndication dismissWithClickedButtonIndex:0 animated:(BOOL)YES];
    [self showAlertWindowTitle:@"Successful" message: @"Decode is successful!"];
}

-(void)showAlertWindowTitle:(NSString*)title message:(NSString*)message
{
    UIAlertView *someError = [[UIAlertView alloc] initWithTitle: title message: message delegate: self cancelButtonTitle: @"Ok" otherButtonTitles: nil];
    [someError show];
}

//Delegate for alertView
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (_statusIndication == alertView) {
        bEnableFlag = NO;
    }
}


- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"segueShowResource"]) {
        [self updateResourceArray];
        UINavigationController *navigationController = [segue destinationViewController];
        DEMOViewControllerShowResource *ViewControllerShowResource = (DEMOViewControllerShowResource *)[navigationController topViewController];
        ViewControllerShowResource.resFileArray = self.resFileArray;
    }
}

//unwind segue
- (void)unwindSegueForShowResourceViewController:(UIStoryboardSegue *)segue
{
    DEMOViewControllerShowResource *ViewControllerShowResource = [segue sourceViewController];
    self.selectedRow = ViewControllerShowResource.selectedRow;
    if  ([self.resFileArray count] > self.selectedRow)
        self.currentSelectedFileTF.text = [[self.resFileArray objectAtIndex:self.selectedRow] lastPathComponent];
}

//**************************************************************************/
// Following codes is for demo testing input
//**************************************************************************/
- (BOOL) DoDecoderAll
{
    BOOL bResult;
    for (NSUInteger index=0; index<[self.resFileArray count]; index++) {
        if ((bResult = [self DoDecoderOne:index]) == NO) {
            return NO;
        }
    }
    return YES;
}
- (BOOL) DoDecoderOne:(NSUInteger)index
{
    char *argv[3];//0 for exe name, 1 for resource input, 2 for output yuvfile
    int  argc = 3;
    NSString *fileName = [[self.resFileArray objectAtIndex:index] lastPathComponent];
    NSString *outputFileName = [[fileName stringByDeletingPathExtension] stringByAppendingPathExtension:@"yuv"];
    NSString *outputFilePath = [[[self.resFileArray objectAtIndex:index] stringByDeletingLastPathComponent] stringByAppendingPathComponent:outputFileName];
    argv[0] = (char *)("decConsole.exe");
    argv[1] = (char *)[[self.resFileArray objectAtIndex:index] UTF8String]; //input resouce file path
    argv[2] = (char *)[outputFilePath UTF8String]; //output file path
    if (bEnableFlag == NO) {
        return NO;
    }
    DecMain(argc, argv);
    return YES;
}

- (void) updateResourceArray
{
    //Clear the resource array
    if ([self.resFileArray count] > 0) {
        [self.resFileArray removeAllObjects];
    }
    //get the sharing folder path
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *sharingFolderPath = [paths objectAtIndex:0];
    //enumerate the h.264 files at sharing folder
    NSFileManager *fileManager = [NSFileManager defaultManager];

    NSError *error;
    NSArray * directoryContents = [fileManager contentsOfDirectoryAtPath:sharingFolderPath error:&error];
    for (NSUInteger index=0; index < [directoryContents count]; index++) {
        NSString *fileName = [directoryContents objectAtIndex:index];
        if (([fileName hasSuffix:@"264"] == YES) ||
            ([fileName hasSuffix:@"h264"] == YES)||
            ([fileName hasSuffix:@"H264"] == YES))
        {
            [self.resFileArray addObject:[sharingFolderPath stringByAppendingPathComponent:fileName]];
        }
    }
}

@end
