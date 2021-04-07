#ifndef __CRYPTO_H_
#define __CRYPTO_H_

#import <Foundation/Foundation.h>

NSData * _Nonnull CryptoMD5(const void * _Nonnull bytes, int count);
NSData * _Nonnull CryptoSHA1(const void * _Nonnull bytes, int count);
NSData * _Nonnull CryptoSHA256(const void * _Nonnull bytes, int count);
NSData * _Nonnull CryptoSHA512(const void * _Nonnull bytes, int count);

@interface IncrementalMD5 : NSObject

- (instancetype _Nonnull)init;
- (void)update:(NSData * _Nonnull)data;
- (void)update:(const void * _Nonnull)bytes count:(int)count;
- (NSData * _Nonnull)complete;

@end

NSData * _Nullable CryptoAES(bool encrypt, NSData * _Nonnull key, NSData * _Nonnull iv, NSData * _Nonnull data);

#endif
