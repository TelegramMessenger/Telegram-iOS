// Sources/SubcodecObjC/SCDecodedFrame.mm
#import "SCDecodedFrame.h"

@implementation SCDecodedFrame

- (instancetype)initWithWidth:(int)width
                       height:(int)height
                            y:(NSData *)y
                           cb:(NSData *)cb
                           cr:(NSData *)cr {
    self = [super init];
    if (self) {
        _width = width;
        _height = height;
        _y = [y copy];
        _cb = [cb copy];
        _cr = [cr copy];
    }
    return self;
}

@end
