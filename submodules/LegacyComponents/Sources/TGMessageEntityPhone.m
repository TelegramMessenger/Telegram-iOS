#import "TGMessageEntityPhone.h"

@implementation TGMessageEntityPhone

- (BOOL)isEqual:(id)object
{
    return [super isEqual:object] && [object isKindOfClass:[TGMessageEntityPhone class]];
}

@end
