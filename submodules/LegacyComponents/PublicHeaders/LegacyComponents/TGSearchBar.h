#import <UIKit/UIKit.h>

@class TGSearchBar;

typedef enum {
    TGSearchBarStyleDefault = 0,
    TGSearchBarStyleDark = 1,
    TGSearchBarStyleLight = 2,
    TGSearchBarStyleLightPlain = 3,
    TGSearchBarStyleLightAlwaysPlain = 4,
    TGSearchBarStyleHeader = 5,
    TGSearchBarStyleKeyboard = 6
} TGSearchBarStyle;

@protocol TGSearchBarDelegate <UISearchBarDelegate>

- (void)searchBar:(TGSearchBar *)searchBar willChangeHeight:(CGFloat)newHeight;

@end

@interface TGSearchBarPallete : NSObject

@property (nonatomic, readonly) bool isDark;
@property (nonatomic, readonly) UIColor *backgroundColor;
@property (nonatomic, readonly) UIColor *highContrastBackgroundColor;
@property (nonatomic, readonly) UIColor *textColor;
@property (nonatomic, readonly) UIColor *placeholderColor;
@property (nonatomic, readonly) UIImage *clearIcon;
@property (nonatomic, readonly) UIColor *barBackgroundColor;
@property (nonatomic, readonly) UIColor *barSeparatorColor;
@property (nonatomic, readonly) UIColor *plainBackgroundColor;
@property (nonatomic, readonly) UIColor *accentColor;
@property (nonatomic, readonly) UIColor *accentContrastColor;
@property (nonatomic, readonly) UIColor *menuBackgroundColor;
@property (nonatomic, readonly) UIImage *segmentedControlBackgroundImage;
@property (nonatomic, readonly) UIImage *segmentedControlSelectedImage;
@property (nonatomic, readonly) UIImage *segmentedControlHighlightedImage;
@property (nonatomic, readonly) UIImage *segmentedControlDividerImage;

+ (instancetype)palleteWithDark:(bool)dark backgroundColor:(UIColor *)backgroundColor highContrastBackgroundColor:(UIColor *)highContrastBackgroundColor textColor:(UIColor *)textColor placeholderColor:(UIColor *)placeholderColor clearIcon:(UIImage *)clearIcon barBackgroundColor:(UIColor *)barBackgroundColor barSeparatorColor:(UIColor *)barSeparatorColor plainBackgroundColor:(UIColor *)plainBackgroundColor accentColor:(UIColor *)accentColor accentContrastColor:(UIColor *)accentContrastColor menuBackgroundColor:(UIColor *)menuBackgroundColor segmentedControlBackgroundImage:(UIImage *)segmentedControlBackgroundImage segmentedControlSelectedImage:(UIImage *)segmentedControlSelectedImage segmentedControlHighlightedImage:(UIImage *)segmentedControlHighlightedImage segmentedControlDividerImage:(UIImage *)segmentedControlDividerImage;

@end

@interface TGSearchBar : UIView

+ (CGFloat)searchBarBaseHeight;
+ (CGFloat)searchBarScopeHeight;
- (CGFloat)baseHeight;

@property (nonatomic, copy) void (^clearPrefix)(bool);

@property (nonatomic, assign) UIEdgeInsets safeAreaInset;

@property (nonatomic, weak) id<TGSearchBarDelegate> delegate;
@property (nonatomic) bool highContrast;

@property (nonatomic, strong) UITextField *customTextField;
@property (nonatomic, readonly) UITextField *maybeCustomTextField;

@property (nonatomic, strong) UIImageView *customBackgroundView;
@property (nonatomic, strong) UIImageView *customActiveBackgroundView;

@property (nonatomic, strong) NSArray *customScopeButtonTitles;
@property (nonatomic) NSInteger selectedScopeButtonIndex;
@property (nonatomic) bool showsScopeBar;
@property (nonatomic) bool scopeBarCollapsed;

@property (nonatomic) bool searchBarShouldShowScopeControl;
@property (nonatomic) bool alwaysExtended;
@property (nonatomic) bool hidesCancelButton;

@property (nonatomic, strong) UIButton *customCancelButton;

@property (nonatomic) TGSearchBarStyle style;
@property (nonatomic, strong) NSString *text;
@property (nonatomic, strong) NSString *placeholder;
@property (nonatomic, strong) NSAttributedString *prefixText;

@property (nonatomic) bool showActivity;
@property (nonatomic) bool delayActivity;

- (instancetype)initWithFrame:(CGRect)frame style:(TGSearchBarStyle)style;

- (void)setShowsCancelButton:(bool)showsCancelButton animated:(bool)animated;

- (void)setCustomScopeBarHidden:(bool)hidden;

- (void)updateClipping:(CGFloat)clippedHeight;

- (void)localizationUpdated;

- (void)setPallete:(TGSearchBarPallete *)pallete;

@end
