#import <LegacyComponents/TGMediaAttachment.h>

@class TGMessage;

#define TGReplyMessageMediaAttachmentType ((int)414002169)

@interface TGReplyMessageMediaAttachment : TGMediaAttachment <NSCopying, TGMediaAttachmentParser>

@property (nonatomic) int32_t replyMessageId;
@property (nonatomic, strong) TGMessage *replyMessage;

@end
