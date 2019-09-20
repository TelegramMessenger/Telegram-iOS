#import "QrCodeInstance.h"

#include "QrCode.hpp"

@interface QrCodeInstance () {
    std::unique_ptr<qrcodegen::QrCode> _qrCode;
}
@end

@implementation QrCodeInstance

- (instancetype _Nullable)initWithStirng:(NSString * _Nonnull)string {
    self = [super init];
    if (self != nil) {
        _qrCode = std::make_unique<qrcodegen::QrCode>(qrcodegen::QrCode::encodeText(string.UTF8String, qrcodegen::QrCode::Ecc::MEDIUM));
    }
    return self;
}

- (int32_t)size {
    return _qrCode->getSize()
}

- (BOOL)getModuleAtX:(int32_t)x y:(int32_t)y {
    return _qrCode->getModule(x, y);
}

@end
