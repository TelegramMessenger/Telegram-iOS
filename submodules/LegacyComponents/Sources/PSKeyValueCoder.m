#import "PSKeyValueCoder.h"

#import <pthread.h>

pthread_rwlock_t classNameCacheLock = PTHREAD_RWLOCK_INITIALIZER;

NSMutableDictionary *classNameCache()
{
    static NSMutableDictionary *dict = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        dict = [[NSMutableDictionary alloc] init];
    });
    
    return dict;
}

@implementation PSKeyValueCoder

+ (Class<PSCoding>)classForName:(NSString *)name
{
    if (name == nil)
        return nil;
    
    Class<PSCoding> result = nil;
    
    pthread_rwlock_rdlock(&classNameCacheLock);
    result = [classNameCache() objectForKey:name];
    pthread_rwlock_unlock(&classNameCacheLock);
    
    if (result == nil)
    {
        result = NSClassFromString(name);
        if (result != nil)
        {
            pthread_rwlock_wrlock(&classNameCacheLock);
            classNameCache()[name] = result;
            pthread_rwlock_unlock(&classNameCacheLock);
        }
    }
    
    return result;
}

- (void)encodeString:(NSString *)__unused string forKey:(NSString *)__unused key
{
}

- (void)encodeInt32:(int32_t)__unused number forKey:(NSString *)__unused key
{
}

- (void)encodeInt64:(int64_t)__unused number forKey:(NSString *)__unused key
{
}

- (void)encodeObject:(id<PSCoding>)__unused object forKey:(NSString *)__unused key
{
}

- (NSString *)decodeStringForKey:(NSString *)__unused key
{
    return nil;
}

- (int32_t)decodeInt32ForKey:(NSString *)__unused key
{
    return 0;
}

- (int64_t)decodeInt64ForKey:(NSString *)__unused key
{
    return 0;
}

- (id<PSCoding>)decodeObjectForKey:(NSString *)__unused key
{
    return nil;
}

- (void)encodeString:(NSString *)__unused string forCKey:(const char *)__unused key
{
}

- (void)encodeInt32:(int32_t)__unused number forCKey:(const char *)__unused key
{
}

- (void)encodeInt64:(int64_t)__unused number forCKey:(const char *)__unused key
{
}

- (void)encodeObject:(id<PSCoding>)__unused object forCKey:(const char *)__unused key
{
}

- (void)encodeArray:(NSArray *)__unused array forKey:(NSString *)__unused key
{
}

- (void)encodeArray:(NSArray *)__unused array forCKey:(const char *)__unused key
{
}

- (void)encodeData:(NSData *)__unused data forCKey:(const char *)__unused key
{
}

- (void)encodeBytes:(uint8_t const *)__unused value length:(NSUInteger)__unused length forCKey:(const char *)__unused key
{
}

- (void)encodeInt32Array:(NSArray *)__unused value forCKey:(const char *)__unused key
{
}

- (void)encodeInt32Dictionary:(NSDictionary *)__unused value forCKey:(const char *)__unused key {
}

- (void)encodeDouble:(double)__unused value forCKey:(const char *)__unused key {
}

- (NSString *)decodeStringForCKey:(const char *)__unused key
{
    return nil;
}

- (int32_t)decodeInt32ForCKey:(const char *)__unused key
{
    return 0;
}

- (int64_t)decodeInt64ForCKey:(const char *)__unused key
{
    return 0;
}

- (id<PSCoding>)decodeObjectForCKey:(const char *)__unused key
{
    return nil;
}

- (NSArray *)decodeArrayForKey:(NSString *)__unused key
{
    return nil;
}

- (NSArray *)decodeArrayForCKey:(const char *)__unused key
{
    return nil;
}

- (NSData *)decodeDataCorCKey:(const char *)__unused key
{
    return nil;
}

- (void)decodeBytesForCKey:(const char *)__unused key value:(uint8_t *)__unused value length:(NSUInteger)__unused length
{
}

- (NSDictionary *)decodeObjectsByKeys
{
    return nil;
}

- (NSArray *)decodeInt32ArrayForCKey:(const char *)__unused key {
    return nil;
}

- (NSDictionary *)decodeInt32DictionaryForCKey:(const char *)__unused key {
    return nil;
}

- (double)decodeDoubleForCKey:(const char *)__unused key {
    return 0.0f;
}

@end
