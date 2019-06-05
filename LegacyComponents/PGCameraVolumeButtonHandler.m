#import "PGCameraVolumeButtonHandler.h"

#import "LegacyComponentsInternal.h"

#import "TGStringUtils.h"
#import "Freedom.h"

@interface PGCameraVolumeButtonHandler ()

@property (nonatomic, copy) void(^upButtonPressedBlock)(void);
@property (nonatomic, copy) void(^upButtonReleasedBlock)(void);
@property (nonatomic, copy) void(^downButtonPressedBlock)(void);
@property (nonatomic, copy) void(^downButtonReleasedBlock)(void);

@end

@implementation PGCameraVolumeButtonHandler

- (instancetype)initWithUpButtonPressedBlock:(void (^)(void))upButtonPressedBlock upButtonReleasedBlock:(void (^)(void))upButtonReleasedBlock downButtonPressedBlock:(void (^)(void))downButtonPressedBlock downButtonReleasedBlock:(void (^)(void))downButtonReleasedBlock
{
    self = [super init];
    if (self != nil)
    {
        self.upButtonPressedBlock = upButtonPressedBlock;
        self.upButtonReleasedBlock = upButtonReleasedBlock;
        self.downButtonPressedBlock = downButtonPressedBlock;
        self.downButtonReleasedBlock = downButtonReleasedBlock;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleNotification:) name:nil object:nil];
     
        self.enabled = true;
    }
    return self;
}

- (void)dealloc
{
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
    if (nameLength == 46 || nameLength == 44 || nameLength == 42)
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
