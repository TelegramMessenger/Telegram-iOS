#import "TGStickerPack.h"

#import <LegacyComponents/LegacyComponents.h>

@implementation TGStickerPack

- (instancetype)initWithPackReference:(id<TGStickerPackReference>)packReference title:(NSString *)title stickerAssociations:(NSArray *)stickerAssociations documents:(NSArray *)documents packHash:(int32_t)packHash hidden:(bool)hidden isMask:(bool)isMask isFeatured:(bool)isFeatured installedDate:(int32_t)installedDate
{
    self = [super init];
    if (self != nil)
    {
        _packReference = packReference;
        _title = title;
        _stickerAssociations = stickerAssociations;
        _documents = documents;
        _packHash = packHash;
        _hidden = hidden;
        _isMask = isMask;
        _installedDate = installedDate;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    return [self initWithPackReference:[aDecoder decodeObjectForKey:@"packReference"] title:[aDecoder decodeObjectForKey:@"title"] stickerAssociations:[aDecoder decodeObjectForKey:@"stickerAssociations"] documents:[aDecoder decodeObjectForKey:@"documents"] packHash:[aDecoder decodeInt32ForKey:@"packHash"] hidden:[aDecoder decodeInt32ForKey:@"hidden"] isMask:[aDecoder decodeInt32ForKey:@"isMask"] isFeatured:[aDecoder decodeInt32ForKey:@"isFeatured"] installedDate:[aDecoder decodeInt32ForKey:@"installedDate"]];
}

- (instancetype)initWithKeyValueCoder:(PSKeyValueCoder *)coder
{
    return [self initWithPackReference:(id<TGStickerPackReference>)[coder decodeObjectForCKey:"r"] title:[coder decodeStringForCKey:"t"] stickerAssociations:[coder decodeArrayForCKey:"a"] documents:[coder decodeArrayForCKey:"d"] packHash:[coder decodeInt32ForCKey:"ph"] hidden:[coder decodeInt32ForCKey:"hi"] isMask:[coder decodeInt32ForCKey:"ma"] isFeatured:[coder decodeInt32ForCKey:"if"] installedDate:[coder decodeInt32ForCKey:"id"]];
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:_packReference forKey:@"packReference"];
    [aCoder encodeObject:_title forKey:@"title"];
    [aCoder encodeObject:_stickerAssociations forKey:@"stickerAssociations"];
    [aCoder encodeObject:_documents forKey:@"documents"];
    [aCoder encodeInt32:_packHash forKey:@"packHash"];
    [aCoder encodeInt32:_hidden ? 1 : 0 forKey:@"hidden"];
    [aCoder encodeInt32:_isMask ? 1 : 0 forKey:@"isMask"];
    [aCoder encodeInt32:_isFeatured ? 1 : 0 forKey:@"isFeatured"];
    [aCoder encodeInt32:_installedDate forKey:@"installedDate"];
}

- (void)encodeWithKeyValueCoder:(PSKeyValueCoder *)coder
{
    [coder encodeObject:_packReference forKey:@"r"];
    [coder encodeString:_title forCKey:"t"];
    [coder encodeArray:_stickerAssociations forCKey:"a"];
    [coder encodeArray:_documents forCKey:"d"];
    [coder encodeInt32:_packHash forCKey:"ph"];
    [coder encodeInt32:_hidden ? 1 : 0 forCKey:"hi"];
    [coder encodeInt32:_isMask ? 1 : 0 forCKey:"ma"];
    [coder encodeInt32:_isFeatured ? 1 : 0 forCKey:"if"];
    [coder encodeInt32:_installedDate forCKey:"id"];
}

- (BOOL)isEqual:(id)object
{
    if (![object isKindOfClass:[TGStickerPack class]])
        return false;
    
    TGStickerPack *other = object;
    
    if (![other->_packReference isEqual:_packReference])
        return false;
    
    if (![other->_stickerAssociations isEqual:_stickerAssociations])
        return false;
    
    if (![other->_documents isEqual:_documents])
        return false;
    
    if (other->_packHash != _packHash)
        return false;
    
    if (other->_hidden != _hidden) {
        return false;
    }
    
    if (other->_isMask != _isMask) {
        return false;
    }
    
    if (other->_isFeatured != _isFeatured) {
        return false;
    }
    
    if (other->_installedDate != _installedDate) {
        return false;
    }
    
    return true;
}

@end
