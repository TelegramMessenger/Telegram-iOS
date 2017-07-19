#import "TGLocationMediaAttachment.h"

@implementation TGVenueAttachment

- (instancetype)initWithTitle:(NSString *)title address:(NSString *)address provider:(NSString *)provider venueId:(NSString *)venueId
{
    self = [super init];
    if (self != nil)
    {
        _title = title;
        _address = address;
        _provider = provider;
        _venueId = venueId;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    return [self initWithTitle:[aDecoder decodeObjectForKey:@"title"] address:[aDecoder decodeObjectForKey:@"address"] provider:[aDecoder decodeObjectForKey:@"provider"] venueId:[aDecoder decodeObjectForKey:@"venueId"]];
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    if (_title != nil)
        [aCoder encodeObject:_title forKey:@"title"];
    if (_address != nil)
        [aCoder encodeObject:_address forKey:@"address"];
    if (_provider != nil)
        [aCoder encodeObject:_provider forKey:@"provider"];
    if (_venueId != nil)
        [aCoder encodeObject:_venueId forKey:@"venueId"];
}

@end

@implementation TGLocationMediaAttachment

- (id)init
{
    self = [super init];
    if (self != nil)
    {
        self.type = TGLocationMediaAttachmentType;
    }
    return self;
}

- (void)serialize:(NSMutableData *)data
{
    int dataLengthPtr = (int)data.length;
    int zero = 0;
    [data appendBytes:&zero length:4];
    
    [data appendBytes:&_latitude length:8];
    [data appendBytes:&_longitude length:8];
    
    NSData *venueData = nil;
    if (_venue != nil)
        venueData = [NSKeyedArchiver archivedDataWithRootObject:_venue];
    int32_t venueDataLength = (int32_t)venueData.length;
    [data appendBytes:&venueDataLength length:4];
    [data appendData:venueData];
    
    int dataLength = (int)(data.length - dataLengthPtr - 4);
    [data replaceBytesInRange:NSMakeRange(dataLengthPtr, 4) withBytes:&dataLength];
}

- (TGMediaAttachment *)parseMediaAttachment:(NSInputStream *)is
{
    int dataLength = 0;
    [is read:(uint8_t *)&dataLength maxLength:4];
    
    TGLocationMediaAttachment *locationAttachment = [[TGLocationMediaAttachment alloc] init];
    
    double tmp = 0;
    [is read:(uint8_t *)&tmp maxLength:8];
    locationAttachment.latitude = tmp;
    
    tmp = 0;
    [is read:(uint8_t *)&tmp maxLength:8];
    locationAttachment.longitude = tmp;
    
    if (dataLength >= 8 + 8 + 4)
    {
        int32_t venueDataLength = 0;
        [is read:(uint8_t *)&venueDataLength maxLength:4];
        if (venueDataLength > 0)
        {
            uint8_t *venueBytes = malloc(venueDataLength);
            [is read:venueBytes maxLength:venueDataLength];
            NSData *venueData = [[NSData alloc] initWithBytesNoCopy:venueBytes length:venueDataLength freeWhenDone:true];
            locationAttachment.venue = [NSKeyedUnarchiver unarchiveObjectWithData:venueData];
        }
    }
    
    return locationAttachment;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self != nil) {
        self.type = TGLocationMediaAttachmentType;
        _latitude = [aDecoder decodeDoubleForKey:@"latitude"];
        _longitude = [aDecoder decodeDoubleForKey:@"longitude"];
        _venue = [aDecoder decodeObjectForKey:@"venue"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeDouble:_latitude forKey:@"latitude"];
    [aCoder encodeDouble:_longitude forKey:@"longitude"];
    [aCoder encodeObject:_venue forKey:@"venue"];
}

@end
