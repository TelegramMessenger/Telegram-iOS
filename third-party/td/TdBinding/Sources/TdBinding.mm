#import <TdBinding/TdBinding.h>

#include <td/e2e/e2e_api.h>

#if DEBUG
static NSString *hexStringFromData(NSData *data) {
    NSMutableString *string = [[NSMutableString alloc] initWithCapacity:data.length * 2];
    for (NSUInteger i = 0; i < data.length; i++) {
        [string appendFormat:@"%02x", ((uint8_t *)data.bytes)[i]];
    }
    return string;
}
#endif

@interface TdKeyPair () {
    tde2e_api::PrivateKeyId _keyId;
    NSData *_publicKey;
}

@end

@implementation TdKeyPair

- (nullable instancetype)initWithKeyId:(int64_t)keyId publicKey:(NSData *)publicKey {
    self = [super init];
    if (self != nil) {
        _keyId = keyId;
        _publicKey = publicKey;
    }
    return self;
}

- (int64_t)keyId {
    return _keyId;
}

- (NSData *)publicKey {
    return _publicKey;
}

+ (nullable instancetype)generate {
    auto privateKey = tde2e_api::key_generate_private_key();
    if (!privateKey.is_ok()) {
        return nil;
    }
    tde2e_api::PrivateKeyId privateKeyId = privateKey.value();
    auto publicKey = tde2e_api::key_to_public_key(privateKeyId);
    if (!publicKey.is_ok()) {
        return nil;
    }
    
    NSData *parsedPublicKey = [[NSData alloc] initWithBytes:publicKey.value().data() length:publicKey.value().size()];
    
    return [[TdKeyPair alloc] initWithKeyId:privateKeyId publicKey:parsedPublicKey];
}

@end

@implementation TdCallParticipant

- (nullable instancetype)initWithInternalId:(NSString *)internalId userId:(int64_t)userId {
    self = [super init];
    if (self != nil) {
        _internalId = internalId;
        _userId = userId;
    }
    return self;
}

@end

@interface TdCall ()

@property (nonatomic, strong) TdKeyPair *keyPair;
@property (nonatomic) int64_t callId;

@end

@implementation TdCall

- (instancetype)initWithId:(int64_t)callId keyPair:(TdKeyPair *)keyPair {
    self = [super init];
    if (self != nil) {
        _callId = callId;
        _keyPair = keyPair;
        
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            #if DEBUG
            tde2e_api::set_log_verbosity_level(4);
            #endif
        });
    }
    return self;
}

- (void)dealloc {
    tde2e_api::call_destroy(_callId);
}

+ (nullable instancetype)makeWithKeyPair:(TdKeyPair *)keyPair userId:(int64_t)userId latestBlock:(NSData *)latestBlock {
    std::string mappedLatestBlock((uint8_t *)latestBlock.bytes, ((uint8_t *)latestBlock.bytes) + latestBlock.length);
    #if DEBUG
    auto describeResult = tde2e_api::call_describe_block(mappedLatestBlock);
    if (describeResult.is_ok()) {
        NSString *utf8String = [[NSString alloc] initWithBytes:describeResult.value().data() length:describeResult.value().size() encoding:NSUTF8StringEncoding];
        if (utf8String) {
            NSLog(@"TdCall.makeWithKeyPair block: %@", utf8String);
        } else {
            NSString *lossyString = [[NSString alloc] initWithData:[NSData dataWithBytes:describeResult.value().data() length:describeResult.value().size()] encoding:NSASCIIStringEncoding];
            if (lossyString) {
                NSLog(@"TdCall.makeWithKeyPair block (lossy conversion): %@", lossyString);
            } else {
                NSLog(@"TdCall.makeWithKeyPair block: [binary data, length: %lu]", (unsigned long)describeResult.value().size());
            }
        }
    } else {
        NSLog(@"TdCall.makeWithKeyPair describe block failed");
    }
    #endif
    
    auto call = tde2e_api::call_create(userId, keyPair.keyId, mappedLatestBlock);
    if (!call.is_ok()) {
        return nil;
    }
    
    return [[TdCall alloc] initWithId:call.value() keyPair: keyPair];
}

