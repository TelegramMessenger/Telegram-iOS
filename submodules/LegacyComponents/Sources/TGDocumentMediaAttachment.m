#import "TGDocumentMediaAttachment.h"

#import "LegacyComponentsInternal.h"

#import "PSCoding.h"
#import "PSKeyValueEncoder.h"
#import "PSKeyValueDecoder.h"

#import "TGMessage.h"

@interface TGDocumentMediaAttachment () {
    NSArray *_textCheckingResults;
}

@end

@implementation TGDocumentMediaAttachment

- (id)init
{
    self = [super init];
    if (self != nil)
    {
        self.type = TGDocumentMediaAttachmentType;
    }
    return self;
}

- (instancetype)copyWithZone:(NSZone *)__unused zone {
    TGDocumentMediaAttachment *document = [[TGDocumentMediaAttachment alloc] init];
    
    document->_documentId = _documentId;
    document->_localDocumentId = _localDocumentId;
    document->_accessHash = _accessHash;
    document->_datacenterId = _datacenterId;
    document->_userId = _userId;
    document->_date = _date;
    document->_mimeType = _mimeType;
    document->_size = _size;
    document->_thumbnailInfo = _thumbnailInfo;
    document->_documentUri = _documentUri;
    document->_attributes = _attributes;
    document->_caption = _caption;
    document->_textCheckingResults = _textCheckingResults;
    document->_version = _version;
    document->_originInfo = _originInfo;
    
    return document;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self != nil)
    {
        self.type = TGDocumentMediaAttachmentType;
        
        _documentId = [aDecoder decodeInt64ForKey:@"documentId"];
        _localDocumentId = [aDecoder decodeInt64ForKey:@"localDocumentId"];
        _accessHash = [aDecoder decodeInt64ForKey:@"accessHash"];
        _datacenterId = [aDecoder decodeInt32ForKey:@"datacenterId"];
        _userId = [aDecoder decodeInt32ForKey:@"userId"];
        _date = [aDecoder decodeInt32ForKey:@"date"];
        _mimeType = [aDecoder decodeObjectForKey:@"mimeType"];
        _size = [aDecoder decodeInt32ForKey:@"size"];
        _thumbnailInfo = [aDecoder decodeObjectForKey:@"thumbnailInfo"];
        _documentUri = [aDecoder decodeObjectForKey:@"documentUri"];
        _attributes = [aDecoder decodeObjectForKey:@"attributes"];
        _caption = [aDecoder decodeObjectForKey:@"caption"];
        _version = [aDecoder decodeInt32ForKey:@"version"];
        _originInfo = [aDecoder decodeObjectForKey:@"origin"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInt64:_documentId forKey:@"documentId"];
    [aCoder encodeInt64:_localDocumentId forKey:@"localDocumentId"];
    [aCoder encodeInt64:_accessHash forKey:@"accessHash"];
    [aCoder encodeInt32:_datacenterId forKey:@"datacenterId"];
    [aCoder encodeInt32:_userId forKey:@"userId"];
    [aCoder encodeInt32:_date forKey:@"date"];
    [aCoder encodeInt32:_version forKey:@"version"];
    if (_mimeType != nil)
        [aCoder encodeObject:_mimeType forKey:@"mimeType"];
    [aCoder encodeInt32:_size forKey:@"size"];
    if (_thumbnailInfo != nil)
        [aCoder encodeObject:_thumbnailInfo forKey:@"thumbnailInfo"];
    if (_documentUri != nil)
        [aCoder encodeObject:_documentUri forKey:@"documentUri"];
    if (_attributes != nil)
        [aCoder encodeObject:_attributes forKey:@"attributes"];
    if (_caption != nil)
        [aCoder encodeObject:_caption forKey:@"caption"];
    if (_originInfo != nil)
        [aCoder encodeObject:_originInfo forKey:@"origin"];
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return true;
    
    if (![object isKindOfClass:[TGDocumentMediaAttachment class]])
        return false;
    
    TGDocumentMediaAttachment *other = object;
    if (_documentId == other->_documentId && _localDocumentId == other->_localDocumentId && _accessHash == other->_accessHash && _datacenterId == other->_datacenterId && _userId == other->_userId && _date == other->_date && TGObjectCompare(_mimeType, other->_mimeType) && _size == other->_size && TGObjectCompare(_thumbnailInfo, other->_thumbnailInfo) && TGObjectCompare(_documentUri, other->_documentUri) && TGObjectCompare(_attributes, other->_attributes) && TGStringCompare(_caption, other->_caption) && _version == other->_version)
        return true;
    return false;
}

