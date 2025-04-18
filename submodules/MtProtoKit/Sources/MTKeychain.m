#import <MtProtoKit/MTKeychain.h>

@implementation MTDeprecated

+ (id)unarchiveDeprecatedWithData:(NSData *)data {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    @try {
        return [NSKeyedUnarchiver unarchiveObjectWithData:data];
    } @catch(NSException *e) {
        return nil;
    }
#pragma clang diagnostic pop
}

@end


