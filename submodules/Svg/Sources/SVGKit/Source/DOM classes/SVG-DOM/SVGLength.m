#import "SVGLength.h"

#import "CSSPrimitiveValue.h"
#import "CSSPrimitiveValue_ConfigurablePixelsPerInch.h"

#import "SVGUtils.h"

#include <sys/types.h>
#include <sys/sysctl.h>

@interface SVGLength()
@property(nonatomic,strong) CSSPrimitiveValue* internalCSSPrimitiveValue;
@end

@implementation SVGLength

@synthesize unitType;
@synthesize value;
@synthesize valueInSpecifiedUnits;
@synthesize valueAsString;
@synthesize internalCSSPrimitiveValue;


- (id)init
{
    NSAssert(FALSE, @"This class must not be init'd. Use the static hepler methods to instantiate it instead");
    return nil;
}

- (id)initWithCSSPrimitiveValue:(CSSPrimitiveValue*) pv
{
    self = [super init];
    if (self) {
        self.internalCSSPrimitiveValue = pv;
    }
    return self;
}

-(float)value
{
	return [self.internalCSSPrimitiveValue getFloatValue:self.internalCSSPrimitiveValue.primitiveType];
}

-(SVG_LENGTH_TYPE)unitType
{
	switch( self.internalCSSPrimitiveValue.primitiveType )
	{
		case CSS_CM:
			return SVG_LENGTHTYPE_CM;
		case CSS_EMS:
			return SVG_LENGTHTYPE_EMS;
		case CSS_EXS:
			return SVG_LENGTHTYPE_EXS;
		case CSS_IN:
			return SVG_LENGTHTYPE_IN;
		case CSS_MM:
			return SVG_LENGTHTYPE_MM;
		case CSS_PC:
			return SVG_LENGTHTYPE_PC;
		case CSS_PERCENTAGE:
			return SVG_LENGTHTYPE_PERCENTAGE;
		case CSS_PT:
			return SVG_LENGTHTYPE_PT;
		case CSS_PX:
			return SVG_LENGTHTYPE_PX;
		case CSS_NUMBER:
		case CSS_DIMENSION:
			return SVG_LENGTHTYPE_NUMBER;
		default:
			return SVG_LENGTHTYPE_UNKNOWN;
	}
}

-(void) newValueSpecifiedUnits:(SVG_LENGTH_TYPE) unitType valueInSpecifiedUnits:(float) valueInSpecifiedUnits
{
	NSAssert(FALSE, @"Not supported yet");
}

-(void) convertToSpecifiedUnits:(SVG_LENGTH_TYPE) unitType
{
	NSAssert(FALSE, @"Not supported yet");
}

/** Apple calls this method when the class is loaded; that's as good a time as any to calculate the device / screen's PPI */
+(void)initialize
{
	cachedDevicePixelsPerInch = [self pixelsPerInchForCurrentDevice];
}

+(SVGLength*) svgLengthZero
{
	SVGLength* result = [[SVGLength alloc] initWithCSSPrimitiveValue:nil];
	
	return result;
}

static float cachedDevicePixelsPerInch;
+(SVGLength*) svgLengthFromNSString:(NSString*) s
{
	CSSPrimitiveValue* pv = [[CSSPrimitiveValue alloc] init];
	
	pv.pixelsPerInch = cachedDevicePixelsPerInch;
	pv.cssText = s;
	
	SVGLength* result = [[SVGLength alloc] initWithCSSPrimitiveValue:pv];
	
	return result;
}

-(float) pixelsValue
{
	return [self.internalCSSPrimitiveValue getFloatValue:CSS_PX];
}

-(float) pixelsValueWithDimension:(float)dimension
{
    if (self.internalCSSPrimitiveValue.primitiveType == CSS_PERCENTAGE)
        return dimension * self.value / 100.0;
    
    return [self pixelsValue];
}

-(float) pixelsValueWithGradientDimension:(float)dimension
{
    if (self.internalCSSPrimitiveValue.primitiveType == CSS_PERCENTAGE) {
        return dimension * self.value / 100.0;
    } else if (self.internalCSSPrimitiveValue.primitiveType == CSS_NUMBER) {
        if (self.value >= 0 && self.value <= 1) {
            return dimension * self.value;
        }
    }
    
    return [self pixelsValue];
}

-(float) numberValue
{
	return [self.internalCSSPrimitiveValue getFloatValue:CSS_NUMBER];
}

#pragma mark - secret methods needed to provide an implementation on ObjectiveC

