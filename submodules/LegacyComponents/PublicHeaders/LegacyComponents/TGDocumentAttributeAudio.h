#import <Foundation/Foundation.h>

#import <LegacyComponents/PSCoding.h>

#import <LegacyComponents/TGAudioWaveform.h>

@interface TGDocumentAttributeAudio : NSObject <NSCoding, PSCoding>

@property (nonatomic, readonly) bool isVoice;
@property (nonatomic, strong, readonly) NSString *title;
@property (nonatomic, strong, readonly) NSString *performer;
@property (nonatomic, readonly) int32_t duration;
@property (nonatomic, strong, readonly) TGAudioWaveform *waveform;

- (instancetype)initWithIsVoice:(bool)isVoice title:(NSString *)title performer:(NSString *)performer duration:(int32_t)duration waveform:(TGAudioWaveform *)waveform;

@end
