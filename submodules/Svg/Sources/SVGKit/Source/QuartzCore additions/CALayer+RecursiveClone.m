//
//  CALayer+RecursiveClone.m
//  SVGKit-iOS
//
//  Created by adam on 22/04/2013.
//  Copyright (c) 2013 na. All rights reserved.
//

#import "CALayer+RecursiveClone.h"

@implementation CALayer (RecursiveClone)

-(CALayer*) cloneRecursively
{
	return [self cloneOptionallRecurse:TRUE];
}

-(CALayer*) cloneShallow
{
	return [self cloneOptionallRecurse:FALSE];
}

-(CALayer*) cloneOptionallRecurse:(BOOL) shouldRecurse
{
	CALayer* clone = [[self class] layer]; // Apple official method for duplicating a layer correctly but leaving all properties empty
	
	if( [clone isKindOfClass:[CALayer class]])
	{
		CALayer* specificClone = clone;
		CALayer* selfSpecific = self;
		
		specificClone.bounds = selfSpecific.bounds; // don't use Frame! According to Apple's docs, it's officially unsupported for writes!
		specificClone.position = selfSpecific.position; // don't use Frame! According to Apple's docs, it's officially unsupported for writes!
		specificClone.zPosition = selfSpecific.zPosition;
		specificClone.anchorPoint = selfSpecific.anchorPoint;
		specificClone.anchorPointZ = selfSpecific.anchorPointZ;
		specificClone.transform = selfSpecific.transform;
		specificClone.hidden = selfSpecific.hidden;
		specificClone.doubleSided = selfSpecific.doubleSided;
		specificClone.geometryFlipped = selfSpecific.geometryFlipped;
		specificClone.sublayerTransform = selfSpecific.sublayerTransform;
		specificClone.mask = [selfSpecific.mask cloneRecursively];
		specificClone.masksToBounds = selfSpecific.masksToBounds;
		specificClone.contents = selfSpecific.contents;
		specificClone.contentsRect = selfSpecific.contentsRect;
		specificClone.contentsGravity = selfSpecific.contentsGravity;
		specificClone.contentsScale = selfSpecific.contentsScale;
		specificClone.contentsCenter = selfSpecific.contentsCenter;
		specificClone.minificationFilter = selfSpecific.minificationFilter;
		specificClone.magnificationFilter = selfSpecific.magnificationFilter;
		specificClone.minificationFilterBias = selfSpecific.minificationFilterBias;
		specificClone.opaque = selfSpecific.opaque;
		specificClone.needsDisplayOnBoundsChange = selfSpecific.needsDisplayOnBoundsChange;
		if( [specificClone respondsToSelector:@selector(drawsAsynchronously)]) // Apple Bug: iOS6+ only, but unmarked in source header
			specificClone.drawsAsynchronously = selfSpecific.drawsAsynchronously;
		specificClone.edgeAntialiasingMask = selfSpecific.edgeAntialiasingMask;
		specificClone.backgroundColor = selfSpecific.backgroundColor;
		specificClone.cornerRadius = selfSpecific.cornerRadius;
		specificClone.borderWidth = selfSpecific.borderWidth;
		specificClone.borderColor = selfSpecific.borderColor;
		specificClone.opacity = selfSpecific.opacity;
		specificClone.compositingFilter = selfSpecific.compositingFilter;
		specificClone.filters = [selfSpecific.filters copy];
		specificClone.backgroundFilters = [selfSpecific.backgroundFilters copy];
		specificClone.shouldRasterize = selfSpecific.shouldRasterize;
		specificClone.rasterizationScale = selfSpecific.rasterizationScale;
		specificClone.shadowColor = selfSpecific.shadowColor;
		specificClone.shadowOpacity = selfSpecific.shadowOpacity;
		specificClone.shadowOffset = selfSpecific.shadowOffset;
		specificClone.shadowRadius = selfSpecific.shadowRadius;
		specificClone.shadowPath = selfSpecific.shadowPath;
		specificClone.name = selfSpecific.name;
		specificClone.style = [selfSpecific.style copy];
	}
	
	if( [clone isKindOfClass:[CAGradientLayer class]])
	{
		CAGradientLayer* specificClone = (CAGradientLayer*) clone;
		CAGradientLayer* selfSpecific = (CAGradientLayer*) self;
		
		specificClone.startPoint = selfSpecific.startPoint;
		specificClone.endPoint = selfSpecific.endPoint;
		specificClone.type = selfSpecific.type;
		specificClone.colors = [selfSpecific.colors copy];
		specificClone.locations = [selfSpecific.locations copy];
	}
	
	if( [clone isKindOfClass:[CAShapeLayer class]])
	{
		CAShapeLayer* specificClone = (CAShapeLayer*) clone;
		CAShapeLayer* selfSpecific = (CAShapeLayer*) self;
		
		specificClone.path = selfSpecific.path;
		specificClone.fillColor = selfSpecific.fillColor;
		specificClone.strokeColor = selfSpecific.strokeColor;
		specificClone.lineWidth = selfSpecific.lineWidth;
		specificClone.lineCap = selfSpecific.lineCap;
	}
	
	if( [clone isKindOfClass:[CATextLayer class]])
	{
		CATextLayer* specificClone = (CATextLayer*) clone;
		CATextLayer* selfSpecific = (CATextLayer*) self;
		
		specificClone.string = selfSpecific.string;
		specificClone.font = selfSpecific.font;
		specificClone.fontSize = selfSpecific.fontSize;
		specificClone.foregroundColor = selfSpecific.foregroundColor;
		specificClone.wrapped = selfSpecific.wrapped;
		specificClone.truncationMode = selfSpecific.truncationMode;
		specificClone.alignmentMode = selfSpecific.alignmentMode;
	}
	
	if( shouldRecurse )
	{
	for( CALayer* subLayer in self.sublayers )
	{
		[clone addSublayer:[subLayer cloneRecursively]];
	}
	}
	
	return clone;
}

@end
