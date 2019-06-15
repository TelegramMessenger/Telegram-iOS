#import <MapKit/MapKit.h>

@class TGLocationPallete;

@interface TGLocationPinAnnotationView : MKAnnotationView

- (instancetype)initWithAnnotation:(id<MKAnnotation>)annotation;

@property (nonatomic, assign, getter=isPinRaised) bool pinRaised;
- (void)setPinRaised:(bool)raised avatar:(bool)avatar animated:(bool)animated completion:(void (^)(void))completion;

- (void)setCustomPin:(bool)customPin animated:(bool)animated;

@property (nonatomic, strong) TGLocationPallete *pallete;

@end

extern NSString * const TGLocationPinAnnotationKind;


@interface TGLocationPinWrapperView : UIView

@end
