#import "TGModernGalleryEmbeddedStickersHeaderView.h"

#import <LegacyComponents/LegacyComponents.h>

#import <LegacyComponents/TGModernButton.h>

@interface TGModernGalleryEmbeddedStickersHeaderView () {
    TGModernButton *_stickerButton;
}

@end

@implementation TGModernGalleryEmbeddedStickersHeaderView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self != nil) {
        _stickerButton = [[TGModernButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 50.0f, 44.0f)];
        [_stickerButton setImage:TGTintedImage([UIImage imageNamed:@"GalleryEmbeddedStickersIcon"], [UIColor whiteColor]) forState:UIControlStateNormal];
        [_stickerButton addTarget:self action:@selector(stickerButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_stickerButton];
    }
    return self;
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
    if (!_stickerButton.hidden && CGRectContainsPoint(_stickerButton.frame, point))
        return true;
    
    return [super pointInside:point withEvent:event];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    _stickerButton.frame = CGRectMake(self.frame.size.width + 26.0f, -1.0f, _stickerButton.frame.size.width, _stickerButton.frame.size.height);
}

- (void)stickerButtonPressed {
    if (_showEmbeddedStickers) {
        _showEmbeddedStickers();
    }
}

@end
