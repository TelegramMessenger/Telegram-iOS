#import <MurMurHash32/MurMurHash32.h>

#include <stdlib.h>
#include <string.h>

#define FORCE_INLINE __attribute__((always_inline))

static inline uint32_t rotl32 ( uint32_t x, int8_t r )
{
    return (x << r) | (x >> (32 - r));
}

#define ROTL32(x,y) rotl32(x,y)

static FORCE_INLINE uint32_t getblock ( const uint32_t * p, int i )
{
    return p[i];
}

static FORCE_INLINE uint32_t fmix ( uint32_t h )
{
    h ^= h >> 16;
    h *= 0x85ebca6b;
    h ^= h >> 13;
    h *= 0xc2b2ae35;
    h ^= h >> 16;
    
    return h;
}

static void murMurHash32Impl(const void *key, uint32_t len, uint32_t seed, void *out)
{
    const uint8_t * data = (const uint8_t*)key;
    const int nblocks = len / 4;
    
    uint32_t h1 = seed;
    
    const uint32_t c1 = 0xcc9e2d51;
    const uint32_t c2 = 0x1b873593;
    
    //----------
    // body
    
    const uint32_t * blocks = (const uint32_t *)(data + nblocks*4);
    
    for(int i = -nblocks; i; i++)
    {
        uint32_t k1 = getblock(blocks,i);
        
        k1 *= c1;
        k1 = ROTL32(k1,15);
        k1 *= c2;
        
        h1 ^= k1;
        h1 = ROTL32(h1,13);
        h1 = h1*5+0xe6546b64;
    }
    
    //----------
    // tail
    
    const uint8_t * tail = (const uint8_t*)(data + nblocks*4);
    
    uint32_t k1 = 0;
    
    switch(len & 3)
    {
        case 3: k1 ^= tail[2] << 16;
        case 2: k1 ^= tail[1] << 8;
        case 1: k1 ^= tail[0];
            k1 *= c1; k1 = ROTL32(k1,15); k1 *= c2; h1 ^= k1;
    };
    
    //----------
    // finalization
    
    h1 ^= len;
    
    h1 = fmix(h1);
    
    *(uint32_t*)out = h1;
}

int32_t murMurHash32(void *bytes, int length)
{
    int32_t result = 0;
    murMurHash32Impl(bytes, length, -137723950, &result);
    
    return result;
}

int32_t murMurHash32Data(NSData *data) {
    return murMurHash32((void *)data.bytes, (int)data.length);
}

int32_t murMurHashString32(const char *s)
{
    int32_t result = 0;
    murMurHash32Impl(s, (int)strlen(s), -137723950, &result);
    
    return result;
}

