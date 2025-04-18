#import "WKInterfaceTable+TGDataDrivenTable.h"

@class TGUserHandle;

@interface TGUserHandleRowController : TGTableRowController

@property (nonatomic, weak) IBOutlet WKInterfaceLabel *handleLabel;
@property (nonatomic, weak) IBOutlet WKInterfaceLabel *typeLabel;

- (void)updateWithUserHandle:(TGUserHandle *)userHandle;

@end

@interface TGUserHandleActiveRowController : TGUserHandleRowController

@end