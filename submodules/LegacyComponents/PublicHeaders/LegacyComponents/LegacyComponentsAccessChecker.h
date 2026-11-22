#import <Foundation/Foundation.h>

typedef enum {
    TGPhotoAccessIntentRead,
    TGPhotoAccessIntentSave,
    TGPhotoAccessIntentCustomWallpaper
} TGPhotoAccessIntent;

typedef enum {
    TGMicrophoneAccessIntentVoice,
    TGMicrophoneAccessIntentVideo,
    TGMicrophoneAccessIntentCall,
    TGMicrophoneAccessIntentVideoMessage
} TGMicrophoneAccessIntent;

typedef enum {
    TGCameraAccessIntentDefault,
    TGCameraAccessIntentVideoMessage
} TGCameraAccessIntent;

typedef enum {
    TGLocationAccessIntentSend,
    TGLocationAccessIntentTracking,
    TGLocationAccessIntentLiveLocation
} TGLocationAccessIntent;

@protocol LegacyComponentsAccessChecker <NSObject>

- (bool)checkPhotoAuthorizationStatusForIntent:(TGPhotoAccessIntent)intent alertDismissCompletion:(void (^)(void))alertDismissCompletion;

- (bool)checkMicrophoneAuthorizationStatusForIntent:(TGMicrophoneAccessIntent)intent alertDismissCompletion:(void (^)(void))alertDismissCompletion;

- (bool)checkCameraAuthorizationStatusForIntent:(TGCameraAccessIntent)intent completion:(void (^)(BOOL))completion alertDismissCompletion:(void (^)(void))alertDismissCompletion;

@end
