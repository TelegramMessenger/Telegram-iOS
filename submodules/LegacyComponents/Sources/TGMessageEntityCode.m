#import "TGMessageEntityCode.h"

@implementation TGMessageEntityCode

- (BOOL)isEqual:(id)object
{
    return [super isEqual:object] && [object isKindOfClass:[TGMessageEntityCode class]];
}

@end
