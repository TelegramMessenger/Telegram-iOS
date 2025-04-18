#import <LokiRng/LokiRng.h>

static uint32_t tausStep(const uint32_t z, const int32_t s1, const int32_t s2, const int32_t s3, const uint32_t M) {
    uint32_t b = (((z << s1) ^ z) >> s2);
    return (((z & M) << s3) ^ b);
}

@interface LokiRng () {
    float _seed;
}

@end

@implementation LokiRng

- (instancetype _Nonnull)initWithSeed0:(NSUInteger)seed0 seed1:(NSUInteger)seed1 seed2:(NSUInteger)seed2 {
    self = [super init];
    if (self != nil) {
        uint32_t seed = ((uint32_t)seed0) * 1099087573U;
        uint32_t seedb = ((uint32_t)seed1) * 1099087573U;
        uint32_t seedc = ((uint32_t)seed2) * 1099087573U;

        // Round 1: Randomise seed
        uint32_t z1 = tausStep(seed,13,19,12,429496729U);
        uint32_t z2 = tausStep(seed,2,25,4,4294967288U);
        uint32_t z3 = tausStep(seed,3,11,17,429496280U);
        uint32_t z4 = (1664525*seed + 1013904223U);

        // Round 2: Randomise seed again using second seed
        uint32_t r1 = (z1^z2^z3^z4^seedb);

        z1 = tausStep(r1,13,19,12,429496729U);
        z2 = tausStep(r1,2,25,4,4294967288U);
        z3 = tausStep(r1,3,11,17,429496280U);
        z4 = (1664525*r1 + 1013904223U);

        // Round 3: Randomise seed again using third seed
        r1 = (z1^z2^z3^z4^seedc);

        z1 = tausStep(r1,13,19,12,429496729U);
        z2 = tausStep(r1,2,25,4,4294967288U);
        z3 = tausStep(r1,3,11,17,429496280U);
        z4 = (1664525*r1 + 1013904223U);

        _seed = (z1^z2^z3^z4) * 2.3283064365387e-10f;
    }
    return self;
}

- (float)next {
    uint32_t hashed_seed = _seed * 1099087573U;

    uint32_t z1 = tausStep(hashed_seed,13,19,12,429496729U);
    uint32_t z2 = tausStep(hashed_seed,2,25,4,4294967288U);
    uint32_t z3 = tausStep(hashed_seed,3,11,17,429496280U);
    uint32_t z4 = (1664525*hashed_seed + 1013904223U);

    float old_seed = _seed;
    _seed = (z1^z2^z3^z4) * 2.3283064365387e-10f;

    return old_seed;
}

@end