- (void)serialize:(NSMutableData *)data
{
    int dataLengthPtr = (int)data.length;
    int zero = 0;
    [data appendBytes:&zero length:4];
    
    uint8_t version = 7;
    [data appendBytes:&version length:sizeof(version)];
    
    [data appendBytes:&_localDocumentId length:sizeof(_localDocumentId)];
    
    [data appendBytes:&_documentId length:sizeof(_documentId)];
    [data appendBytes:&_accessHash length:sizeof(_accessHash)];
    [data appendBytes:&_datacenterId length:sizeof(_datacenterId)];
    [data appendBytes:&_userId length:sizeof(_userId)];
    [data appendBytes:&_date length:sizeof(_date)];
    
    NSData *filenameData = [[self fileName] dataUsingEncoding:NSUTF8StringEncoding];
    int filenameLength = (int)filenameData.length;
    [data appendBytes:&filenameLength length:sizeof(filenameLength)];
    [data appendData:filenameData];
    
    NSData *mimeData = [_mimeType dataUsingEncoding:NSUTF8StringEncoding];
    int mimeLength = (int)mimeData.length;
    [data appendBytes:&mimeLength length:sizeof(mimeLength)];
    [data appendData:mimeData];
    
    [data appendBytes:&_size length:sizeof(_size)];
    
    uint8_t thumbnailExists = _thumbnailInfo != nil;
    [data appendBytes:&thumbnailExists length:sizeof(thumbnailExists)];
    [_thumbnailInfo serialize:data];
    
    NSData *uriData = [_documentUri dataUsingEncoding:NSUTF8StringEncoding];
    int uriLength = (int)uriData.length;
    [data appendBytes:&uriLength length:sizeof(uriLength)];
    if (uriData != nil)
        [data appendData:uriData];
    
    PSKeyValueEncoder *encoder = [[PSKeyValueEncoder alloc] init];
    [encoder encodeArray:_attributes forCKey:"attributes"];
    int32_t attributesLength = (int32_t)encoder.data.length;
    [data appendBytes:&attributesLength length:4];
    [data appendData:encoder.data];
    
    NSData *captionData = [_caption dataUsingEncoding:NSUTF8StringEncoding];
    int32_t captionLength = (int)captionData.length;
    [data appendBytes:&captionLength length:sizeof(captionLength)];
    if (captionData != nil) {
        [data appendData:captionData];
    }
    
    [data appendBytes:&_version length:4];
    
    NSData *originData = nil;
    @try {
        originData = [NSKeyedArchiver archivedDataWithRootObject:_originInfo];
    } @catch (NSException *e) {
        
    }
    int32_t originLength = (int)originData.length;
    [data appendBytes:&originLength length:sizeof(originLength)];
    if (originData != nil) {
        [data appendData:originData];
    }

    int dataLength = (int)(data.length - dataLengthPtr - 4);
    [data replaceBytesInRange:NSMakeRange(dataLengthPtr, 4) withBytes:&dataLength];
}

