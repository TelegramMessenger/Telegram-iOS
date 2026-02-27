#ifndef TDBINDING_H
#define TDBINDING_H

#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

NS_ASSUME_NONNULL_BEGIN

@interface TdKeyPair : NSObject

@property (nonatomic, readonly) int64_t keyId;
@property (nonatomic, strong, readonly) NSData *publicKey;

- (nullable instancetype)initWithKeyId:(int64_t)keyId publicKey:(NSData *)publicKey;

+ (nullable instancetype)generate;

@end

@interface TdCallParticipant : NSObject

@property (nonatomic, strong, readonly) NSString *internalId;
@property (nonatomic, readonly) int64_t userId;

- (nullable instancetype)initWithInternalId:(NSString *)internalId userId:(int64_t)userId;

@end

@interface TdCall : NSObject

+ (nullable instancetype)makeWithKeyPair:(TdKeyPair *)keyPair userId:(int64_t)userId latestBlock:(NSData *)latestBlock;

- (NSArray<NSData *> *)takeOutgoingBroadcastBlocks;
- (NSData *)emojiState;
- (NSArray<TdCallParticipant *> *)participants;

- (NSDictionary<NSNumber *, NSNumber *> *)participantLatencies;

- (bool)applyBlock:(NSData *)block;
- (void)applyBroadcastBlock:(NSData *)block;

- (nullable NSData *)generateRemoveParticipantsBlock:(NSArray<NSNumber *> *)participantIds;

- (nullable NSData *)encrypt:(NSData *)message channelId:(int32_t)channelId plaintextPrefixLength:(NSInteger)plaintextPrefixLength;
- (nullable NSData *)decrypt:(NSData *)message userId:(int64_t)userId;

@end

NSData * _Nullable tdGenerateZeroBlock(TdKeyPair *keyPair, int64_t userId);
NSData * _Nullable tdGenerateSelfAddBlock(TdKeyPair *keyPair, int64_t userId, NSData *previousBlock);

NS_ASSUME_NONNULL_END

#ifdef __cplusplus
}
#endif

#endif
