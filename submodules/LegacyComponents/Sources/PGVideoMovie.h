#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "GPUImageContext.h"
#import "GPUImageOutput.h"

@interface PGVideoMovie : GPUImageOutput

@property (readwrite, retain) AVPlayerItem *playerItem;

- (instancetype)initWithPlayerItem:(AVPlayerItem *)playerItem;

- (void)startProcessing;
- (void)endProcessing;
- (void)cancelProcessing;
- (void)processMovieFrame:(CMSampleBufferRef)movieSampleBuffer; 

- (void)process;
- (void)reprocessCurrent;

@end
