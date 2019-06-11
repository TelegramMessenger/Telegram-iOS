#import "TGReplyMarkupAttachment.h"

#import "LegacyComponentsInternal.h"

#import "PSKeyValueEncoder.h"
#import "PSKeyValueDecoder.h"

#import "NSInputStream+TL.h"

@implementation TGReplyMarkupAttachment

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        self.type = TGReplyMarkupAttachmentType;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self != nil)
    {
        self.type = TGReplyMarkupAttachmentType;
        
        NSData *replyMarkupData = [aDecoder decodeObjectForKey:@"replyMarkupData"];
        _replyMarkup = [[TGBotReplyMarkup alloc] initWithKeyValueCoder:[[PSKeyValueDecoder alloc] initWithData:replyMarkupData]];
    }
    return self;
}

- (instancetype)initWithReplyMarkup:(TGBotReplyMarkup *)replyMarkup {
    self = [super init];
    if (self != nil)
    {
        _replyMarkup = replyMarkup;
        self.type = TGReplyMarkupAttachmentType;
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    PSKeyValueEncoder *encoder = [[PSKeyValueEncoder alloc] init];
    [_replyMarkup encodeWithKeyValueCoder:encoder];
    [aCoder encodeObject:[encoder data] forKey:@"replyMarkupData"];
}

- (BOOL)isEqual:(id)object
{
    return [object isKindOfClass:[TGReplyMarkupAttachment class]] && TGObjectCompare(((TGReplyMarkupAttachment *)object)->_replyMarkup, _replyMarkup);
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
