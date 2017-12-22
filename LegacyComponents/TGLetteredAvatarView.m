#import "TGLetteredAvatarView.h"

#import "LegacyComponentsInternal.h"
#import "TGFont.h"
#import "TGImageUtils.h"

#import <LegacyComponents/TGImageManager.h>
#import "TGGradientLabel.h"

@interface TGLetteredAvatarView ()
{
    TGGradientLabel *_label;
    
    UIFont *_singleFont;
    UIFont *_doubleFont;
    bool _usingSingleFont;
    CGFloat _singleSize;
    CGFloat _doubleSize;
}

@end

@implementation TGLetteredAvatarView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        if (iosMajorVersion() >= 11)
            self.accessibilityIgnoresInvertColors = true;
        
        _label = [[TGGradientLabel alloc] init];
        _label.backgroundColor = [UIColor clearColor];
        [self addSubview:_label];
    }
    return self;
}

- (void)setSingleFontSize:(CGFloat)singleFontSize doubleFontSize:(CGFloat)doubleFontSize useBoldFont:(bool)__unused useBoldFont
{
    if (ABS(singleFontSize - _singleSize) < FLT_EPSILON && ABS(doubleFontSize - _doubleSize) < FLT_EPSILON)
        return;
    
    _singleSize = singleFontSize;
    _doubleSize = doubleFontSize;
    
    _singleFont = [TGFont roundedFontOfSize:singleFontSize];
    _doubleFont = _singleFont;
}

- (void)loadImage:(UIImage *)image
{
    _label.hidden = true;
    
    [super loadImage:image];
}

- (void)loadImage:(NSString *)url filter:(NSString *)filter placeholder:(UIImage *)placeholder forceFade:(bool)forceFade
{
    _label.hidden = true;
    
    [super loadImage:url filter:filter placeholder:placeholder forceFade:forceFade];
}

static bool isEmojiCharacter(NSString *singleChar)
{
    const unichar high = [singleChar characterAtIndex:0];
    
    if (0xd800 <= high && high <= 0xdbff && singleChar.length >= 2)
    {
        const unichar low = [singleChar characterAtIndex:1];
        const int codepoint = ((high - 0xd800) * 0x400) + (low - 0xdc00) + 0x10000;
        
        return (0x1d000 <= codepoint && codepoint <= 0x1f77f);
    }
    
    return (0x2100 <= high && high <= 0x27bf);
}

- (NSString *)_cleanedUpString:(NSString *)string
{
    NSMutableString *__block buffer = [NSMutableString stringWithCapacity:string.length];
    
    [string enumerateSubstringsInRange:NSMakeRange(0, string.length)
                               options:NSStringEnumerationByComposedCharacterSequences
                            usingBlock: ^(NSString* substring, __unused NSRange substringRange, __unused NSRange enclosingRange, __unused BOOL* stop)
     {
         [buffer appendString:isEmojiCharacter(substring) ? @"" : substring];
     }];
    
    return buffer;
}

- (void)setFirstName:(NSString *)firstName lastName:(NSString *)lastName
{
    if (!_label.hidden)
    {
        NSString *cleanFirstName = [self _cleanedUpString:firstName];
        NSString *cleanLastName = [self _cleanedUpString:lastName];
        
        if (cleanFirstName.length != 0 && cleanLastName.length != 0)
            _label.text = [[NSString alloc] initWithFormat:@"%@\u200B%@", [cleanFirstName substringToIndex:1], [cleanLastName substringToIndex:1]];
        else if (cleanFirstName.length != 0)
            _label.text = [cleanFirstName substringToIndex:1];
        else if (cleanLastName.length != 0)
            _label.text = [cleanLastName substringToIndex:1];
        else
            _label.text = @" ";
        
        if (cleanFirstName.length != 0 && cleanLastName.length != 0)
        {
            _label.text = [[NSString alloc] initWithFormat:@"%@\u200B%@", [cleanFirstName substringToIndex:1], [cleanLastName substringToIndex:1]];
        }
        else if (cleanFirstName.length != 0)
        {
            _label.text = [cleanFirstName substringToIndex:1];
        }
        else if (cleanLastName.length != 0)
        {
            _label.text = [cleanLastName substringToIndex:1];
        }
        else
            _label.text = @" ";
        
        [_label sizeToFit];
        CGSize labelSize = _label.frame.size;
        CGSize boundsSize = self.bounds.size;
        labelSize.height = boundsSize.height;
        _label.frame = CGRectMake(TGRetinaFloor((boundsSize.width - labelSize.width) / 2.0f), CGFloor((boundsSize.height - labelSize.height) / 2.0f), labelSize.width, labelSize.height);
    }
}

