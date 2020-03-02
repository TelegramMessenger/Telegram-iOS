#import "TGViaUserAttachment.h"

#import "NSInputStream+TL.h"

@implementation TGViaUserAttachment

- (instancetype)initWithUserId:(int32_t)userId username:(NSString *)username {
    self = [super init];
    if (self != nil) {
        self.type = TGViaUserAttachmentType;
        
        _userId = userId;
        _username = username;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    return [self initWithUserId:[aDecoder decodeInt32ForKey:@"userId"] username:[aDecoder decodeObjectForKey:@"username"]];
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeInt32:_userId forKey:@"userId"];
    if (_username != nil) {
        [aCoder encodeObject:_username forKey:@"username"];
    }
}

- (void)serialize:(NSMutableData *)data
{
    NSData *serializedData = [NSKeyedArchiver archivedDataWithRootObject:self];
    int32_t length = (int32_t)serializedData.length;
    [data appendBytes:&length length:4];
    [data appendData:serializedData];
}

- (TGMediaAttachment *)parseMediaAttachment:(NSInputStream *)is
{
    int32_t length = [is readInt32];
    NSData *data = [is readData:length];
    return [NSKeyedUnarchiver unarchiveObjectWithData:data];
}

@end
