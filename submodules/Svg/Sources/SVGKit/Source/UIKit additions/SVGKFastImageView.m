#import "SVGKFastImageView.h"

@interface SVGKFastImageView ()
@property(nonatomic,readwrite) NSTimeInterval timeIntervalForLastReRenderOfSVGFromMemory;
@property (nonatomic, strong) NSDate* startRenderTime, * endRenderTime; /**< for debugging, lets you know how long it took to add/generate the CALayer (may have been cached! Only SVGKImage knows true times) */
@property (nonatomic) BOOL didRegisterObservers, didRegisterInternalRedrawObservers;

@end

@implementation SVGKFastImageView
{
	NSString* internalContextPointerBecauseApplesDemandsIt;
}

@synthesize image = _image;
@synthesize tileRatio = _tileRatio;
@synthesize disableAutoRedrawAtHighestResolution = _disableAutoRedrawAtHighestResolution;
@synthesize timeIntervalForLastReRenderOfSVGFromMemory = _timeIntervalForLastReRenderOfSVGFromMemory;

- (id)init
{
	NSAssert(false, @"init not supported, use initWithSVGKImage:");
    
    return nil;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
	self = [super initWithCoder:aDecoder];
    if( self )
    {
        [self populateFromImage:nil];
    }
    return self;
}

-(id)initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];
	if( self )
	{
        [self populateFromImage:nil];
	}
	return self;
}

- (id)initWithSVGKImage:(SVGKImage*) im
{
    self = [super init];
    if (self)
	{
        [self populateFromImage:im];
    }
    return self;
}

- (void)populateFromImage:(SVGKImage*) im
{
#if SVGKIT_MAC && USE_SUBLAYERS_INSTEAD_OF_BLIT
    // setup layer-backed view
    self.wantsLayer = YES;
#endif
	if( im == nil )
	{
		SVGKitLogWarn(@"[%@] WARNING: you have initialized an SVGKImageView with a blank image (nil). Possibly because you're using Storyboards or NIBs which Apple won't allow us to decorate. Make sure you assign an SVGKImage to the .image property!", [self class]);
	}
    
    self.image = im;
    self.frame = CGRectMake( 0,0, im.size.width, im.size.height ); // NB: this uses the default SVG Viewport; an ImageView can theoretically calc a new viewport (but its hard to get right!)
    self.tileRatio = CGSizeZero;
#if SVGKIT_UIKIT
    self.backgroundColor = [UIColor clearColor];
#else
    self.layer.backgroundColor = [NSColor clearColor].CGColor;
#endif
}

- (void)setImage:(SVGKImage *)image {
    
    if( !internalContextPointerBecauseApplesDemandsIt ) {
        internalContextPointerBecauseApplesDemandsIt = @"Apple wrote the addObserver / KVO notification API wrong in the first place and now requires developers to pass around pointers to fake objects to make up for the API deficicineces. You have to have one of these pointers per object, and they have to be internal and private. They serve no real value.";
    }
	
    [_image removeObserver:self forKeyPath:@"size" context:(__bridge void * _Nullable)(internalContextPointerBecauseApplesDemandsIt)];
    _image = image;
    
    /** redraw-observers */
    if( self.disableAutoRedrawAtHighestResolution )
        ;
    else {
        [self addInternalRedrawOnResizeObservers];
        [_image addObserver:self forKeyPath:@"size" options:NSKeyValueObservingOptionNew context:(__bridge void * _Nullable)(internalContextPointerBecauseApplesDemandsIt)];
    }
    
    /** other obeservers */
  if (!self.didRegisterObservers) {
    self.didRegisterObservers = true;
    [self addObserver:self forKeyPath:@"image" options:NSKeyValueObservingOptionNew context:(__bridge void * _Nullable)(internalContextPointerBecauseApplesDemandsIt)];
    [self addObserver:self forKeyPath:@"tileRatio" options:NSKeyValueObservingOptionNew context:(__bridge void * _Nullable)(internalContextPointerBecauseApplesDemandsIt)];
    [self addObserver:self forKeyPath:@"showBorder" options:NSKeyValueObservingOptionNew context:(__bridge void * _Nullable)(internalContextPointerBecauseApplesDemandsIt)];
  }

}

