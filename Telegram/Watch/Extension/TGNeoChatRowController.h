#import "WKInterfaceTable+TGDataDrivenTable.h"

@class TGBridgeContext;
@class TGBridgeChat;

@interface TGNeoChatRowController : TGTableRowController

@property (nonatomic, copy) bool (^shouldRenderContent)(void);

@property (nonatomic, weak) IBOutlet WKInterfaceGroup *contentGroup;
@property (nonatomic, weak) IBOutlet WKInterfaceGroup *avatarGroup;
@property (nonatomic, weak) IBOutlet WKInterfaceLabel *avatarLabel;
@property (nonatomic, weak) IBOutlet WKInterfaceGroup *statusGroup;
@property (nonatomic, weak) IBOutlet WKInterfaceLabel *statusLabel;

- (void)updateWithChat:(TGBridgeChat *)chat forForward:(bool)forForward context:(TGBridgeContext *)context;

@end
