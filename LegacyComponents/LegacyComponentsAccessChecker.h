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

- (bool)checkAddressBookAuthorizationStatusWithAlertDismissComlpetion:(void (^)(void))alertDismissCompletion;

- (bool)checkPhotoAuthorizationStatusForIntent:(TGPhotoAccessIntent)intent alertDismissCompletion:(void (^)(void))alertDismissCompletion;

- (bool)checkMicrophoneAuthorizationStatusForIntent:(TGMicrophoneAccessIntent)intent alertDismissCompletion:(void (^)(void))alertDismissCompletion;

- (bool)checkCameraAuthorizationStatusForIntent:(TGCameraAccessIntent)intent alertDismissCompletion:(void (^)(void))alertDismissCompletion;

- (bool)checkLocationAuthorizationStatusForIntent:(TGLocationAccessIntent)intent alertDismissComlpetion:(void (^)(void))alertDismissCompletion;

@end
