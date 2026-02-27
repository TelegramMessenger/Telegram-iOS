

#import <Foundation/Foundation.h>

@interface MTOutgoingMessage : NSObject

@property (nonatomic, strong, readonly) id internalId;
@property (nonatomic, strong, readonly) NSData *data;
@property (nonatomic, strong, readonly) id metadata;
@property (nonatomic, strong, readonly) NSString *additionalDebugDescription;
@property (nonatomic, strong, readonly) id shortMetadata;
@property (nonatomic, readonly) int64_t messageId;
@property (nonatomic, readonly) int32_t messageSeqNo;
@property (nonatomic) bool requiresConfirmation;
@property (nonatomic) bool needsQuickAck;
@property (nonatomic) bool hasHighPriority;
@property (nonatomic) int64_t inResponseToMessageId;

@property (nonatomic, copy) id (^dynamicDecorator)(int64_t, NSData *currentData, NSMutableDictionary *messageInternalIdToPreparedMessage);

- (instancetype)initWithData:(NSData *)data metadata:(id)metadata additionalDebugDescription:(NSString *)additionalDebugDescription shortMetadata:(id)shortMetadata;
- (instancetype)initWithData:(NSData *)data metadata:(id)metadata additionalDebugDescription:(NSString *)additionalDebugDescription shortMetadata:(id)shortMetadata messageId:(int64_t)messageId messageSeqNo:(int32_t)messageSeqNo;

@end
