#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class MTSignal;

@interface TONError : NSObject

@property (nonatomic, strong, readonly) NSString *text;

@end

@interface TONKey : NSObject

@property (nonatomic, strong, readonly) NSString *publicKey;
@property (nonatomic, strong, readonly) NSData *secret;

- (instancetype)initWithPublicKey:(NSString *)publicKey secret:(NSData *)secret;

@end

@interface TONAccountState : NSObject

@property (nonatomic, readonly) int64_t balance;
@property (nonatomic, readonly) int32_t seqno;

- (instancetype)initWithBalance:(int64_t)balance seqno:(int32_t)seqno;

@end

@interface TON : NSObject

- (instancetype)initWithKeystoreDirectory:(NSString *)keystoreDirectory config:(NSString *)config;

- (MTSignal *)createKeyWithLocalPassword:(NSData *)localPassword mnemonicPassword:(NSString *)mnemonicPassword;
- (MTSignal *)getTestWalletAccountAddressWithPublicKey:(NSString *)publicKey;
- (MTSignal *)getTestGiverAccountState;
- (MTSignal *)testGiverSendGramsWithAccountState:(TONAccountState *)accountState accountAddress:(NSString *)accountAddress amount:(int64_t)amount;
- (MTSignal *)getAccountStateWithAddress:(NSString *)accountAddress;
- (MTSignal *)sendGramsFromKey:(TONKey *)key localPassword:(NSData *)localPassword fromAddress:(NSString *)fromAddress toAddress:(NSString *)address amount:(int64_t)amount;
- (MTSignal *)exportKey:(TONKey *)key localPassword:(NSData *)localPassword;
- (MTSignal *)importKeyWithLocalPassword:(NSData *)localPassword mnemonicPassword:(NSString *)mnemonicPassword wordList:(NSArray<NSString *> *)wordList;
- (MTSignal *)deleteKeyWithPublicKey:(NSString *)publicKey;
- (MTSignal *)makeWalletInitialized:(TONKey *)key localPassword:(NSData *)localPassword;

@end

NS_ASSUME_NONNULL_END
