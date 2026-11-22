#import <WatchKit/WatchKit.h>
#import <SSignalKit/SSignalKit.h>

@interface WKInterfaceImage (Signals)

- (void)setSignal:(SSignal *)signal isVisible:(bool (^)(void))isVisible;
- (void)updateIfNeeded;

@end
