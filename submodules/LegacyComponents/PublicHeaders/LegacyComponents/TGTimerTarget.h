#import <Foundation/Foundation.h>

@interface TGTimerTarget : NSObject

@property (nonatomic, weak) id target;
@property (nonatomic) SEL action;

+ (NSTimer *)scheduledMainThreadTimerWithTarget:(id)target action:(SEL)action interval:(NSTimeInterval)interval repeat:(bool)repeat;
+ (NSTimer *)scheduledMainThreadTimerWithTarget:(id)target action:(SEL)action interval:(NSTimeInterval)interval repeat:(bool)repeat runLoopModes:(NSString *)runLoopModes;

@end
