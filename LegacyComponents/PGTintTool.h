#import "PGPhotoTool.h"

@interface PGTintToolValue : NSObject <PGCustomToolValue>

@property (nonatomic, assign) UIColor *shadowsColor;
@property (nonatomic, assign) UIColor *highlightsColor;
@property (nonatomic, assign) CGFloat shadowsIntensity;
@property (nonatomic, assign) CGFloat highlightsIntensity;

@property (nonatomic, assign) bool editingHighlights;

@end

@interface PGTintTool : PGPhotoTool

@end
