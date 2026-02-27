#ifndef CallsEmoji_h
#define CallsEmoji_h

#import <Foundation/Foundation.h>

NSString *randomCallsEmoji();
NSData *dataForEmojiRawKey(NSData *data);
NSArray<NSString *> *stringForEmojiHashOfData(NSData *data, NSInteger count);

#endif /* CallsEmoji_h */
