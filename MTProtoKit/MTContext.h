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
@class MTTransportStraregy;
@class MTKeychain;
@class MTSessionInfo;

@protocol MTContextChangeListener <NSObject>

@optional

- (void)contextDatacenterAddressSetUpdated:(MTContext *)context datacenterId:(NSInteger)datacenterId addressSet:(MTDatacenterAddressSet *)addressSet;
- (void)contextDatacenterAuthInfoUpdated:(MTContext *)context datacenterId:(NSInteger)datacenterId authInfo:(MTDatacenterAuthInfo *)authInfo;
- (void)contextDatacenterAuthTokenUpdated:(MTContext *)context datacenterId:(NSInteger)datacenterId authToken:(id)authToken;

@end

@interface MTContext : NSObject

@property (nonatomic, strong) MTKeychain *keychain;

@property (nonatomic, strong, readonly) id<MTSerialization> serialization;

- (instancetype)initWithSerialization:(id<MTSerialization>)serialization;

- (void)performBatchUpdates:(void (^)())block;

- (void)addChangeListener:(id<MTContextChangeListener>)changeListener;
- (void)removeChangeListener:(id<MTContextChangeListener>)changeListener;

- (NSTimeInterval)globalTime;
- (NSTimeInterval)globalTimeDifference;
- (NSTimeInterval)globalTimeOffsetFromUTC;
- (void)setGlobalTimeDifference:(NSTimeInterval)globalTimeDifference;

- (void)setSeedAddressSetForDatacenterWithId:(NSInteger)datacenterId seedAddressSet:(MTDatacenterAddressSet *)seedAddressSet;
- (void)updateAddressSetForDatacenterWithId:(NSInteger)datacenterId addressSet:(MTDatacenterAddressSet *)addressSet;
- (void)updateAuthInfoForDatacenterWithId:(NSInteger)datacenterId authInfo:(MTDatacenterAuthInfo *)authInfo;
- (void)updateTransportStrategyForDatacenterWithId:(NSInteger)datacenterId strategy:(MTTransportStraregy *)transportStrategy;

- (void)scheduleSessionCleanupForAuthKeyId:(int64_t)authKeyId sessionInfo:(MTSessionInfo *)sessionInfo;
- (void)collectSessionIdsForCleanupWithAuthKeyId:(int64_t)authKeyId completion:(void (^)(NSArray *sessionIds))completion;
- (void)sessionIdsDeletedForAuthKeyId:(int64_t)authKeyId sessionIds:(NSArray *)sessionIds;

- (NSArray *)knownDatacenterIds;
- (void)enumerateAddressSetsForDatacenters:(void (^)(NSInteger datacenterId, MTDatacenterAddressSet *addressSet, BOOL *stop))block;

- (MTDatacenterAddressSet *)addressSetForDatacenterWithId:(NSInteger)datacenterId;
- (MTDatacenterAuthInfo *)authInfoForDatacenterWithId:(NSInteger)datacenterId;

- (void)removeAllAuthTokens;
- (id)authTokenForDatacenterWithId:(NSInteger)datacenterId;
- (void)updateAuthTokenForDatacenterWithId:(NSInteger)datacenterId authToken:(id)authToken;
- (bool)findAnyDatacenterIdWithAuthToken:(id)authToken datacenterId:(NSInteger *)datacenterId;

- (void)addressSetForDatacenterWithIdRequired:(NSInteger)datacenterId;
- (void)authInfoForDatacenterWithIdRequired:(NSInteger)datacenterId;
- (void)authTokenForDatacenterWithIdRequired:(NSInteger)datacenterId authToken:(id)authToken masterDatacenterId:(NSInteger)masterDatacenterId;

- (void)reportProblemsWithDatacenterAddressForId:(NSInteger)datacenterId address:(MTDatacenterAddress *)address;

@end
