#import "TGLocationAnnotation.h"

#import "TGLocationMediaAttachment.h"

@interface TGLocationAnnotation ()
{
    CLLocationCoordinate2D _coordinate;
    NSMutableSet *_observers;
}
@end

@implementation TGLocationAnnotation

- (void)addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options context:(void *)context
{
    NSString *observerId = [NSString stringWithFormat:@"%lu%@", observer.hash, keyPath];
    [_observers addObject:observerId];
    
    [super addObserver:observer forKeyPath:keyPath options:options context:context];
}

- (void)removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath
{
    NSString *observerId = [NSString stringWithFormat:@"%lu%@", observer.hash, keyPath];
    if ([_observers containsObject:observerId])
    {
        [_observers removeObject:observerId];
        [super removeObserver:observer forKeyPath:keyPath];
    }
}

- (instancetype)initWithLocation:(TGLocationMediaAttachment *)location
{
    return [self initWithLocation:location color:nil];
}

- (instancetype)initWithLocation:(TGLocationMediaAttachment *)location color:(UIColor *)color
{
    self = [super init];
    if (self != nil)
    {
        _coordinate = CLLocationCoordinate2DMake(location.latitude, location.longitude);
        _color = color;
        _location = location;
        _observers = [[NSMutableSet alloc] init];
    }
    return self;
}

- (NSString *)title
{
    return @"";
}

- (NSString *)subtitle
{
    return @"";
}

- (CLLocationCoordinate2D)coordinate
{
    return _coordinate;
}

- (void)setCoordinate:(CLLocationCoordinate2D)newCoordinate
{
    if (fabs(newCoordinate.latitude - _coordinate.latitude) > DBL_EPSILON || fabs(newCoordinate.longitude - _coordinate.longitude) > DBL_EPSILON)
    {
        [self willChangeValueForKey:@"coordinate"];
        _coordinate = newCoordinate;
        [self didChangeValueForKey:@"coordinate"];
    }
}

- (void)setIsExpired:(bool)isExpired
{
    if (isExpired != _isExpired)
    {
        [self willChangeValueForKey:@"isExpired"];
        _isExpired = isExpired;
        [self didChangeValueForKey:@"isExpired"];
    }
}

- (void)setHasSession:(bool)hasSession
{
    if (hasSession != _hasSession)
    {
        [self willChangeValueForKey:@"hasSession"];
        _hasSession = hasSession;
        [self didChangeValueForKey:@"hasSession"];
    }
}

- (bool)isLiveLocation
{
    return _location.period > 0;
}

@end


@interface TGLocationPickerAnnotation ()
{
    CLLocationCoordinate2D _coordinate;
    NSMutableSet *_observers;
}
@end

@implementation TGLocationPickerAnnotation

- (instancetype)initWithCoordinate:(CLLocationCoordinate2D)coordinate
{
    self = [super init];
    if (self != nil)
    {
        _coordinate = coordinate;
        _observers = [[NSMutableSet alloc] init];
    }
    return self;
}

- (void)addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options context:(void *)context
{
    NSString *observerId = [NSString stringWithFormat:@"%lu%@", observer.hash, keyPath];
    [_observers addObject:observerId];
    
    [super addObserver:observer forKeyPath:keyPath options:options context:context];
}

- (void)removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath
{
    NSString *observerId = [NSString stringWithFormat:@"%lu%@", observer.hash, keyPath];
    if ([_observers containsObject:observerId])
    {
        [_observers removeObject:observerId];
        [super removeObserver:observer forKeyPath:keyPath];
    }
}


- (CLLocationCoordinate2D)coordinate
{
    return _coordinate;
}

- (void)setCoordinate:(CLLocationCoordinate2D)newCoordinate
{
    if (fabs(newCoordinate.latitude - _coordinate.latitude) > DBL_EPSILON || fabs(newCoordinate.longitude - _coordinate.longitude) > DBL_EPSILON)
    {
        [self willChangeValueForKey:@"coordinate"];
        _coordinate = newCoordinate;
        [self didChangeValueForKey:@"coordinate"];
    }
}

@end
