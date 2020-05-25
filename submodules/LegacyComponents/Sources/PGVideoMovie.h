#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "GPUImageContext.h"
#import "GPUImageOutput.h"

@interface PGVideoMovie : GPUImageOutput

@property (readwrite, retain) AVAsset *asset;
@property (readwrite, retain) AVPlayerItem *playerItem;
@property (nonatomic, assign) bool shouldRepeat;

@property (readonly, nonatomic) CGFloat progress;

@property (readonly, nonatomic) AVAssetReader *assetReader;
@property (readonly, nonatomic) bool videoEncodingIsFinished;

- (instancetype)initWithAsset:(AVAsset *)asset;
- (instancetype)initWithPlayerItem:(AVPlayerItem *)playerItem;

- (BOOL)readNextVideoFrameFromOutput:(AVAssetReaderOutput *)readerVideoTrackOutput;
- (void)startProcessing;
- (void)endProcessing;
- (void)cancelProcessing;
- (void)processMovieFrame:(CMSampleBufferRef)movieSampleBuffer; 

- (void)reprocessCurrent;

@end
