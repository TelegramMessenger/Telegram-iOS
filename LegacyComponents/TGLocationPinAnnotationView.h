#import <MapKit/MapKit.h>

@interface TGLocationPinAnnotationView : MKAnnotationView

- (instancetype)initWithAnnotation:(id<MKAnnotation>)annotation;

@property (nonatomic, assign, getter=isPinRaised) bool pinRaised;
- (void)setPinRaised:(bool)raised animated:(bool)animated completion:(void (^)(void))completion;

@end

extern NSString * const TGLocationPinAnnotationKind;


@interface TGLocationPinWrapperView : UIView

@end
