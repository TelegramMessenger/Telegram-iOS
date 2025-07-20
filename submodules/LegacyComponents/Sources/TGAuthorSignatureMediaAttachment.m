#import <LegacyComponents/TGAuthorSignatureMediaAttachment.h>

#import "LegacyComponentsInternal.h"

#import <LegacyComponents/NSInputStream+TL.h>

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
    NSData *serializedData = [NSKeyedArchiver archivedDataWithRootObject:self requiringSecureCoding:false error:nil];
    int32_t length = (int32_t)serializedData.length;
    [data appendBytes:&length length:4];
    [data appendData:serializedData];
}

- (TGMediaAttachment *)parseMediaAttachment:(NSInputStream *)is
{
    int32_t length = [is readInt32];
    NSData *data = [is readData:length];
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [NSKeyedUnarchiver unarchiveObjectWithData:data];
#pragma clang diagnostic pop
}

- (BOOL)isEqual:(id)object {
    return [object isKindOfClass:[TGAuthorSignatureMediaAttachment class]] && TGStringCompare(((TGAuthorSignatureMediaAttachment *)object)->_signature, _signature);
}

@end
