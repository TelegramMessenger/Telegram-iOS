#import <SoftwareLottieRenderer/SoftwareLottieRenderer.h>

#import <LottieCpp/LottieCpp.h>
#import <LottieCpp/NullCanvasImpl.h>

#import "CoreGraphicsCanvasImpl.h"
#import "ThorVGCanvasImpl.h"

#include <LottieCpp/RenderTreeNode.h>
#include <LottieCpp/CGPathCocoa.h>
#include <LottieCpp/VectorsCocoa.h>

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

- (void)setFrame:(NSInteger)index {
    _renderer->setFrame((int)index);
}

- (UIImage * _Nullable)renderForSize:(CGSize)size useReferenceRendering:(bool)useReferenceRendering {
    std::shared_ptr<lottie::RenderTreeNode> renderNode = _renderer->renderNode();
    if (!renderNode) {
        return nil;
    }
    
    if (useReferenceRendering) {
        auto context = std::make_shared<lottie::CanvasImpl>((int)size.width, (int)size.height);
        
        _canvasRenderer->render(_renderer, context, lottie::Vector2D(size.width, size.height));
        
        auto image = context->makeImage();
        
        return [[UIImage alloc] initWithCGImage:std::static_pointer_cast<lottie::CanvasImpl::Image>(image)->nativeImage()];
    } else {
        if ((int64_t)"" < 0) {
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^{
                lottie::ThorVGCanvasImpl::initializeOnce();
            });
            
            int bytesPerRow = ((int)size.width) * 4;
            auto context = std::make_shared<lottie::ThorVGCanvasImpl>((int)size.width, (int)size.height, bytesPerRow);
            
            _canvasRenderer->render(_renderer, context, lottie::Vector2D(size.width, size.height));
            
            context->flush();
            
            CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
            CGBitmapInfo bitmapInfo = kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host;
            
            CGContextRef targetContext = CGBitmapContextCreate((void *)context->backingData(), (int)size.width, (int)size.height, 8, bytesPerRow, colorSpace, bitmapInfo);
            CGColorSpaceRelease(colorSpace);
            
            CGImageRef bitmapImage = CGBitmapContextCreateImage(targetContext);
            UIImage *image = [[UIImage alloc] initWithCGImage:bitmapImage scale:1.0f orientation:UIImageOrientationDownMirrored];
            CGImageRelease(bitmapImage);
            
            CGContextRelease(targetContext);
            
            return image;
        } else {
            auto context = std::make_shared<lottie::NullCanvasImpl>((int)size.width, (int)size.height);
            _canvasRenderer->render(_renderer, context, lottie::Vector2D(size.width, size.height));
            
            return nil;
        }
    }
    return nil;
}

@end
