#import <StringTransliteration/StringTransliteration.h>

NSString *postboxTransformedString(CFStringRef string, bool replaceWithTransliteratedVersion, bool appendTransliteratedVersion) {
    NSMutableString *mutableString = [[NSMutableString alloc] initWithString:(__bridge NSString * _Nonnull)(string)];
    CFStringTransform((CFMutableStringRef)mutableString, NULL, kCFStringTransformStripCombiningMarks, false);
    
    if (replaceWithTransliteratedVersion || appendTransliteratedVersion) {
        NSMutableString *transliteratedString = [[NSMutableString alloc] initWithString:mutableString];
        CFStringTransform((CFMutableStringRef)transliteratedString, NULL, kCFStringTransformToLatin, false);
        if (replaceWithTransliteratedVersion) {
            return transliteratedString;
        } else {
            [mutableString appendString:@" "];
            [mutableString appendString:transliteratedString];
        }
    }
    
    return mutableString;
}