- (NSArray<NSData *> *)takeOutgoingBroadcastBlocks {
    NSMutableArray<NSData *> *outboundBroadcastBlocks = [[NSMutableArray alloc] init];
    auto outboundMessages = tde2e_api::call_pull_outbound_messages(_callId);
    if (!outboundMessages.is_ok()) {
        return @[];
    }
    for (const auto &it : outboundMessages.value()) {
        #if DEBUG
        auto describeResult = tde2e_api::call_describe_message(it);
        if (describeResult.is_ok()) {
            NSString *utf8String = [[NSString alloc] initWithBytes:describeResult.value().data() length:describeResult.value().size() encoding:NSUTF8StringEncoding];
            if (utf8String) {
                NSLog(@"TdCall.call_pull_outbound_messages block: %@", utf8String);
            } else {
                NSString *lossyString = [[NSString alloc] initWithData:[NSData dataWithBytes:describeResult.value().data() length:describeResult.value().size()] encoding:NSASCIIStringEncoding];
                if (lossyString) {
                    NSLog(@"TdCall.call_pull_outbound_messages block (lossy conversion): %@", lossyString);
                } else {
                    NSLog(@"TdCall.call_pull_outbound_messages block: [binary data, length: %lu]", (unsigned long)describeResult.value().size());
                }
            }
        } else {
            NSLog(@"TdCall.takeOutgoingBroadcastBlocks call_pull_outbound_messages: describe block failed");
        }
        #endif
        
        NSData *outBlock = [[NSData alloc] initWithBytes:it.data() length:it.size()];
        
        [outboundBroadcastBlocks addObject:outBlock];
    }
    return outboundBroadcastBlocks;
}

- (NSData *)emojiState {
    auto result = tde2e_api::call_get_verification_state(_callId);
    if (!result.is_ok()) {
        return [NSData data];
    }
    auto emojiHash = result.value().emoji_hash;
    if (!emojiHash.has_value()) {
        return [NSData data];
    }
    if (emojiHash.value().empty()) {
        return [NSData data];
    }
    NSData *outEmojiHash = [[NSData alloc] initWithBytes:emojiHash.value().data() length:emojiHash.value().size()];
    return outEmojiHash;
}

- (NSArray<TdCallParticipant *> *)participants {
    auto result = tde2e_api::call_get_state(_callId);
    if (!result.is_ok()) {
        return @[];
    }
    auto state = result.value();
    NSMutableArray<TdCallParticipant *> *participants = [[NSMutableArray alloc] init];
    for (const auto &it : state.participants) {
        NSString *internalId = [[NSString alloc] initWithFormat:@"%lld", it.public_key_id];
        [participants addObject:[[TdCallParticipant alloc] initWithInternalId:internalId userId:it.user_id]];
    }
    return participants;
}

- (NSDictionary<NSNumber *, NSNumber *> *)participantLatencies {
    auto describeResult = tde2e_api::call_describe(_callId);
    if (describeResult.is_ok()) {
        NSString *string = [[NSString alloc] initWithData:[NSData dataWithBytes:describeResult.value().data() length:describeResult.value().size()] encoding:NSASCIIStringEncoding];
        
        NSRegularExpression *pairRe = [NSRegularExpression regularExpressionWithPattern:@"(\\d+):(\\d+\\.\\d+)s" options:0 error:NULL];
        
        NSMutableDictionary<NSNumber*, NSNumber*> *commitTimes = [NSMutableDictionary dictionary];
        NSMutableDictionary<NSNumber*, NSNumber*> *revealTimes = [NSMutableDictionary dictionary];
        
        // split into lines and look for the two lines
        [string enumerateLinesUsingBlock:^(NSString * _Nonnull line, BOOL * _Nonnull stop) {
            if ([line containsString:@"commit ="]) {
                [pairRe enumerateMatchesInString:line options:0 range:NSMakeRange(0, line.length) usingBlock:^(NSTextCheckingResult * _Nullable match, NSMatchingFlags flags, BOOL * _Nonnull stop) {
                    NSString *userIdStr = [line substringWithRange:[match rangeAtIndex:1]];
                    NSString *durStr    = [line substringWithRange:[match rangeAtIndex:2]];
                    NSNumber *uid = @([userIdStr longLongValue]);
                    NSNumber *dur = @([durStr doubleValue]);
                    commitTimes[uid] = dur;
                }];
            }
            else if ([line containsString:@"reveal ="]) {
                [pairRe enumerateMatchesInString:line options:0 range:NSMakeRange(0, line.length) usingBlock:^(NSTextCheckingResult * _Nullable match, NSMatchingFlags flags, BOOL * _Nonnull stop) {
                    NSString *userIdStr = [line substringWithRange:[match rangeAtIndex:1]];
                    NSString *durStr    = [line substringWithRange:[match rangeAtIndex:2]];
                    NSNumber *uid = @([userIdStr longLongValue]);
                    NSNumber *dur = @([durStr doubleValue]);
                    revealTimes[uid] = dur;
                }];
            }
        }];
        
        // build final result = commit+reveal
        NSMutableDictionary<NSNumber*, NSNumber*> *result = [NSMutableDictionary dictionary];
        for (NSNumber *uid in commitTimes) {
            double commit = commitTimes[uid].doubleValue;
            double reveal = revealTimes[uid].doubleValue; // will be 0 if missing
            result[uid] = @(commit + reveal);
        }
        
        return result;
    }
    
    return @{};
}

