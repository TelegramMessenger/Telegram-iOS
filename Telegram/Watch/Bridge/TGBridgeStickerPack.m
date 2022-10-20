#import "TGBridgeStickerPack.h"

#import <WatchCommonWatch/WatchCommonWatch.h>

NSString *const TGBridgeStickerPackBuiltInKey = @"builtin";
NSString *const TGBridgeStickerPackTitleKey = @"title";
NSString *const TGBridgeStickerPackDocumentsKey = @"documents";

@implementation TGBridgeStickerPack

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self != nil)
    {
        _builtIn = [aDecoder decodeBoolForKey:TGBridgeStickerPackBuiltInKey];
        _title = [aDecoder decodeObjectForKey:TGBridgeStickerPackTitleKey];
        _documents = [aDecoder decodeObjectForKey:TGBridgeStickerPackDocumentsKey];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeBool:self.builtIn forKey:TGBridgeStickerPackBuiltInKey];
    [aCoder encodeObject:self.title forKey:TGBridgeStickerPackTitleKey];
    [aCoder encodeObject:self.documents forKey:TGBridgeStickerPackDocumentsKey];
}

@end
