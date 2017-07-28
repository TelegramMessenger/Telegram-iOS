#import "LegacyComponentsContext.h"

@implementation LegacyComponentsActionSheetAction

- (instancetype)initWithTitle:(NSString *)title action:(NSString *)action {
    return [self initWithTitle:title action:action type:LegacyComponentsActionSheetActionTypeGeneric];
}

- (instancetype)initWithTitle:(NSString *)title action:(NSString *)action type:(LegacyComponentsActionSheetActionType)type {
    self = [super init];
    if (self != nil) {
        _title = title;
        _action = action;
        _type = type;
    }
    return self;
}

@end
