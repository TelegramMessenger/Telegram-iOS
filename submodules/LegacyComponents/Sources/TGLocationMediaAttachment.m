#import "TGLocationMediaAttachment.h"

@implementation TGVenueAttachment

- (instancetype)initWithTitle:(NSString *)title address:(NSString *)address provider:(NSString *)provider venueId:(NSString *)venueId type:(NSString *)type
{
    self = [super init];
    if (self != nil)
    {
        _title = title;
        _address = address;
        _provider = provider;
        _venueId = venueId;
        _type = type;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    return [self initWithTitle:[aDecoder decodeObjectForKey:@"title"] address:[aDecoder decodeObjectForKey:@"address"] provider:[aDecoder decodeObjectForKey:@"provider"] venueId:[aDecoder decodeObjectForKey:@"venueId"] type:[aDecoder decodeObjectForKey:@"type"]];
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
    if (_type != nil)
        [aCoder encodeObject:_type forKey:@"type"];
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
    
    if (_venue == nil)
        [data appendBytes:&_period length:4];
    
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
        else if (dataLength == 8 + 8 + 4 + 4)
        {
            int32_t period = 0;
            [is read:(uint8_t *)&period maxLength:4];
            locationAttachment.period = period;
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
        _period = [aDecoder decodeInt32ForKey:@"period"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeDouble:_latitude forKey:@"latitude"];
    [aCoder encodeDouble:_longitude forKey:@"longitude"];
    [aCoder encodeObject:_venue forKey:@"venue"];
    [aCoder encodeInt32:_period forKey:@"period"];
}

- (bool)isLiveLocation
{
    return _period > 0;
}

@end
