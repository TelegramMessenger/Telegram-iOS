//
//  CBPlayerView.m
//  CoubPlayer
//
//  Created by Pavel Tikhonenko on 17/10/14.
//  Copyright (c) 2014 Pavel Tikhonenko. All rights reserved.
//

#import "CBPlayerView.h"



@implementation CBPlayerView

- (id)initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];

	if(self)
	{
		[self setupView];
	}

	return self;
}
- (void)setupView
{
	self.clipsToBounds = YES;

	_preview = [[UIImageView alloc] initWithFrame:self.bounds];
	_preview.contentMode = UIViewContentModeScaleAspectFill;
	[self addSubview:_preview];

	_videoPlayerView = [[CBPlayerLayerView alloc] initWithFrame:self.bounds];
	_videoPlayerView.hidden = YES;
	((AVPlayerLayer *) _videoPlayerView.layer).videoGravity = AVLayerVideoGravityResizeAspectFill;
	[self addSubview:_videoPlayerView];
}

- (void)setContentMode:(UIViewContentMode)contentMode
{
    [super setContentMode:contentMode];

	_preview.contentMode = contentMode;
	((AVPlayerLayer *)_videoPlayerView.layer).videoGravity = (contentMode == UIViewContentModeScaleAspectFit) ? AVLayerVideoGravityResizeAspect : AVLayerVideoGravityResizeAspectFill;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
	CGRect bounds = self.bounds;

	_videoPlayerView.frame = bounds;
	_preview.frame = bounds;
}

- (void)play
{
    _videoPlayerView.hidden = NO;
}

- (void)stop
{
    _videoPlayerView.hidden = YES;
}

//- (void) layoutSubviews
//{
//	// We need manual aspect fill/fit layout if we want fluid frame animations
//	CGRect bounds = self.bounds;
//	//_preview.frame = bounds;
//
//	if (self.contentMode == UIViewContentModeScaleAspectFit) {
//		CGRect viewFrame = bounds;
//
//		CGSize size = _player.loop.videoTrackSize;
//		if (size.width && size.height) {
//			CGFloat scale = fminf(viewFrame.size.width / size.width, viewFrame.size.height / size.height);
//			size.width = roundf(size.width * scale);
//			size.height = roundf(size.height * scale);
//			viewFrame = CGRectInset(viewFrame, 0.5f * (viewFrame.size.width - size.width), 0.5f * (viewFrame.size.height - size.height));
//		}
//
//		_videoPlayerView.frame = viewFrame;
//	} else
//		_videoPlayerView.frame = bounds;
//
//	CGPoint center = (CGPoint) { CGRectGetMidX(bounds), CGRectGetMidY(bounds) };
//	_spinner.center = center;
//	_reloadButton.center = center;
//}

@end

//#pragma mark -
//#pragma mark CBPlayerLayerView 
//
//@implementation CBPlayerLayerView
//+ (Class)layerClass { return [AVPlayerLayer class]; }
//@end
