#import <LegacyComponents/TGMediaAttachment.h>

@class TGImageMediaAttachment;
@class TGDocumentMediaAttachment;
@class TGWebPageMediaAttachment;

#define TGGameAttachmentType ((int)0x57af081e)

@interface TGGameMediaAttachment : TGMediaAttachment <TGMediaAttachmentParser, NSCoding>

@property (nonatomic, readonly) int64_t gameId;
@property (nonatomic, readonly) int64_t accessHash;
@property (nonatomic, strong, readonly) NSString *shortName;
@property (nonatomic, strong, readonly) NSString *title;
@property (nonatomic, strong, readonly) NSString *gameDescription;
@property (nonatomic, strong, readonly) TGImageMediaAttachment *photo;
@property (nonatomic, strong, readonly) TGDocumentMediaAttachment *document;

- (instancetype)initWithGameId:(int64_t)gameId accessHash:(int64_t)accessHash shortName:(NSString *)shortName title:(NSString *)title gameDescription:(NSString *)gameDescription photo:(TGImageMediaAttachment *)photo document:(TGDocumentMediaAttachment *)document;

- (TGWebPageMediaAttachment *)webPageWithText:(NSString *)text entities:(NSArray *)entities;

@end
