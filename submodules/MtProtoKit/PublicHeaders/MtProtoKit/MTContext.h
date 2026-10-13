#import <Foundation/Foundation.h>

#import <MtProtoKit/MTDatacenterAuthInfo.h>
#import <MtProtoKit/MTNetworkUsageCalculationInfo.h>

#import <EncryptionProvider/EncryptionProvider.h>

@class MTDatacenterAddress;
@class MTDatacenterAddressSet;
@protocol MTSerialization;
@class MTContext;
@class MTTransportScheme;
@protocol MTKeychain;
@class MTSessionInfo;
@class MTApiEnvironment;
@class MTSignal;
@class MTQueue;

@protocol MTTcpConnectionInterface;

@protocol MTTcpConnectionInterfaceDelegate <NSObject>

- (void)connectionInterfaceDidReadPartialDataOfLength:(NSUInteger)partialLength tag:(long)tag;
- (void)connectionInterfaceDidReadData:(NSData * _Nonnull)rawData withTag:(long)tag networkType:(int32_t)networkType;
- (void)connectionInterfaceDidConnect;
- (void)connectionInterfaceDidDisconnectWithError:(NSError * _Nullable)error;

@end

@protocol MTTcpConnectionInterface<NSObject>

- (void)setGetLogPrefix:(NSString * _Nonnull(^_Nullable)())getLogPrefix;
- (void)setUsageCalculationInfo:(MTNetworkUsageCalculationInfo * _Nullable)usageCalculationInfo;
- (bool)connectToHost:(NSString * _Nonnull)inHost
               onPort:(uint16_t)port
         viaInterface:(NSString * _Nullable)inInterface
          withTimeout:(NSTimeInterval)timeout
                error:(NSError * _Nullable * _Nullable)errPtr;
- (void)writeData:(NSData * _Nonnull)data;
- (void)readDataToLength:(NSUInteger)length withTimeout:(NSTimeInterval)timeout tag:(long)tag;
- (void)disconnect;
- (void)resetDelegate;

@optional

/// True only for the WEB proxy carrier, which multiplexes the connection over a hidden
/// WebView instead of opening a socket, and therefore IGNORES the host and port it is
/// handed. `MTTcpConnection` uses that to pair the interface with
/// `MTSocksProxySettings.webProxy`: a connection that has a real address to reach must
/// never be given the carrier, and a WEB proxy connection must never fall back to a socket.
- (bool)isWebProxyCarrier;

@end


@protocol MTContextChangeListener <NSObject>

@optional

- (void)contextDatacenterAddressSetUpdated:(MTContext * _Nonnull)context datacenterId:(NSInteger)datacenterId addressSet:(MTDatacenterAddressSet * _Nonnull)addressSet;
- (void)contextDatacenterAuthInfoUpdated:(MTContext * _Nonnull)context datacenterId:(NSInteger)datacenterId authInfo:(MTDatacenterAuthInfo * _Nonnull)authInfo selector:(MTDatacenterAuthInfoSelector)selector;
- (void)contextDatacenterAuthTokenUpdated:(MTContext * _Nonnull)context datacenterId:(NSInteger)datacenterId authToken:(id _Nullable)authToken;
// Creating the datacenter's auth key for this selector ended without a key
// (or was abandoned). A listener still waiting for that key asks for it again;
// the context starts nothing on its own.
- (void)contextDatacenterAuthInfoRequestFailed:(MTContext * _Nonnull)context datacenterId:(NSInteger)datacenterId selector:(MTDatacenterAuthInfoSelector)selector;
// Transferring the datacenter's auth token ended without a token (or was
// cancelled). A listener still waiting for the token asks for it again.
- (void)contextDatacenterAuthTokenTransferFailed:(MTContext * _Nonnull)context datacenterId:(NSInteger)datacenterId;
- (void)contextDatacenterTransportSchemesUpdated:(MTContext * _Nonnull)context datacenterId:(NSInteger)datacenterId shouldReset:(bool)shouldReset;
- (void)contextIsPasswordRequiredUpdated:(MTContext * _Nonnull)context datacenterId:(NSInteger)datacenterId;
- (void)contextDatacenterPublicKeysUpdated:(MTContext * _Nonnull)context datacenterId:(NSInteger)datacenterId publicKeys:(NSArray<NSDictionary *> * _Nonnull)publicKeys;
- (MTSignal * _Nonnull)fetchContextDatacenterPublicKeys:(MTContext * _Nonnull)context datacenterId:(NSInteger)datacenterId;
- (void)contextApiEnvironmentUpdated:(MTContext * _Nonnull)context apiEnvironment:(MTApiEnvironment * _Nonnull)apiEnvironment;
- (MTSignal * _Nonnull)isContextNetworkAccessAllowed:(MTContext * _Nonnull)context;
- (void)contextLoggedOut:(MTContext * _Nonnull)context;

