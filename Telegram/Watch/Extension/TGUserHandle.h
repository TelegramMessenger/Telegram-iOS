#import "WKInterfaceTable+TGDataDrivenTable.h"

typedef NS_ENUM(NSUInteger, TGUserHandleType) {
    TGUserHandleTypeUndefined,
    TGUserHandleTypePhone,
    TGUserHandleTypeDescription
};

@interface TGUserHandle : NSObject <TGTableItem>

@property (nonatomic, readonly) NSString *handle;
@property (nonatomic, readonly) NSString *type;
@property (nonatomic, readonly) TGUserHandleType handleType;
@property (nonatomic, readonly) NSString *data;

- (instancetype)initWithHandle:(NSString *)handle type:(NSString *)type handleType:(TGUserHandleType)handleType data:(NSString *)data;

@end