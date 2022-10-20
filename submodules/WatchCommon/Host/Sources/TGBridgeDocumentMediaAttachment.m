#import "TGBridgeDocumentMediaAttachment.h"

const NSInteger TGBridgeDocumentMediaAttachmentType = 0xE6C64318;

NSString *const TGBridgeDocumentMediaDocumentIdKey = @"documentId";
NSString *const TGBridgeDocumentMediaLocalDocumentIdKey = @"localDocumentId";
NSString *const TGBridgeDocumentMediaFileSizeKey = @"fileSize";
NSString *const TGBridgeDocumentMediaFileNameKey = @"fileName";
NSString *const TGBridgeDocumentMediaImageSizeKey = @"imageSize";
NSString *const TGBridgeDocumentMediaAnimatedKey = @"animated";
NSString *const TGBridgeDocumentMediaStickerKey = @"sticker";
NSString *const TGBridgeDocumentMediaStickerAltKey = @"stickerAlt";
NSString *const TGBridgeDocumentMediaStickerPackIdKey = @"stickerPackId";
NSString *const TGBridgeDocumentMediaStickerPackAccessHashKey = @"stickerPackAccessHash";
NSString *const TGBridgeDocumentMediaAudioKey = @"audio";
NSString *const TGBridgeDocumentMediaAudioTitleKey = @"title";
NSString *const TGBridgeDocumentMediaAudioPerformerKey = @"performer";
NSString *const TGBridgeDocumentMediaAudioVoice = @"voice";
NSString *const TGBridgeDocumentMediaAudioDuration = @"duration";

@implementation TGBridgeDocumentMediaAttachment

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self != nil)
    {
        _documentId = [aDecoder decodeInt64ForKey:TGBridgeDocumentMediaDocumentIdKey];
        _localDocumentId = [aDecoder decodeInt64ForKey:TGBridgeDocumentMediaLocalDocumentIdKey];
        _fileSize = [aDecoder decodeInt32ForKey:TGBridgeDocumentMediaFileSizeKey];
        _fileName = [aDecoder decodeObjectForKey:TGBridgeDocumentMediaFileNameKey];
        _imageSize = [aDecoder decodeObjectForKey:TGBridgeDocumentMediaImageSizeKey];
        _isAnimated = [aDecoder decodeBoolForKey:TGBridgeDocumentMediaAnimatedKey];
        _isSticker = [aDecoder decodeBoolForKey:TGBridgeDocumentMediaStickerKey];
        _stickerAlt = [aDecoder decodeObjectForKey:TGBridgeDocumentMediaStickerAltKey];
        _stickerPackId = [aDecoder decodeInt64ForKey:TGBridgeDocumentMediaStickerPackIdKey];
        _stickerPackAccessHash = [aDecoder decodeInt64ForKey:TGBridgeDocumentMediaStickerPackAccessHashKey];
        _isAudio = [aDecoder decodeBoolForKey:TGBridgeDocumentMediaAudioKey];
        _title = [aDecoder decodeObjectForKey:TGBridgeDocumentMediaAudioTitleKey];
        _performer = [aDecoder decodeObjectForKey:TGBridgeDocumentMediaAudioPerformerKey];
        _isVoice = [aDecoder decodeBoolForKey:TGBridgeDocumentMediaAudioVoice];
        _duration = [aDecoder decodeInt32ForKey:TGBridgeDocumentMediaAudioDuration];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInt64:self.documentId forKey:TGBridgeDocumentMediaDocumentIdKey];
    [aCoder encodeInt64:self.localDocumentId forKey:TGBridgeDocumentMediaLocalDocumentIdKey];
    [aCoder encodeInt32:self.fileSize forKey:TGBridgeDocumentMediaFileSizeKey];
    [aCoder encodeObject:self.fileName forKey:TGBridgeDocumentMediaFileNameKey];
    [aCoder encodeObject:self.imageSize forKey:TGBridgeDocumentMediaImageSizeKey];
    [aCoder encodeBool:self.isAnimated forKey:TGBridgeDocumentMediaAnimatedKey];
    [aCoder encodeBool:self.isSticker forKey:TGBridgeDocumentMediaStickerKey];
    [aCoder encodeObject:self.stickerAlt forKey:TGBridgeDocumentMediaStickerAltKey];
    [aCoder encodeInt64:self.stickerPackId forKey:TGBridgeDocumentMediaStickerPackIdKey];
    [aCoder encodeInt64:self.stickerPackAccessHash forKey:TGBridgeDocumentMediaStickerPackAccessHashKey];
    [aCoder encodeBool:self.isAudio forKey:TGBridgeDocumentMediaAudioKey];
    [aCoder encodeObject:self.title forKey:TGBridgeDocumentMediaAudioTitleKey];
    [aCoder encodeObject:self.performer forKey:TGBridgeDocumentMediaAudioPerformerKey];
    [aCoder encodeBool:self.isVoice forKey:TGBridgeDocumentMediaAudioVoice];
    [aCoder encodeInt32:self.duration forKey:TGBridgeDocumentMediaAudioDuration];
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    
    if (!object || ![object isKindOfClass:[self class]])
        return NO;
    
    TGBridgeDocumentMediaAttachment *document = (TGBridgeDocumentMediaAttachment *)object;
    
    return (self.localDocumentId == 0 && self.documentId == document.documentId) || (self.localDocumentId != 0 && self.localDocumentId == document.localDocumentId);
}

+ (NSInteger)mediaType
{
    return TGBridgeDocumentMediaAttachmentType;
}

@end
