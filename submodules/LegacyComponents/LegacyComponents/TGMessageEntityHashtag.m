#import "TGMessageEntityHashtag.h"

@implementation TGMessageEntityHashtag

- (BOOL)isEqual:(id)object
{
    return [super isEqual:object] && [object isKindOfClass:[TGMessageEntityHashtag class]];
}

@end
