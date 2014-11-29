/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

@class MTDatacenterAddress;
@class MTDatacenterAddressSet;
@class MTDatacenterAuthInfo;
@protocol MTSerialization;
@class MTContext;
@class MTTransportScheme;
@class MTKeychain;
@class MTSessionInfo;
@class MTApiEnvironment;

@protocol MTContextChangeListener <NSObject>

@optional

- (void)contextDatacenterAddressSetUpdated:(MTContext *)context datacenterId:(NSInteger)datacenterId addressSet:(MTDatacenterAddressSet *)addressSet;
- (void)contextDatacenterAuthInfoUpdated:(MTContext *)context datacenterId:(NSInteger)datacenterId authInfo:(MTDatacenterAuthInfo *)authInfo;
- (void)contextDatacenterAuthTokenUpdated:(MTContext *)context datacenterId:(NSInteger)datacenterId authToken:(id)authToken;
- (void)contextDatacenterTransportSchemeUpdated:(MTContext *)context datacenterId:(NSInteger)datacenterId transportScheme:(MTTransportScheme *)transportScheme;
- (void)contextIsPasswordRequiredUpdated:(MTContext *)context datacenterId:(NSInteger)datacenterId;

@end

@interface MTContextBlockChangeListener : NSObject <MTContextChangeListener>

@property (nonatomic, copy) void (^contextIsPasswordRequiredUpdated)(MTContext *, NSInteger);

@end

@interface MTContext : NSObject

@property (nonatomic, strong) MTKeychain *keychain;

@property (nonatomic, strong, readonly) id<MTSerialization> serialization;
@property (nonatomic, strong, readonly) MTApiEnvironment *apiEnvironment;

- (instancetype)initWithSerialization:(id<MTSerialization>)serialization apiEnvironment:(MTApiEnvironment *)apiEnvironment;

- (void)performBatchUpdates:(void (^)())block;

- (void)addChangeListener:(id<MTContextChangeListener>)changeListener;
- (void)removeChangeListener:(id<MTContextChangeListener>)changeListener;

- (NSTimeInterval)globalTime;
- (NSTimeInterval)globalTimeDifference;
- (NSTimeInterval)globalTimeOffsetFromUTC;
- (void)setGlobalTimeDifference:(NSTimeInterval)globalTimeDifference;

- (void)setSeedAddressSetForDatacenterWithId:(NSInteger)datacenterId seedAddressSet:(MTDatacenterAddressSet *)seedAddressSet;
- (void)updateAddressSetForDatacenterWithId:(NSInteger)datacenterId addressSet:(MTDatacenterAddressSet *)addressSet;
- (void)addAddressForDatacenterWithId:(NSInteger)datacenterId address:(MTDatacenterAddress *)address;
- (void)updateTransportSchemeForDatacenterWithId:(NSInteger)datacenterId transportScheme:(MTTransportScheme *)transportScheme;
- (void)updateAuthInfoForDatacenterWithId:(NSInteger)datacenterId authInfo:(MTDatacenterAuthInfo *)authInfo;

- (bool)isPasswordInputRequiredForDatacenterWithId:(NSInteger)datacenterId;
- (bool)updatePasswordInputRequiredForDatacenterWithId:(NSInteger)datacenterId required:(bool)required;

- (void)scheduleSessionCleanupForAuthKeyId:(int64_t)authKeyId sessionInfo:(MTSessionInfo *)sessionInfo;
- (void)collectSessionIdsForCleanupWithAuthKeyId:(int64_t)authKeyId completion:(void (^)(NSArray *sessionIds))completion;
- (void)sessionIdsDeletedForAuthKeyId:(int64_t)authKeyId sessionIds:(NSArray *)sessionIds;

- (NSArray *)knownDatacenterIds;
- (void)enumerateAddressSetsForDatacenters:(void (^)(NSInteger datacenterId, MTDatacenterAddressSet *addressSet, BOOL *stop))block;

- (MTDatacenterAddressSet *)addressSetForDatacenterWithId:(NSInteger)datacenterId;
- (MTTransportScheme *)transportSchemeForDatacenterWithid:(NSInteger)datacenterId;
- (void)transportSchemeForDatacenterWithIdRequired:(NSInteger)datacenterId;
- (void)invalidateTransportSchemeForDatacenterId:(NSInteger)datacenterId transportScheme:(MTTransportScheme *)transportScheme isProbablyHttp:(bool)isProbablyHttp;
- (void)revalidateTransportSchemeForDatacenterId:(NSInteger)datacenterId transportScheme:(MTTransportScheme *)transportScheme;
- (MTDatacenterAuthInfo *)authInfoForDatacenterWithId:(NSInteger)datacenterId;

- (void)removeAllAuthTokens;
- (id)authTokenForDatacenterWithId:(NSInteger)datacenterId;
- (void)updateAuthTokenForDatacenterWithId:(NSInteger)datacenterId authToken:(id)authToken;

- (void)addressSetForDatacenterWithIdRequired:(NSInteger)datacenterId;
- (void)authInfoForDatacenterWithIdRequired:(NSInteger)datacenterId;
- (void)authTokenForDatacenterWithIdRequired:(NSInteger)datacenterId authToken:(id)authToken masterDatacenterId:(NSInteger)masterDatacenterId;

- (void)reportProblemsWithDatacenterAddressForId:(NSInteger)datacenterId address:(MTDatacenterAddress *)address;

@end
