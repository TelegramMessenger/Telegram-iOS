#import <Foundation/Foundation.h>

@class TGInterfaceController;

@interface TGInputController : NSObject

+ (void)presentPlainInputControllerForInterfaceController:(TGInterfaceController *)interfaceController completion:(void (^)(NSString *))completion;
+ (void)presentInputControllerForInterfaceController:(TGInterfaceController *)interfaceController suggestionsForText:(NSString *)text completion:(void (^)(NSString *))completion;
+ (void)presentAudioControllerForInterfaceController:(TGInterfaceController *)interfaceController completion:(void (^)(int64_t uniqueId, int32_t duration, NSURL *url))completion;

+ (NSArray *)suggestionsForText:(NSString *)text;

@end
