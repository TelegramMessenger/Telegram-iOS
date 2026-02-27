#import "TGBridgeMessage+TGTableItem.h"

@implementation TGBridgeMessage (TGTableItem)

- (NSString *)uniqueIdentifier
{
    return [NSString stringWithFormat:@"%d", self.identifier];
}

@end
