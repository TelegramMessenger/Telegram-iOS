#import <LegacyComponents/TGMenuSheetItemView.h>

@interface TGMenuSheetTitleItemView : TGMenuSheetItemView

@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *subtitle;

- (instancetype)initWithTitle:(NSString *)title subtitle:(NSString *)subtitle;
- (instancetype)initWithTitle:(NSString *)title subtitle:(NSString *)subtitle solidSubtitle:(bool)solidSubtitle;

@end
