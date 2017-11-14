#import <Foundation/Foundation.h>

@class MTDatacenterAddress;
@class MTDatacenterAddressSet;
@class MTDatacenterAuthInfo;
@protocol MTSerialization;
@class MTContext;
@class MTTransportScheme;
@protocol MTKeychain;
@class MTSessionInfo;
@class MTApiEnvironment;
@class MTSignal;

@protocol MTContextChangeListener <NSObject>

@optional

- (void)contextDatacenterAddressSetUpdated:(MTContext *)context datacenterId:(NSInteger)datacenterId addressSet:(MTDatacenterAddressSet *)addressSet;
- (void)contextDatacenterAuthInfoUpdated:(MTContext *)context datacenterId:(NSInteger)datacenterId authInfo:(MTDatacenterAuthInfo *)authInfo;
- (void)contextDatacenterAuthTokenUpdated:(MTContext *)context datacenterId:(NSInteger)datacenterId authToken:(id)authToken;
- (void)contextDatacenterTransportSchemeUpdated:(MTContext *)context datacenterId:(NSInteger)datacenterId transportScheme:(MTTransportScheme *)transportScheme media:(bool)media;
- (void)contextIsPasswordRequiredUpdated:(MTContext *)context datacenterId:(NSInteger)datacenterId;
- (void)contextDatacenterPublicKeysUpdated:(MTContext *)context datacenterId:(NSInteger)datacenterId publicKeys:(NSArray<NSDictionary *> *)publicKeys;
- (MTSignal *)fetchContextDatacenterPublicKeys:(MTContext *)context datacenterId:(NSInteger)datacenterId;
- (void)contextApiEnvironmentUpdated:(MTContext *)context apiEnvironment:(MTApiEnvironment *)apiEnvironment;

@end

@interface MTContextBlockChangeListener : NSObject <MTContextChangeListener>

@property (nonatomic, copy) void (^contextIsPasswordRequiredUpdated)(MTContext *, NSInteger);
@property (nonatomic, copy) MTSignal *(^fetchContextDatacenterPublicKeys)(MTContext *, NSInteger);

@end

@interface MTContext : NSObject

@property (nonatomic, strong) id<MTKeychain> keychain;

@property (nonatomic, strong, readonly) id<MTSerialization> serialization;
@property (nonatomic, strong, readonly) MTApiEnvironment *apiEnvironment;

- (instancetype)initWithSerialization:(id<MTSerialization>)serialization apiEnvironment:(MTApiEnvironment *)apiEnvironment;

- (void)performBatchUpdates:(void (^)())block;

- (void)addChangeListener:(id<MTContextChangeListener>)changeListener;
- (void)removeChangeListener:(id<MTContextChangeListener>)changeListener;

- (void)setDiscoverBackupAddressListSignal:(MTSignal *)signal;

- (NSTimeInterval)globalTime;
- (NSTimeInterval)globalTimeDifference;
- (NSTimeInterval)globalTimeOffsetFromUTC;
- (void)setGlobalTimeDifference:(NSTimeInterval)globalTimeDifference;

- (void)setSeedAddressSetForDatacenterWithId:(NSInteger)datacenterId seedAddressSet:(MTDatacenterAddressSet *)seedAddressSet;
- (void)updateAddressSetForDatacenterWithId:(NSInteger)datacenterId addressSet:(MTDatacenterAddressSet *)addressSet forceUpdateSchemes:(bool)forceUpdateSchemes;
- (void)addAddressForDatacenterWithId:(NSInteger)datacenterId address:(MTDatacenterAddress *)address;
- (void)updateTransportSchemeForDatacenterWithId:(NSInteger)datacenterId transportScheme:(MTTransportScheme *)transportScheme media:(bool)media isProxy:(bool)isProxy;
- (void)updateAuthInfoForDatacenterWithId:(NSInteger)datacenterId authInfo:(MTDatacenterAuthInfo *)authInfo;

- (bool)isPasswordInputRequiredForDatacenterWithId:(NSInteger)datacenterId;
- (bool)updatePasswordInputRequiredForDatacenterWithId:(NSInteger)datacenterId required:(bool)required;

- (void)scheduleSessionCleanupForAuthKeyId:(int64_t)authKeyId sessionInfo:(MTSessionInfo *)sessionInfo;
- (void)collectSessionIdsForCleanupWithAuthKeyId:(int64_t)authKeyId completion:(void (^)(NSArray *sessionIds))completion;
- (void)sessionIdsDeletedForAuthKeyId:(int64_t)authKeyId sessionIds:(NSArray *)sessionIds;

- (NSArray *)knownDatacenterIds;
- (void)enumerateAddressSetsForDatacenters:(void (^)(NSInteger datacenterId, MTDatacenterAddressSet *addressSet, BOOL *stop))block;

- (MTDatacenterAddressSet *)addressSetForDatacenterWithId:(NSInteger)datacenterId;
- (MTTransportScheme *)transportSchemeForDatacenterWithId:(NSInteger)datacenterId media:(bool)media isProxy:(bool)isProxy;
- (void)transportSchemeForDatacenterWithIdRequired:(NSInteger)datacenterId media:(bool)media;
- (void)invalidateTransportSchemeForDatacenterId:(NSInteger)datacenterId transportScheme:(MTTransportScheme *)transportScheme isProbablyHttp:(bool)isProbablyHttp media:(bool)media;
- (void)revalidateTransportSchemeForDatacenterId:(NSInteger)datacenterId transportScheme:(MTTransportScheme *)transportScheme media:(bool)media;
- (MTDatacenterAuthInfo *)authInfoForDatacenterWithId:(NSInteger)datacenterId;
    
- (NSArray<NSDictionary *> *)publicKeysForDatacenterWithId:(NSInteger)datacenterId;
- (void)updatePublicKeysForDatacenterWithId:(NSInteger)datacenterId publicKeys:(NSArray<NSDictionary *> *)publicKeys;
- (void)publicKeysForDatacenterWithIdRequired:(NSInteger)datacenterId;

- (void)removeAllAuthTokens;
- (id)authTokenForDatacenterWithId:(NSInteger)datacenterId;
- (void)updateAuthTokenForDatacenterWithId:(NSInteger)datacenterId authToken:(id)authToken;

- (void)addressSetForDatacenterWithIdRequired:(NSInteger)datacenterId;
- (void)authInfoForDatacenterWithIdRequired:(NSInteger)datacenterId isCdn:(bool)isCdn;
- (void)tempAuthKeyForDatacenterWithIdRequired:(NSInteger)datacenterId;
- (void)authTokenForDatacenterWithIdRequired:(NSInteger)datacenterId authToken:(id)authToken masterDatacenterId:(NSInteger)masterDatacenterId;

- (void)reportProblemsWithDatacenterAddressForId:(NSInteger)datacenterId address:(MTDatacenterAddress *)address;
    
- (void)updateApiEnvironment:(MTApiEnvironment *(^)(MTApiEnvironment *))f;

@end
