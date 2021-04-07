#import <Foundation/Foundation.h>

@interface BuildConfigExtra : NSObject

- (instancetype _Nonnull)initWithBaseAppBundleId:(NSString * _Nonnull)baseAppBundleId;

+ (NSDictionary * _Nonnull)signatureDict;

@end
