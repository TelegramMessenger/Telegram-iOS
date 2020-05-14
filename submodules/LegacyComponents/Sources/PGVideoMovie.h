#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "GPUImageContext.h"
#import "GPUImageOutput.h"

@interface PGVideoMovie : GPUImageOutput

@property (readwrite, retain) AVAsset *asset;
@property (readonly, assign) bool shouldRepeat;

@property (readonly, nonatomic) CGFloat progress;

@property (readonly, nonatomic) AVAssetReader *assetReader;
@property (readonly, nonatomic) BOOL audioEncodingIsFinished;
@property (readonly, nonatomic) BOOL videoEncodingIsFinished;

- (instancetype)initWithAsset:(AVAsset *)asset;

- (BOOL)readNextVideoFrameFromOutput:(AVAssetReaderOutput *)readerVideoTrackOutput;
- (BOOL)readNextAudioSampleFromOutput:(AVAssetReaderOutput *)readerAudioTrackOutput;
- (void)startProcessing;
- (void)endProcessing;
- (void)cancelProcessing;
- (void)processMovieFrame:(CMSampleBufferRef)movieSampleBuffer; 

@end
