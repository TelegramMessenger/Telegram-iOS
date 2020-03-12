#import "PGEnhanceTool.h"

#import "LegacyComponentsInternal.h"

#import "PGPhotoEnhancePass.h"

@implementation PGEnhanceTool

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _identifier = @"enhance";
        _type = PGPhotoToolTypePass;
        _order = 0;
        
        _pass = [[PGPhotoEnhancePass alloc] init];
        
        _minimumValue = 0;
        _maximumValue = 100;
        _defaultValue = 0;
        
        self.value = @(_defaultValue);
    }
    return self;
}

- (NSString *)title
{
    return TGLocalized(@"PhotoEditor.EnhanceTool");
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
    [(PGPhotoEnhancePass *)_pass setIntensity:value.floatValue / 100];
}

@end
