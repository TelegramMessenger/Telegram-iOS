#import "TGVideoInfo.h"

#include <vector>

struct TGVideoQualityRecord
{
    int quality;
    int size;
    NSString *url;
    
    TGVideoQualityRecord(int quality_, NSString *url_, int size_) :
        quality(quality_), size(size_)
    {
        url = url_;
    }
    
    TGVideoQualityRecord(const TGVideoQualityRecord &other)
    {
        url = other.url;
        quality = other.quality;
        size = other.size;
    }
    
    TGVideoQualityRecord & operator= (const TGVideoQualityRecord &other)
    {
        if (this != &other)
        {
            url = other.url;
            quality = other.quality;
            size = other.size;
        }
        
        return *this;
    }
    
    ~TGVideoQualityRecord()
    {
        url = nil;
    }
};

@interface TGVideoInfo ()
{
    std::vector<TGVideoQualityRecord> _qualitySet;
}

@end

@implementation TGVideoInfo

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self != nil) {
        _qualitySet.push_back(TGVideoQualityRecord(0, [aDecoder decodeObjectForKey:@"url"], [aDecoder decodeInt32ForKey:@"size"]));
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    if (!_qualitySet.empty()) {
        auto q = _qualitySet[0];
        [aCoder encodeInt32:q.size forKey:@"size"];
        [aCoder encodeObject:q.url forKey:@"url"];
    }
}

- (BOOL)isEqual:(id)object
{
    if (![object isKindOfClass:[TGVideoInfo class]])
        return false;
    
    TGVideoInfo *other = object;
    
    if (_qualitySet.size() != other->_qualitySet.size())
        return false;
    
    for (size_t i = 0; i < _qualitySet.size(); i++)
    {
        if (_qualitySet[i].quality != other->_qualitySet[i].quality)
            return false;
        
        if (_qualitySet[i].size != other->_qualitySet[i].size)
            return false;
        
        if (![_qualitySet[i].url isEqualToString:other->_qualitySet[i].url])
            return false;
    }
    
    return true;
}

- (void)addVideoWithQuality:(int)quality url:(NSString *)url size:(int)size
{
    _qualitySet.push_back(TGVideoQualityRecord(quality, url, size));
}

- (NSString *)urlWithQuality:(int)quality actualQuality:(int *)actualQuality actualSize:(int *)actualSize
{
    NSString *url = nil;
    int closestQuality = INT_MAX;
    int closestSize = 0;
    
    for (std::vector<TGVideoQualityRecord>::iterator it = _qualitySet.begin(); it != _qualitySet.end(); it++)
    {
        if (it->quality == quality)
        {
            if (actualQuality != NULL)
                *actualQuality = quality;
            if (actualSize != NULL)
                *actualSize = it->size;
            return it->url;
        }
        else if (ABS(it->quality - quality) < ABS(closestQuality - quality))
        {
            closestQuality = quality;
            url = it->url;
            closestSize = it->size;
        }
    }
    
    if (url != nil)
    {
        if (actualQuality != NULL)
            *actualQuality = closestQuality;
        if (actualSize != NULL)
            *actualSize = closestSize;
    }
    
    return url;
}

- (void)serialize:(NSMutableData *)data
{
    size_t count = _qualitySet.size();
    [data appendBytes:&count length:4];
    
    for (std::vector<TGVideoQualityRecord>::iterator it = _qualitySet.begin(); it != _qualitySet.end(); it++)
    {
        NSData *urlData = [it->url dataUsingEncoding:NSUTF8StringEncoding];
        int32_t length = (int32_t)urlData.length;
        [data appendBytes:&length length:4];
        [data appendData:urlData];
        
        [data appendBytes:&it->quality length:4];
        [data appendBytes:&it->size length:4];
    }
}

+ (TGVideoInfo *)deserialize:(NSInputStream *)is
{
    TGVideoInfo *videoInfo = [[TGVideoInfo alloc] init];
    
    int count = 0;
    [is read:(uint8_t *)&count maxLength:4];
    
    for (int i = 0; i < count; i++)
    {
        int length = 0;
        [is read:(uint8_t *)&length maxLength:4];
        uint8_t *urlBytes = (uint8_t *)malloc(length);
        [is read:urlBytes maxLength:length];
        NSString *url = [[NSString alloc] initWithBytesNoCopy:urlBytes length:length encoding:NSUTF8StringEncoding freeWhenDone:true];
        
        int quality = 0;
        [is read:(uint8_t *)&quality maxLength:4];
        
        int size = 0;
        [is read:(uint8_t *)&size maxLength:4];
        
        [videoInfo addVideoWithQuality:quality url:url size:size];
    }
    
    return videoInfo;
}

@end
