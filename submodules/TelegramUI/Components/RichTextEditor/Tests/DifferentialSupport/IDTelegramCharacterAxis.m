// NOT VENDORED. Written for Telegram, Task 9c. See `IDTelegramCharacterAxis.h` for the measurement
// this file exists to answer and for why the inverse must not be improvised.
//
// Every function here talks to the input through the PUBLIC `UITextInput` surface only — no
// downcast to a Telegram concrete type, and nothing that a stock `UITextView` does not also answer.
// That is what lets both arms of the differential run the same conversion code.
#import "IDTelegramCharacterAxis.h"

NSNumber *IDTelegramCharacterIndexForPosition(
    id<UITextInput> input, UITextPosition *position) {
    if (input == nil || position == nil) return nil;
    UITextRange *prefix =
        [input textRangeFromPosition:input.beginningOfDocument toPosition:position];
    if (prefix == nil) return nil;
    NSString *text = [input textInRange:prefix];
    if (text == nil) return nil;
    return @(text.length);
}

NSValue *IDTelegramCharacterRangeForTextRange(
    id<UITextInput> input, UITextRange *range) {
    if (range == nil) return [NSValue valueWithRange:NSMakeRange(NSNotFound, 0)];
    NSNumber *start = IDTelegramCharacterIndexForPosition(input, range.start);
    NSNumber *end = IDTelegramCharacterIndexForPosition(input, range.end);
    if (start == nil || end == nil) return nil;
    NSInteger location = start.integerValue;
    NSInteger length = end.integerValue - start.integerValue;
    if (location < 0 || length < 0) return nil;
    return [NSValue valueWithRange:
        NSMakeRange((NSUInteger)location, (NSUInteger)length)];
}

UITextPosition *IDTelegramPositionForCharacterIndex(
    id<UITextInput> input, NSUInteger index) {
    if (input == nil) return nil;
    UITextPosition *current = input.beginningOfDocument;
    if (current == nil) return nil;
    // Step the input's own positions rather than doing offset arithmetic from the beginning of the
    // document: `-positionFromPosition:offset:` adds to the RAW offset and then snaps, which lands
    // one character early past every structural boundary (see the header's measurement). Stepping
    // asks the input to move by one position at a time, so it skips the non-renderable slots exactly
    // as the editor does — and on a `UITextView`, where there are none, it is the identity.
    //
    // The map is monotone and injective over these positions (measured), so the FIRST position whose
    // character index equals `index` is the only one, and the walk terminates at the first index that
    // exceeds the target rather than running to the end.
    NSUInteger guardCounter = 0;
    while (current != nil && guardCounter < 1u << 20) {
        guardCounter += 1;
        NSNumber *at = IDTelegramCharacterIndexForPosition(input, current);
        if (at == nil) return nil;
        if (at.unsignedIntegerValue == index) return current;
        if (at.unsignedIntegerValue > index) return nil;   // stepped past it: unreachable
        UITextPosition *next = [input positionFromPosition:current offset:1];
        if (next == nil ||
            [input comparePosition:next toPosition:current] == NSOrderedSame) {
            return nil;                                    // end of document, or no progress
        }
        current = next;
    }
    return nil;
}

UITextRange *IDTelegramTextRangeForCharacterRange(
    id<UITextInput> input, NSRange range) {
    if (range.location == NSNotFound) return nil;
    UITextPosition *start = IDTelegramPositionForCharacterIndex(input, range.location);
    if (start == nil) return nil;
    if (range.length == 0) return [input textRangeFromPosition:start toPosition:start];
    UITextPosition *end =
        IDTelegramPositionForCharacterIndex(input, NSMaxRange(range));
    if (end == nil) return nil;
    return [input textRangeFromPosition:start toPosition:end];
}