- (TGMediaAttachment *)parseMediaAttachment:(NSInputStream *)is
{
    int dataLength = 0;
    [is read:(uint8_t *)&dataLength maxLength:4];
    
    uint8_t version = 0;
    [is read:&version maxLength:sizeof(version)];
    if (version != 1 && version != 2 && version != 3 && version != 4 && version != 5 && version != 6 && version != 7)
    {
        TGLegacyLog(@"***** Document serialized version mismatch");
        return nil;
    }
    
    TGDocumentMediaAttachment *documentAttachment = [[TGDocumentMediaAttachment alloc] init];
    
    if (version >= 2)
        [is read:(uint8_t *)&documentAttachment->_localDocumentId maxLength:sizeof(documentAttachment->_localDocumentId)];
    
    [is read:(uint8_t *)&documentAttachment->_documentId maxLength:sizeof(documentAttachment->_documentId)];
    [is read:(uint8_t *)&documentAttachment->_accessHash maxLength:sizeof(documentAttachment->_accessHash)];
    [is read:(uint8_t *)&documentAttachment->_datacenterId maxLength:sizeof(documentAttachment->_datacenterId)];
    [is read:(uint8_t *)&documentAttachment->_userId maxLength:sizeof(documentAttachment->_userId)];
    [is read:(uint8_t *)&documentAttachment->_date maxLength:sizeof(documentAttachment->_date)];
    
    NSString *legacyFileName = @"file";
    int filenameLength = 0;
    [is read:(uint8_t *)&filenameLength maxLength:sizeof(filenameLength)];
    if (filenameLength != 0)
    {
        uint8_t *filenameBytes = malloc(filenameLength);
        [is read:filenameBytes maxLength:filenameLength];
        legacyFileName = [[NSString alloc] initWithBytesNoCopy:filenameBytes length:filenameLength encoding:NSUTF8StringEncoding freeWhenDone:true];
    }

    int mimeLength = 0;
    [is read:(uint8_t *)&mimeLength maxLength:sizeof(mimeLength)];
    if (mimeLength != 0)
    {
        uint8_t *mimeBytes = malloc(mimeLength);
        [is read:mimeBytes maxLength:mimeLength];
        documentAttachment.mimeType = [[NSString alloc] initWithBytesNoCopy:mimeBytes length:mimeLength encoding:NSUTF8StringEncoding freeWhenDone:true];
    }
    
    [is read:(uint8_t *)&documentAttachment->_size maxLength:sizeof(documentAttachment->_size)];
    
    uint8_t thumbnailExists = 0;
    [is read:&thumbnailExists maxLength:sizeof(thumbnailExists)];
    if (thumbnailExists)
    {
        documentAttachment.thumbnailInfo = [TGImageInfo deserialize:is];
    }
    
    if (version >= 3)
    {
        int uriLength = 0;
        [is read:(uint8_t *)&uriLength maxLength:sizeof(uriLength)];
        if (uriLength > 0)
        {
            uint8_t *uriBytes = malloc(uriLength);
            [is read:uriBytes maxLength:uriLength];
            documentAttachment.documentUri = [[NSString alloc] initWithBytesNoCopy:uriBytes length:uriLength encoding:NSUTF8StringEncoding freeWhenDone:true];
        }
    }
    
    if (version >= 4)
    {
        int32_t attributesSize = 0;
        [is read:(uint8_t *)&attributesSize maxLength:4];
        if (attributesSize > 0)
        {
            uint8_t *attributeBytes = malloc(attributesSize);
            [is read:attributeBytes maxLength:attributesSize];
            NSData *data = [[NSData alloc] initWithBytesNoCopy:attributeBytes length:attributesSize freeWhenDone:true];
            PSKeyValueDecoder *decoder = [[PSKeyValueDecoder alloc] initWithData:data];
            documentAttachment.attributes = [decoder decodeArrayForCKey:"attributes"];
        }
    }
    
    if (version >= 5) {
        int32_t captionLength = 0;
        [is read:(uint8_t *)&captionLength maxLength:sizeof(captionLength)];
        if (captionLength > 0)
        {
            uint8_t *captionBytes = malloc(captionLength);
            [is read:captionBytes maxLength:captionLength];
            documentAttachment.caption = [[NSString alloc] initWithBytesNoCopy:captionBytes length:captionLength encoding:NSUTF8StringEncoding freeWhenDone:true];
        }
    }
    
    if (version >= 6) {
        int32_t fileVersion = 0;
        [is read:(uint8_t *)&fileVersion maxLength:4];
        documentAttachment.version = fileVersion;
    }
    
    if (version >= 7) {
        int32_t originLength = 0;
        [is read:(uint8_t *)&originLength maxLength:sizeof(originLength)];
        if (originLength > 0)
        {
            uint8_t *originBytes = malloc(originLength);
            [is read:originBytes maxLength:originLength];
            NSData *data = [[NSData alloc] initWithBytesNoCopy:originBytes length:originLength freeWhenDone:true];
            TGMediaOriginInfo *origin = nil;
            @try {
                origin = [NSKeyedUnarchiver unarchiveObjectWithData:data];
            } @catch (NSException *e) {
                
            }
            documentAttachment.originInfo = origin;
        }
    }
    
    bool hasFilenameAttribute = false;
    for (id attribute in documentAttachment.attributes)
    {
        if ([attribute isKindOfClass:[TGDocumentAttributeFilename class]])
        {
            hasFilenameAttribute = true;
            break;
        }
    }
    
    if (!hasFilenameAttribute)
    {
        NSMutableArray *array = [[NSMutableArray alloc] initWithArray:documentAttachment.attributes];
        [array addObject:[[TGDocumentAttributeFilename alloc] initWithFilename:legacyFileName]];
        documentAttachment.attributes = array;
    }
    
    return documentAttachment;
}