- (void)applyBlock:(NSData *)block {
    std::string mappedBlock((uint8_t *)block.bytes, ((uint8_t *)block.bytes) + block.length);
    
    #if DEBUG
    auto describeResult = tde2e_api::call_describe_block(mappedBlock);
    if (describeResult.is_ok()) {
        NSString *utf8String = [[NSString alloc] initWithBytes:describeResult.value().data() length:describeResult.value().size() encoding:NSUTF8StringEncoding];
        if (utf8String) {
            NSLog(@"TdCall.applyBlock block: %@", utf8String);
        } else {
            NSString *lossyString = [[NSString alloc] initWithData:[NSData dataWithBytes:describeResult.value().data() length:describeResult.value().size()] encoding:NSASCIIStringEncoding];
            if (lossyString) {
                NSLog(@"TdCall.applyBlock block (lossy conversion): %@", lossyString);
            } else {
                NSLog(@"TdCall.applyBlock block: [binary data, length: %lu]", (unsigned long)describeResult.value().size());
            }
        }
    } else {
        NSLog(@"TdCall.applyBlock block: describe block failed");
    }
    #endif
    
    auto result = tde2e_api::call_apply_block(_callId, mappedBlock);
    if (!result.is_ok()) {
        return;
    }
}

- (void)applyBroadcastBlock:(NSData *)block {
    std::string mappedBlock((uint8_t *)block.bytes, ((uint8_t *)block.bytes) + block.length);
    
    #if DEBUG
    auto describeResult = tde2e_api::call_describe_message(mappedBlock);
    if (describeResult.is_ok()) {
        NSString *utf8String = [[NSString alloc] initWithBytes:describeResult.value().data() length:describeResult.value().size() encoding:NSUTF8StringEncoding];
        if (utf8String) {
            NSLog(@"TdCall.applyBroadcastBlock block: %@", utf8String);
        } else {
            NSString *lossyString = [[NSString alloc] initWithData:[NSData dataWithBytes:describeResult.value().data() length:describeResult.value().size()] encoding:NSASCIIStringEncoding];
            if (lossyString) {
                NSLog(@"TdCall.applyBroadcastBlock block (lossy conversion): %@", lossyString);
            } else {
                NSLog(@"TdCall.applyBroadcastBlock block: [binary data, length: %lu]", (unsigned long)describeResult.value().size());
            }
        }
    } else {
        NSLog(@"TdCall.applyBroadcastBlock block: describe block failed");
    }
    #endif
    
    auto result = tde2e_api::call_receive_inbound_message(_callId, mappedBlock);
    if (!result.is_ok()) {
        return;
    }
    
    #if DEBUG
    describeResult = tde2e_api::call_describe(_callId);
    if (describeResult.is_ok()) {
        NSString *utf8String = [[NSString alloc] initWithBytes:describeResult.value().data() length:describeResult.value().size() encoding:NSUTF8StringEncoding];
        if (utf8String) {
            NSLog(@"TdCall.applyBroadcastBlock call after apply: %@", utf8String);
        } else {
            NSString *lossyString = [[NSString alloc] initWithData:[NSData dataWithBytes:describeResult.value().data() length:describeResult.value().size()] encoding:NSASCIIStringEncoding];
            if (lossyString) {
                NSLog(@"TdCall.applyBroadcastBlock call after apply (lossy conversion): %@", lossyString);
            } else {
                NSLog(@"TdCall.applyBroadcastBlock call after apply: [binary data, length: %lu]", (unsigned long)describeResult.value().size());
            }
        }
    } else {
        NSLog(@"TdCall.applyBroadcastBlock call after apply: describe block failed");
    }
    #endif
}

- (nullable NSData *)generateRemoveParticipantsBlock:(NSArray<NSNumber *> *)participantIds {
    auto stateResult = tde2e_api::call_get_state(_callId);
    if (!stateResult.is_ok()) {
        return nil;
    }
    auto state = stateResult.value();
    for (NSNumber *participantId in participantIds) {
        auto it = std::find_if(state.participants.begin(), state.participants.end(), [participantId](const tde2e_api::CallParticipant &participant) {
            return participant.user_id == [participantId longLongValue];
        });
        if (it != state.participants.end()) {
            state.participants.erase(it);
        }
    }
    
    auto result = tde2e_api::call_create_change_state_block(_callId, state);
    if (!result.is_ok()) {
        return nil;
    }
    return [[NSData alloc] initWithBytes:result.value().data() length:result.value().size()];
}

