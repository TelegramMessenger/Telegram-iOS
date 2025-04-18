#ifndef StringTransliteration_h
#define StringTransliteration_h

#import <Foundation/Foundation.h>

NSString *postboxTransformedString(CFStringRef string, bool replaceWithTransliteratedVersion, bool appendTransliteratedVersion);

#endif
