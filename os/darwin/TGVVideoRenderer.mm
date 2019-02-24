//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#import "TGVVideoRenderer.h"
#include "SampleBufferDisplayLayerRenderer.h"

@implementation TGVVideoRenderer{
	AVSampleBufferDisplayLayer* layer;
	id<TGVVideoRendererDelegate> delegate;
	tgvoip::video::SampleBufferDisplayLayerRenderer* nativeRenderer;
}

- (instancetype)initWithDisplayLayer:(AVSampleBufferDisplayLayer *)layer delegate:(nonnull id<TGVVideoRendererDelegate>)delegate{
	self=[super init];
	self->layer=layer;
	self->delegate=delegate;
	nativeRenderer=new tgvoip::video::SampleBufferDisplayLayerRenderer();
	return self;
}

- (void)dealloc{
	delete nativeRenderer;
}

- (tgvoip::video::VideoRenderer *)nativeVideoRenderer{
	return nativeRenderer;
}

@end
