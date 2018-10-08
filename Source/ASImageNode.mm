//
//  ASImageNode.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASImageNode.h>

#import <tgmath.h>

#import <AsyncDisplayKit/_ASDisplayLayer.h>
#import <AsyncDisplayKit/ASAssert.h>
#import <AsyncDisplayKit/ASDimension.h>
#import <AsyncDisplayKit/ASDisplayNode+FrameworkPrivate.h>
#import <AsyncDisplayKit/ASDisplayNode+Subclasses.h>
#import <AsyncDisplayKit/ASDisplayNodeExtras.h>
#import <AsyncDisplayKit/ASDisplayNode+Beta.h>
#import <AsyncDisplayKit/ASGraphicsContext.h>
#import <AsyncDisplayKit/ASLayout.h>
#import <AsyncDisplayKit/ASTextNode.h>
#import <AsyncDisplayKit/ASImageNode+AnimatedImagePrivate.h>
#import <AsyncDisplayKit/ASImageNode+CGExtras.h>
#import <AsyncDisplayKit/AsyncDisplayKit+Debug.h>
#import <AsyncDisplayKit/ASInternalHelpers.h>
#import <AsyncDisplayKit/ASEqualityHelpers.h>
#import <AsyncDisplayKit/ASHashing.h>
#import <AsyncDisplayKit/ASWeakMap.h>
#import <AsyncDisplayKit/CoreGraphics+ASConvenience.h>
#import <AsyncDisplayKit/_ASCoreAnimationExtras.h>

// TODO: It would be nice to remove this dependency; it's the only subclass using more than +FrameworkSubclasses.h
#import <AsyncDisplayKit/ASDisplayNodeInternal.h>

static const CGSize kMinReleaseImageOnBackgroundSize = {20.0, 20.0};

typedef void (^ASImageNodeDrawParametersBlock)(ASWeakMapEntry *entry);

@interface ASImageNodeDrawParameters : NSObject {
@package
  UIImage *_image;
  BOOL _opaque;
  CGRect _bounds;
  CGFloat _contentsScale;
  UIColor *_backgroundColor;
  UIViewContentMode _contentMode;
  BOOL _cropEnabled;
  BOOL _forceUpscaling;
  CGSize _forcedSize;
  CGRect _cropRect;
  CGRect _cropDisplayBounds;
  asimagenode_modification_block_t _imageModificationBlock;
  ASDisplayNodeContextModifier _willDisplayNodeContentWithRenderingContext;
  ASDisplayNodeContextModifier _didDisplayNodeContentWithRenderingContext;
  ASImageNodeDrawParametersBlock _didDrawBlock;
}

@end

@implementation ASImageNodeDrawParameters

@end

/**
 * Contains all data that is needed to generate the content bitmap.
 */
@interface ASImageNodeContentsKey : NSObject

@property (nonatomic) UIImage *image;
@property CGSize backingSize;
@property CGRect imageDrawRect;
@property BOOL isOpaque;
@property (nonatomic, copy) UIColor *backgroundColor;
@property (nonatomic) ASDisplayNodeContextModifier willDisplayNodeContentWithRenderingContext;
@property (nonatomic) ASDisplayNodeContextModifier didDisplayNodeContentWithRenderingContext;
@property (nonatomic) asimagenode_modification_block_t imageModificationBlock;

@end

@implementation ASImageNodeContentsKey

- (BOOL)isEqual:(id)object
{
  if (self == object) {
    return YES;
  }

  // Optimization opportunity: The `isKindOfClass` call here could be avoided by not using the NSObject `isEqual:`
  // convention and instead using a custom comparison function that assumes all items are heterogeneous.
  // However, profiling shows that our entire `isKindOfClass` expression is only ~1/40th of the total
  // overheard of our caching, so it's likely not high-impact.
  if ([object isKindOfClass:[ASImageNodeContentsKey class]]) {
    ASImageNodeContentsKey *other = (ASImageNodeContentsKey *)object;
    return [_image isEqual:other.image]
      && CGSizeEqualToSize(_backingSize, other.backingSize)
      && CGRectEqualToRect(_imageDrawRect, other.imageDrawRect)
      && _isOpaque == other.isOpaque
      && [_backgroundColor isEqual:other.backgroundColor]
      && _willDisplayNodeContentWithRenderingContext == other.willDisplayNodeContentWithRenderingContext
      && _didDisplayNodeContentWithRenderingContext == other.didDisplayNodeContentWithRenderingContext
      && _imageModificationBlock == other.imageModificationBlock;
  } else {
    return NO;
  }
}

