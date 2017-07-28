#import <UIKit/UIKit.h>
#import "TGPhotoPaintSettingsView.h"

@class TGPaintBrush;
@class TGPaintBrushPreview;

@interface TGPhotoBrushSettingsView : UIView <TGPhotoPaintPanelView>

@property (nonatomic, copy) void (^brushChanged)(TGPaintBrush *brush);

@property (nonatomic, strong) TGPaintBrush *brush;

- (instancetype)initWithBrushes:(NSArray *)brushes preview:(TGPaintBrushPreview *)preview;

@end
