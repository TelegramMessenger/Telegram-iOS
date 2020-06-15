#import "PGSkinTool.h"

#import "LegacyComponentsInternal.h"

#import "PGPhotoSkinPass.h"

@implementation PGSkinTool

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _identifier = @"skin";
        _type = PGPhotoToolTypePass;
        _order = 0;
        
        _pass = [[PGPhotoSkinPass alloc] init];
        
        _minimumValue = 0;
        _maximumValue = 100;
        _defaultValue = 0;
        
        self.value = @(_defaultValue);
    }
    return self;
}

- (NSString *)title
{
    return TGLocalized(@"PhotoEditor.SkinTool");
}

- (PGPhotoProcessPass *)pass
{
    [self updatePassParameters];
    
    return _pass;
}

- (bool)shouldBeSkipped
{
    return (ABS(((NSNumber *)self.displayValue).floatValue - self.defaultValue) < FLT_EPSILON);
}

- (void)updatePassParameters
{
    NSNumber *value = (NSNumber *)self.displayValue;
    [(PGPhotoSkinPass *)_pass setIntensity:value.floatValue / 100];
}

- (bool)requiresFaces
{
    return true;
}

@end
