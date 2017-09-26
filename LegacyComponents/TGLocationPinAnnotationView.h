#import <MapKit/MapKit.h>

@interface TGLocationPinAnnotationView : MKAnnotationView

- (instancetype)initWithAnnotation:(id<MKAnnotation>)annotation;

@end

extern NSString * const TGLocationPinAnnotationKind;