- (NSUInteger)hash
{
#pragma clang diagnostic push
#pragma clang diagnostic warning "-Wpadded"
  struct {
    NSUInteger imageHash;
    CGSize backingSize;
    CGRect imageDrawRect;
    NSInteger isOpaque;
    NSUInteger backgroundColorHash;
    void *willDisplayNodeContentWithRenderingContext;
    void *didDisplayNodeContentWithRenderingContext;
    void *imageModificationBlock;
#pragma clang diagnostic pop
  } data = {
    _image.hash,
    _backingSize,
    _imageDrawRect,
    _isOpaque,
    _backgroundColor.hash,
    (void *)_willDisplayNodeContentWithRenderingContext,
    (void *)_didDisplayNodeContentWithRenderingContext,
    (void *)_imageModificationBlock
  };
  return ASHashBytes(&data, sizeof(data));
}

@end


@implementation ASImageNode
{
@private
  UIImage *_image;
  ASWeakMapEntry *_weakCacheEntry;  // Holds a reference that keeps our contents in cache.
  UIColor *_placeholderColor;

  void (^_displayCompletionBlock)(BOOL canceled);
  
  // Drawing
  ASTextNode *_debugLabelNode;
  
  // Cropping.
  BOOL _cropEnabled; // Defaults to YES.
  BOOL _forceUpscaling; //Defaults to NO.
  CGSize _forcedSize; //Defaults to CGSizeZero, indicating no forced size.
  CGRect _cropRect; // Defaults to CGRectMake(0.5, 0.5, 0, 0)
  CGRect _cropDisplayBounds; // Defaults to CGRectNull
}

@synthesize image = _image;
@synthesize imageModificationBlock = _imageModificationBlock;

#pragma mark - Lifecycle

- (instancetype)init
{
  if (!(self = [super init]))
    return nil;

  // TODO can this be removed?
  self.contentsScale = ASScreenScale();
  self.contentMode = UIViewContentModeScaleAspectFill;
  self.opaque = NO;
  self.clipsToBounds = YES;

  // If no backgroundColor is set to the image node and it's a subview of UITableViewCell, UITableView is setting
  // the opaque value of all subviews to YES if highlighting / selection is happening and does not set it back to the
  // initial value. With setting a explicit backgroundColor we can prevent that change.
  self.backgroundColor = [UIColor clearColor];

  _cropEnabled = YES;
  _forceUpscaling = NO;
  _cropRect = CGRectMake(0.5, 0.5, 0, 0);
  _cropDisplayBounds = CGRectNull;
  _placeholderColor = ASDisplayNodeDefaultPlaceholderColor();
#ifndef MINIMAL_ASDK
  _animatedImageRunLoopMode = ASAnimatedImageDefaultRunLoopMode;
#endif
  
  return self;
}

- (void)dealloc
{
  // Invalidate all components around animated images
#ifndef MINIMAL_ASDK
  [self invalidateAnimatedImage];
#endif
}

#pragma mark - Placeholder

- (UIImage *)placeholderImage
{
  // FIXME: Replace this implementation with reusable CALayers that have .backgroundColor set.
  // This would completely eliminate the memory and performance cost of the backing store.
  CGSize size = self.calculatedSize;
  if ((size.width * size.height) < CGFLOAT_EPSILON) {
    return nil;
  }
  
  ASDN::MutexLocker l(__instanceLock__);
  
  ASGraphicsBeginImageContextWithOptions(size, NO, 1);
  [self.placeholderColor setFill];
  UIRectFill(CGRectMake(0, 0, size.width, size.height));
  UIImage *image = ASGraphicsGetImageAndEndCurrentContext();
  
  return image;
}

#pragma mark - Layout and Sizing

- (CGSize)calculateSizeThatFits:(CGSize)constrainedSize
{
  let image = ASLockedSelf(_image);

  if (image == nil) {
    return [super calculateSizeThatFits:constrainedSize];
  }

  return image.size;
}

