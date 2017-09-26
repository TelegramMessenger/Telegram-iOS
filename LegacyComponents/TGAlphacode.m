#import "TGAlphacode.h"

@implementation TGAlphacodeEntry

- (instancetype)initWithEmoji:(NSString *)emoji code:(NSString *)code {
    self = [super init];
    if (self != nil) {
        _emoji = emoji;
        _code = code;
    }
    return self;
}

@end
