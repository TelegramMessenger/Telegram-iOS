#import "TGBridgeVideoMediaAttachment.h"
#import <UIKit/UIKit.h>

const NSInteger TGBridgeVideoMediaAttachmentType = 0x338EAA20;

NSString *const TGBridgeVideoMediaVideoIdKey = @"videoId";
NSString *const TGBridgeVideoMediaDimensionsKey = @"dimensions";
NSString *const TGBridgeVideoMediaDurationKey = @"duration";
NSString *const TGBridgeVideoMediaRoundKey = @"round";

@implementation TGBridgeVideoMediaAttachment

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self != nil)
    {
        _videoId = [aDecoder decodeInt64ForKey:TGBridgeVideoMediaVideoIdKey];
        _dimensions = [aDecoder decodeCGSizeForKey:TGBridgeVideoMediaDimensionsKey];
        _duration = [aDecoder decodeInt32ForKey:TGBridgeVideoMediaDurationKey];
        _round = [aDecoder decodeBoolForKey:TGBridgeVideoMediaRoundKey];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInt64:self.videoId forKey:TGBridgeVideoMediaVideoIdKey];
    [aCoder encodeCGSize:self.dimensions forKey:TGBridgeVideoMediaDimensionsKey];
    [aCoder encodeInt32:self.duration forKey:TGBridgeVideoMediaDurationKey];
    [aCoder encodeBool:self.round forKey:TGBridgeVideoMediaRoundKey];
}

+ (NSInteger)mediaType
{
    return TGBridgeVideoMediaAttachmentType;
}

@end
