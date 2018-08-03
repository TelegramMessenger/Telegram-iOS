#import "MTArgon2.h"
#import "argon2.h"

NSData * _Nullable MTArgon2(NSData * _Nonnull data, NSData * _Nonnull salt, int32_t iterations) {
    if (iterations < 2) {
        return nil;
    }
    size_t hashLength = 32;
    NSMutableData *result = [[NSMutableData alloc] initWithLength:hashLength];
    int rc = argon2i_hash_raw(iterations, 1 << 14, 4, data.bytes, (size_t)data.length, salt.bytes, (size_t)salt.length, result.mutableBytes, (size_t)result.length);
    if (rc != ARGON2_OK) {
        return nil;
    }
    return result;
}
