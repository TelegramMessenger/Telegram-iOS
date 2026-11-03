

#import <LegacyComponents/TGMediaAttachment.h>

#define TGUnsupportedMediaAttachmentType ((int)0x3837BEF7)

@interface TGUnsupportedMediaAttachment : TGMediaAttachment <TGMediaAttachmentParser>

@property (nonatomic, strong) NSData *data;

@end
