#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class MTSignal;

@interface TONKey : NSObject

@property (nonatomic, strong, readonly) NSString *publicKey;
@property (nonatomic, strong, readonly) NSString *secret;

- (instancetype)initWithPublicKey:(NSString *)publicKey secret:(NSString *)secret;

@end

@interface TONTestGiverAccountState : NSObject

@property (nonatomic, readonly) int64_t balance;
@property (nonatomic, readonly) int32_t seqno;

- (instancetype)initWithBalance:(int64_t)balance seqno:(int32_t)seqno;

@end

@interface TON : NSObject

- (instancetype)initWithKeystoreDirectory:(NSString *)keystoreDirectory config:(NSString *)config;

- (MTSignal *)createKeyWithLocalPassword:(NSString *)localPassword mnemonicPassword:(NSString *)mnemonicPassword;
- (MTSignal *)getTestWalletAccountAddressWithPublicKey:(NSString *)publicKey;
- (MTSignal *)getTestGiverAccountState;
- (MTSignal *)testGiverSendGramsWithAccountState:(TONTestGiverAccountState *)accountState accountAddress:(NSString *)accountAddress amount:(int64_t)amount;
- (MTSignal *)getAccountStateWithAddress:(NSString *)accountAddress;

@end

NS_ASSUME_NONNULL_END
