#import "GPUImageTextureOutput.h"

@implementation GPUImageTextureOutput

@synthesize delegate = _delegate;
@synthesize texture = _texture;
@synthesize enabled;

#pragma mark -
#pragma mark Initialization and teardown

- (id)init;
{
    if (!(self = [super init]))
    {
		return nil;
    }
    
    self.enabled = YES;
    
    return self;
}

- (void)doneWithTexture;
{
    [firstInputFramebuffer unlock];
}

#pragma mark -
#pragma mark GPUImageInput protocol

- (void)newFrameReadyAtTime:(CMTime)frameTime atIndex:(NSInteger)textureIndex;
{
    [_delegate newFrameReadyFromTextureOutput:self];
}

- (NSInteger)nextAvailableTextureIndex;
{
    return 0;
}

- (CIImage *)CIImageWithSize:(CGSize)size
{
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CIImage *image = [[CIImage alloc] initWithTexture:self.texture size:size flipped:true colorSpace:colorSpace];
    CGColorSpaceRelease(colorSpace);
    return image;
}

// TODO: Deal with the fact that the texture changes regularly as a result of the caching
- (void)setInputFramebuffer:(GPUImageFramebuffer *)newInputFramebuffer atIndex:(NSInteger)textureIndex;
{
    firstInputFramebuffer = newInputFramebuffer;
    [firstInputFramebuffer lock];
    
    _texture = [firstInputFramebuffer texture];
}

- (void)setInputRotation:(GPUImageRotationMode)newInputRotation atIndex:(NSInteger)textureIndex;
{
}

- (void)setInputSize:(CGSize)newSize atIndex:(NSInteger)textureIndex;
{
}

- (CGSize)maximumOutputSize;
{
    return CGSizeZero;
}

- (void)endProcessing
{
}

- (BOOL)shouldIgnoreUpdatesToThisTarget;
{
    return NO;
}

- (BOOL)wantsMonochromeInput;
{
    return NO;
}

- (void)setCurrentlyReceivingMonochromeInput:(BOOL)newValue;
{
    
}

@end