+(float) pixelsPerInchForCurrentDevice
{
	/** Using this as reference: http://en.wikipedia.org/wiki/Retina_Display and https://www.theiphonewiki.com/wiki/Models
      */
	
	size_t size;
	sysctlbyname("hw.machine", NULL, &size, NULL, 0);
	char *machine = malloc(size);
	sysctlbyname("hw.machine", machine, &size, NULL, 0);
	NSString *platform = [NSString stringWithUTF8String:machine];
	free(machine);
	
	if( [platform hasPrefix:@"iPhone1"]
	|| [platform hasPrefix:@"iPhone2"]
	|| [platform hasPrefix:@"iPhone3"])
		return 163.0f;
	
    if( [platform hasPrefix:@"iPhone4"]
       || [platform hasPrefix:@"iPhone5"]
       || [platform hasPrefix:@"iPhone6"]
       || [platform hasPrefix:@"iPhone7,2"]
       || [platform hasPrefix:@"iPhone8,1"]
       || [platform hasPrefix:@"iPhone8,4"]
       || [platform hasPrefix:@"iPhone9,1"]
       || [platform hasPrefix:@"iPhone9,3"]) {
        return 326.0f;
    }
    
    if ( [platform hasPrefix:@"iPhone7,1"]
       || [platform hasPrefix:@"iPhone8,2"]
       || [platform hasPrefix:@"iPhone9,2"]
       || [platform hasPrefix:@"iPhone9,4"]) {
        return 401.0f;
    }
	
	if( [platform hasPrefix:@"iPhone"]) // catch-all for higher-end devices not yet existing
	{
		NSAssert(FALSE, @"Update your source code or disable assertions: you are using an iPhone that didn't exist when this code was written, we have no idea what the pixel count per inch is!");
		return 401.0f;
	}
	
	if( [platform hasPrefix:@"iPod1"]
	   || [platform hasPrefix:@"iPod2"]
	   || [platform hasPrefix:@"iPod3"])
		return 163.0f;
	
	if( [platform hasPrefix:@"iPod4"]
	   || [platform hasPrefix:@"iPod5"]
	   || [platform hasPrefix:@"iPod7"])
		return 326.0f;
	
	if( [platform hasPrefix:@"iPod"]) // catch-all for higher-end devices not yet existing
	{
		NSAssert(FALSE, @"Update your source code or disable assertions: you are using an iPod that didn't exist when this code was written, we have no idea what the pixel count per inch is!");
		return 326.0f;
	}
	
    if( [platform hasPrefix:@"iPad5,1"]
       || [platform hasPrefix:@"iPad5,2"])
        return 326.0f;
    
	if( [platform hasPrefix:@"iPad1"]
	|| [platform hasPrefix:@"iPad2"])
		return 132.0f;
	if( [platform hasPrefix:@"iPad3"]
	|| [platform hasPrefix:@"iPad4"]
	|| [platform hasPrefix:@"iPad5,3"]
    || [platform hasPrefix:@"iPad5,4"]
	|| [platform hasPrefix:@"iPad6"]
    || [platform hasPrefix:@"iPad7"]
    || [platform hasPrefix:@"iPad8"])
		return 264.0f;
    
	if( [platform hasPrefix:@"iPad"]) // catch-all for higher-end devices not yet existing
	{
		NSAssert(FALSE, @"Update your source code or disable assertions: you are using an iPad that didn't exist when this code was written, we have no idea what the pixel count per inch is!");
		return 264.0f;
	}
    
    if( [platform hasPrefix:@"iWatch1"])
        return 326.0f;
    
    if( [platform hasPrefix:@"iWatch"]) // catch-all for higher-end devices not yet existing
    {
        NSAssert(FALSE, @"Update your source code or disable assertions: you are using an iWatch that didn't exist when this code was written, we have no idea what the pixel count per inch is!");
        return 326.0f;
    }
	
	if( [platform hasPrefix:@"x86_64"])
	{
		SVGKitLogWarn(@"[%@] WARNING: you are running on the simulator; it's impossible for us to calculate centimeter/millimeter/inches units correctly", [self class]);
		return 132.0f; // Simulator, running on desktop machine
	}
	
	NSAssert(FALSE, @"Cannot determine the PPI values for current device; returning 0.0f - hopefully this will crash your code (you CANNOT run SVG's that use CM/IN/MM etc until you fix this)" );
	return 0.0f; // Bet you'll get a divide by zero here...
}

@end
