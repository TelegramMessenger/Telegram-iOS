#import "TGPassportOCR.h"
#import "TGPassportMRZ.h"
#import "ocr.h"

@implementation TGPassportOCR

+ (SSignal *)recognizeMRZInImage:(UIImage *)image
{
    return [[SSignal defer:^SSignal *
    {
        CGRect boundingRect;
        NSString *string = recognizeMRZ(image, &boundingRect);
        
        NSArray *lines = [string componentsSeparatedByString:@"\n"];
        TGPassportMRZ *mrz = [TGPassportMRZ parseLines:lines];
        
        return [SSignal single:mrz];
    }] startOn:[SQueue concurrentDefaultQueue]];
}

@end
