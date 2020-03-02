#import <Foundation/Foundation.h>
#import "GPUImageContext.h"

typedef struct
{
    GLubyte red;
    GLubyte green;
    GLubyte blue;
    GLubyte alpha;
} PGByteColorVector;

@protocol GPURawDataProcessor;

@interface PGPhotoEditorRawDataOutput : NSObject <GPUImageInput>
{
    GPUImageRotationMode inputRotation;
    bool outputBGRA;
}

@property (nonatomic, readonly) GLubyte *rawBytesForImage;
@property (nonatomic, copy) void(^newFrameAvailableBlock)(void);
@property (nonatomic, assign) bool enabled;
@property (nonatomic, assign) CGSize imageSize;

- (instancetype)initWithImageSize:(CGSize)newImageSize resultsInBGRAFormat:(bool)resultsInBGRAFormat;

- (PGByteColorVector)colorAtLocation:(CGPoint)locationInImage;
- (NSUInteger)bytesPerRowInOutput;

- (void)lockFramebufferForReading;
- (void)unlockFramebufferAfterReading;

@end