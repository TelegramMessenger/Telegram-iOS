#import "TGPinAnnotationView.h"

@interface TGLocationPinAnnotationView : TGPinAnnotationView

@property (nonatomic, copy) void(^getDirectionsPressed)(void);

@end

extern NSString * const TGLocationPinAnnotationKind;

extern NSString * const TGLocationETAKey;