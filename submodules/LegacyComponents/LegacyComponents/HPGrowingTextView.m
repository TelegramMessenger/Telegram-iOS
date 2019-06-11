#import "HPGrowingTextView.h"

#import "LegacyComponentsInternal.h"
#import "TGFont.h"

#import "HPTextViewInternal.h"

#import "TGInputTextTag.h"

#import "TGMessage.h"

#import "TGColor.h"

NSString *TGMentionUidAttributeName = @"TGMentionUidAttributeName";
NSString *TGMentionBoldAttributeName = @"TGMentionBoldAttributeName";

@implementation TGAttributedTextRange

- (instancetype)initWithAttachment:(id)attachment {
    self = [super init];
    if (self != nil) {
        _attachment = attachment;
    }
    return self;
}

@end

@interface HPGrowingTextView ()
{
    UIColor *_intrinsicTextColor;
    UIFont *_intrinsicTextFont;
    
    __weak TGKeyCommandController *_keyCommandController;
}

@end

@implementation HPGrowingTextView

- (instancetype)initWithKeyCommandController:(TGKeyCommandController *)keyCommandController
{
    self = [super initWithFrame:CGRectZero];
    if (self != nil)
    {
        _keyCommandController = keyCommandController;
        
        [self commonInitialiser];
    }
    return self;
}

- (NSDictionary *)defaultAttributes {
    if (_intrinsicTextFont == nil) {
        return @{NSFontAttributeName: TGSystemFontOfSize(17)};
    } else {
        if (_intrinsicTextColor)
            return @{NSFontAttributeName: _intrinsicTextFont, NSForegroundColorAttributeName: _intrinsicTextColor};
        else
            return @{NSFontAttributeName: _intrinsicTextFont};
    }
}

- (void)commonInitialiser
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        [HPTextViewInternal addTextViewMethods];
    });
    
    CGRect frame = self.frame;
    frame.origin = CGPointZero;
    _internalTextView = [[HPTextViewInternal alloc] initWithKeyCommandController:_keyCommandController];
    _internalTextView.frame = frame;
    _internalTextView.delegate = self;
    _internalTextView.contentInset = UIEdgeInsetsZero;
    _internalTextView.showsHorizontalScrollIndicator = NO;
    _internalTextView.attributedText = [[NSAttributedString alloc] initWithString:@"-" attributes:[self defaultAttributes]];
    _internalTextView.scrollsToTop = false;
    if (iosMajorVersion() >= 7) {
        _internalTextView.textContainer.layoutManager.allowsNonContiguousLayout = true;
        _internalTextView.allowsEditingTextAttributes = true;
    }
    [self addSubview:_internalTextView];
    
    _minHeight = _internalTextView.frame.size.height;
    _minNumberOfLines = 1;
    
    _animateHeightChange = true;
    _animationDuration = 0.1f;
    
    _internalTextView.attributedText = [[NSAttributedString alloc] initWithString:@"" attributes:[self defaultAttributes]];
}

- (void)setDisableFormatting:(bool)disableFormatting
{
    _disableFormatting = disableFormatting;
    if (iosMajorVersion() >= 7)
        _internalTextView.allowsEditingTextAttributes = !disableFormatting;
}

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    
    frame.origin = CGPointZero;
    _internalTextView.frame = frame;
}

- (CGSize)sizeThatFits:(CGSize)size
{
    if (self.attributedText.length == 0)
        size.height = _minHeight;
    
    return size;
}

