#import "TGBridgeUser+TGTableItem.h"

@implementation TGBridgeUser (TGTableItem)

- (NSString *)uniqueIdentifier
{
    return [NSString stringWithFormat:@"%d", self.identifier];
}

@end
