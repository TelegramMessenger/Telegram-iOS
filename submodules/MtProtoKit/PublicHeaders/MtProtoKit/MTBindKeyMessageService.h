#import <Foundation/Foundation.h>
#import <MtProtoKit/MTMessageService.h>
#import <MtProtoKit/MTDatacenterAuthInfo.h>

@interface MTBindKeyMessageService : NSObject <MTMessageService>

- (instancetype)initWithPersistentKey:(MTDatacenterAuthKey *)persistentKey ephemeralKey:(MTDatacenterAuthKey *)ephemeralKey completion:(void (^)(bool))completion;

@end
