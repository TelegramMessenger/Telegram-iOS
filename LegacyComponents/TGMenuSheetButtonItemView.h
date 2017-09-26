#import <LegacyComponents/TGMenuSheetItemView.h>

typedef enum
{
    TGMenuSheetButtonTypeDefault,
    TGMenuSheetButtonTypeCancel,
    TGMenuSheetButtonTypeDestructive,
    TGMenuSheetButtonTypeSend
} TGMenuSheetButtonType;

@class TGModernButton;

@interface TGMenuSheetButtonItemView : TGMenuSheetItemView
{
    TGModernButton *_button;
}

@property (nonatomic, strong) NSString *title;
@property (nonatomic, assign) TGMenuSheetButtonType buttonType;
@property (nonatomic, copy) void(^longPressAction)(void);
@property (nonatomic, copy) void (^action)(void);

- (instancetype)initWithTitle:(NSString *)title type:(TGMenuSheetButtonType)type action:(void (^)(void))action;

@end

extern const CGFloat TGMenuSheetButtonItemViewHeight;
