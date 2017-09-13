#import "TGLocationPinAnnotationView.h"

#import "LegacyComponentsInternal.h"
#import "TGFont.h"

#import "TGLocationAnnotation.h"

NSString *const TGLocationPinAnnotationKind = @"TGLocationPinAnnotation";

NSString *const TGLocationETAKey = @"eta";

@interface TGLocationPinAnnotationView ()
{
    UIImageView *_shadowView;
    UIImageView *_backgroundView;
    UIImageView *_iconView;
    UIImageView *_dotView;
}
@end

@implementation TGLocationPinAnnotationView

- (instancetype)initWithAnnotation:(id<MKAnnotation>)annotation reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithAnnotation:annotation reuseIdentifier:reuseIdentifier];
    if (self != nil)
    {
        self.exclusiveTouch = true;
        
        _shadowView = [[UIImageView alloc] initWithImage:TGComponentsImageNamed(@"LocationPinShadow")];
        [self addSubview:_shadowView];
        
        _backgroundView = [[UIImageView alloc] init];
        [self addSubview:_backgroundView];
        
        _iconView = [[UIImageView alloc] init];
        [self addSubview:_iconView];
        
        _dotView = [[UIImageView alloc] init];
        [self addSubview:_dotView];
    }
    return self;
}

- (void)setAnnotation:(id<MKAnnotation>)annotation
{
    
}

#pragma mark - Layout

//- (void)sizeToFit
//{
//    CGRect frame = _calloutWrapper.frame;
//
//    CGSize titleLabelSize = [_titleLabel sizeThatFits:CGSizeMake(214, FLT_MAX)];
//    CGSize subtitleLabelSize = [_subtitleLabel sizeThatFits:CGSizeMake(214, FLT_MAX)];
//    
//    CGFloat labelsWidth = MAX(titleLabelSize.width, subtitleLabelSize.width) + 86;
//    
//    frame.size.width = MIN(300, MAX(labelsWidth, 194));
//    frame.size.height = 46;
//    
//    _calloutWrapper.frame = frame;
//}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    //_view.center = CGPointZero;
}

@end
