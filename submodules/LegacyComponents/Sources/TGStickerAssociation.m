#import "TGStickerAssociation.h"

#import "LegacyComponentsInternal.h"
#import "PSKeyValueCoder.h"

@implementation TGStickerAssociation

- (instancetype)initWithKey:(NSString *)key documentIds:(NSArray *)documentIds
{
    self = [super init];
    if (self != nil)
    {
        _key = key;
        _documentIds = documentIds;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    return [self initWithKey:[aDecoder decodeObjectForKey:@"key"] documentIds:[aDecoder decodeObjectForKey:@"documentIds"]];
}

- (instancetype)initWithKeyValueCoder:(PSKeyValueCoder *)coder
{
    NSMutableArray *documentIds = [[NSMutableArray alloc] init];
    NSData *documentIdsData = [coder decodeDataCorCKey:"d"];
    for (NSUInteger offset = 0; offset < documentIdsData.length; offset += 8)
    {
        int64_t documentId = 0;
        [documentIdsData getBytes:&documentId range:NSMakeRange(0, 8)];
        [documentIds addObject:@(documentId)];
    }
    return [self initWithKey:[coder decodeStringForCKey:"k"] documentIds:documentIds];
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:_key forKey:@"key"];
    [aCoder encodeObject:_documentIds forKey:@"documentIds"];
}

- (void)encodeWithKeyValueCoder:(PSKeyValueCoder *)coder
{
    NSMutableData *data = [[NSMutableData alloc] init];
    for (NSNumber *nDocumentId in _documentIds)
    {
        int64_t documentId = [nDocumentId longLongValue];
        [data appendBytes:&documentId length:8];
    }
    [coder encodeString:_key forCKey:"k"];
    [coder encodeData:data forCKey:"d"];
}

- (BOOL)isEqual:(id)object
{
    return [object isKindOfClass:[TGStickerAssociation class]] && TGStringCompare(((TGStickerAssociation *)object)->_key, _key) && TGObjectCompare(((TGStickerAssociation *)object)->_documentIds, _documentIds);
}

@end
