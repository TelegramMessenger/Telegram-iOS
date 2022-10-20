

#import <LegacyComponents/TGMediaAttachment.h>

#define TGForwardedMessageMediaAttachmentType ((int)0xAA1050C1)

@interface TGForwardedMessageMediaAttachment : TGMediaAttachment <NSCopying, TGMediaAttachmentParser>

@property (nonatomic) int64_t forwardSourcePeerId;

@property (nonatomic) int64_t forwardPeerId;
@property (nonatomic) int forwardDate;

@property (nonatomic) int32_t forwardAuthorUserId;
@property (nonatomic) int32_t forwardPostId;

@property (nonatomic) NSString *forwardAuthorSignature;

@property (nonatomic) int forwardMid;

@end
