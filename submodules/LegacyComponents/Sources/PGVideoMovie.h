#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "GPUImageContext.h"
#import "GPUImageOutput.h"

@interface PGVideoMovie : GPUImageOutput

@property (readwrite, retain) AVAsset *asset;
@property (nonatomic, assign) bool shouldRepeat;

@property (readonly, nonatomic) CGFloat progress;

@property (readonly, nonatomic) AVAssetReader *assetReader;
@property (readonly, nonatomic) bool audioEncodingIsFinished;
@property (readonly, nonatomic) bool videoEncodingIsFinished;

- (instancetype)initWithAsset:(AVAsset *)asset;

- (BOOL)readNextVideoFrameFromOutput:(AVAssetReaderOutput *)readerVideoTrackOutput;
- (BOOL)readNextAudioSampleFromOutput:(AVAssetReaderOutput *)readerAudioTrackOutput;
- (void)startProcessing;
- (void)endProcessing;
- (void)cancelProcessing;
- (void)processMovieFrame:(CMSampleBufferRef)movieSampleBuffer; 

@end
