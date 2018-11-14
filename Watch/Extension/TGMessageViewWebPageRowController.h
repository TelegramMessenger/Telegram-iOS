#import "WKInterfaceTable+TGDataDrivenTable.h"

@class TGBridgeWebPageMediaAttachment;
@class TGBridgeMessage;

@interface TGMessageViewWebPageRowController : TGTableRowController

@property (nonatomic, weak) IBOutlet WKInterfaceLabel *siteNameLabel;
@property (nonatomic, weak) IBOutlet WKInterfaceLabel *titleLabel;
@property (nonatomic, weak) IBOutlet WKInterfaceGroup *titleImageGroup;
@property (nonatomic, weak) IBOutlet WKInterfaceLabel *textLabel;
@property (nonatomic, weak) IBOutlet WKInterfaceGroup *imageGroup;
@property (nonatomic, weak) IBOutlet WKInterfaceImage *activityIndicator;
@property (nonatomic, weak) IBOutlet WKInterfaceGroup *durationGroup;
@property (nonatomic, weak) IBOutlet WKInterfaceLabel *durationLabel;

- (void)updateWithAttachment:(TGBridgeWebPageMediaAttachment *)attachment message:(TGBridgeMessage *)message;

@end
