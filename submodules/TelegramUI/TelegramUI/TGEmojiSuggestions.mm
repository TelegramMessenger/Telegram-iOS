#import "TGEmojiSuggestions.h"

#import "emoji_suggestions.h"

#import <LegacyComponents/TGAlphacode.h>

std::vector<Ui::Emoji::utf16char> convertToUtf16(NSString *string) {
    auto cf = (__bridge CFStringRef)string;
    auto range = CFRangeMake(0, CFStringGetLength(cf));
    auto bufferLength = CFIndex(0);
    CFStringGetBytes(cf, range, kCFStringEncodingUTF16LE, 0, FALSE, nullptr, 0, &bufferLength);
    if (!bufferLength) {
        return std::vector<Ui::Emoji::utf16char>();
    }
    auto result = std::vector<Ui::Emoji::utf16char>(bufferLength / 2 + 1, 0);
    CFStringGetBytes(cf, range, kCFStringEncodingUTF16LE, 0, FALSE, reinterpret_cast<UInt8*>(result.data()), result.size() * 2, &bufferLength);
    result.resize(bufferLength / 2);
    return result;
}

NSString *convertFromUtf16(Ui::Emoji::utf16string string) {
    auto result = CFStringCreateWithBytes(nullptr, reinterpret_cast<const UInt8*>(string.data()), string.size() * 2, kCFStringEncodingUTF16LE, false);
    return (__bridge NSString*)result;
}

void test() {
    
}

@implementation TGEmojiSuggestions

+ (NSArray *)suggestionsForQuery:(NSString *)queryText {
    auto query = convertToUtf16(queryText);
    auto values = Ui::Emoji::GetSuggestions(Ui::Emoji::utf16string(query.data(), query.size()));
    
    NSMutableArray *array = [[NSMutableArray alloc] init];
    
    for (auto &item : values) {
        NSString *emoji = convertFromUtf16(item.emoji());
        NSString *label = convertFromUtf16(item.label());
        NSString *replacement = convertFromUtf16(item.replacement());
        
        [array addObject:[[TGAlphacodeEntry alloc] initWithEmoji:emoji code:replacement]];
    }
    
    return array;
}

@end
