#import "WKInterfaceTable+TGDataDrivenTable.h"

@interface TGStickersHeaderController : TGTableRowController

@property (nonatomic, weak) IBOutlet WKInterfaceLabel *nameLabel;

- (void)update;

@end
