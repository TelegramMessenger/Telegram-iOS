/**
 SVGGroupElement.m
 
 In SVG, every single element can contain children.
 
 However, the SVG spec defines a special (optional) "group" element, that is never rendered,
 but allows additional nesting (e.g. for programmatic / organizational purposes).
 
 This is the "G" tag.
 */
#import "SVGGroupElement.h"

#import "CALayerWithChildHitTest.h"

#import "SVGElement_ForParser.h" // to resolve Xcode circular dependencies; in long term, parsing SHOULD NOT HAPPEN inside any class whose name starts "SVG" (because those are reserved classes for the SVG Spec)
#import "Node.h"

@implementation SVGGroupElement

@synthesize opacity = _opacity;


- (void)loadDefaults {
	_opacity = 1.0f;
}

- (void)postProcessAttributesAddingErrorsTo:(SVGKParseResult *)parseResult {
	[super postProcessAttributesAddingErrorsTo:parseResult];
	
	if( [[self getAttribute:@"opacity"] length] > 0 )
	_opacity = [[self getAttribute:@"opacity"] floatValue];
}

- (CALayer *) newLayer
{
	
	CALayer* _layer = [CALayerWithChildHitTest layer];
		
		_layer.name = self.identifier;
		[_layer setValue:self.identifier forKey:kSVGElementIdentifier];
		_layer.opacity = _opacity;
		
	
	return _layer;
}

- (void)layoutLayer:(CALayer *)layer {
	CGRect mainRect = CGRectZero;
	
	/** Adam: make a frame thats the UNION of all sublayers frames */
	for ( CALayer *currentLayer in [layer sublayers] )
	{
		CGRect subLayerFrame = currentLayer.frame;
		mainRect = CGRectUnion(mainRect, subLayerFrame);
	}
	
	layer.frame = mainRect;
	
	/** Adam:(dont know why this is here): set each sublayer to have a frame the same size as the parent frame, but with 0 offset.
	 
	 Adam: if I understand this correctly, the person who wrote it should have just written:
	 
	 "currentLayer.bounds = layer.frame"
	 
	 i.e. make every layer have the same size as the parent layer.
	 
	 But whoever wrote this didn't document their bad code, so I have no idea if thats correct or not
	 */
	for (CALayer *currentLayer in [layer sublayers]) {
		CGRect frame = currentLayer.frame;
		frame.origin.x -= mainRect.origin.x;
		frame.origin.y -= mainRect.origin.y;
		
		currentLayer.frame = frame;
	}
}

/*
 FIXME: this cannot work; this is incompatible with the way that SVG spec was designed; this code comes from old SVGKit
 
 //we can't propagate opacity down unfortunately, so we need to build a set of all the properties except a few (opacity is applied differently to groups than simply inheriting it to it's children, <g opacity occurs AFTER blending all of its children
 
 BOOL attributesFound = NO;
 NSMutableDictionary *buildDictionary = [NSMutableDictionary new];
 for( Node* node in self.attributes )
 {
 if( ![node.localName isEqualToString:@"opacity"] )
 {
 attributesFound = YES;
 [buildDictionary setObject:[attributes objectForKey:key] forKey:node.localName];
 }
 }
 if( attributesFound )
 {
 _attributes = [[NSDictionary alloc] initWithDictionary:buildDictionary];
 //these properties are inherited by children of this group
 }
 [buildDictionary release];
 
 */

@end
