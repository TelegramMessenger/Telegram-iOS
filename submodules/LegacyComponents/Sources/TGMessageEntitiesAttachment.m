#import <LegacyComponents/TGMessageEntitiesAttachment.h>

#import "LegacyComponentsInternal.h"

#import <LegacyComponents/PSKeyValueEncoder.h>
#import <LegacyComponents/PSKeyValueDecoder.h>

#import <LegacyComponents/NSInputStream+TL.h>

@implementation TGMessageEntitiesAttachment

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        self.type = TGMessageEntitiesAttachmentType;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self != nil)
    {
        self.type = TGMessageEntitiesAttachmentType;
        
        NSData *entitiesData = [aDecoder decodeObjectForKey:@"entitiesData"];
        _entities = [[[PSKeyValueDecoder alloc] initWithData:entitiesData] decodeArrayForCKey:"_"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    PSKeyValueEncoder *encoder = [[PSKeyValueEncoder alloc] init];
    [encoder encodeArray:_entities forCKey:"_"];
    [aCoder encodeObject:[encoder data] forKey:@"entitiesData"];
}

- (BOOL)isEqual:(id)object
{
    return [object isKindOfClass:[TGMessageEntitiesAttachment class]] && TGObjectCompare(((TGMessageEntitiesAttachment *)object)->_entities, _entities);
}

- (void)serialize:(NSMutableData *)data
{
    NSData *serializedData = [NSKeyedArchiver archivedDataWithRootObject:self requiringSecureCoding:false error:nil];
    int32_t length = (int32_t)serializedData.length;
    [data appendBytes:&length length:4];
    [data appendData:serializedData];
}

- (TGMediaAttachment *)parseMediaAttachment:(NSInputStream *)is
{
    bool readingError = false;
    int32_t length = [is readInt32:&readingError];
    if (readingError) {
        return nil;
    }
    NSData *data = [is readData:length failed:&readingError];
    if (readingError) {
        return nil;
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [NSKeyedUnarchiver unarchiveObjectWithData:data];
#pragma clang diagnostic pop
}

@end
