#import <Foundation/Foundation.h>

#import <LegacyComponents/TGRootControllerProtocol.h>
#import <LegacyComponents/LegacyComponentsAccessChecker.h>

#import <SSignalKit/SSignalKit.h>

@class TGLocalization;
@class UIViewController;

typedef enum {
    TGAudioSessionTypePlayVoice,
    TGAudioSessionTypePlayMusic,
    TGAudioSessionTypePlayVideo,
    TGAudioSessionTypePlayEmbedVideo,
    TGAudioSessionTypePlayAndRecord,
    TGAudioSessionTypePlayAndRecordHeadphones,
    TGAudioSessionTypeCall
} TGAudioSessionType;

@protocol LegacyComponentsGlobalsProvider <NSObject>

- (TGLocalization *)effectiveLocalization;
- (void)log:(NSString *)format :(va_list)args;
- (UIViewController<TGRootControllerProtocol> *)rootController;
- (NSArray<UIWindow *> *)applicationWindows;
- (UIWindow *)applicationStatusBarWindow;
- (UIWindow *)applicationKeyboardWindow;
- (UIApplication *)applicationInstance;

- (CGRect)statusBarFrame;
- (bool)isStatusBarHidden;
- (void)setStatusBarHidden:(BOOL)hidden withAnimation:(UIStatusBarAnimation)animation;
- (UIStatusBarStyle)statusBarStyle;
- (void)setStatusBarStyle:(UIStatusBarStyle)statusBarStyle animated:(BOOL)animated;
- (void)forceStatusBarAppearanceUpdate;

- (void)disableUserInteractionFor:(NSTimeInterval)timeInterval;
- (void)setIdleTimerDisabled:(bool)value;

- (void)pauseMusicPlayback;

- (NSString *)dataStoragePath;

- (id<LegacyComponentsAccessChecker>)accessChecker;

- (id<SDisposable>)requestAudioSession:(TGAudioSessionType)type interrupted:(void (^)())interrupted;

@end

@interface LegacyComponentsGlobals : NSObject

+ (void)setProvider:(id<LegacyComponentsGlobalsProvider>)provider;
+ (id<LegacyComponentsGlobalsProvider>)provider;

@end

