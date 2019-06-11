#import "TGMessageEntityCashtag.h"

@implementation TGMessageEntityCashtag

- (BOOL)isEqual:(id)object
{
    return [super isEqual:object] && [object isKindOfClass:[TGMessageEntityCashtag class]];
}

@end
