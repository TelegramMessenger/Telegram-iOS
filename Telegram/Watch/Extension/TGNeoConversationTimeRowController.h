#import "WKInterfaceTable+TGDataDrivenTable.h"

@class TGChatTimestamp;

@interface TGNeoConversationTimeRowController : TGTableRowController

@property (nonatomic, weak) IBOutlet WKInterfaceLabel *label;

- (void)updateWithTimestamp:(TGChatTimestamp *)timestamp;

@end
