#import <WatchBridgeAudioImpl/TGBridgeAudioEncoder.h>
#import <AVFoundation/AVFoundation.h>

#import <OpusBinding/OpusBinding.h>

static const char *AMQueueSpecific = "AMQueueSpecific";

const NSInteger TGBridgeAudioEncoderSampleRate = 48000;

typedef enum {
    ATQueuePriorityLow,
    ATQueuePriorityDefault,
    ATQueuePriorityHigh
} ATQueuePriority;

@interface ATQueue : NSObject

+ (ATQueue *)mainQueue;
+ (ATQueue *)concurrentDefaultQueue;
+ (ATQueue *)concurrentBackgroundQueue;

- (instancetype)init;
- (instancetype)initWithName:(NSString *)name;
- (instancetype)initWithPriority:(ATQueuePriority)priority;

- (void)dispatch:(dispatch_block_t)block;
- (void)dispatch:(dispatch_block_t)block synchronous:(bool)synchronous;
- (void)dispatchAfter:(NSTimeInterval)seconds block:(dispatch_block_t)block;

- (dispatch_queue_t)nativeQueue;

@end

@interface TGFileDataItem : TGDataItem

- (instancetype)initWithTempFile;

- (void)appendData:(NSData *)data;
- (NSData *)readDataAtOffset:(NSUInteger)offset length:(NSUInteger)length;
- (NSUInteger)length;

- (NSString *)path;

@end

@interface TGBridgeAudioEncoder ()
{
    AVAssetReader *_assetReader;
    AVAssetReaderOutput *_readerOutput;
    
    NSMutableData *_audioBuffer;
    TGFileDataItem *_tempFileItem;
    TGOggOpusWriter *_oggWriter;
    
    int _tailLength;
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
        
        _tempFileItem = [[TGFileDataItem alloc] initWithTempFile];
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

+ (ATQueue *)processingQueue
{
    static ATQueue *queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        queue = [[ATQueue alloc] initWithName:@"org.telegram.opusAudioEncoderQueue"];
    });
    
    return queue;
}

static const int encoderPacketSizeInBytes = 16000 / 1000 * 60 * 2;

- (void)startWithCompletion:(void (^)(NSString *, int32_t))completion
{
    [[TGBridgeAudioEncoder processingQueue] dispatch:^
    {
        _oggWriter = [[TGOggOpusWriter alloc] init];
        if (![_oggWriter beginWithDataItem:_tempFileItem])
        {
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
                    [[TGBridgeAudioEncoder processingQueue] dispatch:^
                    {
                        if (_tailLength > 0) {
                            [_oggWriter writeFrame:(uint8_t *)_audioBuffer.bytes frameByteCount:(NSUInteger)_tailLength];
                        }
                    }];
                    break;
                }
            }
        }
        
        [[TGBridgeAudioEncoder processingQueue] dispatch:^
        {
            TGFileDataItem *dataItemResult = nil;
            NSTimeInterval durationResult = 0.0;
            
            NSUInteger totalBytes = 0;
            
            if (_assetReader.status == AVAssetReaderStatusCompleted)
            {
                NSLog(@"finished");
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
                completion(dataItemResult.path, (int32_t)durationResult);
        }];
    }];
}

- (void)_processBuffer:(AudioBuffer const *)buffer
{
    @autoreleasepool
    {
        if (_oggWriter == nil)
            return;
        
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
                else {
                    break;
                }
            }
            _tailLength = currentEncoderPacketSize;
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
                _tailLength = 0;
            }
        }
    }
}

@end

@interface TGFileDataItem ()
{
    NSUInteger _length;
    
    NSString *_fileName;
    bool _fileExists;
    
    NSMutableData *_data;
}

@end

@implementation TGFileDataItem
{
    ATQueue *_queue;
}

- (void)_commonInit
{
    _queue = [[ATQueue alloc] initWithPriority:ATQueuePriorityLow];
    _data = [[NSMutableData alloc] init];
}

- (instancetype)initWithTempFile
{
    self = [super init];
    if (self != nil)
    {
        [self _commonInit];
        
        [_queue dispatch:^
         {
             int64_t randomId = 0;
             arc4random_buf(&randomId, 8);
             _fileName = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSString alloc] initWithFormat:@"%" PRIx64 "", randomId]];
             _fileExists = false;
         }];
    }
    return self;
}

- (instancetype)initWithFilePath:(NSString *)filePath
{
    self = [super init];
    if (self != nil)
    {
        [self _commonInit];
        
        
        [_queue dispatch:^
        {
            _fileName = filePath;
            _length = [[[NSFileManager defaultManager] attributesOfItemAtPath:_fileName error:nil][NSFileSize] unsignedIntegerValue];
            _fileExists = [[NSFileManager defaultManager] fileExistsAtPath:_fileName];
        }];
    }
    return self;
}

- (void)noop
{
}

- (void)moveToPath:(NSString *)path
{
    [_queue dispatch:^
    {
        [[NSFileManager defaultManager] moveItemAtPath:_fileName toPath:path error:nil];
        _fileName = path;
    }];
}

- (void)remove
{
    [_queue dispatch:^
    {
        [[NSFileManager defaultManager] removeItemAtPath:_fileName error:nil];
    }];
}

