/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#ifndef MTEncryption_H
#define MTEncryption_H

#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif
    
NSData *MTSha1(NSData *data);
NSData *MTSubdataSha1(NSData *data, NSUInteger offset, NSUInteger length);
    
NSData *MTSha256(NSData *data);
    
int32_t MTMurMurHash32(const void *bytes, int length);
    
void MTAesEncryptInplace(NSMutableData *data, NSData *key, NSData *iv);
void MTAesEncryptInplaceAndModifyIv(NSMutableData *data, NSData *key, NSMutableData *iv);
void MTAesDecryptInplace(NSMutableData *data, NSData *key, NSData *iv);
void MTAesDecryptInplaceAndModifyIv(NSMutableData *data, NSData *key, NSMutableData *iv);
NSData *MTAesEncrypt(NSData *data, NSData *key, NSData *iv);
NSData *MTAesDecrypt(NSData *data, NSData *key, NSData *iv);
NSData *MTRsaEncrypt(NSString *publicKey, NSData *data);
NSData *MTExp(NSData *base, NSData *exp, NSData *modulus);
bool MTFactorize(uint64_t what, uint64_t *resA, uint64_t *resB);
    
@class MTKeychain;
bool MTCheckIsSafeG(unsigned int g);
bool MTCheckIsSafePrime(NSData *numberBytes, MTKeychain *keychain);
bool MTCheckIsSafeGAOrB(NSData *gAOrB, NSData *p);
bool MTCheckMod(NSData *numberBytes, unsigned int g, MTKeychain *keychain);

#ifdef __cplusplus
}
#endif

#endif
