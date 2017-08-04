#import <MapKit/MapKit.h>

@interface TGPinAnnotationView : MKPinAnnotationView
{
    UIButton *_calloutWrapper;
    
    UILabel *_titleLabel;
    UILabel *_subtitleLabel;
}

@property (nonatomic, copy) void(^calloutPressed)(void);

@property (nonatomic, assign) NSString *title;
@property (nonatomic, assign) NSString *subtitle;
@property (nonatomic, assign) bool selectable;

@property (nonatomic, readonly) bool appeared;

@end