#pragma mark - Setter / Getter

- (void)setImage:(UIImage *)image
{
  ASDN::MutexLocker l(__instanceLock__);
  [self _locked_setImage:image];
}

- (void)_locked_setImage:(UIImage *)image
{
  ASAssertLocked(__instanceLock__);
  if (ASObjectIsEqual(_image, image)) {
    return;
  }

  UIImage *oldImage = _image;
  _image = image;
  
  if (image != nil) {
    // We explicitly call setNeedsDisplay in this case, although we know setNeedsDisplay will be called with lock held.
    // Therefore we have to be careful in methods that are involved with setNeedsDisplay to not run into a deadlock
    [self setNeedsDisplay];
    
    if (_displayWithoutProcessing && ASDisplayNodeThreadIsMain()) {
      BOOL stretchable = !UIEdgeInsetsEqualToEdgeInsets(image.capInsets, UIEdgeInsetsZero);
      if (stretchable) {
        ASDisplayNodeSetupLayerContentsWithResizableImage(self.layer, image);
      } else {
        self.contents = (id)image.CGImage;
      }
      return;
    }
  } else {
    self.contents = nil;
  }

  // Destruction of bigger images on the main thread can be expensive
  // and can take some time, so we dispatch onto a bg queue to
  // actually dealloc.
  CGSize oldImageSize = oldImage.size;
  BOOL shouldReleaseImageOnBackgroundThread = oldImageSize.width > kMinReleaseImageOnBackgroundSize.width
                                              || oldImageSize.height > kMinReleaseImageOnBackgroundSize.height;
  if (shouldReleaseImageOnBackgroundThread) {
    ASPerformBackgroundDeallocation(&oldImage);
  }
}

- (UIImage *)image
{
  return ASLockedSelf(_image);
}

- (UIColor *)placeholderColor
{
  return ASLockedSelf(_placeholderColor);
}

- (void)setPlaceholderColor:(UIColor *)placeholderColor
{
  ASLockScopeSelf();
  if (ASCompareAssignCopy(_placeholderColor, placeholderColor)) {
    _placeholderEnabled = (placeholderColor != nil);
  }
}

#pragma mark - Drawing

- (NSObject *)drawParametersForAsyncLayer:(_ASDisplayLayer *)layer
{
  ASLockScopeSelf();
  
  ASImageNodeDrawParameters *drawParameters = [[ASImageNodeDrawParameters alloc] init];
  drawParameters->_image = _image;
  drawParameters->_bounds = [self threadSafeBounds];
  drawParameters->_opaque = self.opaque;
  drawParameters->_contentsScale = _contentsScaleForDisplay;
  drawParameters->_backgroundColor = self.backgroundColor;
  drawParameters->_contentMode = self.contentMode;
  drawParameters->_cropEnabled = _cropEnabled;
  drawParameters->_forceUpscaling = _forceUpscaling;
  drawParameters->_forcedSize = _forcedSize;
  drawParameters->_cropRect = _cropRect;
  drawParameters->_cropDisplayBounds = _cropDisplayBounds;
  drawParameters->_imageModificationBlock = _imageModificationBlock;
  drawParameters->_willDisplayNodeContentWithRenderingContext = _willDisplayNodeContentWithRenderingContext;
  drawParameters->_didDisplayNodeContentWithRenderingContext = _didDisplayNodeContentWithRenderingContext;

  // Hack for now to retain the weak entry that was created while this drawing happened
  drawParameters->_didDrawBlock = ^(ASWeakMapEntry *entry){
    ASLockScopeSelf();
    _weakCacheEntry = entry;
  };
  
  return drawParameters;
}

