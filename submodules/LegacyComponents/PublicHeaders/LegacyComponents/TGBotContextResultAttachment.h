#import <LegacyComponents/TGMediaAttachment.h>

#import <LegacyComponents/TGImageInfo.h>
#import <LegacyComponents/TGDocumentMediaAttachment.h>

#define TGBotContextResultAttachmentType ((int)0x1718023f)

@interface TGBotContextResultAttachment : TGMediaAttachment <TGMediaAttachmentParser, NSCoding>

@property (nonatomic, readonly) int32_t userId;
@property (nonatomic, strong, readonly) NSString *resultId;
@property (nonatomic, readonly) int64_t queryId;

- (instancetype)initWithUserId:(int32_t)userId resultId:(NSString *)resultId queryId:(int64_t)queryId;

@end
