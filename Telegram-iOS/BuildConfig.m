#import "BuildConfig.h"

@interface BuildConfig () {
    int32_t _apiId;
    NSString * _Nonnull _apiHash;
    NSString * _Nullable _hockeyAppId;
}

@end

@implementation BuildConfig

+ (instancetype _Nonnull)sharedBuildConfig {
    static BuildConfig *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[BuildConfig alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        char buf[3];
        buf[2] = '\0';
        NSString *hex = @(APP_CONFIG_DATA);
        assert(0 == [hex length] % 2);
        unsigned char *bytes = malloc([hex length]/2);
        unsigned char *bp = bytes;
        for (CFIndex i = 0; i < [hex length]; i += 2) {
            buf[0] = [hex characterAtIndex:i];
            buf[1] = [hex characterAtIndex:i+1];
            char *b2 = NULL;
            *bp++ = strtol(buf, &b2, 16);
            assert(b2 == buf + 2);
        }
        
        NSMutableData *data = [NSMutableData dataWithBytesNoCopy:bytes length:[hex length]/2 freeWhenDone:YES];
        if ([data length] == 0) {
            assert(false);
        }
        
        const char *streamCode = "Cypher";
        int keyLength = (int)strlen(streamCode);
        int keyOffset = 0;
        for (NSUInteger i = 0; i < data.length; i++) {
            ((uint8_t *)data.mutableBytes)[i] ^= ((uint8_t *)streamCode)[keyOffset % keyLength];
            keyOffset += 1;
        }
        
        int offset = 0;
        uint32_t header = 0;
        [data getBytes:&header range:NSMakeRange(offset, 4)];
        offset += 4;
        if (header != 0xabcdef01U) {
            assert(false);
        }
        
        [data getBytes:&_apiId range:NSMakeRange(offset, 4)];
        offset += 4;
        
        int32_t apiHashLength = 0;
        [data getBytes:&apiHashLength range:NSMakeRange(offset, 4)];
        offset += 4;
        
        if (apiHashLength > 0) {
            _apiHash = [[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(offset, apiHashLength)] encoding:NSUTF8StringEncoding];
            offset += apiHashLength;
        } else {
            assert(false);
        }
        
        int32_t hockeyappIdLength = 0;
        [data getBytes:&hockeyappIdLength range:NSMakeRange(offset, 4)];
        offset += 4;
        
        if (hockeyappIdLength > 0) {
            _hockeyAppId = [[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(offset, hockeyappIdLength)] encoding:NSUTF8StringEncoding];
            offset += hockeyappIdLength;
        }
    }
    return self;
}

- (int32_t)apiId {
    return _apiId;
}

- (NSString * _Nonnull)apiHash {
    return _apiHash;
}

- (NSString * _Nullable)hockeyAppId {
    return _hockeyAppId;
}

- (bool)isInternalBuild {
    return APP_CONFIG_IS_INTERNAL_BUILD;
}

- (bool)isAppStoreBuild {
    return APP_CONFIG_IS_APPSTORE_BUILD;
}

- (int64_t)appStoreId {
    return APP_CONFIG_APPSTORE_ID;
}

- (NSString *)appSpecificUrlScheme {
    return @(APP_SPECIFIC_URL_SCHEME);
}

@end