+ (UIImage *)displayWithParameters:(id<NSObject>)parameter isCancelled:(NS_NOESCAPE asdisplaynode_iscancelled_block_t)isCancelled
{
  ASImageNodeDrawParameters *drawParameter = (ASImageNodeDrawParameters *)parameter;

  UIImage *image = drawParameter->_image;
  if (image == nil) {
    return nil;
  }

  if (true) {
    return image;
  }
  
  CGRect drawParameterBounds       = drawParameter->_bounds;
  BOOL forceUpscaling              = drawParameter->_forceUpscaling;
  CGSize forcedSize                = drawParameter->_forcedSize;
  BOOL cropEnabled                 = drawParameter->_cropEnabled;
  BOOL isOpaque                    = drawParameter->_opaque;
  UIColor *backgroundColor         = drawParameter->_backgroundColor;
  UIViewContentMode contentMode    = drawParameter->_contentMode;
  CGFloat contentsScale            = drawParameter->_contentsScale;
  CGRect cropDisplayBounds         = drawParameter->_cropDisplayBounds;
  CGRect cropRect                  = drawParameter->_cropRect;
  asimagenode_modification_block_t imageModificationBlock                 = drawParameter->_imageModificationBlock;
  ASDisplayNodeContextModifier willDisplayNodeContentWithRenderingContext = drawParameter->_willDisplayNodeContentWithRenderingContext;
  ASDisplayNodeContextModifier didDisplayNodeContentWithRenderingContext  = drawParameter->_didDisplayNodeContentWithRenderingContext;
  
  BOOL hasValidCropBounds = cropEnabled && !CGRectIsEmpty(cropDisplayBounds);
  CGRect bounds = (hasValidCropBounds ? cropDisplayBounds : drawParameterBounds);
  
  
  ASDisplayNodeAssert(contentsScale > 0, @"invalid contentsScale at display time");
  
  // if the image is resizable, bail early since the image has likely already been configured
  BOOL stretchable = !UIEdgeInsetsEqualToEdgeInsets(image.capInsets, UIEdgeInsetsZero);
  if (stretchable) {
    if (imageModificationBlock != NULL) {
      image = imageModificationBlock(image);
    }
    return image;
  }
  
  CGSize imageSize = image.size;
  CGSize imageSizeInPixels = CGSizeMake(imageSize.width * image.scale, imageSize.height * image.scale);
  CGSize boundsSizeInPixels = CGSizeMake(std::floor(bounds.size.width * contentsScale), std::floor(bounds.size.height * contentsScale));
  
  BOOL contentModeSupported = contentMode == UIViewContentModeScaleAspectFill ||
                              contentMode == UIViewContentModeScaleAspectFit ||
                              contentMode == UIViewContentModeCenter;
  
  CGSize backingSize   = CGSizeZero;
  CGRect imageDrawRect = CGRectZero;
  
  if (boundsSizeInPixels.width * contentsScale < 1.0f || boundsSizeInPixels.height * contentsScale < 1.0f ||
      imageSizeInPixels.width < 1.0f                  || imageSizeInPixels.height < 1.0f) {
    return nil;
  }
  
  
  // If we're not supposed to do any cropping, just decode image at original size
  if (!cropEnabled || !contentModeSupported || stretchable) {
    backingSize = imageSizeInPixels;
    imageDrawRect = (CGRect){.size = backingSize};
  } else {
    if (CGSizeEqualToSize(CGSizeZero, forcedSize) == NO) {
      //scale forced size
      forcedSize.width *= contentsScale;
      forcedSize.height *= contentsScale;
    }
    ASCroppedImageBackingSizeAndDrawRectInBounds(imageSizeInPixels,
                                                 boundsSizeInPixels,
                                                 contentMode,
                                                 cropRect,
                                                 forceUpscaling,
                                                 forcedSize,
                                                 &backingSize,
                                                 &imageDrawRect);
  }
  
  if (backingSize.width <= 0.0f        || backingSize.height <= 0.0f ||
      imageDrawRect.size.width <= 0.0f || imageDrawRect.size.height <= 0.0f) {
    return nil;
  }

  ASImageNodeContentsKey *contentsKey = [[ASImageNodeContentsKey alloc] init];
  contentsKey.image = image;
  contentsKey.backingSize = backingSize;
  contentsKey.imageDrawRect = imageDrawRect;
  contentsKey.isOpaque = isOpaque;
  contentsKey.backgroundColor = backgroundColor;
  contentsKey.willDisplayNodeContentWithRenderingContext = willDisplayNodeContentWithRenderingContext;
  contentsKey.didDisplayNodeContentWithRenderingContext = didDisplayNodeContentWithRenderingContext;
  contentsKey.imageModificationBlock = imageModificationBlock;

  if (isCancelled()) {
    return nil;
  }

  ASWeakMapEntry<UIImage *> *entry = [self.class contentsForkey:contentsKey
                                                 drawParameters:parameter
                                                    isCancelled:isCancelled];
  // If nil, we were cancelled.
  if (entry == nil) {
    return nil;
  }
  
  if (drawParameter->_didDrawBlock) {
    drawParameter->_didDrawBlock(entry);
  }

  return entry.value;
}

