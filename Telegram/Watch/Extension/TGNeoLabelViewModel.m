#import "TGNeoLabelViewModel.h"

@implementation TGNeoLabelViewModel

- (instancetype)initWithText:(NSString *)text font:(UIFont *)font color:(UIColor *)color attributes:(NSDictionary *)attributes
{
    self = [super init];
    if (self != nil)
    {
        _text = text;
        _multiline = true;
        
        NSMutableDictionary *finalAttributes = [NSMutableDictionary dictionaryWithDictionary:attributes];
        finalAttributes[NSFontAttributeName] = font;
        finalAttributes[NSForegroundColorAttributeName] = color;
        _attributes = finalAttributes;
    }
    return self;
}

- (instancetype)initWithAttributedText:(NSAttributedString *)attributedText
{
    self = [super init];
    if (self != nil)
    {
        _attributedText = attributedText;
    }
    return self;
}

- (CGSize)contentSizeWithContainerSize:(CGSize)containerSize
{
    NSAttributedString *string = nil;
    
    if (_attributedText != nil)
        string = _attributedText;
    else if (self.text.length > 0)
        string = [[NSAttributedString alloc] initWithString:self.text attributes:_attributes];
    else
        string = [[NSAttributedString alloc] initWithString:@" "];
    
    CGSize contentSize = [string boundingRectWithSize:containerSize options:[self _stringDrawingOptionsForMetrics:true] context:nil].size;
    contentSize.width = ceilf(contentSize.width);
    contentSize.height = ceilf(contentSize.height);

    return contentSize;
}

- (void)drawInContext:(CGContextRef)context
{
    UIGraphicsPushContext(context);
    NSStringDrawingOptions options = [self _stringDrawingOptionsForMetrics:false];
    if (self.attributedText.length > 0)
        [self.attributedText drawWithRect:self.bounds options:options context:nil];
    else if (self.text.length > 0)
        [self.text drawWithRect:self.bounds options:options attributes:self.attributes context:nil];
    UIGraphicsPopContext();
}

- (NSStringDrawingOptions)_stringDrawingOptionsForMetrics:(bool)forMetrics
{
    NSStringDrawingOptions options = kNilOptions;
    if (self.multiline || !forMetrics)
        options |= NSStringDrawingUsesLineFragmentOrigin;
    
    if (!self.multiline)
        options |= NSStringDrawingTruncatesLastVisibleLine;
    
    return options;
}

@end
