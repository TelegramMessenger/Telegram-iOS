#import "PGPhotoTool.h"

@interface PGTintToolValue : NSObject <PGCustomToolValue>

@property (nonatomic, strong) UIColor *shadowsColor;
@property (nonatomic, strong) UIColor *highlightsColor;
@property (nonatomic, assign) CGFloat shadowsIntensity;
@property (nonatomic, assign) CGFloat highlightsIntensity;

@property (nonatomic, assign) bool editingHighlights;

- (instancetype)initWithDictionary:(NSDictionary *)dictionary;
- (NSDictionary *)dictionary;

@end

@interface PGTintTool : PGPhotoTool

@end
