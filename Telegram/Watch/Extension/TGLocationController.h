#import "TGInterfaceController.h"

@class TGBridgeLocationMediaAttachment;

@interface TGLocationControllerContext : NSObject <TGInterfaceContext>

@property (nonatomic, copy) void (^completionBlock)(TGBridgeLocationMediaAttachment *location);

@end

@interface TGLocationController : TGInterfaceController

@property (nonatomic, weak) IBOutlet WKInterfaceTable *table;
@property (nonatomic, weak) IBOutlet WKInterfaceGroup *activityGroup;
@property (nonatomic, weak) IBOutlet WKInterfaceImage *activityIndicator;

@property (nonatomic, weak) IBOutlet WKInterfaceGroup *alertGroup;
@property (nonatomic, weak) IBOutlet WKInterfaceLabel *alertLabel;

@end
