#import "TGBotContextResultAttachment.h"

#import "NSInputStream+TL.h"

@implementation TGBotContextResultAttachment

- (instancetype)initWithUserId:(int32_t)userId resultId:(NSString *)resultId queryId:(int64_t)queryId {
    self = [super init];
    if (self != nil) {
        self.type = TGBotContextResultAttachmentType;
        _userId = userId;
        _resultId = resultId;
        _queryId = queryId;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    return [self initWithUserId:[aDecoder decodeInt32ForKey:@"userId"] resultId:[aDecoder decodeObjectForKey:@"resultId"] queryId:[aDecoder decodeInt64ForKey:@"queryId"]];
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeInt32:_userId forKey:@"userId"];
    [aCoder encodeObject:_resultId forKey:@"resultId"];
    [aCoder encodeInt64:_queryId forKey:@"queryId"];
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
