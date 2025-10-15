#import <LegacyComponents/TGMediaAttachment.h>

#define TGViaUserAttachmentType ((int)0xA3F4C8F5)

@interface TGViaUserAttachment : TGMediaAttachment <TGMediaAttachmentParser, NSCoding>

@property (nonatomic, readonly) int32_t userId;
@property (nonatomic, readonly) NSString *username;

- (instancetype)initWithUserId:(int32_t)userId username:(NSString *)username;

@end