@end

@interface MTContextBlockChangeListener : NSObject <MTContextChangeListener>

@property (nonatomic, copy) void (^ _Nullable contextIsPasswordRequiredUpdated)(MTContext * _Nonnull, NSInteger);
@property (nonatomic, copy) MTSignal * _Nonnull (^ _Nullable fetchContextDatacenterPublicKeys)(MTContext * _Nonnull, NSInteger);
@property (nonatomic, copy) MTSignal * _Nonnull(^ _Nullable isContextNetworkAccessAllowed)(MTContext * _Nonnull);

@end

@interface MTContext : NSObject

@property (nonatomic, strong) id<MTKeychain> _Nonnull keychain;

@property (nonatomic, strong, readonly) id<MTSerialization> _Nonnull serialization;
@property (nonatomic, strong) id<EncryptionProvider> _Nonnull encryptionProvider;
@property (nonatomic, strong, readonly) MTApiEnvironment * _Nonnull apiEnvironment;
@property (nonatomic, readonly) bool isTestingEnvironment;
@property (nonatomic, readonly) bool useTempAuthKeys;
@property (nonatomic) int32_t tempKeyExpiration;
// Replaces bound temporary keys this process uses before they expire. Off by default; app extensions keep it off.
@property (nonatomic) bool refreshesTemporaryKeys;

@property (nonatomic, copy) id<MTTcpConnectionInterface> _Nonnull (^ _Nullable makeTcpConnectionInterface)(id<MTTcpConnectionInterfaceDelegate> _Nonnull delegate, dispatch_queue_t _Nonnull delegateQueue);

+ (int32_t)fixedTimeDifference;
+ (void)setFixedTimeDifference:(int32_t)fixedTimeDifference;

+ (MTQueue * _Nonnull)contextQueue;

+ (void)performWithObjCTry:(dispatch_block_t _Nonnull)block;

+ (void)copyAuthInfoFrom:(id<MTKeychain> _Nonnull)keychain toTempKeychain:(id<MTKeychain> _Nonnull)tempKeychain;

- (instancetype _Nonnull)initWithSerialization:(id<MTSerialization> _Nonnull)serialization encryptionProvider:(id<EncryptionProvider> _Nonnull)encryptionProvider apiEnvironment:(MTApiEnvironment * _Nonnull)apiEnvironment isTestingEnvironment:(bool)isTestingEnvironment useTempAuthKeys:(bool)useTempAuthKeys;

- (void)performBatchUpdates:(void (^ _Nonnull)())block;

- (void)addChangeListener:(id<MTContextChangeListener> _Nonnull)changeListener;
- (void)removeChangeListener:(id<MTContextChangeListener> _Nonnull)changeListener;

- (void)setDiscoverBackupAddressListSignal:(MTSignal * _Nonnull)signal;
- (void)setExternalRequestVerification:(MTSignal * _Nonnull (^ _Nonnull)(NSString * _Nonnull))externalRequestVerification;
- (void)setExternalRecaptchaRequestVerification:(MTSignal * _Nonnull (^ _Nonnull)(NSString * _Nonnull, NSString * _Nonnull))externalRecaptchaRequestVerification;
- (MTSignal * _Nullable)performExternalRequestVerificationWithNonce:(NSString * _Nonnull)nonce;
- (MTSignal * _Nullable)performExternalRecaptchaRequestVerificationWithMethod:(NSString * _Nonnull)method siteKey:(NSString * _Nonnull)siteKey;

- (NSTimeInterval)globalTime;
- (NSTimeInterval)globalTimeDifference;
- (NSTimeInterval)globalTimeOffsetFromUTC;
- (void)setGlobalTimeDifference:(NSTimeInterval)globalTimeDifference;

- (void)setSeedAddressSetForDatacenterWithId:(NSInteger)datacenterId seedAddressSet:(MTDatacenterAddressSet * _Nonnull)seedAddressSet;
- (void)updateAddressSetForDatacenterWithId:(NSInteger)datacenterId addressSet:(MTDatacenterAddressSet * _Nonnull)addressSet forceUpdateSchemes:(bool)forceUpdateSchemes;
- (void)addAddressForDatacenterWithId:(NSInteger)datacenterId address:(MTDatacenterAddress * _Nonnull)address;
- (void)updateTransportSchemeForDatacenterWithId:(NSInteger)datacenterId transportScheme:(MTTransportScheme * _Nonnull)transportScheme media:(bool)media isProxy:(bool)isProxy;
- (void)updateAuthInfoForDatacenterWithId:(NSInteger)datacenterId authInfo:(MTDatacenterAuthInfo * _Nullable)authInfo selector:(MTDatacenterAuthInfoSelector)selector;