- (void)setMaxNumberOfLines:(int)maxNumberOfLines
{
    if (maxNumberOfLines == 0 && _maxHeight > 0) // the user specified a maxHeight themselves.
        return;
    
    // Use internalTextView for height calculations, thanks to Gwynne <http://blog.darkrainfall.org/>
    NSAttributedString *saveText = _internalTextView.attributedText;
    NSMutableAttributedString *newText = [[NSMutableAttributedString alloc] initWithString:@"-" attributes:[self defaultAttributes]];
    
    _internalTextView.delegate = nil;
    _internalTextView.hidden = YES;
    
    for (int i = 1; i < maxNumberOfLines; ++i) {
        [newText appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n|W|"]];
    }
    
    _internalTextView.attributedText = newText;
    
    _maxHeight = [self measureHeight];
    
    _internalTextView.attributedText = saveText;
    _internalTextView.hidden = NO;
    _internalTextView.delegate = self;
    
    [self sizeToFit];
    
    _maxNumberOfLines = maxNumberOfLines;
}

- (void)setMaxHeight:(CGFloat)maxHeight
{
    _maxHeight = maxHeight;
    _maxNumberOfLines = 0;
}

- (void)setMinNumberOfLines:(int)minNumberOfLines
{
    if (minNumberOfLines == 0 && _minHeight > 0) // the user specified a minHeight themselves.
        return;

	// Use internalTextView for height calculations, thanks to Gwynne <http://blog.darkrainfall.org/>
    NSAttributedString *saveText = _internalTextView.attributedText;
    NSMutableAttributedString *newText = [[NSMutableAttributedString alloc] initWithString:@"-" attributes:[self defaultAttributes]];
    
    _internalTextView.delegate = nil;
    _internalTextView.hidden = YES;
    
    for (int i = 1; i < minNumberOfLines; ++i) {
        [newText appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n|W|"]];
    }
    
    _internalTextView.attributedText = newText;
    
    _minHeight = [self measureHeight];
    
    _internalTextView.attributedText = saveText;
    _internalTextView.hidden = NO;
    _internalTextView.delegate = self;
    
    [self sizeToFit];
    
    _minNumberOfLines = minNumberOfLines;
}

- (void)setMinHeight:(CGFloat)minHeight
{
    _minHeight = minHeight;
    _minNumberOfLines = 0;
}

- (void)textViewDidChange:(UITextView *)__unused textView
{
    [self refreshAttributes];
    
    [self refreshHeight:true];
    if (self.showPlaceholderWhenFocussed)
        _placeholderView.hidden = [_internalTextView hasText];
}

- (void)textViewDidChangeSelection:(UITextView *)__unused textView
{
    id<HPGrowingTextViewDelegate> delegate = _delegate;
    
    if ([delegate respondsToSelector:@selector(growingTextViewDidChangeSelection:)])
        [delegate growingTextViewDidChangeSelection:self];
    
    //_internalTextView.typingAttributes = [self defaultAttributes];
    
    if ([_internalTextView selectedRange].length == 0) {
        //[self refreshAttributes];
    }
}

- (void)refreshHeight:(bool)textChanged
{
    CGFloat newSizeH = [self measureHeight]; //size of content, so we can set the frame of self
    
    if(newSizeH < _minHeight || !_internalTextView.hasText)
        newSizeH = _minHeight; //not smalles than minHeight
    
    if (_internalTextView.frame.size.height > _maxHeight)
        newSizeH = _maxHeight; // not taller than maxHeight
    
    id<HPGrowingTextViewDelegate> delegate = _delegate;

	if (ABS(_internalTextView.frame.size.height - newSizeH) > FLT_EPSILON || _oneTimeLongAnimation)
	{
        // [fixed] Pasting too much text into the view failed to fire the height change, 
        // thanks to Gwynne <http://blog.darkrainfall.org/>
        
        if (newSizeH > _maxHeight && _internalTextView.frame.size.height <= _maxHeight)
            newSizeH = _maxHeight;
        
		if (newSizeH <= _maxHeight)
		{
            if (_animateHeightChange && !_internalTextView.isPasting)
            {
                NSTimeInterval currentAnimationDuration = 0.12;
                if (_oneTimeLongAnimation)
                {
                    _oneTimeLongAnimation = false;
                    currentAnimationDuration = 0.3;
                    if (iosMajorVersion() < 7)
                        currentAnimationDuration *= 0.7;
                }
                
                [UIView animateWithDuration:currentAnimationDuration delay:0 options:(UIViewAnimationOptionAllowUserInteraction| UIViewAnimationOptionBeginFromCurrentState) animations:^
                {
                    [self resizeTextView:newSizeH];
                } completion:nil];
                
                if ([delegate respondsToSelector:@selector(growingTextView:willChangeHeight:duration:animationCurve:)])
                    [delegate growingTextView:self willChangeHeight:newSizeH duration:currentAnimationDuration animationCurve:0];
            }
            else
            {
                [self resizeTextView:newSizeH];
                
                if ([delegate respondsToSelector:@selector(growingTextView:willChangeHeight:duration:animationCurve:)])
                    [delegate growingTextView:self willChangeHeight:newSizeH duration:0.0 animationCurve:0];
            }
		}
		
        // scroll to caret (needed on iOS7)
        if (iosMajorVersion() >= 7)
        {
            /*NSRange range = _internalTextView.selectedRange;
            [_internalTextView _scrollRangeToVisible:range animated:false];
            
            CGRect r = [_internalTextView caretRectForPosition:_internalTextView.selectedTextRange.end];
            CGFloat frameHeight = _internalTextView.frame.size.height;
            CGFloat caretY = MAX(r.origin.y - frameHeight + r.size.height + 8, 0);
            if (r.origin.y != INFINITY)
            {
                CGPoint contentOffset = _internalTextView.contentOffset;
                contentOffset.y = caretY;
                _internalTextView.contentOffset = contentOffset;
            }*/
        }
	}
	
    if (textChanged && [delegate respondsToSelector:@selector(growingTextViewDidChange:afterSetText:afterPastingText:)]) {
		[delegate growingTextViewDidChange:self afterSetText:_ignoreChangeNotification afterPastingText:_internalTextView.isPasting];
    }

    _oneTimeLongAnimation = false;
}

- (void)notifyHeight {
    id<HPGrowingTextViewDelegate> delegate = _delegate;
    if ([delegate respondsToSelector:@selector(growingTextView:willChangeHeight:duration:animationCurve:)])
        [delegate growingTextView:self willChangeHeight:_internalTextView.frame.size.height duration:0.0 animationCurve:0];
}

// Code from apple developer forum - @Steve Krulewitz, @Mark Marszal, @Eric Silverberg
- (CGFloat)measureHeight
{
    if (iosMajorVersion() >= 7)
    {
        CGRect frame = _internalTextView.bounds;
        CGSize fudgeFactor = CGSizeMake(10.0, 17.0);
        
        frame.size.height -= fudgeFactor.height;
        frame.size.width -= fudgeFactor.width;
        
        frame.size.width -= _internalTextView.textContainerInset.right;
        
        NSMutableAttributedString *textToMeasure = [[NSMutableAttributedString alloc] initWithAttributedString:_internalTextView.attributedText];
        if ([textToMeasure.string hasSuffix:@"\n"])
        {
            [textToMeasure appendAttributedString:[[NSAttributedString alloc] initWithString:@"-"]];
        }
        [textToMeasure removeAttribute:NSFontAttributeName range:NSMakeRange(0, textToMeasure.length)];
        if (_intrinsicTextFont != nil) {
            [textToMeasure addAttribute:NSFontAttributeName value:_intrinsicTextFont range:NSMakeRange(0, textToMeasure.length)];
        }
        
        // NSString class method: boundingRectWithSize:options:attributes:context is
        // available only on ios7.0 sdk.
        CGRect size = [textToMeasure boundingRectWithSize:CGSizeMake(CGRectGetWidth(frame), MAXFLOAT)
                                                  options:NSStringDrawingUsesLineFragmentOrigin
                                               //attributes:attributes
                                                  context:nil];
        
        return CGFloor(CGRectGetHeight(size) + fudgeFactor.height);
    }
    else
    {
        return CGFloor(self.internalTextView.contentSize.height);
    }
}

- (void)resizeTextView:(CGFloat)newSizeH
{
    CGRect internalTextViewFrame = self.frame;
    internalTextViewFrame.size.height = CGFloor(newSizeH);
    self.frame = internalTextViewFrame;
    
    internalTextViewFrame.origin = CGPointZero;
    if(!CGRectEqualToRect(_internalTextView.frame, internalTextViewFrame))
        _internalTextView.frame = internalTextViewFrame;
    
    //[_internalTextView textViewEnsureSelectionVisible];
}

- (BOOL)becomeFirstResponder
{
    return [_internalTextView becomeFirstResponder];
}

- (BOOL)resignFirstResponder
{
	return [_internalTextView resignFirstResponder];
}

- (BOOL)isFirstResponder
{
    return [_internalTextView isFirstResponder];
}

- (BOOL)canBecomeFirstResponder
{
    return [_internalTextView canBecomeFirstResponder];
}

- (void)setText:(NSString *)newText
{
    [self setText:newText animated:true];
}

- (void)setAttributedText:(NSAttributedString *)attributedText {
    [self setAttributedText:attributedText animated:true];
}

- (NSAttributedString *)attributedText {
    return _internalTextView.attributedText;
}

- (void)setText:(NSString *)newText animated:(bool)animated {
    [self setAttributedText:[[NSAttributedString alloc] initWithString:newText == nil ? @"" : newText attributes:[self defaultAttributes]] animated:animated];
}

- (void)setAttributedText:(NSAttributedString *)newText animated:(bool)animated {
    [self setAttributedText:newText keepFormatting:false animated:animated];
}

- (void)setAttributedText:(NSAttributedString *)newText keepFormatting:(bool)keepFormatting animated:(bool)animated {
    NSMutableAttributedString *fixedFontString = [[NSMutableAttributedString alloc] initWithAttributedString:newText];
    if (!keepFormatting)
    {
        [fixedFontString removeAttribute:NSFontAttributeName range:NSMakeRange(0, fixedFontString.length)];
        [fixedFontString addAttribute:NSFontAttributeName value:_intrinsicTextFont == nil ? [UIFont systemFontOfSize:17.0f] : _intrinsicTextFont range:NSMakeRange(0, fixedFontString.length)];
    }
    
    _internalTextView.attributedText = fixedFontString;
    _internalTextView.typingAttributes = [self defaultAttributes];
    [self refreshAttributes];
    
    _placeholderView.hidden = fixedFontString.length != 0 || [_internalTextView isFirstResponder];
    
    // include this line to analyze the height of the textview.
    // fix from Ankit Thakur
    
    bool previousAnimateHeightChange = _animateHeightChange;
    _animateHeightChange = animated;
    _ignoreChangeNotification = true;
    [self performSelector:@selector(textViewDidChange:) withObject:_internalTextView];
    _ignoreChangeNotification = false;
    _animateHeightChange = previousAnimateHeightChange;
}

- (void)selectRange:(NSRange)range force:(bool)force {
    if (range.length != 0 || force) {
        UITextPosition *startPosition = [_internalTextView positionFromPosition:_internalTextView.beginningOfDocument offset:range.location];
        UITextPosition *endPosition = [_internalTextView positionFromPosition:_internalTextView.beginningOfDocument offset:range.location + range.length];
        UITextRange *selection = [_internalTextView textRangeFromPosition:startPosition toPosition:endPosition];
        _internalTextView.selectedTextRange = selection;
    }
}

-(NSString *)text
{
    return _internalTextView.text;
}

- (void)setFont:(UIFont *)afont
{
	_internalTextView.font = afont;
    _intrinsicTextFont = afont;
	
	[self setMaxNumberOfLines:_maxNumberOfLines];
	[self setMinNumberOfLines:_minNumberOfLines];
}

- (UIFont *)font
{
    return _intrinsicTextFont;
}

- (void)setTextColor:(UIColor *)color
{
	_internalTextView.textColor = color;
    _intrinsicTextColor = color;
}

- (UIColor *)textColor
{
	return _internalTextView.textColor;
}

- (UIColor *)accentColor
{
    if (_accentColor != nil)
        return _accentColor;
    
    return TGAccentColor();
}

- (void)setTextAlignment:(NSTextAlignment)aligment
{
	_internalTextView.textAlignment = aligment;
}

- (NSTextAlignment)textAlignment
{
	return _internalTextView.textAlignment;
}

#pragma mark -

- (BOOL)textViewShouldBeginEditing:(UITextView *)__unused textView
{
    id<HPGrowingTextViewDelegate> delegate = _delegate;
    
    if ([delegate respondsToSelector:@selector(growingTextViewShouldBeginEditing:)])
        return [delegate growingTextViewShouldBeginEditing:self];
    
    return true;
}

- (void)textViewDidBeginEditing:(UITextView *)__unused textView
{
    id<HPGrowingTextViewDelegate> delegate = _delegate;
    
	if ([delegate respondsToSelector:@selector(growingTextViewDidBeginEditing:)])
		[delegate growingTextViewDidBeginEditing:self];
    
    if (!self.showPlaceholderWhenFocussed && ![_internalTextView hasText])
        _placeholderView.hidden = true;
}

- (void)textViewDidEndEditing:(UITextView *)__unused textView
{
    id<HPGrowingTextViewDelegate> delegate = _delegate;
    
	if ([delegate respondsToSelector:@selector(growingTextViewDidEndEditing:)])
		[delegate growingTextViewDidEndEditing:self];
    
    if (!self.showPlaceholderWhenFocussed)
        _placeholderView.hidden = [_internalTextView hasText];
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)atext
{
    id<HPGrowingTextViewDelegate> delegate = _delegate;
    
    if ([delegate respondsToSelector:@selector(growingTextViewEnabled:)]) {
        if (![delegate growingTextViewEnabled:self]) {
            return false;
        }
    }
    
	if (![textView hasText] && [atext isEqualToString:@""])
        return NO;
	
	if ([atext isEqualToString:@"\n"])
    {
        id<HPGrowingTextViewDelegate> delegate = _delegate;
        
		if ([delegate respondsToSelector:@selector(growingTextViewShouldReturn:)])
            return (BOOL)[delegate performSelector:@selector(growingTextViewShouldReturn:) withObject:self];
	}
    
    if (atext.length == 0) {
        if (range.location != 0 && range.length == 1) {
            NSAttributedString *string = self.attributedText;
            if ([string attributesAtIndex:range.location effectiveRange:nil][NSAttachmentAttributeName] != nil) {
                NSMutableAttributedString *mutableString = [[NSMutableAttributedString alloc] initWithAttributedString:string];
                [mutableString replaceCharactersInRange:NSMakeRange(range.location - 1, 1) withString:@""];
                NSRange badRange = [mutableString.string rangeOfString:@"\uFFFC"];
                if (badRange.location != NSNotFound)
                    [mutableString replaceCharactersInRange:badRange withString:@""];
                self.attributedText = mutableString;
                
                return false;
            }
        }
    } else if (range.length == 0) {
        NSAttributedString *string = self.attributedText;
        if (range.location != 0 && [string attributesAtIndex:range.location - 1 effectiveRange:nil][NSAttachmentAttributeName] != nil) {
            NSMutableAttributedString *mutableString = [[NSMutableAttributedString alloc] initWithAttributedString:string];
            [mutableString replaceCharactersInRange:NSMakeRange(range.location - 1, 0) withString:atext];
            NSRange badRange = [mutableString.string rangeOfString:@"\uFFFC"];
            if (badRange.location != NSNotFound)
                [mutableString replaceCharactersInRange:badRange withString:@""];
            self.attributedText = mutableString;
            
            return false;
        }
    }
	
    return true;
}

- (void)keyCommandPressed:(UIKeyCommand *)keyCommand
{
    id<HPGrowingTextViewDelegate> delegate = _delegate;
    
    if ([delegate respondsToSelector:@selector(growingTextView:receivedReturnKeyCommandWithModifierFlags:)])
        [delegate growingTextView:self receivedReturnKeyCommandWithModifierFlags:keyCommand.modifierFlags];
}

- (NSArray *)keyCommands
{
    if (!self.receiveKeyCommands)
        return nil;
    
    return @
    [
     [UIKeyCommand keyCommandWithInput:@"\r" modifierFlags:0 action:@selector(keyCommandPressed:)],
     [UIKeyCommand keyCommandWithInput:@"\r" modifierFlags:UIKeyModifierAlternate action:@selector(keyCommandPressed:)]
    ];
}

- (void)refreshAttributes {
    if (iosMajorVersion() < 7) {
        return;
    }
    
    self.internalTextView.typingAttributes = [self defaultAttributes];
    
    NSAttributedString *string = self.attributedText;
    if (string.length == 0) {
        return;
    }
    
    CGPoint contentOffset = _internalTextView.contentOffset;
    [_internalTextView setScrollEnabled:false];
    _internalTextView.disableContentOffsetAnimation = true;
    _internalTextView.freezeContentOffset = true;
    
    //NSMutableAttributedString *mutableString = [[NSMutableAttributedString alloc] initWithAttributedString:string];
    //[mutableString removeAttribute:NSForegroundColorAttributeName range:NSMakeRange(0, string.length)];
    [_internalTextView.textStorage removeAttribute:NSForegroundColorAttributeName range:NSMakeRange(0, string.length)];
    
    if (_intrinsicTextColor != nil) {
        //[mutableString addAttribute:NSForegroundColorAttributeName value:_intrinsicTextColor == nil ? [UIColor blackColor] : _intrinsicTextColor range:NSMakeRange(0, string.length)];
        [_internalTextView.textStorage addAttribute:NSForegroundColorAttributeName value:_intrinsicTextColor == nil ? [UIColor blackColor] : _intrinsicTextColor range:NSMakeRange(0, string.length)];
    }

    __block NSMutableArray<TGInputTextTagAndRange *> *inputTextTags = [[NSMutableArray alloc] init];
    [string enumerateAttribute:TGMentionUidAttributeName inRange:NSMakeRange(0, string.length) options:0 usingBlock:^(__unused id value, NSRange range, __unused BOOL *stop) {
        if ([value isKindOfClass:[TGInputTextTag class]]) {
            [inputTextTags addObject:[[TGInputTextTagAndRange alloc] initWithTag:value range:range]];
        }
    }];
    
    [string enumerateAttribute:TGMentionBoldAttributeName inRange:NSMakeRange(0, string.length) options:0 usingBlock:^(__unused id value, NSRange range, __unused BOOL *stop) {
        if ([value isKindOfClass:[TGInputTextTag class]]) {
            [inputTextTags addObject:[[TGInputTextTagAndRange alloc] initWithTag:value range:range]];
        }
    }];
    
    if (inputTextTags != nil) {
        /*if (mutableString == nil) {
            mutableString = [[NSMutableAttributedString alloc] initWithAttributedString:string];
        }*/
        
        static NSCharacterSet *alphanumericSet = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            alphanumericSet = [NSCharacterSet alphanumericCharacterSet];
        });
        
        NSMutableSet<NSNumber *> *removeTags = [[NSMutableSet alloc] init];
        for (NSInteger i = 0; i < ((NSInteger)inputTextTags.count); i++) {
            TGInputTextTagAndRange *tagAndRange = inputTextTags[i];
            if ([removeTags containsObject:@(tagAndRange.tag.uniqueId)]) {
                [inputTextTags removeObjectAtIndex:i];
                //[mutableString removeAttribute:TGMentionUidAttributeName range:tagAndRange.range];
                [_internalTextView.textStorage removeAttribute:TGMentionUidAttributeName range:tagAndRange.range];
                
                i--;
            } else {
                NSInteger j = tagAndRange.range.location;
                while (j < (NSInteger)(tagAndRange.range.location + tagAndRange.range.length)) {
                    unichar c = [string.string characterAtIndex:j];
                    if (c != ' ') {
                        break;
                    }
                    j++;
                }
                
                if (j != (NSInteger)tagAndRange.range.location) {
                    NSRange updatedRange = NSMakeRange(j, tagAndRange.range.location + tagAndRange.range.length - j);
                    //[mutableString removeAttribute:TGMentionUidAttributeName range:tagAndRange.range];
                    [_internalTextView.textStorage removeAttribute:TGMentionUidAttributeName range:tagAndRange.range];
                    
                    //[mutableString addAttribute:TGMentionUidAttributeName value:tagAndRange.tag range:updatedRange];
                    [_internalTextView.textStorage addAttribute:TGMentionUidAttributeName value:tagAndRange.tag range:updatedRange];
                    
                    inputTextTags[i] = [[TGInputTextTagAndRange alloc] initWithTag:tagAndRange.tag range:updatedRange];
                    
                    i--;
                } else {
                    NSInteger j = tagAndRange.range.location;
                    while (j >= 0) {
                        unichar c = [string.string characterAtIndex:j];
                        if (![alphanumericSet characterIsMember:c]) {
                            break;
                        }
                        j--;
                    }
                    j++;
                    
                    if (j < ((NSInteger)tagAndRange.range.location)) {
                        NSRange updatedRange = NSMakeRange(j, tagAndRange.range.location + tagAndRange.range.length - j);
                        //[mutableString removeAttribute:TGMentionUidAttributeName range:tagAndRange.range];
                        [_internalTextView.textStorage removeAttribute:TGMentionUidAttributeName range:tagAndRange.range];
                        
                        //[mutableString addAttribute:TGMentionUidAttributeName value:tagAndRange.tag range:updatedRange];
                        [_internalTextView.textStorage addAttribute:TGMentionUidAttributeName value:tagAndRange.tag range:updatedRange];
                         
                        inputTextTags[i] = [[TGInputTextTagAndRange alloc] initWithTag:tagAndRange.tag range:updatedRange];
                        
                        i--;
                    } else {
                        TGInputTextTagAndRange *nextTagAndRange = nil;
                        if (i != ((NSInteger)inputTextTags.count) - 1) {
                            nextTagAndRange = inputTextTags[i + 1];
                        }
                        
                        if (nextTagAndRange == nil || nextTagAndRange.tag.uniqueId != tagAndRange.tag.uniqueId) {
                            NSInteger candidateStart = tagAndRange.range.location + tagAndRange.range.length;
                            NSInteger candidateEnd = nextTagAndRange == nil ? string.length : nextTagAndRange.range.location;
                            NSInteger j = candidateStart;
                            while (j < candidateEnd) {
                                unichar c = [string.string characterAtIndex:j];
                                static NSCharacterSet *alphanumericSet = nil;
                                static dispatch_once_t onceToken;
                                dispatch_once(&onceToken, ^{
                                    alphanumericSet = [NSCharacterSet alphanumericCharacterSet];
                                });
                                if (![alphanumericSet characterIsMember:c]) {
                                    break;
                                }
                                j++;
                            }
                            
                            if (j == candidateStart) {
                                [removeTags addObject:@(tagAndRange.tag.uniqueId)];
                                //[mutableString addAttribute:NSForegroundColorAttributeName value:TGAccentColor() range:tagAndRange.range];
                                [_internalTextView.textStorage addAttribute:NSForegroundColorAttributeName value:self.accentColor range:tagAndRange.range];
                            } else {
                                //[mutableString removeAttribute:TGMentionUidAttributeName range:tagAndRange.range];
                                [_internalTextView.textStorage removeAttribute:TGMentionUidAttributeName range:tagAndRange.range];
                                
                                NSRange updatedRange = NSMakeRange(tagAndRange.range.location, j - tagAndRange.range.location);
                                //[mutableString addAttribute:TGMentionUidAttributeName value:tagAndRange.tag range:updatedRange];
                                [_internalTextView.textStorage addAttribute:TGMentionUidAttributeName value:tagAndRange.tag range:updatedRange];
                                inputTextTags[i] = [[TGInputTextTagAndRange alloc] initWithTag:tagAndRange.tag range:updatedRange];
                                
                                i--;
                            }
                        } else {
                            NSInteger candidateStart = tagAndRange.range.location + tagAndRange.range.length;
                            NSInteger candidateEnd = nextTagAndRange.range.location;
                            NSInteger j = candidateStart;
                            while (j < candidateEnd) {
                                unichar c = [string.string characterAtIndex:j];
                                if (![alphanumericSet characterIsMember:c] && c != ' ') {
                                    break;
                                }
                                j++;
                            }
                            
                            if (j == candidateEnd) {
                                //[mutableString removeAttribute:TGMentionUidAttributeName range:tagAndRange.range];
                                [_internalTextView.textStorage removeAttribute:TGMentionUidAttributeName range:tagAndRange.range];
                                
                                //[mutableString removeAttribute:TGMentionUidAttributeName range:nextTagAndRange.range];
                                [_internalTextView.textStorage removeAttribute:TGMentionUidAttributeName range:nextTagAndRange.range];
                                
                                NSRange updatedRange = NSMakeRange(tagAndRange.range.location, nextTagAndRange.range.location + nextTagAndRange.range.length - tagAndRange.range.location);
                                
                                //[mutableString addAttribute:TGMentionUidAttributeName value:tagAndRange.tag range:updatedRange];
                                [_internalTextView.textStorage addAttribute:TGMentionUidAttributeName value:tagAndRange.tag range:updatedRange];
                                
                                inputTextTags[i] = [[TGInputTextTagAndRange alloc] initWithTag:tagAndRange.tag range:updatedRange];
                                [inputTextTags removeObjectAtIndex:i + 1];
                                
                                i--;
                            } else if (j != candidateStart) {
                                //[mutableString removeAttribute:TGMentionUidAttributeName range:tagAndRange.range];
                                [_internalTextView.textStorage removeAttribute:TGMentionUidAttributeName range:tagAndRange.range];
                                
                                NSRange updatedRange = NSMakeRange(tagAndRange.range.location, j - tagAndRange.range.location);
                                //[mutableString addAttribute:TGMentionUidAttributeName value:tagAndRange.tag range:updatedRange];
                                [_internalTextView.textStorage addAttribute:TGMentionUidAttributeName value:tagAndRange.tag range:updatedRange];
                                
                                inputTextTags[i] = [[TGInputTextTagAndRange alloc] initWithTag:tagAndRange.tag range:updatedRange];
                                
                                i--;
                            } else {
                                [removeTags addObject:@(tagAndRange.tag.uniqueId)];
                                //[mutableString addAttribute:NSForegroundColorAttributeName value:TGAccentColor() range:tagAndRange.range];
                                [_internalTextView.textStorage addAttribute:NSForegroundColorAttributeName value:self.accentColor range:tagAndRange.range];
                            }
                        }
                    }
                }
            }
        }
    }
    
    _internalTextView.freezeContentOffset = false;
    [_internalTextView setContentOffset:contentOffset];
    _internalTextView.disableContentOffsetAnimation = false;
    [_internalTextView setScrollEnabled:true];
    
    /*if (mutableString != nil && ![mutableString isEqualToAttributedString:_internalTextView.attributedText])*/ {
        /*[_internalTextView.textStorage removeAttribute:NSForegroundColorAttributeName range:NSMakeRange(0, string.length)];
        [_internalTextView.textStorage addAttribute:NSForegroundColorAttributeName value:TGAccentColor() range:NSMakeRange(string.length - 1, 1)];
        
        return;
        
        UITextRange *previousRange = [_internalTextView selectedTextRange];
        UITextPosition *selStartPos = previousRange.start;
        NSInteger previousIdx = [_internalTextView offsetFromPosition:_internalTextView.beginningOfDocument toPosition:selStartPos];
        
        _internalTextView.attributedText = mutableString;
        
        UITextPosition *textPosition = [_internalTextView positionFromPosition:_internalTextView.beginningOfDocument offset:MIN(previousIdx, (NSInteger)mutableString.length)];
        [_internalTextView setSelectedTextRange:[_internalTextView textRangeFromPosition:textPosition toPosition:textPosition]];*/
    }
}

