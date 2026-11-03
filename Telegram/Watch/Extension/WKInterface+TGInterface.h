#import <WatchKit/WatchKit.h>

@interface WKInterfaceObject (TGInterface)

@property (nonatomic, assign) CGFloat alpha;
@property (nonatomic, assign, getter=isHidden) bool hidden;

@property (nonatomic, assign) CGFloat width;
@property (nonatomic, assign) CGFloat height;

- (void)_setInitialHidden:(bool)hidden;

@end

@interface WKInterfaceGroup (TGInterface)

@property (nonatomic, strong) UIColor *backgroundColor;
@property (nonatomic, assign) CGFloat cornerRadius;

@end

@interface WKInterfaceLabel (TGInterface)

@property (nonatomic, strong) NSString *text;
@property (nonatomic, strong) UIColor *textColor;

@property (nonatomic, strong) NSString *hyphenatedText;

@property (nonatomic, strong) NSAttributedString *attributedText;

@end

@interface WKInterfaceButton (TGInterface)

@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSAttributedString *attributedTitle;

@property (nonatomic, assign, getter=isEnabled) bool enabled;

@end

@interface WKInterfaceMap (TGInterface)

@property (nonatomic, assign) MKCoordinateRegion region;
@property (nonatomic, assign) CLLocationCoordinate2D centerPinCoordinate;

@end
