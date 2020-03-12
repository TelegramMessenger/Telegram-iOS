#import "TGPhotoPaintTextEntity.h"

@implementation TGPhotoPaintTextEntity

- (instancetype)initWithText:(NSString *)text font:(TGPhotoPaintFont *)font swatch:(TGPaintSwatch *)swatch baseFontSize:(CGFloat)baseFontSize maxWidth:(CGFloat)maxWidth stroke:(bool)stroke
{
    self = [super init];
    if (self != nil)
    {
        _text = text;
        _font = font;
        _swatch = swatch;
        _baseFontSize = baseFontSize;
        _maxWidth = maxWidth;
        _stroke = stroke;
        self.scale = 1.0f;
    }
    return self;
}

- (instancetype)copyWithZone:(NSZone *)__unused zone
{
    TGPhotoPaintTextEntity *entity = [[TGPhotoPaintTextEntity alloc] initWithText:self.text font:self.font swatch:self.swatch baseFontSize:self.baseFontSize maxWidth:self.maxWidth stroke:self.stroke];

    entity->_uuid = self.uuid;
    entity.position = self.position;
    entity.scale = self.scale;
    entity.angle = self.angle;
    
    return entity;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return true;
    
    if (!object || ![object isKindOfClass:[self class]])
        return false;
    
    TGPhotoPaintTextEntity *entity = (TGPhotoPaintTextEntity *)object;
    return entity.uuid == self.uuid && [entity.text isEqualToString:self.text] && [entity.font isEqual:self.font] && [entity.swatch isEqual:self.swatch] && fabs(entity.baseFontSize - self.baseFontSize) < FLT_EPSILON && fabs(entity.maxWidth - self.maxWidth) < FLT_EPSILON && entity.stroke == self.stroke && CGPointEqualToPoint(entity.position, self.position) && fabs(entity.scale - self.scale) < FLT_EPSILON && fabs(entity.angle - self.angle) < FLT_EPSILON && entity.mirrored == self.mirrored;
}

@end
