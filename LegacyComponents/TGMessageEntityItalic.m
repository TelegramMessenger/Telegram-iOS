#import "TGMessageEntityItalic.h"

@implementation TGMessageEntityItalic

- (BOOL)isEqual:(id)object
{
    return [super isEqual:object] && [object isKindOfClass:[TGMessageEntityItalic class]];
}

@end