- (nullable NSData *)encrypt:(NSData *)message channelId:(int32_t)channelId plaintextPrefixLength:(NSInteger)plaintextPrefixLength {
    std::string mappedMessage((uint8_t *)message.bytes, ((uint8_t *)message.bytes) + message.length);
    auto result = tde2e_api::call_encrypt(_callId, channelId, mappedMessage, (size_t)plaintextPrefixLength);
    if (!result.is_ok()) {
        return nil;
    }
    return [[NSData alloc] initWithBytes:result.value().data() length:result.value().size()];
}

- (nullable NSData *)decrypt:(NSData *)message userId:(int64_t)userId {
    std::string mappedMessage((uint8_t *)message.bytes, ((uint8_t *)message.bytes) + message.length);
    auto result = tde2e_api::call_decrypt(_callId, userId, 0, mappedMessage);
    if (!result.is_ok()) {
        return nil;
    }
    return [[NSData alloc] initWithBytes:result.value().data() length:result.value().size()];
}

@end

NSData * _Nullable tdGenerateZeroBlock(TdKeyPair *keyPair, int64_t userId) {
    if (!keyPair) {
        return nil;
    }
    
    std::string mappedPublicKey((uint8_t *)keyPair.publicKey.bytes, ((uint8_t *)keyPair.publicKey.bytes) + keyPair.publicKey.length);
    
    auto publicKeyId = tde2e_api::key_from_public_key(mappedPublicKey);
    if (!publicKeyId.is_ok()) {
        return nil;
    }
    
    tde2e_api::CallParticipant initialParticipant;
    initialParticipant.user_id = userId;
    initialParticipant.public_key_id = publicKeyId.value();
    initialParticipant.permissions = (1 << 0) | (1 << 1);
    
    tde2e_api::CallState initialCallState;
    initialCallState.participants.push_back(std::move(initialParticipant));
    auto zeroBlock = tde2e_api::call_create_zero_block(keyPair.keyId, initialCallState);
    if (!zeroBlock.is_ok()) {
        return nil;
    }
    
    NSData *zeroBlockData = [[NSData alloc] initWithBytes:zeroBlock.value().data() length:zeroBlock.value().size()];
    #if DEBUG
    NSLog(@"Zero block: %@", hexStringFromData(zeroBlockData));
    #endif
    return zeroBlockData;
}

NSData * _Nullable tdGenerateSelfAddBlock(TdKeyPair *keyPair, int64_t userId, NSData *previousBlock) {
    if (!keyPair) {
        return nil;
    }
    
    std::string mappedPublicKey((uint8_t *)keyPair.publicKey.bytes, ((uint8_t *)keyPair.publicKey.bytes) + keyPair.publicKey.length);
    std::string mappedPreviousBlock((uint8_t *)previousBlock.bytes, ((uint8_t *)previousBlock.bytes) + previousBlock.length);
    
    
    #if DEBUG
    auto describeResult = tde2e_api::call_describe_block(mappedPreviousBlock);
    if (describeResult.is_ok()) {
        NSString *utf8String = [[NSString alloc] initWithBytes:describeResult.value().data() length:describeResult.value().size() encoding:NSUTF8StringEncoding];
        if (utf8String) {
            NSLog(@"TdCall.selfAddBlock block: %@", utf8String);
        } else {
            NSString *lossyString = [[NSString alloc] initWithData:[NSData dataWithBytes:describeResult.value().data() length:describeResult.value().size()] encoding:NSASCIIStringEncoding];
            if (lossyString) {
                NSLog(@"TdCall.selfAddBlock block (lossy conversion): %@", lossyString);
            } else {
                NSLog(@"TdCall.selfAddBlock block: [binary data, length: %lu]", (unsigned long)describeResult.value().size());
            }
        }
    } else {
        NSLog(@"TdCall.selfAddBlock describe block failed");
    }
    #endif
    
    auto publicKeyId = tde2e_api::key_from_public_key(mappedPublicKey);
    if (!publicKeyId.is_ok()) {
        return nil;
    }
    
    tde2e_api::CallParticipant myParticipant;
    myParticipant.user_id = userId;
    myParticipant.public_key_id = publicKeyId.value();
    myParticipant.permissions = (1 << 0) | (1 << 1);
    
    auto result = tde2e_api::call_create_self_add_block(keyPair.keyId, mappedPreviousBlock, myParticipant);
    if (!result.is_ok()) {
        return nil;
    }
    
    NSData *resultBlock = [[NSData alloc] initWithBytes:result.value().data() length:result.value().size()];
    #if DEBUG
    NSLog(@"Self add block: %@", hexStringFromData(resultBlock));
    #endif
    return resultBlock;
}
