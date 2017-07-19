#import "TGMessageEntityBold.h"

@implementation TGMessageEntityBold

- (BOOL)isEqual:(id)object
{
    return [super isEqual:object] && [object isKindOfClass:[TGMessageEntityBold class]];
}

@end
