#import <WalletBackupCrypto/WalletBackupCrypto.h>
#import <Security/Security.h>

#include <td/e2e/e2e_api.h>

#include <array>
#include <cstdint>
#include <string>

NSErrorDomain const WalletBackupCryptoErrorDomain = @"org.telegram.wallet-backup-crypto";

namespace {

constexpr std::uint32_t kObservedEnvelopeWrapperSignature = 0x1ea87158;
constexpr std::size_t kPublicKeyLength = 32;
constexpr std::size_t kShareCount = 3;
constexpr std::size_t kMnemonicBackupSize = 215;
constexpr char kMnemonicBackupPrefix[] = "\x08\xdd\x90\x8b\xd7";
constexpr std::size_t kMnemonicBackupPrefixSize = sizeof(kMnemonicBackupPrefix) - 1;
constexpr std::size_t kMnemonicBackupPayloadSize = kMnemonicBackupPrefixSize + kMnemonicBackupSize;
constexpr std::size_t kObservedEnvelopeWrapperHeaderLength = 16;

NSError *makeError(WalletBackupCryptoErrorCode code, NSString *message) {
    return [NSError errorWithDomain:WalletBackupCryptoErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: message}];
}

void setError(NSError **error, WalletBackupCryptoErrorCode code, NSString *message) {
    if (error != nullptr) {
        *error = makeError(code, message);
    }
}

std::string stringFromData(NSData *data) {
    return std::string(static_cast<const char *>(data.bytes), data.length);
}

NSData *dataFromString(const std::string &value) {
    return [NSData dataWithBytes:value.data() length:value.size()];
}

bool fillSecureRandom(std::string &value) {
    if (value.empty()) {
        return true;
    }
    return SecRandomCopyBytes(
        kSecRandomDefault,
        value.size(),
        reinterpret_cast<std::uint8_t *>(&value[0])
    ) == errSecSuccess;
}

std::uint32_t readLittleEndian32(const char *bytes) {
    const auto *value = reinterpret_cast<const unsigned char *>(bytes);
    return static_cast<std::uint32_t>(value[0])
        | (static_cast<std::uint32_t>(value[1]) << 8)
        | (static_cast<std::uint32_t>(value[2]) << 16)
        | (static_cast<std::uint32_t>(value[3]) << 24);
}

struct EncryptedShareEnvelope {
    std::string publicKey;
    std::string ciphertext;
    std::size_t wrapperLength = 0;
    std::size_t blobLength = 0;
    bool isWrapped = false;
    std::uint32_t wrapperIndex = 0;
    std::uint32_t wrapperCount = 0;
    std::uint32_t wrapperSetId = 0;
};

bool parseTrailingTlBytes(
    const std::string &value,
    std::size_t offset,
    std::string &result
) {
    if (offset >= value.size()) {
        return false;
    }
    const auto *bytes = reinterpret_cast<const unsigned char *>(value.data());
    const unsigned char marker = bytes[offset];
    std::size_t headerLength = 0;
    std::size_t dataLength = 0;
    if (marker < 254) {
        headerLength = 1;
        dataLength = marker;
    } else if (marker == 254) {
        if (value.size() - offset < 4) {
            return false;
        }
        headerLength = 4;
        dataLength = static_cast<std::size_t>(bytes[offset + 1])
            | (static_cast<std::size_t>(bytes[offset + 2]) << 8)
            | (static_cast<std::size_t>(bytes[offset + 3]) << 16);
        if (dataLength < 254) {
            return false;
        }
    } else {
        return false;
    }

    const std::size_t dataOffset = offset + headerLength;
    if (dataLength > value.size() - dataOffset) {
        return false;
    }
    const std::size_t dataEnd = dataOffset + dataLength;
    const std::size_t paddingLength = (4 - ((headerLength + dataLength) % 4)) % 4;
    if (paddingLength > value.size() - dataEnd || dataEnd + paddingLength != value.size()) {
        return false;
    }
    for (std::size_t index = dataEnd; index < value.size(); ++index) {
        if (bytes[index] != 0) {
            return false;
        }
    }
    result.assign(value.data() + dataOffset, dataLength);
    return true;
}

