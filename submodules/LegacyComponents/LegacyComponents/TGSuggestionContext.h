#import <Foundation/Foundation.h>

@class SSignal;

@interface TGSuggestionContext : NSObject

@property (nonatomic, copy) SSignal *(^userListSignal)(NSString *mention);
@property (nonatomic, copy) SSignal *(^hashtagListSignal)(NSString *hashtag);
@property (nonatomic, copy) SSignal *(^alphacodeSignal)(NSString *alphacode, NSString *languageCode);

@end
