#import <UIKit/UIKit.h>

@class TGPassportMRZ;

@interface TGPassportScanView : UIView

@property (nonatomic, copy) void (^finishedWithMRZ)(TGPassportMRZ *);

- (void)start;
- (void)stop;
- (void)pause;

@end