bool extractEncryptedShareEnvelope(
    const std::string &value,
    EncryptedShareEnvelope &result
) {
    std::string blob;
    if (value.size() >= sizeof(std::uint32_t)
        && readLittleEndian32(value.data()) == kObservedEnvelopeWrapperSignature) {
        if (value.size() <= kObservedEnvelopeWrapperHeaderLength
            || !parseTrailingTlBytes(value, kObservedEnvelopeWrapperHeaderLength, blob)) {
            return false;
        }
        result.wrapperLength = value.size();
        result.isWrapped = true;
        result.wrapperIndex = readLittleEndian32(value.data() + 4);
        result.wrapperCount = readLittleEndian32(value.data() + 8);
        result.wrapperSetId = readLittleEndian32(value.data() + 12);
    } else {
        blob = value;
        result.wrapperLength = 0;
    }

    if (blob.size() <= kPublicKeyLength) {
        return false;
    }
    const std::size_t ciphertextLength = blob.size() - kPublicKeyLength;
    if (ciphertextLength == 0 || ciphertextLength % 16 != 0) {
        return false;
    }
    result.blobLength = blob.size();
    result.publicKey = blob.substr(0, kPublicKeyLength);
    result.ciphertext = blob.substr(kPublicKeyLength);
    return true;
}

NSString *tde2eErrorDescription(const tde2e_api::Error &error) {
    NSString *message = [[NSString alloc] initWithBytes:error.message.data()
                                                 length:error.message.size()
                                               encoding:NSUTF8StringEncoding];
    if (message == nil) {
        message = @"Unknown error";
    }
    return [NSString stringWithFormat:@"tde2e(%d): %@", static_cast<int>(error.code), message];
}

bool destroyKey(tde2e_api::AnyKeyId keyId) {
    return tde2e_api::key_destroy(keyId).is_ok();
}

bool encryptShare(const std::string &share, NSData *holderPublicKey, std::string &envelope) {
    if (holderPublicKey.length != kPublicKeyLength) {
        return false;
    }
    auto privateResult = tde2e_api::key_generate_temporary_private_key();
    if (!privateResult.is_ok()) {
        return false;
    }
    const auto privateKeyId = privateResult.value();
    auto publicResult = tde2e_api::key_to_public_key(privateKeyId);
    if (!publicResult.is_ok()) {
        destroyKey(privateKeyId);
        return false;
    }
    const std::string holderKey = stringFromData(holderPublicKey);
    auto holderResult = tde2e_api::key_from_public_key(holderKey);
    if (!holderResult.is_ok()) {
        destroyKey(privateKeyId);
        return false;
    }
    const auto holderKeyId = holderResult.value();
    auto sharedResult = tde2e_api::key_from_ecdh(privateKeyId, holderKeyId);
    if (!sharedResult.is_ok()) {
        destroyKey(holderKeyId);
        destroyKey(privateKeyId);
        return false;
    }
    const auto sharedKeyId = sharedResult.value();
    std::string payload(kMnemonicBackupPrefix, kMnemonicBackupPrefixSize);
    payload.append(share);
    auto encryptedResult = tde2e_api::encrypt_message_for_one(sharedKeyId, payload);
    destroyKey(sharedKeyId);
    destroyKey(holderKeyId);
    destroyKey(privateKeyId);
    if (!encryptedResult.is_ok() || publicResult.value().size() != kPublicKeyLength) {
        return false;
    }
    envelope = publicResult.value();
    envelope.append(encryptedResult.value());
    return true;
}

}

@interface WalletBackupCryptoKeyPair () {
    tde2e_api::PrivateKeyId _privateKeyId;
    NSData *_publicKey;
}
@end

@implementation WalletBackupCryptoKeyPair

+ (nullable instancetype)generate:(NSError **)error {
    auto privateResult = tde2e_api::key_generate_temporary_private_key();
    if (!privateResult.is_ok()) {
        setError(error, WalletBackupCryptoErrorKeyGeneration, @"Could not generate an ephemeral key");
        return nil;
    }
    auto publicResult = tde2e_api::key_to_public_key(privateResult.value());
    if (!publicResult.is_ok() || publicResult.value().size() != kPublicKeyLength) {
        destroyKey(privateResult.value());
        setError(error, WalletBackupCryptoErrorKeyGeneration, @"Could not derive an ephemeral public key");
        return nil;
    }
    WalletBackupCryptoKeyPair *result = [[WalletBackupCryptoKeyPair alloc] init];
    result->_privateKeyId = privateResult.value();
    result->_publicKey = dataFromString(publicResult.value());
    return result;
}

