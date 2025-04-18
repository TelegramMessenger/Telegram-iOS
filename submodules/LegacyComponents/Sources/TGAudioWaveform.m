#import "TGAudioWaveform.h"

#import "LegacyComponentsInternal.h"

#import "PSKeyValueCoder.h"

static int32_t get_bits(uint8_t const *bytes, unsigned int bitOffset, unsigned int numBits)
{
    uint8_t const *data = bytes;
    numBits = (unsigned int)pow(2, numBits) - 1; //this will only work up to 32 bits, of course
    data += bitOffset / 8;
    bitOffset %= 8;
    return (*((int*)data) >> bitOffset) & numBits;
}

static void set_bits(uint8_t *bytes, int32_t bitOffset, int32_t numBits, int32_t value) {
    numBits = (unsigned int)pow(2, numBits) - 1; //this will only work up to 32 bits, of course
    uint8_t *data = bytes;
    data += bitOffset / 8;
    bitOffset %= 8;
    *((int32_t *)data) |= ((value) << bitOffset);
}

@implementation TGAudioWaveform

- (instancetype)initWithSamples:(NSData *)samples peak:(int32_t)peak {
    self = [super init];
    if (self != nil) {
        _samples = samples;
        _peak = peak;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    return [self initWithSamples:[aDecoder decodeObjectForKey:@"samples"] peak:[aDecoder decodeInt32ForKey:@"peak"]];
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:_samples forKey:@"samples"];
    [aCoder encodeInt32:_peak forKey:@"peak"];
}

- (instancetype)initWithKeyValueCoder:(PSKeyValueCoder *)coder {
    return [self initWithSamples:[coder decodeDataCorCKey:"samples"] peak:[coder decodeInt32ForCKey:"peak"]];
}

- (void)encodeWithKeyValueCoder:(PSKeyValueCoder *)coder {
    [coder encodeData:_samples forCKey:"samples"];
    [coder encodeInt32:_peak forCKey:"peak"];
}

- (instancetype)initWithBitstream:(NSData *)bitstream bitsPerSample:(NSUInteger)bitsPerSample {
    int numSamples = (int)(bitstream.length * 8 / bitsPerSample);
    uint8_t const *bytes = bitstream.bytes;
    int32_t maxSample = (1 << bitsPerSample) - 1;
    NSMutableData *result = [[NSMutableData alloc] initWithLength:numSamples * 2];
    int16_t *samples = result.mutableBytes;
    int32_t norm = (1 << bitsPerSample) - 1;
    for (int i = 0; i < numSamples; i++) {
        samples[i] = (int16_t)(((int64_t)get_bits(bytes, i * 5, 5) * maxSample) / norm);
    }
    return [self initWithSamples:result peak:31];
}

- (NSData *)bitstream {
    int numSamples = (int)(_samples.length / 2);
    int bitstreamLength = (numSamples * 5) / 8 + (((numSamples * 5) % 8) == 0 ? 0 : 1);
    NSMutableData *result = [[NSMutableData alloc] initWithLength:bitstreamLength];
    int32_t maxSample = _peak;
    uint16_t const *samples = _samples.bytes;
    uint8_t *bytes = result.mutableBytes;
    
    for (int i = 0; i < numSamples; i++) {
        int32_t value = MIN(31, ABS((int32_t)samples[i]) * 31 / maxSample);
        set_bits(bytes, i * 5, 5, value & 31);
    }
    return result;
}

- (BOOL)isEqual:(id)object {
    return [object isKindOfClass:[TGAudioWaveform class]] && TGObjectCompare(_samples, ((TGAudioWaveform *)object)->_samples) && _peak == ((TGAudioWaveform *)object)->_peak;
}

@end
