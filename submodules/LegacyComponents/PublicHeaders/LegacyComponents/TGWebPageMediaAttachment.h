#import <LegacyComponents/TGMediaAttachment.h>

#import <LegacyComponents/TGImageInfo.h>
#import <LegacyComponents/TGImageMediaAttachment.h>
#import <LegacyComponents/TGDocumentMediaAttachment.h>

#import <LegacyComponents/TGInstantPage.h>

#define TGWebPageMediaAttachmentType ((int)0x584197af)

@interface TGWebPageMediaAttachment : TGMediaAttachment <TGMediaAttachmentParser, NSCoding>

@property (nonatomic) int64_t webPageId;
@property (nonatomic) int64_t webPageLocalId;
@property (nonatomic) int32_t pendingDate;
@property (nonatomic) int32_t webPageHash;

@property (nonatomic, strong) NSString *url;
@property (nonatomic, strong) NSString *displayUrl;
@property (nonatomic, strong) NSString *pageType;
@property (nonatomic, strong) NSString *siteName;
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *pageDescription;
@property (nonatomic, strong) NSArray *pageDescriptionEntities;
@property (nonatomic, strong) TGImageMediaAttachment *photo;
@property (nonatomic, strong) NSString *embedUrl;
@property (nonatomic, strong) NSString *embedType;
@property (nonatomic) CGSize embedSize;
@property (nonatomic, strong) NSNumber *duration;
@property (nonatomic, strong) NSString *author;
@property (nonatomic, strong) TGDocumentMediaAttachment *document;
@property (nonatomic, strong) TGInstantPage *instantPage;

@end
