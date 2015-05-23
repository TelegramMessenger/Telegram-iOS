#import <SSignalKit/SSignalKit.h>

@interface SPipe : NSObject

@property (nonatomic, copy, readonly) SSignal *(^signalProducer)();
@property (nonatomic, copy, readonly) void (^sink)(id);

@end

