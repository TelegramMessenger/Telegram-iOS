#import <LegacyComponents/TGMediaAttachment.h>

#import <LegacyComponents/TGBotReplyMarkup.h>

#define TGReplyMarkupAttachmentType ((int)0x5678acc1)

@interface TGReplyMarkupAttachment : TGMediaAttachment <TGMediaAttachmentParser, NSCoding>

@property (nonatomic, strong) TGBotReplyMarkup *replyMarkup;

- (instancetype)initWithReplyMarkup:(TGBotReplyMarkup *)replyMarkup;

@end
