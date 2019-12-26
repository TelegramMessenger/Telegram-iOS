/*!
//  SVGKPointsAndPathsParser.h

 This class really needs to be "upgraded" by wrapping it in a class named
 
     SVGPathElement
 
 and naming methods in that new class so that they adhere to the method names used in the official SVG standard's SVGPathElement spec:
 
 http://www.w3.org/TR/SVG11/paths.html#InterfaceSVGPathElement
 
 ...
 
 */
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>

/**
 * Partially spammy; not as spammy as DEBUG_PATH_CREATION
 */
#define VERBOSE_PARSE_SVG_COMMAND_STRINGS 0

/*! Very useful for debugging the parser - this will output one line of logging
 * for every CGPath command that's actually done; you can then compare these lines
 * to the input source file, and manually check what's being sent to the renderer
 * versus what was expected
 *
 * this is MORE SPAMMY than VERBOSE_PARSE_SVG_COMMAND_STRINGS
 */
#define DEBUG_PATH_CREATION 0

typedef NS_ENUM(NSUInteger, SVGCurveType) {
    SVGCurveTypePoint,
    SVGCurveTypeCubic,
    SVGCurveTypeQuadratic,
};

typedef struct SVGCurve
{
    SVGCurveType type;
    CGPoint c1;
    CGPoint c2;
    CGPoint p;
} SVGCurve;


@interface SVGKPointsAndPathsParser : NSObject

+ (SVGCurve) startingCurve;

+ (SVGCurve) readMovetoDrawtoCommandGroups:(NSScanner*)scanner path:(CGMutablePathRef)path relativeTo:(CGPoint)origin isRelative:(BOOL) isRelative;
+ (SVGCurve) readMovetoDrawto:(NSScanner*)scanner path:(CGMutablePathRef)path relativeTo:(CGPoint)origin isRelative:(BOOL) isRelative;
+ (SVGCurve) readMoveto:(NSScanner*)scanner path:(CGMutablePathRef)path relativeTo:(CGPoint)origin isRelative:(BOOL) isRelative;
+ (SVGCurve) readMovetoArgumentSequence:(NSScanner*)scanner path:(CGMutablePathRef)path relativeTo:(CGPoint)origin isRelative:(BOOL) isRelative;

+ (SVGCurve) readLinetoCommand:(NSScanner*)scanner path:(CGMutablePathRef)path relativeTo:(CGPoint)origin isRelative:(BOOL) isRelative;
+ (SVGCurve) readLinetoArgumentSequence:(NSScanner*)scanner path:(CGMutablePathRef)path relativeTo:(CGPoint)origin isRelative:(BOOL) isRelative;
+ (SVGCurve) readVerticalLinetoCommand:(NSScanner*)scanner path:(CGMutablePathRef)path relativeTo:(CGPoint)origin;
+ (SVGCurve) readVerticalLinetoArgumentSequence:(NSScanner*)scanner path:(CGMutablePathRef)path relativeTo:(CGPoint)origin;
+ (SVGCurve) readHorizontalLinetoArgumentSequence:(NSScanner*)scanner path:(CGMutablePathRef)path relativeTo:(CGPoint)origin;
+ (SVGCurve) readHorizontalLinetoCommand:(NSScanner*)scanner path:(CGMutablePathRef)path relativeTo:(CGPoint)origin;

+ (SVGCurve) readQuadraticCurvetoCommand:(NSScanner*)scanner path:(CGMutablePathRef)path relativeTo:(CGPoint)origin isRelative:(BOOL) isRelative;
+ (SVGCurve) readQuadraticCurvetoArgumentSequence:(NSScanner*)scanner path:(CGMutablePathRef)path relativeTo:(CGPoint)origin isRelative:(BOOL) isRelative;
+ (SVGCurve) readQuadraticCurvetoArgument:(NSScanner*)scanner path:(CGMutablePathRef)path relativeTo:(CGPoint)origin;
+ (SVGCurve) readSmoothQuadraticCurvetoCommand:(NSScanner*)scanner path:(CGMutablePathRef)path relativeTo:(CGPoint)origin withPrevCurve:(SVGCurve)prevCurve;
+ (SVGCurve) readSmoothQuadraticCurvetoArgumentSequence:(NSScanner*)scanner path:(CGMutablePathRef)path relativeTo:(CGPoint)origin withPrevCurve:(SVGCurve)prevCurve;
+ (SVGCurve) readSmoothQuadraticCurvetoArgument:(NSScanner*)scanner path:(CGMutablePathRef)path relativeTo:(CGPoint)origin withPrevCurve:(SVGCurve)prevCurve;

+ (SVGCurve) readCurvetoCommand:(NSScanner*)scanner path:(CGMutablePathRef)path relativeTo:(CGPoint)origin isRelative:(BOOL) isRelative;
+ (SVGCurve) readCurvetoArgumentSequence:(NSScanner*)scanner path:(CGMutablePathRef)path relativeTo:(CGPoint)origin isRelative:(BOOL) isRelative;
+ (SVGCurve) readCurvetoArgument:(NSScanner*)scanner path:(CGMutablePathRef)path relativeTo:(CGPoint)origin;
+ (SVGCurve) readSmoothCurvetoCommand:(NSScanner*)scanner path:(CGMutablePathRef)path relativeTo:(CGPoint)origin withPrevCurve:(SVGCurve)prevCurve isRelative:(BOOL) isRelative;
+ (SVGCurve) readSmoothCurvetoArgumentSequence:(NSScanner*)scanner path:(CGMutablePathRef)path relativeTo:(CGPoint)origin withPrevCurve:(SVGCurve)prevCurve isRelative:(BOOL) isRelative;
+ (SVGCurve) readSmoothCurvetoArgument:(NSScanner*)scanner path:(CGMutablePathRef)path relativeTo:(CGPoint)origin withPrevCurve:(SVGCurve)prevCurve;

+ (SVGCurve) readEllipticalArcArguments:(NSScanner*)scanner path:(CGMutablePathRef)path relativeTo:(CGPoint)origin isRelative:(BOOL) isRelative;

+ (SVGCurve) readCloseCommand:(NSScanner*)scanner path:(CGMutablePathRef)path relativeTo:(CGPoint)origin;

@end