+ (nullable instancetype)generateKeyPair {
    return [self generate:nil];
}

- (NSData *)publicKey {
    return _publicKey;
}

- (void)dealloc {
    if (_privateKeyId != 0) {
        destroyKey(_privateKeyId);
        _privateKeyId = 0;
    }
}

- (nullable NSData *)decryptAndCombineEnvelopes:(NSArray<NSData *> *)envelopes error:(NSError **)error {
    if (envelopes.count != kShareCount || _privateKeyId == 0) {
        setError(error, WalletBackupCryptoErrorInvalidInput, @"Exactly three encrypted shares are required");
        return nil;
    }
    std::array<EncryptedShareEnvelope, kShareCount> extractedEnvelopes;
    std::array<std::size_t, kShareCount> envelopeOrder = {0, 1, 2};
    bool hasWrappedEnvelope = false;
    bool hasBareEnvelope = false;
    for (std::size_t inputIndex = 0; inputIndex < kShareCount; ++inputIndex) {
        NSData *envelopeData = envelopes[inputIndex];
        const std::string envelope = stringFromData(envelopeData);
        if (!extractEncryptedShareEnvelope(envelope, extractedEnvelopes[inputIndex])) {
            setError(
                error,
                WalletBackupCryptoErrorInvalidInput,
                [NSString stringWithFormat:
                    @"Secret share %zu has invalid envelope framing (input=%zu)",
                    inputIndex,
                    envelope.size()]
            );
            return nil;
        }
        if (extractedEnvelopes[inputIndex].isWrapped) {
            hasWrappedEnvelope = true;
        } else {
            hasBareEnvelope = true;
        }
    }
    if (hasWrappedEnvelope && hasBareEnvelope) {
        setError(error, WalletBackupCryptoErrorInvalidInput, @"Wrapped and bare secret shares cannot be mixed");
        return nil;
    }
    if (hasWrappedEnvelope) {
        std::array<bool, kShareCount> seenIndices = {false, false, false};
        const std::uint32_t expectedSetId = extractedEnvelopes[0].wrapperSetId;
        for (std::size_t inputIndex = 0; inputIndex < kShareCount; ++inputIndex) {
            const auto &extractedEnvelope = extractedEnvelopes[inputIndex];
            if (extractedEnvelope.wrapperCount != kShareCount
                || extractedEnvelope.wrapperIndex >= kShareCount
                || extractedEnvelope.wrapperSetId != expectedSetId
                || seenIndices[extractedEnvelope.wrapperIndex]) {
                setError(error, WalletBackupCryptoErrorInvalidInput, @"Encrypted secret shares do not form one complete wrapper set");
                return nil;
            }
            seenIndices[extractedEnvelope.wrapperIndex] = true;
            envelopeOrder[extractedEnvelope.wrapperIndex] = inputIndex;
        }
    }

    std::array<std::string, kShareCount> shares;
    for (std::size_t index = 0; index < kShareCount; ++index) {
        const auto &extractedEnvelope = extractedEnvelopes[envelopeOrder[index]];
        auto publicResult = tde2e_api::key_from_public_key(extractedEnvelope.publicKey);
        if (!publicResult.is_ok()) {
            setError(error, WalletBackupCryptoErrorKeyAgreement, @"An ephemeral public key is invalid");
            return nil;
        }
        const auto publicKeyId = publicResult.value();
        auto sharedResult = tde2e_api::key_from_ecdh(_privateKeyId, publicKeyId);
        destroyKey(publicKeyId);
        if (!sharedResult.is_ok()) {
            setError(error, WalletBackupCryptoErrorKeyAgreement, @"Could not derive a shared secret");
            return nil;
        }
        const auto sharedKeyId = sharedResult.value();
        auto decryptedResult = tde2e_api::decrypt_message_for_one(sharedKeyId, extractedEnvelope.ciphertext);
        destroyKey(sharedKeyId);
        if (!decryptedResult.is_ok()) {
            setError(
                error,
                WalletBackupCryptoErrorDecryption,
                [NSString stringWithFormat:
                    @"Could not decrypt secret share %zu (wrapper=%zu, blob=%zu, ciphertext=%zu): %@",
                    index,
                    extractedEnvelope.wrapperLength,
                    extractedEnvelope.blobLength,
                    extractedEnvelope.ciphertext.size(),
                    tde2eErrorDescription(decryptedResult.error())]
            );
            return nil;
        }
        if (decryptedResult.value().size() != kMnemonicBackupPayloadSize) {
            setError(error, WalletBackupCryptoErrorInvalidPayload, @"A decrypted share payload must be 220 bytes");
            return nil;
        }
        shares[index] = decryptedResult.value();
    }
    // XORing the complete payloads preserves the prefix: H XOR H XOR H = H.
    // This also reads interim backups that split the prefixed mnemonic block.
    std::string secret(kMnemonicBackupPayloadSize, '\0');
    for (std::size_t index = 0; index < secret.size(); ++index) {
        secret[index] = shares[0][index] ^ shares[1][index] ^ shares[2][index];
    }
    if (secret.compare(0, kMnemonicBackupPrefixSize, kMnemonicBackupPrefix, kMnemonicBackupPrefixSize) != 0) {
        setError(error, WalletBackupCryptoErrorInvalidPayload, @"The reconstructed mnemonic has an invalid prefix");
        return nil;
    }
    return dataFromString(secret.substr(kMnemonicBackupPrefixSize));
}

