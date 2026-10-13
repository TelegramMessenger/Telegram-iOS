#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const WalletBackupCryptoErrorDomain;

typedef NS_ERROR_ENUM(WalletBackupCryptoErrorDomain, WalletBackupCryptoErrorCode) {
    WalletBackupCryptoErrorInvalidInput = 1,
    WalletBackupCryptoErrorKeyGeneration = 2,
    WalletBackupCryptoErrorKeyAgreement = 3,
    WalletBackupCryptoErrorEncryption = 4,
    WalletBackupCryptoErrorDecryption = 5,
    WalletBackupCryptoErrorInvalidPayload = 6,
};

/// Owns one in-memory ephemeral Ed25519 key from the calls e2e library.
/// The corresponding private key never crosses the Objective-C boundary.
@interface WalletBackupCryptoKeyPair : NSObject

@property (nonatomic, readonly) NSData *publicKey;

+ (nullable instancetype)generate:(NSError * _Nullable * _Nullable)error;
+ (nullable instancetype)generateKeyPair NS_SWIFT_NAME(generateKeyPair());

/// Decrypts exactly three bare or observed-wrapper envelopes, XORs their 220-byte
/// payloads, and validates and removes the reconstructed five-byte prefix.
/// Returns the 215-byte padded mnemonic text for the caller to validate and decode.
/// Also accepts interim backups that split the already-prefixed mnemonic block.
- (nullable NSData *)decryptAndCombineEnvelopes:(NSArray<NSData *> *)envelopes
                                          error:(NSError * _Nullable * _Nullable)error;
- (nullable NSData *)decryptAndCombineBackupEnvelopes:(NSArray<NSData *> *)envelopes
    NS_SWIFT_NAME(decryptAndCombineBackupEnvelopes(_:));

@end

@interface WalletBackupCrypto : NSObject

/// Splits the 215-byte padded mnemonic text `secret` into three XOR shares, then
/// prefixes each share with 08 dd 90 8b d7 and encrypts it in holder order.
/// A distinct ephemeral key is used for each holder.
+ (nullable NSArray<NSData *> *)encryptSecret:(NSData *)secret
                          holderPublicKeys:(NSArray<NSData *> *)holderPublicKeys
                                     error:(NSError * _Nullable * _Nullable)error;
/// Encrypts the shares as bare `ephemeralPublicKey || ciphertext` envelopes
/// for wallet.enableBackup. Requires the same 215-byte padded mnemonic text as
/// encryptSecret:holderPublicKeys:error:.
+ (nullable NSArray<NSData *> *)encryptSecretForBackup:(NSData *)secret
                                      holderPublicKeys:(NSArray<NSData *> *)holderPublicKeys
    NS_SWIFT_NAME(encryptSecretForBackup(_:holderPublicKeys:));

@end

NS_ASSUME_NONNULL_END