- (bool)isPasswordInputRequiredForDatacenterWithId:(NSInteger)datacenterId;
- (bool)updatePasswordInputRequiredForDatacenterWithId:(NSInteger)datacenterId required:(bool)required;

- (void)scheduleSessionCleanupForAuthKeyId:(int64_t)authKeyId sessionInfo:(MTSessionInfo * _Nonnull)sessionInfo;
- (void)collectSessionIdsForCleanupWithAuthKeyId:(int64_t)authKeyId completion:(void (^ _Nonnull)(NSArray * _Nonnull sessionIds))completion;
- (void)sessionIdsDeletedForAuthKeyId:(int64_t)authKeyId sessionIds:(NSArray * _Nonnull)sessionIds;

- (NSArray * _Nonnull)knownDatacenterIds;
- (void)enumerateAddressSetsForDatacenters:(void (^ _Nonnull)(NSInteger datacenterId, MTDatacenterAddressSet * _Nonnull addressSet, BOOL * _Nullable stop))block;

- (MTDatacenterAddressSet * _Nonnull)addressSetForDatacenterWithId:(NSInteger)datacenterId;
- (void)reportTransportSchemeFailureForDatacenterId:(NSInteger)datacenterId transportScheme:(MTTransportScheme * _Nonnull)transportScheme;
- (void)reportTransportSchemeSuccessForDatacenterId:(NSInteger)datacenterId transportScheme:(MTTransportScheme * _Nonnull)transportScheme;
- (void)invalidateTransportSchemesForDatacenterIds:(NSArray<NSNumber *> * _Nonnull)datacenterIds;
- (void)invalidateTransportSchemesForKnownDatacenterIds;
- (MTTransportScheme * _Nullable)chooseTransportSchemeForConnectionToDatacenterId:(NSInteger)datacenterId schemes:(NSArray<MTTransportScheme *> * _Nonnull)schemes;
- (NSArray<MTTransportScheme *> * _Nonnull)transportSchemesForDatacenterWithId:(NSInteger)datacenterId media:(bool)media enforceMedia:(bool)enforceMedia isProxy:(bool)isProxy;
- (void)transportSchemeForDatacenterWithIdRequired:(NSInteger)datacenterId media:(bool)media;
- (void)invalidateTransportSchemeForDatacenterId:(NSInteger)datacenterId transportScheme:(MTTransportScheme * _Nonnull)transportScheme isProbablyHttp:(bool)isProbablyHttp media:(bool)media;
- (void)revalidateTransportSchemeForDatacenterId:(NSInteger)datacenterId transportScheme:(MTTransportScheme * _Nonnull)transportScheme media:(bool)media;
- (MTDatacenterAuthInfo * _Nullable)authInfoForDatacenterWithId:(NSInteger)datacenterId selector:(MTDatacenterAuthInfoSelector)selector;
    
- (NSArray<NSDictionary *> * _Nonnull)publicKeysForDatacenterWithId:(NSInteger)datacenterId;
- (void)updatePublicKeysForDatacenterWithId:(NSInteger)datacenterId publicKeys:(NSArray<NSDictionary *> * _Nonnull)publicKeys;
- (void)publicKeysForDatacenterWithIdRequired:(NSInteger)datacenterId;

- (void)removeAllAuthTokens;
- (void)removeTokenForDatacenterWithId:(NSInteger)datacenterId;
- (id _Nullable)authTokenForDatacenterWithId:(NSInteger)datacenterId;
- (void)updateAuthTokenForDatacenterWithId:(NSInteger)datacenterId authToken:(id _Nullable)authToken;

- (void)addressSetForDatacenterWithIdRequired:(NSInteger)datacenterId;
- (void)authInfoForDatacenterWithIdRequired:(NSInteger)datacenterId isCdn:(bool)isCdn selector:(MTDatacenterAuthInfoSelector)selector allowUnboundEphemeralKeys:(bool)allowUnboundEphemeralKeys;
- (void)authTokenForDatacenterWithIdRequired:(NSInteger)datacenterId authToken:(id _Nullable)authToken masterDatacenterId:(NSInteger)masterDatacenterId;

- (void)reportProblemsWithDatacenterAddressForId:(NSInteger)datacenterId address:(MTDatacenterAddress * _Nonnull)address;
    
- (void)updateApiEnvironment:(MTApiEnvironment * _Nullable (^ _Nonnull)(MTApiEnvironment * _Nullable))f;

- (void)beginExplicitBackupAddressDiscovery;

- (void)checkIfLoggedOut:(NSInteger)datacenterId;

@end
