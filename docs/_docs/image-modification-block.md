---
title: Image Modification Blocks
layout: docs
permalink: /docs/image-modification-block.html
prevPage: inversion.html
nextPage: placeholder-fade-duration.html
---

Many times, operations that would affect the appearance of an image you're displaying are big sources of main thread work.  Naturally, you want to move these to a background thread.  

By assigning an `imageModificationBlock` to your imageNode, you can define a set of transformations that need to happen asynchronously to any image that gets set on the imageNode.

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>

<div class = "code">
<pre lang="objc" class="objcCode">
_backgroundImageNode.imageModificationBlock = ^(UIImage *image) {
	UIImage *newImage = [image applyBlurWithRadius:30
		tintColor:[UIColor colorWithWhite:0.5 alpha:0.3]
		saturationDeltaFactor:1.8
		maskImage:nil];
	return newImage ?: image;
};

//some time later...

_backgroundImageNode.image = someImage;
</pre>

<pre lang="swift" class = "swiftCode hidden">
backgroundImageNode.imageModificationBlock = { image in
    let newImage = image.applyBlurWithRadius(30, tintColor: UIColor(white: 0.5, alpha: 0.3),
    								 saturationDeltaFactor: 1.8,
    								 			 maskImage: nil)
    return (newImage != nil) ? newImage : image
}

//some time later...

backgroundImageNode.image = someImage
</pre>
</div>
</div>

The image named "someImage" will now be blurred asynchronously before being assigned to the imageNode to be displayed.

### Adding image effects

The most efficient way to add image effects is by leveraging the `imageModificationBlock` block. If a block is provided it can perform drawing operations on the image during the display phase. As display is happening on a background thread it will not block the main thread.

In the following example we assume we have an avatar node that will be setup in `init` of a supernode and the image of the node should be rounded. We provide the `imageModificationBlock` and in there we call a convenience method that transforms the image passed in into a circular image and return it.

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>

<div class = "code">
<pre lang="objc" class="objcCode">
- (instancetype)init
{
// ...
  _userAvatarImageNode.imageModificationBlock = ^UIImage *(UIImage *image) {
    CGSize profileImageSize = CGSizeMake(USER_IMAGE_HEIGHT, USER_IMAGE_HEIGHT);
    return [image makeCircularImageWithSize:profileImageSize];
  };
  // ...
}
</pre>

<pre lang="swift" class = "swiftCode hidden">
init() {
	// ...
	_userAvatarImageNode?.imageModificationBlock = { image in
		return image.makeCircularImage(size: CGSize(width: USER_IMAGE_HEIGHT, height: USER_IMAGE_HEIGHT))
	}
</pre>
</div>

</div>

The actual drawing code is nicely abstracted away in an UIImage category and looks like the following:

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>

<div class = "code">
<pre lang="objc" class="objcCode">
@implementation UIImage (Additions)
- (UIImage *)makeCircularImageWithSize:(CGSize)size
{
  // make a CGRect with the image's size
  CGRect circleRect = (CGRect) {CGPointZero, size};

  // begin the image context since we're not in a drawRect:
  UIGraphicsBeginImageContextWithOptions(circleRect.size, NO, 0);

  // create a UIBezierPath circle
  UIBezierPath *circle = [UIBezierPath bezierPathWithRoundedRect:circleRect cornerRadius:circleRect.size.width/2];

  // clip to the circle
  [circle addClip];

  // draw the image in the circleRect *AFTER* the context is clipped
  [self drawInRect:circleRect];

  // get an image from the image context
  UIImage *roundedImage = UIGraphicsGetImageFromCurrentImageContext();

  // end the image context since we're not in a drawRect:
  UIGraphicsEndImageContext();

  return roundedImage;
}
@end
</pre>

<pre lang="swift" class = "swiftCode hidden">
extension UIImage {

	func makeCircularImage(size: CGSize) -> UIImage {
		// make a CGRect with the image's size
		let circleRect = CGRect(origin: .zero, size: size)

		// begin the image context since we're not in a drawRect:
		UIGraphicsBeginImageContextWithOptions(circleRect.size, false, 0)

		// create a UIBezierPath circle
		let circle = UIBezierPath(roundedRect: circleRect, cornerRadius: circleRect.size.width * 0.5)

		// clip to the circle
		circle.addClip()

		UIColor.white.set()
		circle.fill()

		// draw the image in the circleRect *AFTER* the context is clipped
		self.draw(in: circleRect)

		// get an image from the image context
		let roundedImage = UIGraphicsGetImageFromCurrentImageContext()

		// end the image context since we're not in a drawRect:
		UIGraphicsEndImageContext()

		return roundedImage ?? self
	}
}
</pre>
</div>
</div>

The imageModificationBlock is very handy and can be used to add all kind of image effects, such as rounding, adding borders, or other pattern overlays, without extraneous display calls.
