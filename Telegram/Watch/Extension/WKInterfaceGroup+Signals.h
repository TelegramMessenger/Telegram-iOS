#import <WatchKit/WatchKit.h>
#import <SSignalKit/SSignalKit.h>

@interface WKInterfaceGroup (Signals)

- (void)setBackgroundImageSignal:(SSignal *)signal isVisible:(bool (^)(void))isVisible;
- (void)updateIfNeeded;

@end