- (nullable NSData *)decryptAndCombineBackupEnvelopes:(NSArray<NSData *> *)envelopes {
    NSError *error = nil;
    NSData *result = [self decryptAndCombineEnvelopes:envelopes error:&error];
#if DEBUG
    if (result == nil && error != nil) {
        NSLog(@"Wallet backup decryption failed: %@", error.localizedDescription);
    }
#endif
    return result;
}

@end

@implementation WalletBackupCrypto

+ (nullable NSArray<NSData *> *)encryptSecret:(NSData *)secret
                          holderPublicKeys:(NSArray<NSData *> *)holderPublicKeys
                                     error:(NSError **)error {
    if (secret.length != kMnemonicBackupSize || holderPublicKeys.count != kShareCount) {
        setError(error, WalletBackupCryptoErrorInvalidInput, @"A 215-byte mnemonic text and exactly three holders are required");
        return nil;
    }
    for (NSData *publicKey in holderPublicKeys) {
        if (publicKey.length != kPublicKeyLength) {
            setError(error, WalletBackupCryptoErrorInvalidInput, @"A holder public key must be 32 bytes");
            return nil;
        }
    }
    const std::string value = stringFromData(secret);
    std::array<std::string, kShareCount> shares = {
        std::string(value.size(), '\0'),
        std::string(value.size(), '\0'),
        std::string(value.size(), '\0')
    };
    if (!fillSecureRandom(shares[0]) || !fillSecureRandom(shares[1])) {
        setError(error, WalletBackupCryptoErrorEncryption, @"Could not generate random secret shares");
        return nil;
    }
    for (std::size_t index = 0; index < value.size(); ++index) {
        shares[2][index] = value[index] ^ shares[0][index] ^ shares[1][index];
    }
    NSMutableArray<NSData *> *result = [[NSMutableArray alloc] initWithCapacity:kShareCount];
    for (std::size_t index = 0; index < kShareCount; ++index) {
        std::string envelope;
        if (!encryptShare(shares[index], holderPublicKeys[index], envelope)) {
            setError(error, WalletBackupCryptoErrorEncryption, @"Could not encrypt a secret share");
            return nil;
        }
        [result addObject:dataFromString(envelope)];
    }
    return result;
}

+ (nullable NSArray<NSData *> *)encryptSecretForBackup:(NSData *)secret
                                      holderPublicKeys:(NSArray<NSData *> *)holderPublicKeys {
    return [self encryptSecret:secret holderPublicKeys:holderPublicKeys error:nil];
}

@end
