#import "TGBridgePresetsSignals.h"

@implementation TGBridgePresetsSignals

+ (NSURL *)presetsURL
{
    static dispatch_once_t onceToken;
    static NSURL *presetsURL;
    dispatch_once(&onceToken, ^
    {
        NSString *documentsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true)[0];
        presetsURL = [[NSURL alloc] initFileURLWithPath:[documentsPath stringByAppendingPathComponent:@"presets.data"]];
    });
    return presetsURL;
}

@end
