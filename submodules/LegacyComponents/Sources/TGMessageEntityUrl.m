#import "TGMessageEntityUrl.h"

@implementation TGMessageEntityUrl

- (BOOL)isEqual:(id)object
{
    return [super isEqual:object] && [object isKindOfClass:[TGMessageEntityUrl class]];
}

@end
