#import <LegacyComponents/TGMediaAttachment.h>

@class TGImageMediaAttachment;
@class TGDocumentMediaAttachment;
@class TGWebPageMediaAttachment;

#define TGAuthorSignatureMediaAttachmentType ((int)0x157b8516)

@interface TGAuthorSignatureMediaAttachment : TGMediaAttachment <TGMediaAttachmentParser, NSCoding>

@property (nonatomic, strong, readonly) NSString *signature;

- (instancetype)initWithSignature:(NSString *)signature;

@end