-(void) addInternalRedrawOnResizeObservers
{
  if (self.didRegisterInternalRedrawObservers) return;
  self.didRegisterInternalRedrawObservers = true;
	[self addObserver:self forKeyPath:@"layer" options:NSKeyValueObservingOptionNew context:(__bridge void * _Nullable)(internalContextPointerBecauseApplesDemandsIt)];
	[self.layer addObserver:self forKeyPath:@"transform" options:NSKeyValueObservingOptionNew context:(__bridge void * _Nullable)(internalContextPointerBecauseApplesDemandsIt)];
}

-(void) removeInternalRedrawOnResizeObservers
{
  if (!self.didRegisterInternalRedrawObservers) return;
	[self removeObserver:self forKeyPath:@"layer" context:(__bridge void * _Nullable)(internalContextPointerBecauseApplesDemandsIt)];
#if !SVGKIT_MAC || USE_SUBLAYERS_INSTEAD_OF_BLIT
	[self.layer removeObserver:self forKeyPath:@"transform" context:(__bridge void * _Nullable)(internalContextPointerBecauseApplesDemandsIt)];
#endif
  self.didRegisterInternalRedrawObservers = false;
}

-(void)setDisableAutoRedrawAtHighestResolution:(BOOL)newValue
{
	if( newValue == _disableAutoRedrawAtHighestResolution )
		return;
	
	_disableAutoRedrawAtHighestResolution = newValue;
	
	if( self.disableAutoRedrawAtHighestResolution ) // disabled, so we have to remove the observers
	{
		[self removeInternalRedrawOnResizeObservers];
	}
	else // newly-enabled ... must add the observers
	{
		[self addInternalRedrawOnResizeObservers];
	}
}

- (void)dealloc
{
	if( self.disableAutoRedrawAtHighestResolution )
		;
	else
		[self removeInternalRedrawOnResizeObservers];
	
  if (self.didRegisterObservers) {
    [self removeObserver:self forKeyPath:@"image" context:(__bridge void * _Nullable)(internalContextPointerBecauseApplesDemandsIt)];
    [self removeObserver:self forKeyPath:@"tileRatio" context:(__bridge void * _Nullable)(internalContextPointerBecauseApplesDemandsIt)];
    [self removeObserver:self forKeyPath:@"showBorder" context:(__bridge void * _Nullable)(internalContextPointerBecauseApplesDemandsIt)];
  }


  
  [_image removeObserver:self forKeyPath:@"size" context:(__bridge void * _Nullable)(internalContextPointerBecauseApplesDemandsIt)];
	_image = nil;
	
}

/** Trigger a call to re-display (at higher or lower draw-resolution) (get Apple to call drawRect: again) */
-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if( [keyPath isEqualToString:@"transform"] &&  CGSizeEqualToSize( CGSizeZero, self.tileRatio ) )
	{
		/*SVGKitLogVerbose(@"transform changed. Setting layer scale: %2.2f --> %2.2f", self.layer.contentsScale, self.transform.a);
		 self.layer.contentsScale = self.transform.a;*/
		[self.image.CALayerTree removeFromSuperlayer]; // force apple to redraw?
#if SVGKIT_UIKIT
		[self setNeedsDisplay];
#else
        [self setNeedsDisplay:YES];
#endif
	}
	else
	{
		
		if( self.disableAutoRedrawAtHighestResolution )
			;
		else
		{
#if SVGKIT_UIKIT
			[self setNeedsDisplay];
#else
            [self setNeedsDisplay:YES];
#endif
		}
	}
}

/**
 NB: this implementation is a bit tricky, because we're extending Apple's concept of a UIView to add "tiling"
 and "automatic rescaling"
 
 */
