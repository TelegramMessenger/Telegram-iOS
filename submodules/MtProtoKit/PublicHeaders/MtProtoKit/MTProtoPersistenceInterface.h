#import <Foundation/Foundation.h>

@class MTSignal;

NS_ASSUME_NONNULL_BEGIN

@protocol MTProtoPersistenceInterface <NSObject>

- (MTSignal *)get:(NSData *)key;
- (void)set:(NSData *)key value:(NSData *)value;

@end

NS_ASSUME_NONNULL_END