- (NSString *)textWithEntities:(__autoreleasing NSArray<TGMessageEntity *> ** _Nullable)entities {
    NSAttributedString *string = self.attributedText;
    
    NSMutableArray *result = [[NSMutableArray alloc] init];
    [string enumerateAttribute:TGMentionUidAttributeName inRange:NSMakeRange(0, string.length) options:0 usingBlock:^(__unused id value, NSRange range, __unused BOOL *stop) {
        if ([value isKindOfClass:[TGInputTextTag class]]) {
            [result addObject:[[TGMessageEntityMentionName alloc] initWithRange:range userId:[((TGInputTextTag *)value).attachment intValue]]];
        }
    }];
    
    if (iosMajorVersion() >= 7) {
        [string enumerateAttribute:NSFontAttributeName inRange:NSMakeRange(0, string.length) options:0 usingBlock:^(UIFont *font, NSRange range, __unused BOOL *stop) {
            NSString *fontDescription = font.description;
            if ([fontDescription rangeOfString:@"font-weight: bold"].location != NSNotFound) {
                [result addObject:[[TGMessageEntityBold alloc] initWithRange:range]];
            } else if ([fontDescription rangeOfString:@"font-style: italic"].location != NSNotFound) {
                [result addObject:[[TGMessageEntityItalic alloc] initWithRange:range]];
            }
        }];
    }
    
    if (entities) {
        *entities = result;
    }
    
    return string.string;
}

