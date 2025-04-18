#import "TGMessageEntityMention.h"

@implementation TGMessageEntityMention

- (BOOL)isEqual:(id)object
{
    return [super isEqual:object] && [object isKindOfClass:[TGMessageEntityMention class]];
}

@end