- (void)appendData:(NSData *)data
{
    [_queue dispatch:^
    {
        if (!_fileExists)
        {
            [[NSFileManager defaultManager] createFileAtPath:_fileName contents:nil attributes:nil];
            _fileExists = true;
        }
        NSFileHandle *file = [NSFileHandle fileHandleForUpdatingAtPath:_fileName];
        [file seekToEndOfFile];
        [file writeData:data];
        [file synchronizeFile];
        [file closeFile];
        _length += data.length;
        
        [_data appendData:data];
    }];
}

- (NSData *)readDataAtOffset:(NSUInteger)offset length:(NSUInteger)length
{
    __block NSData *data = nil;
    
    [_queue dispatch:^
    {
        NSFileHandle *file = [NSFileHandle fileHandleForUpdatingAtPath:_fileName];
        [file seekToFileOffset:(unsigned long long)offset];
        data = [file readDataOfLength:length];
        if (data.length != length)
            //TGLog(@"Read data length mismatch");
        [file closeFile];
    } synchronous:true];
    
    return data;
}

- (NSUInteger)length
{
    __block NSUInteger result = 0;
    [_queue dispatch:^
    {
        result = _length;
    } synchronous:true];
    
    return result;
}

- (NSString *)path {
    return _fileName;
}

@end


@interface ATQueue ()
{
    dispatch_queue_t _nativeQueue;
    bool _isMainQueue;
    
    int32_t _noop;
}

@end

@implementation ATQueue

+ (NSString *)applicationPrefix
{
    static NSString *prefix = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
                  {
                      prefix = [[NSBundle mainBundle] bundleIdentifier];
                  });
    
    return prefix;
}

+ (ATQueue *)mainQueue
{
    static ATQueue *queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        queue = [[ATQueue alloc] init];
        queue->_nativeQueue = dispatch_get_main_queue();
        queue->_isMainQueue = true;
    });
    
    return queue;
}

+ (ATQueue *)concurrentDefaultQueue
{
    static ATQueue *queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        queue = [[ATQueue alloc] initWithNativeQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
    });
    
    return queue;
}

+ (ATQueue *)concurrentBackgroundQueue
{
    static ATQueue *queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        queue = [[ATQueue alloc] initWithNativeQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)];
    });
    
    return queue;
}

- (instancetype)init
{
    return [self initWithName:[[ATQueue applicationPrefix] stringByAppendingFormat:@".%ld", lrand48()]];
}

- (instancetype)initWithName:(NSString *)name
{
    self = [super init];
    if (self != nil)
    {
        _nativeQueue = dispatch_queue_create([name UTF8String], DISPATCH_QUEUE_SERIAL);
        dispatch_queue_set_specific(_nativeQueue, AMQueueSpecific, (__bridge void *)self, NULL);
    }
    return self;
}

- (instancetype)initWithPriority:(ATQueuePriority)priority
{
    self = [super init];
    if (self != nil)
    {
        _nativeQueue = dispatch_queue_create([[[ATQueue applicationPrefix] stringByAppendingFormat:@".%ld", lrand48()] UTF8String], DISPATCH_QUEUE_SERIAL);
        long targetQueueIdentifier = DISPATCH_QUEUE_PRIORITY_DEFAULT;
        switch (priority)
        {
            case ATQueuePriorityLow:
                targetQueueIdentifier = DISPATCH_QUEUE_PRIORITY_LOW;
                break;
            case ATQueuePriorityDefault:
                targetQueueIdentifier = DISPATCH_QUEUE_PRIORITY_DEFAULT;
                break;
            case ATQueuePriorityHigh:
                targetQueueIdentifier = DISPATCH_QUEUE_PRIORITY_HIGH;
                break;
        }
        dispatch_set_target_queue(_nativeQueue, dispatch_get_global_queue(targetQueueIdentifier, 0));
        dispatch_queue_set_specific(_nativeQueue, AMQueueSpecific, (__bridge void *)self, NULL);
    }
    return self;
}

- (instancetype)initWithNativeQueue:(dispatch_queue_t)queue
{
    self = [super init];
    if (self != nil)
    {
#if !OS_OBJECT_USE_OBJC
        _nativeQueue = dispatch_retain(queue);
#else
        _nativeQueue = queue;
#endif
    }
    return self;
}

- (void)dealloc
{
    if (_nativeQueue != nil)
    {
#if !OS_OBJECT_USE_OBJC
        dispatch_release(_nativeQueue);
#endif
        _nativeQueue = nil;
    }
}

- (void)dispatch:(dispatch_block_t)block
{
    [self dispatch:block synchronous:false];
}

- (void)dispatch:(dispatch_block_t)block synchronous:(bool)synchronous
{
    __block ATQueue *strongSelf = self;
    dispatch_block_t blockWithSelf = ^
    {
        block();
        [strongSelf noop];
        strongSelf = nil;
    };
    
    if (_isMainQueue)
    {
        if ([NSThread isMainThread])
            blockWithSelf();
        else if (synchronous)
            dispatch_sync(_nativeQueue, blockWithSelf);
        else
            dispatch_async(_nativeQueue, blockWithSelf);
    }
    else
    {
        if (dispatch_get_specific(AMQueueSpecific) == (__bridge void *)self)
            block();
        else if (synchronous)
            dispatch_sync(_nativeQueue, blockWithSelf);
        else
            dispatch_async(_nativeQueue, blockWithSelf);
    }
}

- (void)dispatchAfter:(NSTimeInterval)seconds block:(dispatch_block_t)block
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(seconds * NSEC_PER_SEC)), _nativeQueue, block);
}

- (dispatch_queue_t)nativeQueue
{
    return _nativeQueue;
}

- (void)noop
{
}

@end
