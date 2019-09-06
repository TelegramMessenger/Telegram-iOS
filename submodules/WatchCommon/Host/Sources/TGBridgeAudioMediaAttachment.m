#import "TGBridgeAudioMediaAttachment.h"

const NSInteger TGBridgeAudioMediaAttachmentType = 0x3A0E7A32;

NSString *const TGBridgeAudioMediaAudioIdKey = @"audioId";
NSString *const TGBridgeAudioMediaAccessHashKey = @"accessHash";
NSString *const TGBridgeAudioMediaLocalIdKey = @"localId";
NSString *const TGBridgeAudioMediaDatacenterIdKey = @"datacenterId";
NSString *const TGBridgeAudioMediaDurationKey = @"duration";
NSString *const TGBridgeAudioMediaFileSizeKey = @"fileSize";

@implementation TGBridgeAudioMediaAttachment

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self != nil)
    {
        _audioId = [aDecoder decodeInt64ForKey:TGBridgeAudioMediaAudioIdKey];
        _accessHash = [aDecoder decodeInt64ForKey:TGBridgeAudioMediaAccessHashKey];
        _localAudioId = [aDecoder decodeInt64ForKey:TGBridgeAudioMediaLocalIdKey];
        _datacenterId = [aDecoder decodeInt32ForKey:TGBridgeAudioMediaDatacenterIdKey];
        _duration = [aDecoder decodeInt32ForKey:TGBridgeAudioMediaDurationKey];
        _fileSize = [aDecoder decodeInt32ForKey:TGBridgeAudioMediaFileSizeKey];
    }
    return self;
}

- (void)encodeWithCoder:(nonnull NSCoder *)aCoder
{
    [aCoder encodeInt64:self.audioId forKey:TGBridgeAudioMediaAudioIdKey];
    [aCoder encodeInt64:self.accessHash forKey:TGBridgeAudioMediaAccessHashKey];
    [aCoder encodeInt64:self.localAudioId forKey:TGBridgeAudioMediaLocalIdKey];
    [aCoder encodeInt32:self.datacenterId forKey:TGBridgeAudioMediaDatacenterIdKey];
    [aCoder encodeInt32:self.duration forKey:TGBridgeAudioMediaDurationKey];
    [aCoder encodeInt32:self.fileSize forKey:TGBridgeAudioMediaFileSizeKey];
}

- (int64_t)identifier
{
    if (self.localAudioId != 0)
        return self.localAudioId;
    
    return self.audioId;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    
    if (!object || ![object isKindOfClass:[self class]])
        return NO;
    
    TGBridgeAudioMediaAttachment *audio = (TGBridgeAudioMediaAttachment *)object;
    
    return (self.audioId == audio.audioId || self.localAudioId == audio.localAudioId);
}

+ (NSInteger)mediaType
{
    return TGBridgeAudioMediaAttachmentType;
}

@end
