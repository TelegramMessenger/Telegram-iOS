#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import <AVFoundation/AVFoundation.h>

@interface PGCameraMomentSegment : NSObject

@property (nonatomic, readonly) NSURL *fileURL;
@property (nonatomic, readonly) AVAsset *asset;
@property (nonatomic, readonly) NSTimeInterval duration;

- (instancetype)initWithURL:(NSURL *)url duration:(NSTimeInterval)duration;

@end
