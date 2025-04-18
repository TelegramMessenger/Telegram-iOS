#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol MTBignum <NSObject>

@end

@protocol MTRsaPublicKey <NSObject>

@end

@protocol MTBignumContext <NSObject>

- (id<MTBignum>)create;
- (id<MTBignum>)clone:(id<MTBignum>)other;

- (void)setConstantTime:(id<MTBignum>)other;

- (void)assignWordTo:(id<MTBignum>)bignum value:(unsigned long)value;
- (void)assignHexTo:(id<MTBignum>)bignum value:(NSString *)value;
- (void)assignBinTo:(id<MTBignum>)bignum value:(NSData *)value;
- (void)assignOneTo:(id<MTBignum>)bignum;
- (void)assignZeroTo:(id<MTBignum>)bignum;

- (bool)isOne:(id<MTBignum>)bignum;
- (bool)isZero:(id<MTBignum>)bignum;
- (NSData *)getBin:(id<MTBignum>)bignum;
- (int)isPrime:(id<MTBignum>)bignum numberOfChecks:(int)numberOfChecks;

- (int)compare:(id<MTBignum>)a with:(id<MTBignum>)b;

- (bool)modAddInto:(id<MTBignum>)result a:(id<MTBignum>)a b:(id<MTBignum>)b mod:(id<MTBignum>)mod;
- (bool)modSubInto:(id<MTBignum>)result a:(id<MTBignum>)a b:(id<MTBignum>)b mod:(id<MTBignum>)mod;
- (bool)modMulInto:(id<MTBignum>)result a:(id<MTBignum>)a b:(id<MTBignum>)b mod:(id<MTBignum>)mod;
- (bool)modExpInto:(id<MTBignum>)result a:(id<MTBignum>)a b:(id<MTBignum>)b mod:(id<MTBignum>)mod;
- (bool)addInto:(id<MTBignum>)result a:(id<MTBignum>)a b:(id<MTBignum>)b;
- (bool)subInto:(id<MTBignum>)result a:(id<MTBignum>)a b:(id<MTBignum>)b;
- (bool)mulInto:(id<MTBignum>)result a:(id<MTBignum>)a b:(id<MTBignum>)b;
- (bool)expInto:(id<MTBignum>)result a:(id<MTBignum>)a b:(id<MTBignum>)b;
- (bool)modInverseInto:(id<MTBignum>)result a:(id<MTBignum>)a mod:(id<MTBignum>)mod;
- (unsigned long)modWord:(id<MTBignum>)a mod:(unsigned long)mod;
- (bool)rightShift1Bit:(id<MTBignum>)result a:(id<MTBignum>)a;

- (id<MTBignum>)rsaGetE:(id<MTRsaPublicKey>)publicKey;
- (id<MTBignum>)rsaGetN:(id<MTRsaPublicKey>)publicKey;

@end

@protocol EncryptionProvider <NSObject>

- (id<MTBignumContext>)createBignumContext;

- (NSData * _Nullable)rsaEncryptWithPublicKey:(NSString *)publicKey data:(NSData *)data;
- (NSData * _Nullable)rsaEncryptPKCS1OAEPWithPublicKey:(NSString *)publicKey data:(NSData *)data;
- (id<MTRsaPublicKey>)parseRSAPublicKey:(NSString *)publicKey;

-(NSData * _Nonnull)macosRSAEncrypt:(NSString *) publicKey data: (NSData *)data;

@end

NS_ASSUME_NONNULL_END
