#import "WKInterfaceTable+TGDataDrivenTable.h"

@interface TGChatTimestamp : NSObject <TGTableItem>

@property (nonatomic, readonly) NSTimeInterval date;
@property (nonatomic, readonly) NSString *string;

- (instancetype)initWithDate:(NSTimeInterval)date string:(NSString *)string;

@end
