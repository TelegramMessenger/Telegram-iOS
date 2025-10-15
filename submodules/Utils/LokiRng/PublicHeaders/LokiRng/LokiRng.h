#ifndef LokiRng_h
#define LokiRng_h

#import <Foundation/Foundation.h>

@interface LokiRng : NSObject

- (instancetype _Nonnull)initWithSeed0:(NSUInteger)seed0 seed1:(NSUInteger)seed1 seed2:(NSUInteger)seed2;

- (float)next;

@end

#endif /* LokiRng_h */
