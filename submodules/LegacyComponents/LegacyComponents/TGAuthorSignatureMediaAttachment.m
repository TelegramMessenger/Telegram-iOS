#import "TGAuthorSignatureMediaAttachment.h"

#import "LegacyComponentsInternal.h"

#import "NSInputStream+TL.h"

@implementation TGAuthorSignatureMediaAttachment

- (instancetype)initWithSignature:(NSString *)signature {
    self = [super init];
    if (self != nil) {
        self.type = TGAuthorSignatureMediaAttachmentType;
        
        _signature = signature;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    return [self initWithSignature:[aDecoder decodeObjectForKey:@"signature"]];
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:_signature forKey:@"signature"];
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

- (BOOL)isEqual:(id)object {
    return [object isKindOfClass:[TGAuthorSignatureMediaAttachment class]] && TGStringCompare(((TGAuthorSignatureMediaAttachment *)object)->_signature, _signature);
}

@end
