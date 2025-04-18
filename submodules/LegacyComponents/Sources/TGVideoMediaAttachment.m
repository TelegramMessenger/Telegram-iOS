#import "TGVideoMediaAttachment.h"

#import "TGMessage.h"

#import "LegacyComponentsInternal.h"

@interface TGVideoMediaAttachment ()
{
    NSArray *_textCheckingResults;
}
@end

@implementation TGVideoMediaAttachment

@synthesize videoId = _videoId;
@synthesize accessHash = _accessHash;

@synthesize localVideoId = _localVideoId;

@synthesize duration = _duration;
@synthesize dimensions = _dimensions;

@synthesize videoInfo = _videoInfo;
@synthesize thumbnailInfo = _thumbnailInfo;

- (id)init
{
    self = [super init];
    if (self != nil)
    {
        self.type = TGVideoMediaAttachmentType;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)__unused zone
{
    TGVideoMediaAttachment *videoAttachment = [[TGVideoMediaAttachment alloc] init];
    
    videoAttachment.videoId = _videoId;
    videoAttachment.accessHash = _accessHash;
    videoAttachment.localVideoId = _localVideoId;
    videoAttachment.duration = _duration;
    videoAttachment.dimensions = _dimensions;
    videoAttachment.videoInfo = _videoInfo;
    videoAttachment.thumbnailInfo = _thumbnailInfo;
    videoAttachment.caption = _caption;
    videoAttachment.hasStickers = _hasStickers;
    videoAttachment.embeddedStickerDocuments = _embeddedStickerDocuments;
    videoAttachment.loopVideo = _loopVideo;
    videoAttachment.roundMessage = _roundMessage;
    videoAttachment.originInfo = _originInfo;
    
    return videoAttachment;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self != nil) {
        self.type = TGVideoMediaAttachmentType;
        
        _videoId = [aDecoder decodeInt64ForKey:@"videoId"];
        _accessHash = [aDecoder decodeInt64ForKey:@"accessHash"];
        _localVideoId = [aDecoder decodeInt64ForKey:@"localVideoId"];
        _duration = [aDecoder decodeInt32ForKey:@"duration"];
        _dimensions = [aDecoder decodeCGSizeForKey:@"dimensions"];
        _videoInfo = [aDecoder decodeObjectForKey:@"videoInfo"];
        _thumbnailInfo = [aDecoder decodeObjectForKey:@"thumbInfo"];
        _caption = [aDecoder decodeObjectForKey:@"caption"];
        _hasStickers = [aDecoder decodeBoolForKey:@"hasStickers"];
        _embeddedStickerDocuments = [aDecoder decodeObjectForKey:@"embeddedStickerDocuments"];
        _roundMessage = [aDecoder decodeBoolForKey:@"roundMessage"];
        _originInfo = [aDecoder decodeObjectForKey:@"origin"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeInt64:_videoId forKey:@"videoId"];
    [aCoder encodeInt64:_accessHash forKey:@"accessHash"];
    [aCoder encodeInt64:_localVideoId forKey:@"localVideoId"];
    [aCoder encodeInt32:_duration forKey:@"duration"];
    [aCoder encodeCGSize:_dimensions forKey:@"dimensions"];
    [aCoder encodeObject:_videoInfo forKey:@"videoInfo"];
    [aCoder encodeObject:_thumbnailInfo forKey:@"thumbInfo"];
    [aCoder encodeObject:_caption forKey:@"caption"];
    [aCoder encodeBool:_hasStickers forKey:@"hasStickers"];
    if (_embeddedStickerDocuments != nil) {
        [aCoder encodeObject:_embeddedStickerDocuments forKey:@"embeddedStickerDocuments"];
    }
    [aCoder encodeBool:_roundMessage forKey:@"roundMessage"];
    [aCoder encodeObject:_originInfo forKey:@"origin"];
}

- (BOOL)isEqual:(id)object
{
    if (![object isKindOfClass:[TGVideoMediaAttachment class]])
        return false;
    
    TGVideoMediaAttachment *other = object;
    
    if (_videoId != other.videoId || _accessHash != other.accessHash || _localVideoId != other.localVideoId || _duration != other.duration || !CGSizeEqualToSize(_dimensions, other.dimensions))
        return false;
    
    if (!TGObjectCompare(_videoInfo, other.videoInfo))
        return false;
    
    if (!TGObjectCompare(_thumbnailInfo, other.thumbnailInfo))
        return false;
    
    if (!TGObjectCompare(_caption, other.caption))
        return false;
    
    if (_hasStickers != other.hasStickers) {
        return false;
    }
    
    if (_roundMessage != other.roundMessage) {
        return false;
    }
    
    return true;
}

- (void)serialize:(NSMutableData *)data
{
    int32_t modernTag = 0x7abacaf1;
    [data appendBytes:&modernTag length:4];
    
    uint8_t version = 5;
    [data appendBytes:&version length:1];
    
    int dataLengthPtr = (int)data.length;
    int zero = 0;
    [data appendBytes:&zero length:4];
    
    [data appendBytes:&_videoId length:8];
    [data appendBytes:&_accessHash length:8];
    
    [data appendBytes:&_localVideoId length:8];
    
    uint8_t hasVideoInfo = _videoInfo != nil ? 1 : 0;
    [data appendBytes:&hasVideoInfo length:1];
    if (hasVideoInfo != 0)
        [_videoInfo serialize:data];
    
    uint8_t hasThumbnailInfo = _thumbnailInfo != nil ? 1 : 0;
    [data appendBytes:&hasThumbnailInfo length:1];
    if (hasThumbnailInfo != 0)
        [_thumbnailInfo serialize:data];
    
    [data appendBytes:&_duration length:4];
    
    int dimension = (int)_dimensions.width;
    [data appendBytes:&dimension length:4];
    dimension = (int)_dimensions.height;
    [data appendBytes:&dimension length:4];
    
    NSData *captionData = [_caption dataUsingEncoding:NSUTF8StringEncoding];
    int32_t captionLength = (int32_t)captionData.length;
    [data appendBytes:&captionLength length:4];
    if (captionLength != 0)
        [data appendData:captionData];
    
    int8_t hasStickers = _hasStickers ? 1 : 0;
    [data appendBytes:&hasStickers length:1];
    
    if (_embeddedStickerDocuments.count == 0) {
        int32_t zero = 0;
        [data appendBytes:&zero length:4];
    } else {
        NSData *stickerData = [NSKeyedArchiver archivedDataWithRootObject:_embeddedStickerDocuments];
        int32_t length = (int32_t)stickerData.length;
        [data appendBytes:&length length:4];
        [data appendData:stickerData];
    }
    
    int8_t roundMessage = _roundMessage ? 1 : 0;
    [data appendBytes:&roundMessage length:1];
    
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
    int32_t dataLength = 0;
    [is read:(uint8_t *)&dataLength maxLength:4];
    
    uint8_t version = 1;
    if (dataLength == 0x7abacaf1)
    {
        [is read:(uint8_t *)&version maxLength:1];
        [is read:(uint8_t *)&dataLength maxLength:4];
    }
    
    TGVideoMediaAttachment *videoAttachment = [[TGVideoMediaAttachment alloc] init];
    
    int64_t videoId = 0;
    [is read:(uint8_t *)&videoId maxLength:8];
    videoAttachment.videoId = videoId;
    
    int64_t accessHash = 0;
    [is read:(uint8_t *)&accessHash maxLength:8];
    videoAttachment.accessHash = accessHash;
    
    int64_t localVideoId = 0;
    [is read:(uint8_t *)&localVideoId maxLength:8];
    videoAttachment.localVideoId = localVideoId;
    
    uint8_t hasVideoInfo = 0;
    [is read:&hasVideoInfo maxLength:1];
    
    if (hasVideoInfo != 0)
        videoAttachment.videoInfo = [TGVideoInfo deserialize:is];
    
    uint8_t hasThumbnailInfo = 0;
    [is read:&hasThumbnailInfo maxLength:1];
    
    if (hasThumbnailInfo != 0)
        videoAttachment.thumbnailInfo = [TGImageInfo deserialize:is];
    
    int duration = 0;
    [is read:(uint8_t *)&duration maxLength:4];
    videoAttachment.duration = duration;
    
    CGSize dimensions = CGSizeZero;
    int dimension = 0;
    [is read:(uint8_t *)&dimension maxLength:4];
    dimensions.width = dimension;
    dimension = 0;
    [is read:(uint8_t *)&dimension maxLength:4];
    dimensions.height = dimension;
    videoAttachment.dimensions = dimensions;
    
    if (version >= 2)
    {
        int32_t captionLength = 0;
        [is read:(uint8_t *)&captionLength maxLength:4];
        if (captionLength != 0)
        {
            uint8_t *captionBytes = malloc(captionLength);
            [is read:captionBytes maxLength:captionLength];
            videoAttachment.caption = [[NSString alloc] initWithBytesNoCopy:captionBytes length:captionLength encoding:NSUTF8StringEncoding freeWhenDone:true];
        }
    }
    
    if (version >= 3)
    {
        int8_t hasStickers = 0;
        [is read:(uint8_t *)&hasStickers maxLength:1];
        videoAttachment.hasStickers = hasStickers != 0;
        
        int32_t stickerDataLength = 0;
        [is read:(uint8_t *)&stickerDataLength maxLength:4];
        if (stickerDataLength != 0) {
            uint8_t *stickerBytes = malloc(stickerDataLength);
            [is read:stickerBytes maxLength:stickerDataLength];
            NSData *stickerData = [[NSData alloc] initWithBytesNoCopy:stickerBytes length:stickerDataLength freeWhenDone:true];
            videoAttachment.embeddedStickerDocuments = [NSKeyedUnarchiver unarchiveObjectWithData:stickerData];
        }
    }
    
    if (version >= 4)
    {
        int8_t roundMessage = 0;
        [is read:(uint8_t *)&roundMessage maxLength:1];
        videoAttachment.roundMessage = roundMessage != 0;
    }
    
    if (version >= 5)
    {
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
            videoAttachment.originInfo = origin;
        }
    }
    
    return videoAttachment;
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