+ (void)replaceMention:(NSString *)mention inputField:(HPGrowingTextView *)inputField username:(bool)username userId:(int32_t)userId
{
    NSString *replacementText = [mention stringByAppendingString:@" "];
    
    NSMutableAttributedString *text = inputField.internalTextView.attributedText == nil ? [[NSMutableAttributedString alloc] init] : [[NSMutableAttributedString alloc] initWithAttributedString:inputField.internalTextView.attributedText];
    
    UITextRange *selRange = inputField.internalTextView.selectedTextRange;
    UITextPosition *selStartPos = selRange.start;
    NSInteger idx = [inputField.internalTextView offsetFromPosition:inputField.internalTextView.beginningOfDocument toPosition:selStartPos];
    idx--;
    NSRange candidateMentionRange = NSMakeRange(NSNotFound, 0);
    
    if (idx >= 0 && idx < (int)text.length)
    {
        for (NSInteger i = idx; i >= 0; i--)
        {
            unichar c = [text.string characterAtIndex:i];
            if (c == '@')
            {
                if (i == idx)
                    candidateMentionRange = NSMakeRange(i + 1, 0);
                else
                    candidateMentionRange = NSMakeRange(i + 1, idx - i);
                break;
            }
            
            if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_'))
                break;
        }
    }
    
    if (candidateMentionRange.location != NSNotFound)
    {
        if (!username) {
            candidateMentionRange.location -= 1;
            candidateMentionRange.length += 1;
            
            [text replaceCharactersInRange:candidateMentionRange withString:replacementText];
            
            static int64_t nextId = 0;
            nextId++;
            [text addAttributes:@{TGMentionUidAttributeName: [[TGInputTextTag alloc] initWithUniqueId:nextId left:true attachment:@(userId)]} range:NSMakeRange(candidateMentionRange.location, replacementText.length - 1)];
        } else {
            [text replaceCharactersInRange:candidateMentionRange withString:replacementText];
        }
        
        [inputField setAttributedText:text];
        UITextPosition *textPosition = [inputField.internalTextView positionFromPosition:inputField.internalTextView.beginningOfDocument offset:candidateMentionRange.location + replacementText.length];
        [inputField.internalTextView setSelectedTextRange:[inputField.internalTextView textRangeFromPosition:textPosition toPosition:textPosition]];
    }
}

