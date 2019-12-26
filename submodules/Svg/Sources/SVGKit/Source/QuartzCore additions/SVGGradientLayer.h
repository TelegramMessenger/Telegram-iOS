//
//  SVGGradientLayer.h
//  SVGKit-iOS
//
//  Created by zhen ling tsai on 19/7/13.
//  Copyright (c) 2013 na. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "SVGGradientElement.h"

/**
 Apple's built-in CAGradientLayer does not support the radial gradient in SVG spec which allows user to provide `cx`, `cy`, `r`, `fx`, `fy`, `fr` 6 args.
 The built-in `kCAGradientLayerRadial` type only supports a ellipse and take `cx`, `cy`, `r` 3 args. Sadlly we can not directly use it for radial gardient.
 So we have to subclass and use the low-level API `CGContextDrawRadialGradient` using custom drawing to follow SVG spec.
 
 Also, though we can use `CAGradientLayer` for all linear gradient. Apples contains bug rending the gradient using `drawInContext:` method on iOS only (but works well on macOS), which will contains some strange bounding rects. This will break `SVGFastImageView` usage (but works well on SVGLayeredImageView).
 So we have to use the low-level API `CGContextDrawLinearGradient` using custom drawing to as well.
 */
@interface SVGGradientLayer : CAGradientLayer

@property (nonatomic, strong) SVGGradientElement *gradientElement;
@property (nonatomic, assign) CGRect objectRect;
@property (nonatomic, assign) SVGRect viewportRect;
@property (nonatomic, assign) CGAffineTransform absoluteTransform;

@end
