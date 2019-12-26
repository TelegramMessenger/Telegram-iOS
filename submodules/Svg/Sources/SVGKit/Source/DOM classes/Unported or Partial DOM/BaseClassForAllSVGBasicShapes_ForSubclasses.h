/**
 Class extension that makes the internal properties readWRITE for subclasses to write to
 */

@interface BaseClassForAllSVGBasicShapes ()
@property (nonatomic, readwrite) CGPathRef pathForShapeInRelativeCoords;
@end
