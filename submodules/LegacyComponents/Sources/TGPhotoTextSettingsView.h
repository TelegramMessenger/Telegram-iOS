#import <UIKit/UIKit.h>
#import "TGPhotoPaintSettingsView.h"
#import "TGPhotoPaintFont.h"
#import "TGPhotoPaintTextEntity.h"

@interface TGPhotoTextSettingsView : UIView <TGPhotoPaintPanelView>

@property (nonatomic, copy) void (^fontChanged)(TGPhotoPaintFont *font);
@property (nonatomic, copy) void (^styleChanged)(TGPhotoPaintTextEntityStyle style);

- (instancetype)initWithFonts:(NSArray *)fonts selectedFont:(TGPhotoPaintFont *)font selectedStyle:(TGPhotoPaintTextEntityStyle)selectedStyle;

@end
