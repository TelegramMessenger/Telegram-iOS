/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

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