- (NSString *)fileName
{
    NSString *fileName = @"file";
    for (id attribute in _attributes)
    {
        if ([attribute isKindOfClass:[TGDocumentAttributeFilename class]])
        {
            fileName = ((TGDocumentAttributeFilename *)attribute).filename;
            break;
        }
    }
    
    return fileName;
}

- (NSString *)safeFileName
{
    return [TGDocumentMediaAttachment safeFileNameForFileName:[self fileName]];
}

+ (NSString *)safeFileNameForFileName:(NSString *)fileName
{
    if (fileName.length == 0)
        return @"file";
    
    return [fileName stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
}

- (bool)isAnimated {
    for (id attribute in _attributes) {
        if ([attribute isKindOfClass:[TGDocumentAttributeAnimated class]]) {
            return true;
        }
    }
    
    return false;
}


- (bool)isSticker {
    for (id attribute in _attributes) {
        if ([attribute isKindOfClass:[TGDocumentAttributeSticker class]]) {
            return true;
        }
    }
    
    return false;
}

- (bool)isStickerWithPack {
    for (id attribute in _attributes) {
        if ([attribute isKindOfClass:[TGDocumentAttributeSticker class]]) {
            return ((TGDocumentAttributeSticker *)attribute).packReference != nil;
        }
    }
    
    return false;
}

- (id<TGStickerPackReference>)stickerPackReference {
    for (id attribute in _attributes) {
        if ([attribute isKindOfClass:[TGDocumentAttributeSticker class]]) {
            return ((TGDocumentAttributeSticker *)attribute).packReference;
        }
    }
    return nil;
}

- (bool)isVoice {
    for (id attribute in _attributes) {
        if ([attribute isKindOfClass:[TGDocumentAttributeAudio class]]) {
            TGDocumentAttributeAudio *audio = attribute;
            if (audio.isVoice) {
                return true;
            }
        }
    }

    return false;
}

- (bool)isRoundVideo {
    for (id attribute in _attributes) {
        if ([attribute isKindOfClass:[TGDocumentAttributeVideo class]]) {
            TGDocumentAttributeVideo *video = attribute;
            if (video.isRoundMessage) {
                return true;
            }
        }
    }
    
    return false;
}

- (CGSize)pictureSize {
    for (id attribute in _attributes) {
        if ([attribute isKindOfClass:[TGDocumentAttributeImageSize class]]) {
            return ((TGDocumentAttributeImageSize *)attribute).size;
        } else if ([attribute isKindOfClass:[TGDocumentAttributeVideo class]]) {
            return ((TGDocumentAttributeVideo *)attribute).size;
        }
    }
    
    return CGSizeZero;
}

- (NSArray *)textCheckingResults
{
    if (_caption.length < 2)
        _textCheckingResults = [NSArray array];
    
    if (_textCheckingResults == nil)
    {
        NSArray *textCheckingResults = [TGMessage textCheckingResultsForText:_caption highlightMentionsAndTags:true highlightCommands:true entities:nil];
        _textCheckingResults = textCheckingResults ?: [NSArray array];
    }
    
    return _textCheckingResults;
}

@end
