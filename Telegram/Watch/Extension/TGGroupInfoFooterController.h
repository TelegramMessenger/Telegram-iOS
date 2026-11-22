#import <WatchKit/WatchKit.h>

@interface TGGroupInfoFooterController : NSObject

@property (nonatomic, weak) IBOutlet WKInterfaceButton *button;
- (IBAction)buttonPressedAction;

@property (nonatomic, copy) void (^buttonPressed)(void);

@end