+ (void)replaceHashtag:(NSString *)hashtag inputField:(HPGrowingTextView *)inputField
{
    if (inputField.attributedText == nil) {
        return;
    }
    
    static NSCharacterSet *characterSet = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        characterSet = [NSCharacterSet alphanumericCharacterSet];
    });
    
    NSString *replacementText = [hashtag stringByAppendingString:@" "];
    
    NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithAttributedString:inputField.attributedText];
    
    UITextRange *selRange = inputField.internalTextView.selectedTextRange;
    UITextPosition *selStartPos = selRange.start;
    NSInteger idx = [inputField.internalTextView offsetFromPosition:inputField.internalTextView.beginningOfDocument toPosition:selStartPos];
    idx--;
    NSRange candidateHashtagRange = NSMakeRange(NSNotFound, 0);
    NSString *string = text.string;
    
    if (idx >= 0 && idx < (int)text.length)
    {
        for (NSInteger i = idx; i >= 0; i--)
        {
            unichar c = [string characterAtIndex:i];
            if (c == '#')
            {
                if (i == idx)
                    candidateHashtagRange = NSMakeRange(i + 1, 0);
                else
                    candidateHashtagRange = NSMakeRange(i + 1, idx - i);
                break;
            }
            
            if (c == ' ' || (![characterSet characterIsMember:c] && c != '_'))
                break;
        }
    }
    
    if (candidateHashtagRange.location != NSNotFound)
    {
        [text replaceCharactersInRange:candidateHashtagRange withString:replacementText];
        [inputField setAttributedText:text];
        UITextPosition *textPosition = [inputField.internalTextView positionFromPosition:inputField.internalTextView.beginningOfDocument offset:candidateHashtagRange.location + replacementText.length];
        [inputField.internalTextView setSelectedTextRange:[inputField.internalTextView textRangeFromPosition:textPosition toPosition:textPosition]];
    }
}

@end