static ASWeakMap<ASImageNodeContentsKey *, UIImage *> *cache = nil;
// Allocate cacheLock on the heap to prevent destruction at app exit (https://github.com/TextureGroup/Texture/issues/136)
static ASDN::StaticMutex& cacheLock = *new ASDN::StaticMutex;

+ (ASWeakMapEntry *)contentsForkey:(ASImageNodeContentsKey *)key drawParameters:(id)drawParameters isCancelled:(asdisplaynode_iscancelled_block_t)isCancelled
{
  {
    ASDN::StaticMutexLocker l(cacheLock);
    if (!cache) {
      cache = [[ASWeakMap alloc] init];
    }
    ASWeakMapEntry *entry = [cache entryForKey:key];
    if (entry != nil) {
      return entry;
    }
  }

  // cache miss
  UIImage *contents = [self createContentsForkey:key drawParameters:drawParameters isCancelled:isCancelled];
  if (contents == nil) { // If nil, we were cancelled
    return nil;
  }

  {
    ASDN::StaticMutexLocker l(cacheLock);
    return [cache setObject:contents forKey:key];
  }
}

+ (UIImage *)createContentsForkey:(ASImageNodeContentsKey *)key drawParameters:(id)drawParameters isCancelled:(asdisplaynode_iscancelled_block_t)isCancelled
{
  // The following `ASGraphicsBeginImageContextWithOptions` call will sometimes take take longer than 5ms on an
  // A5 processor for a 400x800 backingSize.
  // Check for cancellation before we call it.
  if (isCancelled()) {
    return nil;
  }

  // Use contentsScale of 1.0 and do the contentsScale handling in boundsSizeInPixels so ASCroppedImageBackingSizeAndDrawRectInBounds
  // will do its rounding on pixel instead of point boundaries
  ASGraphicsBeginImageContextWithOptions(key.backingSize, key.isOpaque, 1.0);
  
  BOOL contextIsClean = YES;
  
  CGContextRef context = UIGraphicsGetCurrentContext();
  if (context && key.willDisplayNodeContentWithRenderingContext) {
    key.willDisplayNodeContentWithRenderingContext(context, drawParameters);
    contextIsClean = NO;
  }
  
  // if view is opaque, fill the context with background color
  if (key.isOpaque && key.backgroundColor) {
    [key.backgroundColor setFill];
    UIRectFill({ .size = key.backingSize });
    contextIsClean = NO;
  }
  
  // iOS 9 appears to contain a thread safety regression when drawing the same CGImageRef on
  // multiple threads concurrently.  In fact, instead of crashing, it appears to deadlock.
  // The issue is present in Mac OS X El Capitan and has been seen hanging Pro apps like Adobe Premiere,
  // as well as iOS games, and a small number of ASDK apps that provide the same image reference
  // to many separate ASImageNodes.  A workaround is to set .displaysAsynchronously = NO for the nodes
  // that may get the same pointer for a given UI asset image, etc.
  // FIXME: We should replace @synchronized here, probably using a global, locked NSMutableSet, and
  // only if the object already exists in the set we should create a semaphore to signal waiting threads
  // upon removal of the object from the set when the operation completes.
  // Another option is to have ASDisplayNode+AsyncDisplay coordinate these cases, and share the decoded buffer.
  // Details tracked in https://github.com/facebook/AsyncDisplayKit/issues/1068
  
  UIImage *image = key.image;
  BOOL canUseCopy = (contextIsClean || ASImageAlphaInfoIsOpaque(CGImageGetAlphaInfo(image.CGImage)));
  CGBlendMode blendMode = canUseCopy ? kCGBlendModeCopy : kCGBlendModeNormal;
  
  @synchronized(image) {
    [image drawInRect:key.imageDrawRect blendMode:blendMode alpha:1];
  }
  
  if (context && key.didDisplayNodeContentWithRenderingContext) {
    key.didDisplayNodeContentWithRenderingContext(context, drawParameters);
  }

  // Check cancellation one last time before forming image.
  if (isCancelled()) {
    ASGraphicsEndImageContext();
    return nil;
  }

  UIImage *result = ASGraphicsGetImageAndEndCurrentContext();
  
  if (key.imageModificationBlock) {
    result = key.imageModificationBlock(result);
  }
  
  return result;
}