- (void)setTitle:(NSString *)title
{
    NSString *cleanTitle = [self _cleanedUpString:title];
    _label.text = cleanTitle.length >= 1 ? [cleanTitle substringToIndex:1] : @" ";
    
    [_label sizeToFit];
    [self setNeedsLayout];
}

- (void)setTitleNeedsDisplay
{
    if (!_label.hidden)
        [_label setNeedsDisplay];
}

- (void)loadSavedMessagesWithSize:(CGSize)size placeholder:(UIImage *)placeholder
{
    _label.text = @"";
    
    NSString *placeholderUri = [[NSString alloc] initWithFormat:@"placeholder://?type=saved-messages&w=%d&h=%d" PRId32 "", (int)size.width, (int)size.height];
    if (!TGStringCompare([self currentUrl], placeholderUri))
        [super loadImage:placeholderUri filter:nil placeholder:placeholder];
    
    _label.hidden = true;
}

- (void)loadUserPlaceholderWithSize:(CGSize)size uid:(int)uid firstName:(NSString *)firstName lastName:(NSString *)lastName placeholder:(UIImage *)placeholder
{
    _label.font = _doubleFont;
    _usingSingleFont = false;
    
    NSString *cleanFirstName = [self _cleanedUpString:firstName];
    NSString *cleanLastName = [self _cleanedUpString:lastName];
    
    if (cleanFirstName.length != 0 && cleanLastName.length != 0)
    {
        _label.text = [[NSString alloc] initWithFormat:@"%@\u200B%@", [cleanFirstName substringToIndex:1], [cleanLastName substringToIndex:1]];
    }
    else if (cleanFirstName.length != 0)
    {
        _label.text = [cleanFirstName substringToIndex:1];
    }
    else if (cleanLastName.length != 0)
    {
        _label.text = [cleanLastName substringToIndex:1];
    }
    else
        _label.text = @" ";
    
    _label.textColor = [UIColor whiteColor];
    
    [_label sizeToFit];
    [self setNeedsLayout];
    
    NSString *placeholderUri = [[NSString alloc] initWithFormat:@"placeholder://?type=user-avatar&w=%d&h=%d&uid=%" PRId32 "", (int)size.width, (int)size.height, (int32_t)uid];
    if (!TGStringCompare([self currentUrl], placeholderUri))
        [super loadImage:placeholderUri filter:nil placeholder:placeholder];
    
    _label.hidden = false;
}

typedef struct
{
    int top;
    int bottom;
} TGGradientColors;

- (void)loadGroupPlaceholderWithSize:(CGSize)size conversationId:(int64_t)conversationId title:(NSString *)title placeholder:(UIImage *)placeholder
{
    _label.font = _singleFont;
    _usingSingleFont = true;
    
    NSString *cleanTitle = [self _cleanedUpString:title];
    _label.text = cleanTitle.length >= 1 ? [cleanTitle substringToIndex:1] : @" ";
    
    if (conversationId == 0)
        _label.textColor = [UIColor whiteColor];
    else
        _label.textColor = [UIColor whiteColor];
    
    [_label sizeToFit];
    CGSize labelSize = _label.frame.size;
    CGSize boundsSize = self.bounds.size;
    labelSize.height = boundsSize.height;
    _label.frame = CGRectMake(TGRetinaFloor((boundsSize.width - labelSize.width) / 2.0f), CGFloor((boundsSize.height - labelSize.height) / 2.0f), labelSize.width, labelSize.height);
    
    [super loadImage:[[NSString alloc] initWithFormat:@"placeholder://?type=group-avatar&w=%d&h=%d&cid=%" PRId64 "", (int)size.width, (int)size.height, conversationId] filter:nil placeholder:placeholder];
    
    _label.hidden = false;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGSize labelSize = _label.frame.size;
    CGSize boundsSize = self.bounds.size;
    labelSize.height = boundsSize.height;
    _label.frame = CGRectMake(TGScreenPixelFloor((boundsSize.width - labelSize.width) / 2.0f), TGScreenPixelFloor((boundsSize.height - labelSize.height) / 2.0f), labelSize.width, labelSize.height);
}

@end
