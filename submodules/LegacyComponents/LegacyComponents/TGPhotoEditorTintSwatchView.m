#import "TGPhotoEditorTintSwatchView.h"
#import "TGPhotoEditorInterfaceAssets.h"

const CGFloat TGPhotoEditorTintSwatchRadius = 9.0f;
const CGFloat TGPhotoEditorTintSwatchSelectedRadius = 9.0f;
const CGFloat TGPhotoEditorTintSwatchSelectionRadius = 12.0f;
const CGFloat TGPhotoEditorTintSwatchSelectionThickness = 1.5f;
const CGFloat TGPhotoEditorTintSwatchSize = 25.0f;

@implementation TGPhotoEditorTintSwatchView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.backgroundColor = [UIColor clearColor];
        self.contentMode = UIViewContentModeRedraw;
    }
    return self;
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    bool isClearColor = [self.color isEqual:[UIColor clearColor]];
    UIColor *color = isClearColor ? [UIColor whiteColor] : self.color;
    
    CGContextSetFillColorWithColor(context, color.CGColor);
    CGContextSetStrokeColorWithColor(context, color.CGColor);
    CGContextSetLineWidth(context, TGPhotoEditorTintSwatchSelectionThickness);
    
    if (self.isSelected)
    {
        CGContextFillEllipseInRect(context, CGRectMake(rect.size.width / 2 - TGPhotoEditorTintSwatchSelectedRadius, rect.size.height / 2 - TGPhotoEditorTintSwatchSelectedRadius, TGPhotoEditorTintSwatchSelectedRadius * 2, TGPhotoEditorTintSwatchSelectedRadius * 2));
        
        CGContextSetStrokeColorWithColor(context, [TGPhotoEditorInterfaceAssets accentColor].CGColor);
        CGContextStrokeEllipseInRect(context, CGRectMake(rect.size.width / 2 - TGPhotoEditorTintSwatchSelectionRadius + TGPhotoEditorTintSwatchSelectionThickness / 2, rect.size.height / 2 - TGPhotoEditorTintSwatchSelectionRadius + TGPhotoEditorTintSwatchSelectionThickness / 2, TGPhotoEditorTintSwatchSelectionRadius * 2 - TGPhotoEditorTintSwatchSelectionThickness, TGPhotoEditorTintSwatchSelectionRadius * 2 - TGPhotoEditorTintSwatchSelectionThickness));
    }
    else
    {
        if (isClearColor)
        {
            CGContextStrokeEllipseInRect(context, CGRectMake(rect.size.width / 2 - TGPhotoEditorTintSwatchRadius + TGPhotoEditorTintSwatchSelectionThickness / 2, rect.size.height / 2 - TGPhotoEditorTintSwatchRadius + TGPhotoEditorTintSwatchSelectionThickness / 2, TGPhotoEditorTintSwatchRadius * 2 - TGPhotoEditorTintSwatchSelectionThickness, TGPhotoEditorTintSwatchRadius * 2 - TGPhotoEditorTintSwatchSelectionThickness));
        }
        else
        {
            CGContextFillEllipseInRect(context, CGRectMake(rect.size.width / 2 - TGPhotoEditorTintSwatchRadius, rect.size.height / 2 - TGPhotoEditorTintSwatchRadius, TGPhotoEditorTintSwatchRadius * 2, TGPhotoEditorTintSwatchRadius * 2));
        }
    }
}

- (void)setColor:(UIColor *)color
{
    _color = color;
    
    [self setNeedsDisplay];
}

- (void)setSelected:(bool)selected
{
    [super setSelected:selected];
    
    [self setNeedsDisplay];
}

@end
