#import <Foundation/Foundation.h>

#ifdef BUCK
#import <MTProtoKit/MTProtoKit.h>
#else
#import <MTProtoKitDynamic/MTProtoKitDynamic.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@interface Serialization : NSObject <MTSerialization>

@end

NS_ASSUME_NONNULL_END
