 /* FIXME: very different from SVG Spec */

#import "SVGGradientElement.h"
#import "SVGGradientStop.h"
#import "SVGGElement.h"
#import "SVGLinearGradientElement.h"
#import "SVGRadialGradientElement.h"

@implementation SVGGradientElement

@synthesize stops = _stops;
@synthesize transform;
@synthesize locations = _locations;
@synthesize colors = _colors;
@synthesize gradientUnits = _gradientUnits;
@synthesize spreadMethod = _spreadMethod;

-(void)addStop:(SVGGradientStop *)gradientStop
{
    if( _stops == nil )
	{
		_stops = [NSArray arrayWithObject:gradientStop];
	}
	else
	{
		_stops = [_stops arrayByAddingObjectsFromArray:[NSArray arrayWithObject:gradientStop]];
	}
}

- (NSArray *)colors {
    if(_colors == nil ) //these can't be determined until parsing is complete, need to update SVGGradientParser and do this on end element
    {
        NSUInteger numStops = [self.stops count];
        if (numStops == 0) {
            return nil;
        }
        NSMutableArray *colorBuilder = [[NSMutableArray alloc] initWithCapacity:numStops];
        for (SVGGradientStop *theStop in self.stops)
        {
            [colorBuilder addObject:(__bridge id)CGColorWithSVGColor([theStop stopColor])];
        }
        
        _colors = [[NSArray alloc] initWithArray:colorBuilder];
    }
    return _colors;
}

- (NSArray *)locations {
    if(_locations == nil ) //these can't be determined until parsing is complete, need to update SVGGradientParser and do this on end element
    {
        NSUInteger numStops = [self.stops count];
        if (numStops == 0) {
            return nil;
        }
        NSMutableArray *locationBuilder = [[NSMutableArray alloc] initWithCapacity:numStops];
        CGFloat previousOffset = 0;
        for (int i = 0; i < self.stops.count; i++) {
            SVGGradientStop *theStop = self.stops[i];
            // SVG spec: Gradient offset values less than 0 (or less than 0%) are rounded up to 0%. Gradient offset values greater than 1 (or greater than 100%) are rounded down to 100%.
            CGFloat offset = MIN(MAX(0.0, theStop.offset), 1.0);
            // SVG spec: Each gradient offset value is required to be equal to or greater than the previous gradient stop's offset value. If a given gradient stop's offset value is not equal to or greater than all previous offset values, then the offset value is adjusted to be equal to the largest of all previous offset values.
            if (offset < previousOffset) {
                offset = previousOffset;
            }
            // SVG spec: If two gradient stops have the same offset value, then the latter gradient stop controls the color value at the overlap point.
            if (offset == previousOffset) {
                if (offset != 0) {
                    CGFloat adjustedOffset = previousOffset - 0.0000000001;
                    [locationBuilder replaceObjectAtIndex:(i - 1) withObject:@(adjustedOffset)];
                }
            }
            previousOffset = offset;
            [locationBuilder addObject:[NSNumber numberWithFloat:offset]];
        }
        
        _locations = [[NSArray alloc] initWithArray:locationBuilder];
    }
    return _locations;
}

- (SVG_UNIT_TYPE)gradientUnits {
    NSString* gradientUnits = [self getAttributeInheritedIfNil:@"gradientUnits"];
    if( ![gradientUnits length]
       || [gradientUnits isEqualToString:@"objectBoundingBox"]) {
        return SVG_UNIT_TYPE_OBJECTBOUNDINGBOX;
    } else if ([gradientUnits isEqualToString:@"userSpaceOnUse"]) {
        return SVG_UNIT_TYPE_USERSPACEONUSE;
    } else {
        SVGKitLogWarn(@"Unsupported gradientUnits: %@", gradientUnits);
        return SVG_UNIT_TYPE_UNKNOWN;
    }
}

- (SVGSpreadMethod)spreadMethod {
    NSString* spreadMethod = [self getAttributeInheritedIfNil:@"spreadMethod"];
    if( ![spreadMethod length]
       || [spreadMethod isEqualToString:@"pad"]) {
        return SVGSpreadMethodPad;
    } else if ([spreadMethod isEqualToString:@"reflect"]) {
        return SVGSpreadMethodReflect;
    } else if ([spreadMethod isEqualToString:@"repeat"]) {
        return SVGSpreadMethodRepeat;
    } else {
        SVGKitLogWarn(@"Unsupported spreadMethod: %@", spreadMethod);
        return SVGSpreadMethodUnkown;
    }
}

-(void)postProcessAttributesAddingErrorsTo:(SVGKParseResult *)parseResult
{
    [super postProcessAttributesAddingErrorsTo:parseResult];
}

-(NSString*) getAttributeInheritedIfNil:(NSString*) attrName
{
	if( [self.parentNode isKindOfClass:[SVGGElement class]] )
		return [self hasAttribute:attrName] ? [self getAttribute:attrName] : [((SVGElement*)self.parentNode) getAttribute:attrName];
	else
		return [self getAttribute:attrName]; // will return blank if there was no value AND no parent value
}

- (SVGGradientLayer *)newGradientLayerForObjectRect:(CGRect)objectRect viewportRect:(SVGRect)viewportRect transform:(CGAffineTransform)transform {
    return nil;
}

- (void)synthesizeProperties
{
    
}

-(void)layoutLayer:(CALayer *)layer
{
	
}


@end
