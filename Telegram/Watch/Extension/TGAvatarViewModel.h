#import <WatchKit/WatchKit.h>

@class TGBridgeContext;
@class TGBridgeUser;
@class TGBridgeChat;

@interface TGAvatarViewModel : NSObject

@property (nonatomic, weak) WKInterfaceGroup *group;
@property (nonatomic, weak) WKInterfaceLabel *label;

- (void)updateWithUser:(TGBridgeUser *)user context:(TGBridgeContext *)context isVisible:(bool (^)(void))isVisible;
- (void)updateWithChat:(TGBridgeChat *)chat isVisible:(bool (^)(void))isVisible;

- (void)updateIfNeeded;

@end
