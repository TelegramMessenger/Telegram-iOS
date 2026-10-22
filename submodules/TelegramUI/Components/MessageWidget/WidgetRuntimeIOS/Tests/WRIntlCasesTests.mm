// widget-sandbox v0.1.1's Intl parity fixture over iOS's ICU, the one the app ships with (v0.1.1 plan, Task 10): the same
// cases and mapping as WidgetRuntime's host IntlCasesTests (Tests/IntlCases.js), against the drift list's `ios` lines.
#import <XCTest/XCTest.h>

#import <WidgetRuntimeIOS/WRSession.h>

@interface WRIntlCasesDelegate : NSObject <WRSessionDelegate>
@end

@implementation WRIntlCasesDelegate
- (void)session:(WRSession*)session diagnostic:(NSString*)kind detail:(NSString*)detail {
}
- (void)session:(WRSession*)session log:(NSInteger)level text:(NSString*)text {
}
- (void)session:(WRSession*)session bridge:(NSString*)method args:(NSString*)argsJson {
}
- (void)session:(WRSession*)session didWork:(uint64_t)totalUnits {
}
@end

@interface WRIntlCasesTests : XCTestCase
@end

@implementation WRIntlCasesTests

- (NSString*)resource:(NSString*)name {
    NSString* path = [[NSBundle bundleForClass:[self class]] pathForResource:name.stringByDeletingPathExtension ofType:name.pathExtension];
    return path ? [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil] : nil;
}

/// The line's id: what precedes " ## ", trailing spaces dropped.
static NSString* idOf(NSString* line) {
    NSRange hash = [line rangeOfString:@" ## "];
    NSString* head = hash.location == NSNotFound ? line : [line substringToIndex:hash.location];
    return [head stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}

- (void)testTheIntlCasesAnswerAsV8 {
    NSString* fixture = [self resource:@"intl-cases.json"];
    NSString* script = [self resource:@"IntlCases.js"];
    NSString* list = [self resource:@"intl-cases-expected-failures.txt"];
    XCTAssertNotNil(fixture);
    XCTAssertNotNil(script);
    XCTAssertNotNil(list);
    WRIntlCasesDelegate* delegate = [WRIntlCasesDelegate new];
    WRSession* session = [[WRSession alloc] initWithWidth:300 dark:NO scale:2 delegate:delegate];
    XCTAssertTrue([session bootWithSource:@"<!doctype html><p>x</p>"]);
    NSData* quoted = [NSJSONSerialization dataWithJSONObject:fixture options:NSJSONWritingFragmentsAllowed error:nil];
    NSString* code = [NSString stringWithFormat:@"window.intlCasesText = %@;\n%@", [[NSString alloc] initWithData:quoted encoding:NSUTF8StringEncoding], script];
    NSString* result = [session evaluateForTesting:code] ?: @"";
    NSMutableSet<NSString*>* expected = [NSMutableSet set];
    for (NSString* line in [list componentsSeparatedByString:@"\n"]) {
        if ([line hasPrefix:@"ios "]) {
            [expected addObject:idOf([line substringFromIndex:4])];
        }
    }
    NSMutableSet<NSString*>* failures = [NSMutableSet set];
    for (NSString* line in [result componentsSeparatedByString:@"\n"]) {
        if (line.length == 0) {
            continue;
        }
        NSString* caseId = idOf(line);
        [failures addObject:caseId];
        XCTAssertTrue([expected containsObject:caseId], @"unexpected: %@", line);
    }
    for (NSString* caseId in expected) {
        XCTAssertTrue([failures containsObject:caseId], @"answers as V8 now (remove it from the list): %@", caseId);
    }
    NSLog(@"intl cases: %lu differ", (unsigned long)failures.count);
}

@end