- (void)displayDidFinish
{
  [super displayDidFinish];

  __instanceLock__.lock();
    void (^displayCompletionBlock)(BOOL canceled) = _displayCompletionBlock;
    UIImage *image = _image;
    BOOL hasDebugLabel = (_debugLabelNode != nil);
  __instanceLock__.unlock();

  // Update the debug label if necessary
  if (hasDebugLabel) {
    // For debugging purposes we don't care about locking for now
    CGSize imageSize = image.size;
    CGSize imageSizeInPixels = CGSizeMake(imageSize.width * image.scale, imageSize.height * image.scale);
    CGSize boundsSizeInPixels = CGSizeMake(std::floor(self.bounds.size.width * self.contentsScale), std::floor(self.bounds.size.height * self.contentsScale));
    CGFloat pixelCountRatio            = (imageSizeInPixels.width * imageSizeInPixels.height) / (boundsSizeInPixels.width * boundsSizeInPixels.height);
    if (pixelCountRatio != 1.0) {
      NSString *scaleString            = [NSString stringWithFormat:@"%.2fx", pixelCountRatio];
      _debugLabelNode.attributedText   = [[NSAttributedString alloc] initWithString:scaleString attributes:[self debugLabelAttributes]];
      _debugLabelNode.hidden           = NO;
    } else {
      _debugLabelNode.hidden           = YES;
      _debugLabelNode.attributedText   = nil;
    }
  }
  
  // If we've got a block to perform after displaying, do it.
  if (image && displayCompletionBlock) {

    displayCompletionBlock(NO);

    __instanceLock__.lock();
      _displayCompletionBlock = nil;
    __instanceLock__.unlock();
  }
}

- (void)setNeedsDisplayWithCompletion:(void (^ _Nullable)(BOOL canceled))displayCompletionBlock
{
  if (self.displaySuspended) {
    if (displayCompletionBlock)
      displayCompletionBlock(YES);
    return;
  }

  // Stash the block and call-site queue. We'll invoke it in -displayDidFinish.
  {
    ASDN::MutexLocker l(__instanceLock__);
    if (_displayCompletionBlock != displayCompletionBlock) {
      _displayCompletionBlock = displayCompletionBlock;
    }
  }

  [self setNeedsDisplay];
}

#pragma mark Interface State

- (void)clearContents
{
  [super clearContents];
  
  ASDN::MutexLocker l(__instanceLock__);
  _weakCacheEntry = nil;  // release contents from the cache.
}

#pragma mark - Cropping

- (BOOL)isCropEnabled
{
  ASDN::MutexLocker l(__instanceLock__);
  return _cropEnabled;
}

- (void)setCropEnabled:(BOOL)cropEnabled
{
  [self setCropEnabled:cropEnabled recropImmediately:NO inBounds:self.bounds];
}

- (void)setCropEnabled:(BOOL)cropEnabled recropImmediately:(BOOL)recropImmediately inBounds:(CGRect)cropBounds
{
  __instanceLock__.lock();
  if (_cropEnabled == cropEnabled) {
    __instanceLock__.unlock();
    return;
  }

  _cropEnabled = cropEnabled;
  _cropDisplayBounds = cropBounds;
  
  UIImage *image = _image;
  __instanceLock__.unlock();

  // If we have an image to display, display it, respecting our recrop flag.
  if (image != nil) {
    ASPerformBlockOnMainThread(^{
      if (recropImmediately)
        [self displayImmediately];
      else
        [self setNeedsDisplay];
    });
  }
}

- (CGRect)cropRect
{
  ASDN::MutexLocker l(__instanceLock__);
  return _cropRect;
}

