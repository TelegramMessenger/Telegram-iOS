#import "SVGAngle.h"

@implementation SVGAngle

@synthesize unitType;
@synthesize value;
@synthesize valueInSpecifiedUnits;
@synthesize valueAsString;

-(void) newValueSpecifiedUnits:(SVGKAngleType) unitType valueInSpecifiedUnits:(float) valueInSpecifiedUnits { NSAssert( FALSE, @"Not implemented yet" ); }
-(void) convertToSpecifiedUnits:(SVGKAngleType) unitType { NSAssert( FALSE, @"Not implemented yet" ); }

@end
