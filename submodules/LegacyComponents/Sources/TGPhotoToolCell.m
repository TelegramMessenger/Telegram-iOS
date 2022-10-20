#import "TGPhotoToolCell.h"

#import "PGPhotoTool.h"

#import "TGPhotoEditorGenericToolView.h"
#import "TGPhotoEditorInterfaceAssets.h"

NSString * const TGPhotoToolCellKind = @"TGPhotoToolCellKind";

@interface TGPhotoToolCell ()
{
    UIView <TGPhotoEditorToolView> *_toolView;
}
@end

@implementation TGPhotoToolCell

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {        

    }
    return self;
}

- (void)prepareForReuse
{
    [_toolView removeFromSuperview];
    _toolView = nil;

    [super prepareForReuse];
}

- (void)setPhotoTool:(PGPhotoTool *)photoTool landscape:(bool)landscape nameWidth:(CGFloat)nameWidth changeBlock:(void (^)(PGPhotoTool *, id, bool))changeBlock interactionBegan:(void (^)(void))interactionBegan interactionEnded:(void (^)(void))interactionEnded
{
    void (^block)(id, bool) = ^(id newValue, bool animated)
    {
        changeBlock(photoTool, newValue, animated);
    };
    
    _toolView = [photoTool itemControlViewWithChangeBlock:block explicit:true nameWidth:nameWidth];
    _toolView.isLandscape = landscape;
    _toolView.interactionBegan = interactionBegan;
    _toolView.interactionEnded = interactionEnded;
    [self addSubview:_toolView];
    
    [self setNeedsLayout];
}

- (bool)isTracking
{
    return _toolView.isTracking;
}

- (void)setSelected:(BOOL)__unused selected
{

}

- (void)setHighlighted:(BOOL)__unused highlighted
{

}

- (void)layoutSubviews
{
    _toolView.frame = CGRectMake(0.0f, 0.0f, self.frame.size.width, self.frame.size.height);
}

@end
