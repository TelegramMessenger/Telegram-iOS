#import <Foundation/Foundation.h>

@interface MTRpcError : NSObject

@property (nonatomic, readonly) int32_t errorCode;
@property (nonatomic, strong, readonly) NSString *errorDescription;

- (instancetype)initWithErrorCode:(int32_t)errorCode errorDescription:(NSString *)errorDescription;

@end
