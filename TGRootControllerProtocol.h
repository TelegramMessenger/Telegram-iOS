#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class SSignal;

@protocol TGRootControllerProtocol <NSObject>

- (CGRect)applicationBounds;
- (bool)callStatusBarHidden;
- (SSignal *)sizeClass;

@end
