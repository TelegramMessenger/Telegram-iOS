#import "TGPhotoEditorBlurTypeButton.h"

#import "TGPhotoEditorInterfaceAssets.h"

@interface TGPhotoEditorBlurTypeButton ()
{
    UIImageView *_imageView;
    UILabel *_titleLabel;
    
    bool _animateHighlight;
}
@end

@implementation TGPhotoEditorBlurTypeButton

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _imageView = [[UIImageView alloc] init];
        _imageView.contentMode = UIViewContentModeCenter;
        [self addSubview:_imageView];
        
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.font = [TGPhotoEditorInterfaceAssets editorItemTitleFont];
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        _titleLabel.textColor = [TGPhotoEditorInterfaceAssets editorItemTitleColor];
        _titleLabel.highlightedTextColor = [TGPhotoEditorInterfaceAssets accentColor];
        [self addSubview:_titleLabel];
    }
    return self;
}

#pragma mark - Properties

- (UIImage *)image
{
    return _imageView.image;
}

- (void)setImage:(UIImage *)image
{
    [_imageView setImage:image];
    
    UIGraphicsBeginImageContextWithOptions(image.size, false, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    [image drawInRect:CGRectMake(0, 0, image.size.width, image.size.height)];
    CGContextSetBlendMode (context, kCGBlendModeSourceAtop);
    CGContextSetFillColorWithColor(context, [TGPhotoEditorInterfaceAssets accentColor].CGColor);
    CGContextFillRect(context, CGRectMake(0, 0, image.size.width, image.size.height));
    
    [_imageView setHighlightedImage:UIGraphicsGetImageFromCurrentImageContext()];
    
    UIGraphicsEndImageContext();
}

- (NSString *)title
{
    return _titleLabel.text;
}

- (void)setTitle:(NSString *)title
{
    _titleLabel.text = title;
}

#pragma mark - Highlight

- (void)setSelected:(BOOL)selected
{
    [super setSelected:selected];
    
    _imageView.highlighted = selected;
    _titleLabel.highlighted = selected;
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    _animateHighlight = true;
    [super touchesMoved:touches withEvent:event];
    _animateHighlight = false;
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    _animateHighlight = true;
    [super touchesCancelled:touches withEvent:event];
    _animateHighlight = false;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    _animateHighlight = true;
    [super touchesEnded:touches withEvent:event];
    _animateHighlight = false;
}

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];
    
    CGFloat alpha = (highlighted ? 0.4f : 1.0f) * (self.enabled ? 1.0f : 0.5f);
    
    if (ABS(alpha - self.alpha) > FLT_EPSILON)
    {
        if (_animateHighlight)
        {
            [UIView animateWithDuration:0.2 animations:^
            {
                self.alpha = alpha;
            }];
        }
        else
            self.alpha = alpha;
    }
}

#pragma mark - Layout

- (void)layoutSubviews
{
    _imageView.frame = CGRectMake((self.frame.size.width - 50) / 2, (self.frame.size.height - 68) / 2, 50, 50);
    _titleLabel.frame = CGRectMake(0, _imageView.frame.origin.y + _imageView.frame.size.height - 1, self.frame.size.width, 16);
}

@end
