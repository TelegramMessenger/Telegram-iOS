//
//  SVGTextLayer.h
//  SVGKit-iOS
//
//  Created by lizhuoli on 2018/11/6.
//  Copyright © 2018 na. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>

/**
 On macOS, we use the flipped coordinate system. However, Apple's `CATextLayer` render the text using `contentsAreFlipped` property. Which is set to NO and this will cause the text element been drawn flipped unlike what it's drawn on iOS. We use this subclass to override that value on macOS.
 Besides this fix, this class may also implement more features to match the SVG spec in the future, such as gradient stroke (which currently is not supported)
 */
@interface SVGTextLayer : CATextLayer

@end