-(void)drawRect:(CGRect)rect
{
	self.startRenderTime = self.endRenderTime = [NSDate date];
	
	/**
	 view.bounds == width and height of the view
	 imageBounds == natural width and height of the SVGKImage
	 */
	CGRect imageBounds = CGRectMake( 0,0, self.image.size.width, self.image.size.height );
	
	
	/** Check if tiling is enabled in either direction
	 
	 We have to do this FIRST, because we cannot extend Apple's enum they use for UIViewContentMode
	 (objective-C is a weak language).
	 
	 If we find ANY tiling, we will be forced to skip the UIViewContentMode handling
	 
	 TODO: it would be nice to combine the two - e.g. if contentMode=BottomRight, then do the tiling with
	 the bottom right corners aligned. If = TopLeft, then tile with the top left corners aligned,
	 etc.
	 */
	int cols = ceil(self.tileRatio.width);
	int rows = ceil(self.tileRatio.height);
	
	if( cols < 1 ) // It's meaningless to have "fewer than 1" tiles; this lets us ALSO handle special case of "CGSizeZero == disable tiling"
		cols = 1;
	if( rows < 1 ) // It's meaningless to have "fewer than 1" tiles; this lets us ALSO handle special case of "CGSizeZero == disable tiling"
		rows = 1;
	
	
	CGSize scaleConvertImageToView;
	CGSize tileSize;
	if( cols == 1 && rows == 1 ) // if we are NOT tiling, then obey the UIViewContentMode as best we can!
	{
#ifdef USE_SUBLAYERS_INSTEAD_OF_BLIT
		if( self.image.CALayerTree.superlayer == self.layer )
		{
			[super drawRect:rect];
			return; // TODO: Apple's bugs - they ignore all attempts to force a redraw
		}
		else
		{
			[self.layer addSublayer:self.image.CALayerTree];
			return; // we've added the layer - let Apple take care of the rest!
		}
#else
		scaleConvertImageToView = CGSizeMake( self.bounds.size.width / imageBounds.size.width, self.bounds.size.height / imageBounds.size.height );
		tileSize = self.bounds.size;
#endif
	}
	else
	{
		scaleConvertImageToView = CGSizeMake( self.bounds.size.width / (self.tileRatio.width * imageBounds.size.width), self.bounds.size.height / ( self.tileRatio.height * imageBounds.size.height) );
		tileSize = CGSizeMake( self.bounds.size.width / self.tileRatio.width, self.bounds.size.height / self.tileRatio.height );
	}
	
	//DEBUG: SVGKitLogVerbose(@"cols, rows: %i, %i ... scaleConvert: %@ ... tilesize: %@", cols, rows, NSStringFromCGSize(scaleConvertImageToView), NSStringFromCGSize(tileSize) );
	/** To support tiling, and to allow internal shrinking, we use renderInContext */
#if SVGKIT_UIKIT
    CGContextRef context = UIGraphicsGetCurrentContext();
#else
    CGContextRef context = SVGKGraphicsGetCurrentContext();
#endif
	for( int k=0; k<rows; k++ )
		for( int i=0; i<cols; i++ )
		{
			CGContextSaveGState(context);
			
			CGContextTranslateCTM(context, i * tileSize.width, k * tileSize.height );
			CGContextScaleCTM( context, scaleConvertImageToView.width, scaleConvertImageToView.height );
			
            [self.image renderInContext:context];
			
			CGContextRestoreGState(context);
		}
	
	/** The border is VERY helpful when debugging rendering and touch / hit detection problems! */
	if( self.showBorder )
	{
		[[UIColor blackColor] set];
		CGContextStrokeRect(context, rect);
	}
	
	self.endRenderTime = [NSDate date];
	self.timeIntervalForLastReRenderOfSVGFromMemory = [self.endRenderTime timeIntervalSinceDate:self.startRenderTime];
}

#if SVGKIT_MAC
static CGContextRef SVGKGraphicsGetCurrentContext(void) {
    NSGraphicsContext *context = NSGraphicsContext.currentContext;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"
    if ([context respondsToSelector:@selector(CGContext)]) {
        return context.CGContext;
    } else {
        return context.graphicsPort;
    }
#pragma clang diagnostic pop
}
#endif

@end
