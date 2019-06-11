

#import <LegacyComponents/TGMediaAttachment.h>

#define TGContactMediaAttachmentType ((int)0xB90A5663)

@interface TGContactMediaAttachment : TGMediaAttachment <TGMediaAttachmentParser, NSCoding>

@property (nonatomic) int uid;
@property (nonatomic, strong) NSString *firstName;
@property (nonatomic, strong) NSString *lastName;
@property (nonatomic, strong) NSString *phoneNumber;
@property (nonatomic, strong) NSString *vcard;

@end
