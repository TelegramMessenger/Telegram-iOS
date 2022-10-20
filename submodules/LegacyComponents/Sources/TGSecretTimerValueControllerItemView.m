#import "TGSecretTimerValueControllerItemView.h"

#import "LegacyComponentsInternal.h"
#import "TGFont.h"
#import "TGStringUtils.h"

@interface TGSecretTimerValueControllerItemView ()
{
    UILabel *_numberLabel;
    UILabel *_unitLabel;
}

@end

@implementation TGSecretTimerValueControllerItemView

- (instancetype)initWithFrame:(CGRect)frame
{
    return [self initWithFrame:frame dark:false];
}

- (instancetype)initWithFrame:(CGRect)frame dark:(bool)dark
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _numberLabel = [[UILabel alloc] init];
        _numberLabel.backgroundColor = nil;
        _numberLabel.opaque = false;
        _numberLabel.font = TGSystemFontOfSize(24.0f);
        if (dark && iosMajorVersion() > 7)
            _numberLabel.textColor = [UIColor whiteColor];
        [self addSubview:_numberLabel];
        
        _unitLabel = [[UILabel alloc] init];
        _unitLabel.backgroundColor = nil;
        _unitLabel.opaque = false;
        _unitLabel.font = TGMediumSystemFontOfSize(16.0f);
        if (dark && iosMajorVersion() > 7)
            _unitLabel.textColor = [UIColor whiteColor];
        [self addSubview:_unitLabel];
    }
    return self;
}

- (void)setSeconds:(NSUInteger)seconds
{
    _seconds = seconds;
    
    if (_seconds == 0)
    {
        _numberLabel.text = _emptyValue == nil ? TGLocalized(@"Profile.MessageLifetimeForever") : _emptyValue;
        _unitLabel.text = @"";
    }
    else
    {
        NSArray *components = [TGStringUtils stringComponentsForMessageTimerSeconds:seconds];
        _numberLabel.text = components[0];
        _unitLabel.text = components[1];
    }
    
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    [_numberLabel sizeToFit];
    [_unitLabel sizeToFit];
    
    if (_unitLabel.text.length > 0)
    {
        _numberLabel.frame = (CGRect){{self.frame.size.width / 2.0f - 20.0f - _numberLabel.frame.size.width, CGFloor((self.frame.size.height - _numberLabel.frame.size.height) / 2.0f)}, _numberLabel.frame.size};
        _unitLabel.frame = (CGRect){{self.frame.size.width / 2.0f - 12.0f, CGFloor((self.frame.size.height - _unitLabel.frame.size.height) / 2.0f) + 2.0f}, _unitLabel.frame.size};
    }
    else
    {
        _numberLabel.frame = (CGRect){{CGFloor((self.frame.size.width - _numberLabel.frame.size.width) / 2.0f), CGFloor((self.frame.size.height - _numberLabel.frame.size.height) / 2.0f)}, _numberLabel.frame.size};
    }
}

@end
