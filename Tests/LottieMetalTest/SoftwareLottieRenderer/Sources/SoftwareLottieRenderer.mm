#import <SoftwareLottieRenderer/SoftwareLottieRenderer.h>

#import <LottieCpp/LottieCpp.h>
#import <LottieCpp/NullCanvasImpl.h>

#import "CoreGraphicsCanvasImpl.h"
#import "SkiaCanvasImpl.h"

#include <LottieCpp/RenderTreeNode.h>
#include <LottieCpp/CGPathCocoa.h>
#include <LottieCpp/VectorsCocoa.h>

#import <Accelerate/Accelerate.h>

CGRect getPathNativeBoundingBox(CGPathRef _Nonnull path) {
    auto rect = calculatePathBoundingBox(path);
    return CGRectMake(rect.origin.x, rect.origin.y, rect.size.width, rect.size.height);
}

@interface SoftwareLottieRenderer() {
    std::shared_ptr<lottie::Renderer> _renderer;
    std::shared_ptr<lottie::CanvasRenderer> _canvasRenderer;
}

@end

@implementation SoftwareLottieRenderer

- (instancetype _Nullable)initWithData:(NSData * _Nonnull)data {
    self = [super init];
    if (self != nil) {
        _renderer = lottie::Renderer::make(std::string((uint8_t const *)data.bytes, ((uint8_t const *)data.bytes) + data.length));
        if (!_renderer) {
            return nil;
        }
        
        _canvasRenderer = std::make_shared<lottie::CanvasRenderer>();
    }
    return self;
}

- (NSInteger)frameCount {
    return (NSInteger)_renderer->frameCount();
}

- (NSInteger)framesPerSecond {
    return (NSInteger)_renderer->framesPerSecond();
}

- (CGSize)size {
    lottie::Vector2D size = _renderer->size();
    return CGSizeMake(size.x, size.y);
}

- (void)setFrame:(CGFloat)index {
    _renderer->setFrame((float)index);
}

- (UIImage * _Nullable)renderForSize:(CGSize)size useReferenceRendering:(bool)useReferenceRendering canUseMoreMemory:(bool)canUseMoreMemory skipImageGeneration:(bool)skipImageGeneration {
    std::shared_ptr<lottie::RenderTreeNode> renderNode = _renderer->renderNode();
    if (!renderNode) {
        return nil;
    }
    
    lottie::CanvasRenderer::Configuration configuration;
    configuration.canUseMoreMemory = canUseMoreMemory;
    //configuration.canUseMoreMemory = true;
    //configuration.disableGroupTransparency = true;
    
    if (useReferenceRendering) {
        auto context = std::make_shared<lottie::CoreGraphicsCanvasImpl>((int)size.width, (int)size.height);
        
        _canvasRenderer->render(_renderer, context, lottie::Vector2D(size.width, size.height), configuration);
        
        auto image = context->makeImage();
        
        return [[UIImage alloc] initWithCGImage:std::static_pointer_cast<lottie::CoreGraphicsCanvasImpl::Image>(image)->nativeImage()];
    } else {
        if ((int64_t)"" > 0) {
            int bytesPerRow = ((int)size.width) * 4;
            void *pixelData = malloc(bytesPerRow * (int)size.height);
            auto context = std::make_shared<lottie::SkiaCanvasImpl>((int)size.width, (int)size.height, bytesPerRow, pixelData);
            
            _canvasRenderer->render(_renderer, context, lottie::Vector2D(size.width, size.height), configuration);
            context->flush();
            
            if (skipImageGeneration) {
                free(pixelData);
            } else {
                vImage_Buffer src;
                src.data = (void *)pixelData;
                src.width = (int)size.width;
                src.height = (int)size.height;
                src.rowBytes = bytesPerRow;
                
                uint8_t permuteMap[4] = {2, 1, 0, 3};
                vImagePermuteChannels_ARGB8888(&src, &src, permuteMap, kvImageDoNotTile);
                
                CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
                CGBitmapInfo bitmapInfo = kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host;
                
                CGContextRef targetContext = CGBitmapContextCreate(pixelData, (int)size.width, (int)size.height, 8, bytesPerRow, colorSpace, bitmapInfo);
                CGColorSpaceRelease(colorSpace);
                
                CGImageRef bitmapImage = CGBitmapContextCreateImage(targetContext);
                UIImage *image = [[UIImage alloc] initWithCGImage:bitmapImage scale:1.0f orientation:UIImageOrientationDownMirrored];
                CGImageRelease(bitmapImage);
                
                CGContextRelease(targetContext);
                
                free(pixelData);
                
                return image;
            }
        } else {
            auto context = std::make_shared<lottie::NullCanvasImpl>((int)size.width, (int)size.height);
            _canvasRenderer->render(_renderer, context, lottie::Vector2D(size.width, size.height), configuration);
            
            return nil;
        }
    }
    return nil;
}

@end
