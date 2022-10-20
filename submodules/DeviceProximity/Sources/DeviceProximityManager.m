#import <DeviceProximity/DeviceProximityManager.h>

#import <UIKit/UIKit.h>

#import "DeviceProximityBag.h"

@interface DeviceProximityManager () {
    DeviceProximityBag *_subscribers;
    bool _proximityState;
    bool _globallyEnabled;
}

@end

@implementation DeviceProximityManager

+ (DeviceProximityManager * _Nonnull)shared {
    static DeviceProximityManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[DeviceProximityManager alloc] init];
    });
    return instance;
}

- (bool)currentValue {
    return _proximityState;
}

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        _subscribers = [[DeviceProximityBag alloc] init];
        
        __weak DeviceProximityManager *weakSelf = self;
        [[NSNotificationCenter defaultCenter] addObserverForName:UIDeviceProximityStateDidChangeNotification object:[UIDevice currentDevice] queue:[NSOperationQueue mainQueue] usingBlock:^(__unused NSNotification *notification)
         {
             __strong DeviceProximityManager *strongSelf = weakSelf;
             if (strongSelf != nil) {
                 bool proximityState = [UIDevice currentDevice].proximityState;
                 if (strongSelf->_proximityState != proximityState) {
                     strongSelf->_proximityState = proximityState;
                     if (!strongSelf->_proximityState && [strongSelf->_subscribers isEmpty]) {
                         [UIDevice currentDevice].proximityMonitoringEnabled = false;
                     }
                     for (void (^f)(bool) in [strongSelf->_subscribers copyItems]) {
                         f(proximityState);
                     }
                 } else if (!strongSelf->_proximityState && [strongSelf->_subscribers isEmpty]) {
                     [UIDevice currentDevice].proximityMonitoringEnabled = false;
                 }
             }
         }];
    }
    return self;
}

- (void)setGloballyEnabled:(bool)value {
    if (_globallyEnabled != value) {
        _globallyEnabled = value;
        
        [self updateState:![_subscribers isEmpty] globallyEnabled:_globallyEnabled];
    }
}

- (NSInteger)add:(void (^)(bool))f {
    bool wasEmpty = [_subscribers isEmpty];
    NSInteger index = [_subscribers addItem:[f copy]];
    f(_proximityState);
    if (wasEmpty) {
        [self updateState:true globallyEnabled:_globallyEnabled];
    }
    return index;
}

- (void)remove:(NSInteger)index {
    bool wasEmpty = [_subscribers isEmpty];
    [_subscribers removeItem:index];
    if ([_subscribers isEmpty] && !wasEmpty) {
        [self updateState:false globallyEnabled:_globallyEnabled];
    }
}

- (void)updateState:(bool)hasSubscribers globallyEnabled:(bool)globallyEnabled {
    if (hasSubscribers && globallyEnabled) {
        [UIDevice currentDevice].proximityMonitoringEnabled = true;
        bool deviceProximityState = [UIDevice currentDevice].proximityState;
        if (deviceProximityState != _proximityState) {
            _proximityState = deviceProximityState;
            for (void (^f)(bool) in [_subscribers copyItems]) {
                f(_proximityState);
            }
        }
    } else {
        if (_proximityState) {
            _proximityState = false;
            for (void (^f)(bool) in [_subscribers copyItems]) {
                f(_proximityState);
            }
        } else {
            [UIDevice currentDevice].proximityMonitoringEnabled = false;
        }
    }
}

@end
