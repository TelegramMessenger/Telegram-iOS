#import <SSignalKit/SSignalKit.h>

@class TGBridgeMediaAttachment;

@interface TGBridgeAudioSignals : NSObject

+ (SSignal *)audioForAttachment:(TGBridgeMediaAttachment *)attachment conversationId:(int64_t)conversationId messageId:(int32_t)messageId;

+ (SSignal *)sentAudioForConversationId:(int64_t)conversationId;

@end
