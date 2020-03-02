#import "TGDocumentAttributeAudio.h"

#import "LegacyComponentsInternal.h"

#import "PSKeyValueCoder.h"

@implementation TGDocumentAttributeAudio

- (instancetype)initWithIsVoice:(bool)isVoice title:(NSString *)title performer:(NSString *)performer duration:(int32_t)duration waveform:(TGAudioWaveform *)waveform
{
    self = [super init];
    if (self != nil)
    {
        _isVoice = isVoice;
        _title = title;
        _performer = performer;
        _duration = duration;
        _waveform = waveform;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    return [self initWithIsVoice:[aDecoder decodeBoolForKey:@"isVoice"] title:[aDecoder decodeObjectForKey:@"title"] performer:[aDecoder decodeObjectForKey:@"performer"] duration:[aDecoder decodeInt32ForKey:@"duration"] waveform:[aDecoder decodeObjectForKey:@"waveform"]];
}

- (instancetype)initWithKeyValueCoder:(PSKeyValueCoder *)coder
{
    return [self initWithIsVoice:[coder decodeInt32ForCKey:"isVoice"] title:[coder decodeStringForCKey:"title"] performer:[coder decodeStringForCKey:"performer"] duration:[coder decodeInt32ForCKey:"duration"] waveform:(TGAudioWaveform *)[coder decodeObjectForCKey:"waveform"]];
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeBool:_isVoice forKey:@"isVoice"];
    [aCoder encodeObject:_title forKey:@"title"];
    [aCoder encodeObject:_performer forKey:@"performer"];
    [aCoder encodeInt32:_duration forKey:@"duration"];
    [aCoder encodeObject:_waveform forKey:@"waveform"];
}

- (void)encodeWithKeyValueCoder:(PSKeyValueCoder *)coder
{
    [coder encodeInt32:_isVoice ? 1 : 0 forCKey:"isVoice"];
    [coder encodeString:_title forCKey:"title"];
    [coder encodeString:_performer forCKey:"performer"];
    [coder encodeInt32:_duration forCKey:"duration"];
    [coder encodeObject:_waveform forCKey:"waveform"];
}

- (BOOL)isEqual:(id)object
{
    return [object isKindOfClass:[TGDocumentAttributeAudio class]] && TGStringCompare(((TGDocumentAttributeAudio *)object)->_title, _title) && TGStringCompare(((TGDocumentAttributeAudio *)object)->_performer, _performer) && ((TGDocumentAttributeAudio *)object)->_duration == _duration && _isVoice == ((TGDocumentAttributeAudio *)object)->_isVoice;
}

@end
