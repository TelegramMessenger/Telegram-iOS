#import <Foundation/Foundation.h>

@class MTQueue;

@interface MTNetworkUsageCalculationInfo : NSObject

@property (nonatomic, strong, readonly) NSString *filePath;

- (instancetype)initWithFilePath:(NSString *)filePath;

@end
