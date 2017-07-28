#import "TGMediaAssetsMomentsSectionHeaderView.h"

#import <LegacyComponents/LegacyComponents.h>

@interface TGMediaAssetsMomentsSectionHeaderView ()
{
    UILabel *_titleLabel;
    UILabel *_locationLabel;
    UILabel *_dateLabel;
}
@end

@implementation TGMediaAssetsMomentsSectionHeaderView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.backgroundColor = [UIColor colorWithWhite:1.0f alpha:0.92f];
        
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.textColor = [UIColor blackColor];
        _titleLabel.font = TGSystemFontOfSize(15.0f);
        [self addSubview:_titleLabel];
        
        _locationLabel = [[UILabel alloc] init];
        _locationLabel.backgroundColor = [UIColor clearColor];
        _locationLabel.textColor = [UIColor blackColor];
        _locationLabel.font = TGSystemFontOfSize(12.0f);
        [self addSubview:_locationLabel];
        
        _dateLabel = [[UILabel alloc] init];
        _dateLabel.backgroundColor = [UIColor clearColor];
        _dateLabel.textColor = [UIColor blackColor];
        _dateLabel.font = TGSystemFontOfSize(12.0f);
        [self addSubview:_dateLabel];
    }
    return self;
}

- (void)setTitle:(NSString *)title location:(NSString *)location date:(NSString *)date
{
    _titleLabel.text = title;
    [_titleLabel sizeToFit];
    
    _locationLabel.text = location;
    [_locationLabel sizeToFit];
    
    _dateLabel.text = date;
    [_dateLabel sizeToFit];
    
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    _dateLabel.frame = (CGRect){{self.bounds.size.width - _dateLabel.frame.size.width - 8.0f, 27.0f}, _dateLabel.frame.size};
    
    CGFloat titleWidth = _titleLabel.frame.size.width;
    if (_dateLabel.text.length > 0)
        titleWidth = MIN(titleWidth, _dateLabel.frame.origin.x - 8.0f);
    
    if (_locationLabel.text.length > 0)
    {
        _titleLabel.frame = (CGRect){{8.0f, 8.0f}, { titleWidth, _titleLabel.frame.size.height }};
        _locationLabel.frame = (CGRect){{8.0f, 27.0f}, _locationLabel.frame.size};
    }
    else
    {
        _titleLabel.frame = (CGRect){{8.0f, TGRetinaFloor((self.bounds.size.height - _titleLabel.frame.size.height) / 2.0f)}, { titleWidth, _titleLabel.frame.size.height }};
    }
}

@end