- (void)setCropRect:(CGRect)cropRect
{
  {
    ASDN::MutexLocker l(__instanceLock__);
    if (CGRectEqualToRect(_cropRect, cropRect)) {
      return;
    }

    _cropRect = cropRect;
  }

  // TODO: this logic needs to be updated to respect cropRect.
  CGSize boundsSize = self.bounds.size;
  CGSize imageSize = self.image.size;

  BOOL isCroppingImage = ((boundsSize.width < imageSize.width) || (boundsSize.height < imageSize.height));

  // Re-display if we need to.
  ASPerformBlockOnMainThread(^{
    if (self.nodeLoaded && self.contentMode == UIViewContentModeScaleAspectFill && isCroppingImage)
      [self setNeedsDisplay];
  });
}

- (BOOL)forceUpscaling
{
  ASDN::MutexLocker l(__instanceLock__);
  return _forceUpscaling;
}

- (void)setForceUpscaling:(BOOL)forceUpscaling
{
  ASDN::MutexLocker l(__instanceLock__);
  _forceUpscaling = forceUpscaling;
}

- (CGSize)forcedSize
{
  ASDN::MutexLocker l(__instanceLock__);
  return _forcedSize;
}

- (void)setForcedSize:(CGSize)forcedSize
{
  ASDN::MutexLocker l(__instanceLock__);
  _forcedSize = forcedSize;
}

- (asimagenode_modification_block_t)imageModificationBlock
{
  ASDN::MutexLocker l(__instanceLock__);
  return _imageModificationBlock;
}

- (void)setImageModificationBlock:(asimagenode_modification_block_t)imageModificationBlock
{
  ASDN::MutexLocker l(__instanceLock__);
  _imageModificationBlock = imageModificationBlock;
}

#pragma mark - Debug

- (void)layout
{
  [super layout];
  
  if (_debugLabelNode) {
    CGSize boundsSize        = self.bounds.size;
    CGSize debugLabelSize    = [_debugLabelNode layoutThatFits:ASSizeRangeMake(CGSizeZero, boundsSize)].size;
    CGPoint debugLabelOrigin = CGPointMake(boundsSize.width - debugLabelSize.width,
                                           boundsSize.height - debugLabelSize.height);
    _debugLabelNode.frame    = (CGRect) {debugLabelOrigin, debugLabelSize};
  }
}

- (NSDictionary *)debugLabelAttributes
{
  return @{
    NSFontAttributeName: [UIFont systemFontOfSize:15.0],
    NSForegroundColorAttributeName: [UIColor redColor]
  };
}

@end

#pragma mark - Extras

asimagenode_modification_block_t ASImageNodeRoundBorderModificationBlock(CGFloat borderWidth, UIColor *borderColor)
{
  return ^(UIImage *originalImage) {
    ASGraphicsBeginImageContextWithOptions(originalImage.size, NO, originalImage.scale);
    UIBezierPath *roundOutline = [UIBezierPath bezierPathWithOvalInRect:(CGRect){CGPointZero, originalImage.size}];

    // Make the image round
    [roundOutline addClip];

    // Draw the original image
    [originalImage drawAtPoint:CGPointZero blendMode:kCGBlendModeCopy alpha:1];

    // Draw a border on top.
    if (borderWidth > 0.0) {
      [borderColor setStroke];
      [roundOutline setLineWidth:borderWidth];
      [roundOutline stroke];
    }

    return ASGraphicsGetImageAndEndCurrentContext();
  };
}

asimagenode_modification_block_t ASImageNodeTintColorModificationBlock(UIColor *color)
{
  return ^(UIImage *originalImage) {
    ASGraphicsBeginImageContextWithOptions(originalImage.size, NO, originalImage.scale);
    
    // Set color and render template
    [color setFill];
    UIImage *templateImage = [originalImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    [templateImage drawAtPoint:CGPointZero blendMode:kCGBlendModeCopy alpha:1];
    
    UIImage *modifiedImage = ASGraphicsGetImageAndEndCurrentContext();

    // if the original image was stretchy, keep it stretchy
    if (!UIEdgeInsetsEqualToEdgeInsets(originalImage.capInsets, UIEdgeInsetsZero)) {
      modifiedImage = [modifiedImage resizableImageWithCapInsets:originalImage.capInsets resizingMode:originalImage.resizingMode];
    }

    return modifiedImage;
  };
}
