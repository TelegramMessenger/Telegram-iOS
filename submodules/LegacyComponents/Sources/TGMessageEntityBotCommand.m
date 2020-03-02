#import "TGMessageEntityBotCommand.h"

@implementation TGMessageEntityBotCommand

- (BOOL)isEqual:(id)object
{
    return [super isEqual:object] && [object isKindOfClass:[TGMessageEntityBotCommand class]];
}

@end
