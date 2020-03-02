

#import <LegacyComponents/TGMediaAttachment.h>

#define TGLocalMessageMetaMediaAttachmentType 0x944DE6B6

@interface TGLocalMessageMetaMediaAttachment : TGMediaAttachment <TGMediaAttachmentParser>

@property (nonatomic, strong) NSMutableArray *imageInfoList;
@property (nonatomic, strong) NSMutableDictionary *imageUrlToDataFile;
@property (nonatomic) int localMediaId;

@end
