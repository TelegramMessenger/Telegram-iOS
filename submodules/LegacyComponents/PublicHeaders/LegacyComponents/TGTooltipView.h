

#import <UIKit/UIKit.h>

#import <LegacyComponents/ASWatcher.h>

@interface TGTooltipView : UIView

@property (nonatomic, assign) CGFloat maxWidth;
@property (nonatomic, weak) UIView *sourceView;
@property (nonatomic) NSInteger numberOfLines;
@property (nonatomic, assign) bool forceArrowOnTop;

- (void)setText:(NSString *)text animated:(bool)animated;

@end

@interface TGTooltipContainerView : UIView

@property (nonatomic, strong) TGTooltipView *tooltipView;

@property (nonatomic, readonly) bool isShowingTooltip;
@property (nonatomic) CGRect showingTooltipFromRect;

- (void)showTooltipFromRect:(CGRect)rect;
- (void)showTooltipFromRect:(CGRect)rect animated:(bool)animated;
- (void)hideTooltip;

@end
