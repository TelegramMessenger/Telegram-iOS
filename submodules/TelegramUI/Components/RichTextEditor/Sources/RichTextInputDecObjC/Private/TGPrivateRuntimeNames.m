#import "TGPrivateRuntimeNames.h"
#import "TGPrivateMethodAliases.h"

#import <objc/runtime.h>

NSString *TGPrivateRuntimeNameDecode(const uint8_t *bytes, size_t length) {
    uint8_t buffer[256];
    uint8_t *decoded = length <= sizeof(buffer) ? buffer : malloc(length);
    for (size_t i = 0; i < length; i++) {
        decoded[i] = bytes[i] ^ 0x5A;
    }
    NSString *value = [[NSString alloc] initWithBytes:decoded length:length encoding:NSUTF8StringEncoding];
    if (decoded != buffer) {
        free(decoded);
    }
    return value ?: @"";
}

NSData *TGPrivateRuntimeDataDecode(const uint8_t *bytes, size_t length) {
    NSMutableData *data = [NSMutableData dataWithLength:length];
    uint8_t *decoded = data.mutableBytes;
    for (size_t i = 0; i < length; i++) {
        decoded[i] = bytes[i] ^ 0x5A;
    }
    return data;
}

void TGPrivateInstallMethodAliases(Class cls, const TGPrivateMethodAlias *aliases, NSUInteger count) {
    for (NSUInteger i = 0; i < count; i++) {
        Method method = class_getInstanceMethod(cls, aliases[i].implementation);
        if (method == NULL) {
            continue;
        }
        // `class_addMethod`, never `class_replaceMethod`: it adds the method only when `cls` does not
        // define one under that name ITSELF. A superclass's implementation (UIKit's own, for an
        // override) is still overridden, as a compiled method would override it; installing twice
        // is harmless; and a subclass that defines the private name itself keeps its definition —
        // replacing it clobbered every such override (the engine's own test subclasses have them).
        class_addMethod(cls,
                        NSSelectorFromString(aliases[i].privateName()),
                        method_getImplementation(method),
                        method_getTypeEncoding(method));
    }
}
