#import <WatchBridgeAudioImpl/TGBridgeAudioDecoder.h>

#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

#import <SSignalKit/SSignalKit.h>

#import <OpusBinding/OpusBinding.h>

const NSInteger TGBridgeAudioDecoderInputSampleRate = 48000;
const NSInteger TGBridgeAudioDecoderResultSampleRate = 24000;
const NSUInteger TGBridgeAudioDecoderBufferSize = 32768;

#define checkResult(result,operation) (_checkResultLite((result),(operation),__FILE__,__LINE__))

struct TGAudioBuffer
{
    NSUInteger capacity;
    uint8_t *data;
    NSUInteger size;
    int64_t pcmOffset;
};

inline TGAudioBuffer *TGAudioBufferWithCapacity(NSUInteger capacity)
{
    TGAudioBuffer *audioBuffer = (TGAudioBuffer *)malloc(sizeof(TGAudioBuffer));
    audioBuffer->capacity = capacity;
    audioBuffer->data = (uint8_t *)malloc(capacity);
    audioBuffer->size = 0;
    audioBuffer->pcmOffset = 0;
    return audioBuffer;
}

inline void TGAudioBufferDispose(TGAudioBuffer *audioBuffer)
{
    if (audioBuffer != NULL)
    {
        free(audioBuffer->data);
        free(audioBuffer);
    }
}

static inline bool _checkResultLite(OSStatus result, const char *operation, const char* file, int line)
{
    if ( result != noErr )
    {
        NSLog(@"%s:%d: %s result %d %08X %4.4s\n", file, line, operation, (int)result, (int)result, (char*)&result);
        return NO;
    }
    return YES;
}

@interface TGBridgeAudioDecoder ()
{
    NSURL *_url;
    NSURL *_resultURL;
    
    OggOpusReader *_opusReader;
    
    bool _finished;
    bool _cancelled;
}
@end

@implementation TGBridgeAudioDecoder

- (instancetype)initWithURL:(NSURL *)url outputUrl:(NSURL *)outputUrl
{
    self = [super init];
    if (self != nil)
    {
        _url = url;
        
        int64_t randomId = 0;
        arc4random_buf(&randomId, 8);
        _resultURL = outputUrl;
    }
    return self;
}

- (void)startWithCompletion:(void (^)(void))completion
{
    [[TGBridgeAudioDecoder processingQueue] dispatch:^
    {
        _opusReader = [[OggOpusReader alloc] initWithPath:_url.path];
        if (_opusReader == NULL) {
            return;
        }
        
        AudioStreamBasicDescription sourceFormat;
        sourceFormat.mSampleRate = TGBridgeAudioDecoderInputSampleRate;
        sourceFormat.mFormatID = kAudioFormatLinearPCM;
        sourceFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
        sourceFormat.mFramesPerPacket = 1;
        sourceFormat.mChannelsPerFrame = 1;
        sourceFormat.mBitsPerChannel = 16;
        sourceFormat.mBytesPerPacket = 2;
        sourceFormat.mBytesPerFrame = 2;
        
        AudioStreamBasicDescription destFormat;
        memset(&destFormat, 0, sizeof(destFormat));
        destFormat.mChannelsPerFrame = sourceFormat.mChannelsPerFrame;
        destFormat.mFormatID = kAudioFormatMPEG4AAC;
        destFormat.mSampleRate = TGBridgeAudioDecoderResultSampleRate;
        UInt32 size = sizeof(destFormat);
        if (!checkResult(AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, NULL, &size, &destFormat),
                          "AudioFormatGetProperty(kAudioFormatProperty_FormatInfo)"))
        {
            return;
        }
        
        ExtAudioFileRef destinationFile;
        if (!checkResult(ExtAudioFileCreateWithURL((__bridge CFURLRef)_resultURL, kAudioFileM4AType, &destFormat, NULL, kAudioFileFlags_EraseFile, &destinationFile), "ExtAudioFileCreateWithURL"))
        {
            return;
        }
        
        if (!checkResult(ExtAudioFileSetProperty(destinationFile, kExtAudioFileProperty_ClientDataFormat, size, &sourceFormat),
                         "ExtAudioFileSetProperty(destinationFile, kExtAudioFileProperty_ClientDataFormat"))
        {
            return;
        }
        
        bool canResumeAfterInterruption = false;
        AudioConverterRef converter;
        size = sizeof(converter);
        if (checkResult(ExtAudioFileGetProperty(destinationFile, kExtAudioFileProperty_AudioConverter, &size, &converter),
                         "ExtAudioFileGetProperty(kExtAudioFileProperty_AudioConverter;)"))
        {
            UInt32 canResume = 0;
            size = sizeof(canResume);
            if (AudioConverterGetProperty(converter, kAudioConverterPropertyCanResumeFromInterruption, &size, &canResume) == noErr)
                canResumeAfterInterruption = canResume;
        }
        
        uint8_t srcBuffer[TGBridgeAudioDecoderBufferSize];
        while (!_cancelled)
        {
            AudioBufferList bufferList;
            bufferList.mNumberBuffers = 1;
            bufferList.mBuffers[0].mNumberChannels = sourceFormat.mChannelsPerFrame;
            bufferList.mBuffers[0].mDataByteSize = TGBridgeAudioDecoderBufferSize;
            bufferList.mBuffers[0].mData = srcBuffer;
            
            uint32_t writtenOutputBytes = 0;
            while (writtenOutputBytes < TGBridgeAudioDecoderBufferSize)
            {
                int32_t readSamples = [_opusReader read:(uint16_t *)(srcBuffer + writtenOutputBytes) bufSize:(TGBridgeAudioDecoderBufferSize - writtenOutputBytes) / sourceFormat.mBytesPerFrame];
                
                if (readSamples > 0)
                    writtenOutputBytes += readSamples * sourceFormat.mBytesPerFrame;
                else
                    break;
            }
            bufferList.mBuffers[0].mDataByteSize = writtenOutputBytes;
            int32_t nFrames = writtenOutputBytes / sourceFormat.mBytesPerFrame;
            
            if (nFrames == 0)
                break;
            
            OSStatus status = ExtAudioFileWrite(destinationFile, nFrames, &bufferList);
            if (status == kExtAudioFileError_CodecUnavailableInputConsumed)
            {
                //TGLog(@"1");
            }
            else if (status == kExtAudioFileError_CodecUnavailableInputNotConsumed)
            {
                //TGLog(@"2");
            }
            else if (!checkResult(status, "ExtAudioFileWrite"))
            {
                //TGLog(@"3");
            }
        }
        
        ExtAudioFileDispose(destinationFile);
        
        if (completion != nil)
            completion();
    }];
}

+ (SQueue *)processingQueue
{
    static SQueue *queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        static const char *queueSpecific = "org.telegram.opusAudioDecoderQueue";
        dispatch_queue_t dispatchQueue = dispatch_queue_create("org.telegram.opusAudioDecoderQueue", DISPATCH_QUEUE_SERIAL);
        dispatch_queue_set_specific(dispatchQueue, queueSpecific, (void *)queueSpecific, NULL);
        queue = [SQueue wrapConcurrentNativeQueue:dispatchQueue];
    });
    return queue;
}

@end
