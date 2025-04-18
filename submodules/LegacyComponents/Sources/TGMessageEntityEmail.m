#import "TGMessageEntityEmail.h"

@implementation TGMessageEntityEmail

- (BOOL)isEqual:(id)object
{
    return [super isEqual:object] && [object isKindOfClass:[TGMessageEntityEmail class]];
}

@end
