#import "TGPhotoPaintStickerEntity.h"

#import <LegacyComponents/LegacyComponents.h>

@implementation TGPhotoPaintStickerEntity

- (instancetype)initWithDocument:(TGDocumentMediaAttachment *)document baseSize:(CGSize)baseSize
{
    self = [super init];
    if (self != nil)
    {
        _document = document;
        _baseSize = baseSize;
        self.scale = 1.0;
    }
    return self;
}

- (instancetype)initWithEmoji:(NSString *)emoji
{
    self = [super init];
    if (self != nil)
    {
        _emoji = emoji;
        self.scale = 1.0f;
    }
    return self;
}

- (instancetype)copyWithZone:(NSZone *)__unused zone
{
    TGPhotoPaintStickerEntity *entity = nil;
    if (_document != nil)
        entity = [[TGPhotoPaintStickerEntity alloc] initWithDocument:self.document baseSize:self.baseSize];
    else if (_emoji != nil)
        entity = [[TGPhotoPaintStickerEntity alloc] initWithEmoji:self.emoji];
    else
        return nil;
    
    entity->_uuid = self.uuid;
    entity.position = self.position;
    entity.scale = self.scale;
    entity.angle = self.angle;
    entity.mirrored = self.mirrored;

    return entity;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return true;
    
    if (!object || ![object isKindOfClass:[self class]])
        return false;
    
    TGPhotoPaintStickerEntity *entity = (TGPhotoPaintStickerEntity *)object;
    return entity.uuid == self.uuid && [entity.document isEqual:self.document] && CGSizeEqualToSize(entity.baseSize, self.baseSize) && CGPointEqualToPoint(entity.position, self.position) && fabs(entity.scale - self.scale) < FLT_EPSILON && fabs(entity.angle - self.angle) < FLT_EPSILON && entity.mirrored == self.mirrored;
}

@end
