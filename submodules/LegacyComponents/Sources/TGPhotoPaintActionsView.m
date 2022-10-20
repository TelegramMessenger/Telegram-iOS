#import "TGPhotoPaintActionsView.h"

#import "LegacyComponentsInternal.h"
#import "TGFont.h"
#import "TGImageUtils.h"

#import <LegacyComponents/TGModernButton.h>

@interface TGPhotoPaintActionsView ()
{
    TGModernButton *_undoButton;
    TGModernButton *_redoButton;
    TGModernButton *_clearButton;
}
@end

@implementation TGPhotoPaintActionsView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _undoButton = [[TGModernButton alloc] init];
        _undoButton.adjustsImageWhenDisabled = false;
        _undoButton.enabled = false;
        _undoButton.exclusiveTouch = true;
        [_undoButton setImage:TGTintedImage([UIImage imageNamed:@"Editor/Undo"], [UIColor whiteColor]) forState:UIControlStateNormal];
        [_undoButton addTarget:self action:@selector(undoButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_undoButton];
        
        _redoButton = [[TGModernButton alloc] init];
        _redoButton.adjustsImageWhenDisabled = false;
        _redoButton.enabled = false;
        _redoButton.exclusiveTouch = true;
        [_redoButton setImage:TGComponentsImageNamed(@"PaintRedoIcon") forState:UIControlStateNormal];
        [_redoButton addTarget:self action:@selector(redoButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        //[self addSubview:_redoButton];
        
        _clearButton = [[TGModernButton alloc] init];
        _clearButton.enabled = false;
        _clearButton.exclusiveTouch = true;
        _clearButton.titleLabel.font = TGSystemFontOfSize(17.0f);
        _clearButton.titleLabel.textAlignment = NSTextAlignmentCenter;
        [_clearButton setTitle:TGLocalized(@"Paint.Clear") forState:UIControlStateNormal];
        [_clearButton setTitleColor:[UIColor whiteColor]];
        [_clearButton addTarget:self action:@selector(clearButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [_clearButton sizeToFit];
        [self addSubview:_clearButton];
    }
    return self;
}

- (void)undoButtonPressed
{
    if (self.undoPressed != nil)
        self.undoPressed();
}

- (void)redoButtonPressed
{
    if (self.redoPressed != nil)
        self.redoPressed();
}

- (void)clearButtonPressed
{
    if (self.clearPressed != nil)
        self.clearPressed(_clearButton);
}

- (void)setUndoEnabled:(bool)enabled
{
    _undoButton.enabled = enabled;
}

- (void)setRedoEnabled:(bool)enabled
{
    _redoButton.enabled = enabled;
}

- (void)setClearEnabled:(bool)enabled
{
    _clearButton.enabled = enabled;
}

- (void)layoutSubviews
{
    if (self.frame.size.width > self.frame.size.height)
    {
        _undoButton.frame = CGRectMake(6, 0, 40, self.frame.size.height);
        _redoButton.frame = CGRectMake(CGRectGetMaxX(_undoButton.frame) + 18, 0, 40, self.frame.size.height);
        
        _clearButton.titleLabel.font = TGSystemFontOfSize(17.0f);
        _clearButton.titleLabel.numberOfLines = 1;
        
        if (_clearButton.frame.size.width < FLT_EPSILON) {
            _clearButton.frame = CGRectMake(0, 0, 100, self.frame.size.height);
            [_clearButton sizeToFit];
        }
        
        _clearButton.frame = CGRectMake(self.frame.size.width - _clearButton.frame.size.width - 10.0f, 0, _clearButton.frame.size.width, self.frame.size.height);
    }
    else
    {
        //_redoButton.frame = CGRectMake(0, self.frame.size.height - 40 - 14, self.frame.size.width, 40);
        _undoButton.frame = CGRectMake(0, self.frame.size.height - 40 - 6, self.frame.size.width, 40);
        
        _clearButton.titleLabel.font = TGSystemFontOfSize(13.0f);
        _clearButton.titleLabel.numberOfLines = 2;
        _clearButton.frame = CGRectMake(0.0f, 10.0f, self.frame.size.width, 24.0f);
    }
}

@end
