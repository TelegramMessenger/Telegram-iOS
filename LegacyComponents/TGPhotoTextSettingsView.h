#import <UIKit/UIKit.h>
#import "TGPhotoPaintSettingsView.h"
#import "TGPhotoPaintFont.h"

@interface TGPhotoTextSettingsView : UIView <TGPhotoPaintPanelView>

@property (nonatomic, copy) void (^fontChanged)(TGPhotoPaintFont *font);
@property (nonatomic, copy) void (^strokeChanged)(bool stroke);

@property (nonatomic, strong) TGPhotoPaintFont *font;
@property (nonatomic, assign) bool stroke;

- (instancetype)initWithFonts:(NSArray *)fonts selectedFont:(TGPhotoPaintFont *)font selectedStroke:(bool)selectedStroke;

@end
