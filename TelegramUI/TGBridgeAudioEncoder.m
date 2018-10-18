#import "TGBridgeAudioEncoder.h"
#import <AVFoundation/AVFoundation.h>

#import <SSignalKit/SSignalKit.h>

#import "opus.h"
#import "opusenc.h"

#import "TGDataItem.h"

const NSInteger TGBridgeAudioEncoderSampleRate = 16000;

@interface TGBridgeAudioEncoder ()
{
    AVAssetReader *_assetReader;
    AVAssetReaderOutput *_readerOutput;
    
    NSMutableData *_audioBuffer;
    TGDataItem *_tempFileItem;
    TGOggOpusWriter *_oggWriter;
}
@end

@implementation TGBridgeAudioEncoder

- (instancetype)initWithURL:(NSURL *)url
{
    self = [super init];
    if (self != nil)
    {
        AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:url options:nil];
        if (asset == nil || asset.tracks.count == 0)
        {
            //TGLog(@"Asset create fail");
            return nil;
        }
        
        NSError *error;
        _assetReader = [[AVAssetReader alloc] initWithAsset:asset error:&error];
        
        NSDictionary *outputSettings = @
        {
            AVFormatIDKey: @(kAudioFormatLinearPCM),
            AVSampleRateKey: @(TGBridgeAudioEncoderSampleRate),
            AVNumberOfChannelsKey: @1,
            AVLinearPCMBitDepthKey: @16,
            AVLinearPCMIsFloatKey: @false,
            AVLinearPCMIsBigEndianKey: @false,
            AVLinearPCMIsNonInterleaved: @false
        };
        
        _readerOutput = [AVAssetReaderAudioMixOutput assetReaderAudioMixOutputWithAudioTracks:asset.tracks audioSettings:outputSettings];
        
        [_assetReader addOutput:_readerOutput];
        
        _tempFileItem = [[TGDataItem alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [self cleanup];
}

- (void)cleanup
{
    _oggWriter = nil;
}

+ (SQueue *)processingQueue
{
    static SQueue *queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        static const char *queueSpecific = "org.telegram.opusAudioEncoderQueue";
        dispatch_queue_t dispatchQueue = dispatch_queue_create("org.telegram.opusAudioEncoderQueue", DISPATCH_QUEUE_SERIAL);
        dispatch_queue_set_specific(dispatchQueue, queueSpecific, (void *)queueSpecific, NULL);
        queue = [SQueue wrapConcurrentNativeQueue:dispatchQueue];
    });
    return queue;
}

- (void)startWithCompletion:(void (^)(TGDataItem *, int32_t))completion
{
    CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
    
    [[TGBridgeAudioEncoder processingQueue] dispatch:^
    {
        _oggWriter = [[TGOggOpusWriter alloc] init];
        if (![_oggWriter beginWithDataItem:_tempFileItem])
        {
            //TGLog(@"[TGBridgeAudioEncoder#%x error initializing ogg opus writer]", self);
            [self cleanup];
            return;
        }
        
        [_assetReader startReading];
        
        while (_assetReader.status != AVAssetReaderStatusCompleted)
        {
            if (_assetReader.status == AVAssetReaderStatusReading)
            {
                CMSampleBufferRef nextBuffer = [_readerOutput copyNextSampleBuffer];
                if (nextBuffer)
                {
                    AudioBufferList abl;
                    CMBlockBufferRef blockBuffer;
                    CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(nextBuffer, NULL, &abl, sizeof(abl), NULL, NULL, kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment, &blockBuffer);
                    
                    [[TGBridgeAudioEncoder processingQueue] dispatch:^
                    {
                        [self _processBuffer:&abl.mBuffers[0]];
                        
                        CFRelease(nextBuffer);
                        CFRelease(blockBuffer);
                    }];
                }
                else
                {
                    break;
                }
            }
        }
        
        TGDataItem *dataItemResult = nil;
        NSTimeInterval durationResult = 0.0;
        
        NSUInteger totalBytes = 0;
        
        if (_assetReader.status == AVAssetReaderStatusCompleted)
        {
            if (_oggWriter != nil && [_oggWriter writeFrame:NULL frameByteCount:0])
            {
                dataItemResult = _tempFileItem;
                durationResult = [_oggWriter encodedDuration];
                totalBytes = [_oggWriter encodedBytes];
            }
             
            [self cleanup];
        }
        
        //TGLog(@"[TGBridgeAudioEncoder#%x convert time: %f ms]", self, (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0);
        
        if (completion != nil)
            completion(dataItemResult, (int32_t)durationResult);
    }];
}

- (void)_processBuffer:(AudioBuffer const *)buffer
{
    @autoreleasepool
    {
        if (_oggWriter == nil)
            return;
        
        static const int millisecondsPerPacket = 60;
        static const int encoderPacketSizeInBytes = TGBridgeAudioEncoderSampleRate / 1000 * millisecondsPerPacket * 2;
        
        unsigned char currentEncoderPacket[encoderPacketSizeInBytes];
        
        int bufferOffset = 0;
        
        while (true)
        {
            int currentEncoderPacketSize = 0;
            
            while (currentEncoderPacketSize < encoderPacketSizeInBytes)
            {
                if (_audioBuffer.length != 0)
                {
                    int takenBytes = MIN((int)_audioBuffer.length, encoderPacketSizeInBytes - currentEncoderPacketSize);
                    if (takenBytes != 0)
                    {
                        memcpy(currentEncoderPacket + currentEncoderPacketSize, _audioBuffer.bytes, takenBytes);
                        [_audioBuffer replaceBytesInRange:NSMakeRange(0, takenBytes) withBytes:NULL length:0];
                        currentEncoderPacketSize += takenBytes;
                    }
                }
                else if (bufferOffset < (int)buffer->mDataByteSize)
                {
                    int takenBytes = MIN((int)buffer->mDataByteSize - bufferOffset, encoderPacketSizeInBytes - currentEncoderPacketSize);
                    if (takenBytes != 0)
                    {
                        memcpy(currentEncoderPacket + currentEncoderPacketSize, ((const char *)buffer->mData) + bufferOffset, takenBytes);
                        bufferOffset += takenBytes;
                        currentEncoderPacketSize += takenBytes;
                    }
                }
                else
                    break;
            }
            
            if (currentEncoderPacketSize < encoderPacketSizeInBytes)
            {
                if (_audioBuffer == nil)
                    _audioBuffer = [[NSMutableData alloc] initWithCapacity:encoderPacketSizeInBytes];
                [_audioBuffer appendBytes:currentEncoderPacket length:currentEncoderPacketSize];
                
                break;
            }
            else
            {
                [_oggWriter writeFrame:currentEncoderPacket frameByteCount:(NSUInteger)currentEncoderPacketSize];
            }
        }
    }
}

@end
