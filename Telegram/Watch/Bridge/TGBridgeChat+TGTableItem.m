#import "TGBridgeChat+TGTableItem.h"

@implementation TGBridgeChat (TGTableItem)

- (NSString *)uniqueIdentifier
{
    return [NSString stringWithFormat:@"%lld", self.identifier];
}

@end
