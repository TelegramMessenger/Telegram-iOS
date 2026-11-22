

#import <MtProtoKit/MTMessageService.h>

@class MTContext;
@class MTDatacenterAuthMessageService;
@class MTDatacenterAuthKey;

@protocol MTDatacenterAuthMessageServiceDelegate <NSObject>

- (void)authMessageServiceCompletedWithAuthKey:(MTDatacenterAuthKey *)authKey timestamp:(int64_t)timestamp serverSalt:(int64_t)serverSalt;

@end

/// The RSA public keys, in PEM, that keys for the production or the test datacenters are made with.
#ifdef __cplusplus
extern "C"
#endif
NSArray<NSString *> *MTDatacenterAuthDefaultPublicKeys(bool isProduction);

@interface MTDatacenterAuthMessageService : NSObject <MTMessageService>

@property (nonatomic, weak) id<MTDatacenterAuthMessageServiceDelegate> delegate;

- (instancetype)initWithContext:(MTContext *)context tempAuth:(bool)tempAuth;

@end
