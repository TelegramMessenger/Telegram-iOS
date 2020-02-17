#import "TGLocationInfoCell.h"
#import "TGLocationVenueCell.h"

#import "TGLocationMapViewController.h"
#import "TGLocationSignals.h"
#import "TGLocationUtils.h"
#import "TGLocationReverseGeocodeResult.h"

#import "TGLocationMediaAttachment.h"

#import "LegacyComponentsInternal.h"
#import "TGColor.h"
#import "TGFont.h"
#import "TGImageUtils.h"

#import "TGImageView.h"
#import "TGModernButton.h"

NSString *const TGLocationInfoCellKind = @"TGLocationInfoCell";
const CGFloat TGLocationInfoCellHeight = 134.0f;

@interface TGLocationInfoCell ()
{
    TGModernButton *_locateButton;
    UIImageView *_circleView;
    TGImageView *_iconView;
    
    UILabel *_titleLabel;
    UILabel *_addressLabel;
    
    TGModernButton *_directionsButton;
    UILabel *_directionsButtonLabel;
    UILabel *_etaLabel;
    
    SMetaDisposable *_addressDisposable;
    int32_t _messageId;
}
@end

@implementation TGLocationInfoCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self != nil)
    {
        _messageId = -1;
        
        _locateButton = [[TGModernButton alloc] init];
        [_locateButton addTarget:self action:@selector(locateButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:_locateButton];
        
        _circleView = [[UIImageView alloc] init];
        [_circleView setImage:TGTintedImage([TGLocationVenueCell circleImage], UIColorRGB(0x008df2))];
        [_locateButton addSubview:_circleView];
        
        _iconView = [[TGImageView alloc] init];
        _iconView.contentMode = UIViewContentModeCenter;
        _iconView.image = TGComponentsImageNamed(@"LocationMessagePinIcon");
        [_circleView addSubview:_iconView];
        
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.font = TGBoldSystemFontOfSize(17.0f);
        _titleLabel.textColor = [UIColor blackColor];
        [_locateButton addSubview:_titleLabel];
        
        _addressLabel = [[UILabel alloc] init];
        _addressLabel.font = TGSystemFontOfSize(13);
        _addressLabel.textColor = UIColorRGB(0x8e8e93);
        [_locateButton addSubview:_addressLabel];
        
        static dispatch_once_t onceToken;
        static UIImage *buttonImage = nil;
        dispatch_once(&onceToken, ^
        {
            CGSize size = CGSizeMake(16.0f, 16.0f);
            UIGraphicsBeginImageContextWithOptions(size, false, 0.0f);
            CGContextRef context = UIGraphicsGetCurrentContext();
            CGContextSetStrokeColorWithColor(context, TGAccentColor().CGColor);
            CGContextSetLineWidth(context, 1.0f);
            CGContextStrokeEllipseInRect(context, CGRectMake(0.5f, 0.5f, size.width - 1.0f, size.height - 1.0f));
            buttonImage = [UIGraphicsGetImageFromCurrentImageContext() stretchableImageWithLeftCapWidth:(NSInteger)(size.width / 2.0f) topCapHeight:(NSInteger)(size.height / 2.0f)];
            UIGraphicsEndImageContext();
        });
        
        _directionsButton = [[TGModernButton alloc] init];
        _directionsButton.adjustsImageWhenHighlighted = false;
        [_directionsButton setBackgroundImage:buttonImage forState:UIControlStateNormal];
        [_directionsButton addTarget:self action:@selector(directionsButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:_directionsButton];
        
        _directionsButtonLabel = [[UILabel alloc] init];
        _directionsButtonLabel.backgroundColor = [UIColor clearColor];
        _directionsButtonLabel.font = TGBoldSystemFontOfSize(17.0f);
        _directionsButtonLabel.text = TGLocalized(@"Map.Directions");
        _directionsButtonLabel.textAlignment = NSTextAlignmentCenter;
        _directionsButtonLabel.textColor = TGAccentColor();
        _directionsButtonLabel.userInteractionEnabled = false;
        [_directionsButtonLabel sizeToFit];
        [_directionsButton addSubview:_directionsButtonLabel];
        
        _etaLabel = [[UILabel alloc] init];
        _etaLabel.alpha = 0.0f;
        _etaLabel.font = TGSystemFontOfSize(13);
        _etaLabel.textAlignment = NSTextAlignmentCenter;
        _etaLabel.textColor = TGAccentColor();
        _etaLabel.userInteractionEnabled = false;
        [_directionsButton addSubview:_etaLabel];
    }
    return self;
}

- (void)dealloc
{
    [_addressDisposable dispose];
}

- (void)setPallete:(TGLocationPallete *)pallete
{
    if (pallete == nil || _pallete == pallete)
        return;
    
    _pallete = pallete;
    
    self.backgroundColor = pallete.backgroundColor;
    [_circleView setImage:TGTintedImage([TGLocationVenueCell circleImage], _pallete.locationColor)];
    _titleLabel.textColor = pallete.textColor;
    _addressLabel.textColor = pallete.secondaryTextColor;
    _directionsButtonLabel.textColor = pallete.accentColor;
    _etaLabel.textColor = pallete.accentColor;
    
    CGSize size = CGSizeMake(16.0f, 16.0f);
    UIGraphicsBeginImageContextWithOptions(size, false, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetStrokeColorWithColor(context, pallete.accentColor.CGColor);
    CGContextSetLineWidth(context, 1.0f);
    CGContextStrokeEllipseInRect(context, CGRectMake(0.5f, 0.5f, size.width - 1.0f, size.height - 1.0f));
    UIImage *buttonImage = [UIGraphicsGetImageFromCurrentImageContext() stretchableImageWithLeftCapWidth:(NSInteger)(size.width / 2.0f) topCapHeight:(NSInteger)(size.height / 2.0f)];
    UIGraphicsEndImageContext();
    
    [_directionsButton setBackgroundImage:buttonImage forState:UIControlStateNormal];
}

- (void)locateButtonPressed
{
    if (self.locatePressed != nil)
        self.locatePressed();
}

- (void)directionsButtonPressed
{
    if (self.directionsPressed != nil)
        self.directionsPressed();
}

- (UIButton *)directionsButton
{
    return _directionsButton;
}

- (void)setLocation:(TGLocationMediaAttachment *)location color:(UIColor *)color messageId:(int32_t)messageId userLocationSignal:(SSignal *)userLocationSignal
{
    if (_messageId == messageId)
        return;
    
    _messageId = messageId;
    
    _titleLabel.text = location.venue.title.length > 0 ? location.venue.title : TGLocalized(@"Map.Location");
    
    UIColor *pinColor = _pallete != nil ? _pallete.iconColor : [UIColor whiteColor];
    if (color != nil) {
        [_circleView setImage:TGTintedImage([TGLocationVenueCell circleImage], color)];
        pinColor = [UIColor whiteColor];
    }
    
    if (location.venue.type.length > 0 && [location.venue.provider isEqualToString:@"foursquare"])
        [_iconView loadUri:[NSString stringWithFormat:@"location-venue-icon://type=%@&width=%d&height=%d&color=%d", location.venue.type, 48, 48, TGColorHexCode(pinColor)] withOptions:nil];

    SSignal *addressSignal = [SSignal single:@""];
    if (location.venue.address.length > 0)
    {
        addressSignal = [SSignal single:location.venue.address];
    }
    else
    {
        addressSignal = [[[TGLocationSignals reverseGeocodeCoordinate:CLLocationCoordinate2DMake(location.latitude, location.longitude)] map:^id(TGLocationReverseGeocodeResult *result)
        {
            return [result displayAddress];
        }] catch:^SSignal *(__unused id error)
        {
            return [SSignal single:[TGLocationUtils stringForCoordinate:CLLocationCoordinate2DMake(location.latitude, location.longitude)]];
        }];
        addressSignal = [[SSignal single:TGLocalized(@"Map.Locating")] then:addressSignal];
    }
    
    CLLocation *pointLocation = [[CLLocation alloc] initWithLatitude:location.latitude longitude:location.longitude];

    if (_addressDisposable == nil)
        _addressDisposable = [[SMetaDisposable alloc] init];
    
    SSignal *updatedLocationSignal = [userLocationSignal reduceLeftWithPassthrough:nil with:^id(CLLocation *previous, CLLocation *next, void (^emit)(id))
    {
        if (next == nil)
            return nil;
        
        if (previous == nil && next != nil)
        {
            emit(@{@"location":next, @"update":@true});
            return next;
        }
        else
        {
            bool update = [next distanceFromLocation:previous] > 100;
            emit(@{@"location":next, @"update":@(update)});
            return update ? next : previous;
        }
    }];
    
    SSignal *signal = [[SSignal combineSignals:@[addressSignal, updatedLocationSignal] withInitialStates:@[ TGLocalized(@"Map.Locating"), [NSNull null] ]] mapToSignal:^SSignal *(NSArray *results)
    {
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        dict[@"address"] = results.firstObject;
        
        if (![results.lastObject isKindOfClass:[NSNull class]])
        {
            CLLocation *newLocation = ((NSDictionary *)results.lastObject)[@"location"];
            bool updateEta = [((NSDictionary *)results.lastObject)[@"update"] boolValue];
            dict[@"distance"] = @([pointLocation distanceFromLocation:newLocation]);
            
            if (updateEta)
            {
                return [[SSignal single:dict] then:[[TGLocationSignals driveEta:pointLocation.coordinate] map:^id(NSNumber *eta)
                {
                    NSMutableDictionary *newDict = [dict mutableCopy];
                    newDict[@"eta"] = eta;
                    return newDict;
                }]];
            }
        }
        
        return [SSignal single:dict];
    }];
    
    __weak TGLocationInfoCell *weakSelf = self;
    [_addressDisposable setDisposable:[[signal deliverOn:[SQueue mainQueue]] startWithNext:^(NSDictionary *next)
    {
        __strong TGLocationInfoCell *strongSelf = weakSelf;
        if (strongSelf != nil)
        {
            NSString *address = next[@"address"];
            CGFloat distanceValue = [next[@"distance"] doubleValue];
            NSString *distance = next[@"distance"] ? [NSString stringWithFormat:TGLocalized(@"Map.DistanceAway"), [TGLocationUtils stringFromDistance:distanceValue]] : nil;
            if (next[@"distance"] != nil && distanceValue < 10)
                distance = TGLocalized(@"Map.YouAreHere");
            
            if (next[@"eta"] != nil)
                [strongSelf setDrivingETA:[next[@"eta"] doubleValue]];
            
            NSMutableArray *components = [[NSMutableArray alloc] init];
            if (address.length > 0)
                [components addObject:address];
            if (distance.length > 0)
                [components addObject:distance];
            
            NSString *string = [components componentsJoinedByString:@" • "];
            if ([strongSelf->_addressLabel.text isEqualToString:string])
                return;
            
            if (strongSelf->_addressLabel.text.length == 0)
            {
                strongSelf->_addressLabel.text = string;
            }
            else
            {
                [UIView transitionWithView:strongSelf->_addressLabel duration:0.2 options:UIViewAnimationOptionTransitionCrossDissolve animations:^
                {
                    strongSelf->_addressLabel.text = string;
                } completion:nil];
            }
        }
    }]];
}

- (void)setDrivingETA:(NSTimeInterval)drivingETA
{
    if (drivingETA > 0 && drivingETA < 60 * 60 * 10)
    {
        drivingETA = MAX(drivingETA, 60);
        
        NSInteger minutes = (NSInteger)(drivingETA / 60) % 60;
        NSInteger hours = (NSInteger)(drivingETA / 3600.0f);
        
        NSString *string = nil;
        
        if (hours < 1)
        {
            string = [NSString stringWithFormat:TGLocalized(@"Map.ETAMinutes_any"), [NSString stringWithFormat:@"%d", (int)minutes]];
        }
        else
        {
            if (hours == 1 && minutes == 0)
            {
                string = [NSString stringWithFormat:TGLocalized(@"Map.ETAHours_1"), @"1"];
            }
            else
            {
                string = [NSString stringWithFormat:TGLocalized(@"Map.ETAHours_any"), [NSString stringWithFormat:@"%d:%02d", (int)hours, (int)minutes]];
            }
        }
        
        string = [NSString stringWithFormat:TGLocalized(@"Map.DirectionsDriveEta"), string];
        
        if ([_etaLabel.text isEqualToString:string])
            return;
        
        if (_etaLabel.text.length == 0)
        {
            _etaLabel.text = string;
            [UIView animateWithDuration:0.3 animations:^
            {
                _etaLabel.alpha = 1.0f;
                [self layoutSubviews];
            }];
        }
        else
        {
            [UIView transitionWithView:_etaLabel duration:0.2 options:UIViewAnimationOptionTransitionCrossDissolve animations:^
            {
                _etaLabel.text = string;
            } completion:nil];
        }
    }
}

- (void)setSafeInset:(UIEdgeInsets)safeInset
{
    _safeInset = safeInset;
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    _locateButton.frame = CGRectMake(0.0f, 0.0f, self.frame.size.width, 60.0f);
    _circleView.frame = CGRectMake(12.0f + self.safeInset.left, 12.0f, 48.0f, 48.0f);
    _iconView.frame = _circleView.bounds;
    
    _titleLabel.frame = CGRectMake(76.0f + self.safeInset.left, 15.0f, self.frame.size.width - 76.0f - 12.0f - self.safeInset.left - self.safeInset.right, 20.0f);
    _addressLabel.frame = CGRectMake(76.0f + self.safeInset.left, 38.0f, self.frame.size.width - 76.0f - 12.0f - self.safeInset.left - self.safeInset.right, 20.0f);
    
    _directionsButton.frame = CGRectMake(12.0f + self.safeInset.left, 72.0f, self.frame.size.width - 12.0f * 2.0f - self.safeInset.left - self.safeInset.right, 50.0f);
    
    bool hasEta = _etaLabel.text.length > 0;
    _directionsButtonLabel.frame = CGRectMake(0.0f, hasEta ? 6.0f : 14.0f, _directionsButton.frame.size.width, _directionsButtonLabel.frame.size.height);
    _etaLabel.frame = CGRectMake(0.0f, hasEta ? 25.0f : 20.0f, _directionsButton.frame.size.width, 20.0f);
}

@end
