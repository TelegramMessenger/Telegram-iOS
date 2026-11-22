#import <LegacyComponents/PGCameraVolumeButtonHandler.h>

#import "LegacyComponentsInternal.h"

#import <LegacyComponents/TGStringUtils.h>
#import <LegacyComponents/Freedom.h>

#import <AVKit/AVKit.h>

static NSString *encodeText(NSString *string, int key) {
    NSMutableString *result = [[NSMutableString alloc] init];
    
    for (int i = 0; i < (int)[string length]; i++) {
        unichar c = [string characterAtIndex:i];
        c += key;
        [result appendString:[NSString stringWithCharacters:&c length:1]];
    }
    
    return result;
}

@interface PGCameraVolumeButtonHandler () {
    id _dataSource;
    id<UIInteraction> _eventInteraction;
}

@property (nonatomic, weak) UIView *eventView;

@property (nonatomic, copy) void(^upButtonPressedBlock)(void);
@property (nonatomic, copy) void(^upButtonReleasedBlock)(void);
@property (nonatomic, copy) void(^downButtonPressedBlock)(void);
@property (nonatomic, copy) void(^downButtonReleasedBlock)(void);

@end

@implementation PGCameraVolumeButtonHandler

- (instancetype)initWithIsCameraSpecific:(bool)isCameraSpecific eventView:(UIView *)eventView upButtonPressedBlock:(void (^)(void))upButtonPressedBlock upButtonReleasedBlock:(void (^)(void))upButtonReleasedBlock downButtonPressedBlock:(void (^)(void))downButtonPressedBlock downButtonReleasedBlock:(void (^)(void))downButtonReleasedBlock
{
    self = [super init];
    if (self != nil)
    {
        self.eventView = eventView;
        
        self.upButtonPressedBlock = upButtonPressedBlock;
        self.upButtonReleasedBlock = upButtonReleasedBlock;
        self.downButtonPressedBlock = downButtonPressedBlock;
        self.downButtonReleasedBlock = downButtonReleasedBlock;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleNotification:) name:nil object:nil];
     
        self.enabled = true;
        
        if (@available(iOS 17.2, *)) {
            if (isCameraSpecific) {
                __weak PGCameraVolumeButtonHandler *weakSelf = self;
                AVCaptureEventInteraction *interaction = [[AVCaptureEventInteraction alloc] initWithPrimaryEventHandler:^(AVCaptureEvent * _Nonnull event) {
                    __strong PGCameraVolumeButtonHandler *strongSelf = weakSelf;
                    switch (event.phase) {
                        case AVCaptureEventPhaseBegan:
                            strongSelf.downButtonPressedBlock();
                            break;
                        case AVCaptureEventPhaseEnded:
                            strongSelf.downButtonReleasedBlock();
                            break;
                        case AVCaptureEventPhaseCancelled:
                            strongSelf.downButtonReleasedBlock();
                            break;
                        default:
                            break;
                    }
                } secondaryEventHandler:^(AVCaptureEvent * _Nonnull event) {
                    __strong PGCameraVolumeButtonHandler *strongSelf = weakSelf;
                    switch (event.phase) {
                        case AVCaptureEventPhaseBegan:
                            strongSelf.upButtonPressedBlock();
                            break;
                        case AVCaptureEventPhaseEnded:
                            strongSelf.upButtonReleasedBlock();
                            break;
                        case AVCaptureEventPhaseCancelled:
                            strongSelf.upButtonReleasedBlock();
                            break;
                        default:
                            break;
                    }
                }];
                interaction.enabled = true;
                [eventView addInteraction:interaction];
                _eventInteraction = interaction;
            } else {
                NSString *className = encodeText(@"NQWpmvnfDpouspmmfsTztufnEbubTpvsdf", -1);
                Class c = NSClassFromString(className);
                _dataSource = [[c alloc] init];
            }
        }
    }
    return self;
}

- (void)dealloc
{
    if (_eventInteraction != nil) {
        [self.eventView removeInteraction:_eventInteraction];
    }
    
    self.enabled = false;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark -

static void PGButtonHandlerEnableMonitoring(bool enable)
{
    static void (*methodImpl)(id, SEL, BOOL) = NULL;
    static dispatch_once_t onceToken;
    static SEL methodSelector = NULL;
    dispatch_once(&onceToken, ^
    {
        methodImpl = (void (*)(id, SEL, BOOL))freedomImplInstancesOfClass([UIApplication class], 0xf8de0049, NULL);
    });
    
    if (methodImpl != NULL) {
        methodImpl([[LegacyComponentsGlobals provider] applicationInstance], methodSelector, enable);
    }
}

#pragma mark -

- (void)handleNotification:(NSNotification *)notification
{
    NSUInteger nameLength = notification.name.length;
    if (nameLength == 46 || nameLength == 44 || nameLength == 42 || nameLength == 21)
    {
        uint32_t hash = legacy_murMurHash32(notification.name);
        switch (hash)
        {
            case 0xaeae3258: //_UIApplicationVolumeDownButtonDownNotification
            {
                if (self.downButtonPressedBlock != nil)
                    self.downButtonPressedBlock();
            }
                break;
                
            case 0x784c165e: //_UIApplicationVolumeDownButtonUpNotification
            {
                if (self.downButtonReleasedBlock != nil)
                    self.downButtonReleasedBlock();
            }
                break;
                
            case 0xba416d8e: //_UIApplicationVolumeUpButtonDownNotification
            {
                if (self.upButtonPressedBlock != nil)
                    self.upButtonPressedBlock();
            }
                break;
                
            case 0x4074ecfb: //_UIApplicationVolumeUpButtonUpNotification
            {
                if (self.upButtonReleasedBlock != nil)
                    self.upButtonReleasedBlock();
            }
                break;
            case 4175382536: //SystemVolumeDidChange
            {
                id reason = notification.userInfo[@"Reason"];
                if (reason && [@"ExplicitVolumeChange" isEqual:reason]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (self.upButtonPressedBlock != nil) {
                            self.upButtonPressedBlock();
                        }
                    });
                }
                break;
            }
                
            default:
                break;
        }
    }
}

#pragma mark -

- (void)setEnabled:(bool)enabled
{
    _enabled = enabled;
    TGDispatchOnMainThread(^{
        PGButtonHandlerEnableMonitoring(enabled);
    });
}

- (void)enableIn:(NSTimeInterval)timeInterval
{
    if (_enabled)
        return;
    
    TGDispatchAfter(timeInterval, dispatch_get_main_queue(), ^
    {
        [self setEnabled:true];
    });
}

- (void)disableFor:(NSTimeInterval)timeInterval
{
    if (!_enabled)
        return;
    
    TGDispatchAfter(timeInterval, dispatch_get_main_queue(), ^
    {
        _enabled = true;
    });
}

- (void)ignoreEventsFor:(NSTimeInterval)timeInterval andDisable:(bool)disable
{
    if (!self.enabled)
        return;
    
    _ignoring = true;
    
    [self performSelector:@selector(_ignoreFinished:) withObject:@(disable) afterDelay:timeInterval];
}

- (void)_ignoreFinished:(NSNumber *)disable
{
    _ignoring = false;
    
    if (disable.boolValue)
        self.enabled = false;
}

@end
