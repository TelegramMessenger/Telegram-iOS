#import "TGInterfaceController.h"

@class TGBridgeContext;
@class TGBridgeUser;

@interface TGContactsControllerContext : NSObject <TGInterfaceContext>

@property (nonatomic, strong) TGBridgeContext *context;
@property (nonatomic, readonly) NSString *query;
@property (nonatomic, copy) void (^completionBlock)(TGBridgeUser *user);

- (instancetype)initWithQuery:(NSString *)query;

@end

@interface TGContactsController : TGInterfaceController

@property (nonatomic, weak) IBOutlet WKInterfaceTable *table;
@property (nonatomic, weak) IBOutlet WKInterfaceImage *activityIndicator;

@property (nonatomic, weak) IBOutlet WKInterfaceLabel *alertLabel;

@end
