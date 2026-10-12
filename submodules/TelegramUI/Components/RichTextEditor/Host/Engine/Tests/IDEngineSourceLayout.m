#import "IDEngineSourceLayout.h"

NSString *IDEngineSourceRoot(void) {
    // From THIS file rather than from the caller's `__FILE__`: every scanner then agrees on one
    // root, and a suite that moves within Host/Engine/ does not silently start reading nothing.
    // Host/Engine/Tests/IDEngineSourceLayout.m -> Host/Engine/Tests -> Host/Engine -> Host -> the package.
    NSString *package = [NSString stringWithUTF8String:__FILE__];
    for (NSUInteger level = 0; level < 4; level += 1) {
        package = [package stringByDeletingLastPathComponent];
    }
    return [package stringByAppendingPathComponent:@"Sources/RichTextInputDecUpstream"];
}

/// Host/Engine — where everything that is NOT the shipped engine lives: upstream's demo `App/`, the
/// suites themselves in `Tests/`, `Sources/` (IDTextView), and the contract inventory.
static NSString *IDEngineTestRoot(void) {
    return [[NSString stringWithUTF8String:__FILE__]
        stringByDeletingLastPathComponent].stringByDeletingLastPathComponent;
}

NSString *IDEngineSourceFile(NSString *upstreamRelativePath) {
    NSString *root = IDEngineSourceRoot();
    NSString *rebased = [root stringByAppendingPathComponent:upstreamRelativePath];
    NSFileManager *files = NSFileManager.defaultManager;
    if ([files fileExistsAtPath:rebased]) {
        return rebased;   // every `.m` — this tree keeps upstream's TextView/ and PrivateUIKit/
    }
    NSString *name = upstreamRelativePath.lastPathComponent;
    // An intermediate directory this port flattened: upstream files the autoscroll pair under
    // TextView/Autoscroll/, and the port keeps every `.m` directly under TextView/. Try the first
    // component plus the basename before anything else, so `TextView/Autoscroll/X.m` finds
    // `TextView/X.m`. The ownership audits ENUMERATE and COUNT these, so a miss under-reports the
    // graph rather than merely failing one read.
    NSArray<NSString *> *components = upstreamRelativePath.pathComponents;
    if (components.count > 2) {
        NSString *collapsed = [[root stringByAppendingPathComponent:components.firstObject]
            stringByAppendingPathComponent:name];
        if ([files fileExistsAtPath:collapsed]) {
            return collapsed;
        }
    }
    // A header: flattened on the way in, public to include/ and private to Internal/.
    if ([name.pathExtension isEqualToString:@"h"]) {
        for (NSString *directory in @[@"include", @"Internal"]) {
            NSString *candidate = [[root stringByAppendingPathComponent:directory]
                stringByAppendingPathComponent:name];
            if ([files fileExistsAtPath:candidate]) {
                return candidate;
            }
        }
    }
    // Not the engine at all. `App/` and `Tests/` keep their upstream-relative shape under
    // Host/Engine; the IDTextView family is the exception, upstream-filed under TextView/ and
    // PrivateUIKit/ but living in Host/Engine/Sources here because nothing in Telegram uses it and
    // it must stay out of the shipped module.
    NSString *beside = [IDEngineTestRoot() stringByAppendingPathComponent:upstreamRelativePath];
    if ([files fileExistsAtPath:beside]) {
        return beside;
    }
    NSString *flattened = [[IDEngineTestRoot() stringByAppendingPathComponent:@"Sources"]
        stringByAppendingPathComponent:name];
    if ([files fileExistsAtPath:flattened]) {
        return flattened;
    }
    // The BEHAVIOUR KERNEL. Upstream files it under PrivateUIKit/BehaviorKernel/ beside the rest of
    // its private-UIKit work; here it is a module of its own, RichTextInputDecObjC, with the same
    // flat-header split as the engine. Several ownership audits enumerate its files and count them,
    // so a miss does not merely fail an assertion — it reports a smaller graph than exists.
    NSString *kernel = [[[IDEngineSourceRoot() stringByDeletingLastPathComponent]
        stringByAppendingPathComponent:@"RichTextInputDecObjC"] copy];
    for (NSString *directory in @[@"Kernel", @"include/Kernel", @"Generated", @"Host", @"include",
                                  @"Private"]) {
        NSString *candidate = [[kernel stringByAppendingPathComponent:directory]
            stringByAppendingPathComponent:name];
        if ([files fileExistsAtPath:candidate]) {
            return candidate;
        }
    }
    // The PROJECT DESCRIPTION. Upstream's tests read its generated `project.pbxproj` to assert that
    // an experiment's infrastructure is absent from the project as well as from the source. This
    // repo has no `.xcodeproj` under version control — ours is generated from `Host/project.yml` by
    // xcodegen — so that file IS the equivalent artifact, and an absence check against it carries
    // the same meaning. A project this repo actually builds, rather than one it carries.
    if ([upstreamRelativePath hasSuffix:@"project.pbxproj"]) {
        NSString *ours = [[IDEngineTestRoot() stringByDeletingLastPathComponent]
            stringByAppendingPathComponent:@"project.yml"];
        if ([files fileExistsAtPath:ours]) {
            return ours;
        }
    }
    // Upstream's own README keeps its name under UPSTREAM-README.md here, because this directory
    // has a README of its own describing the import.
    if ([upstreamRelativePath isEqualToString:@"README.md"]) {
        NSString *renamed = [IDEngineTestRoot()
            stringByAppendingPathComponent:@"UPSTREAM-README.md"];
        if ([files fileExistsAtPath:renamed]) {
            return renamed;
        }
    }
    // Unresolvable stays unresolvable — see the header.
    return rebased;
}

BOOL IDIsUpstreamRunArtifactPath(NSString *path) {
    return [path isKindOfClass:NSString.class] && path.length > 0 &&
        [path.pathExtension isEqualToString:@"xcresult"];
}

NSDictionary<NSString *, NSString *> *IDPrivateRuntimeNamesByFunction(void) {
    static NSDictionary<NSString *, NSString *> *names;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *header = [[[IDEngineSourceRoot() stringByDeletingLastPathComponent]
            stringByAppendingPathComponent:@"RichTextInputDecObjC/include"]
            stringByAppendingPathComponent:@"TGPrivateRuntimeNames.h"];
        NSString *source = [NSString stringWithContentsOfFile:header encoding:NSUTF8StringEncoding error:nil] ?: @"";
        NSRegularExpression *entry = [NSRegularExpression
            regularExpressionWithPattern:@"(?m)^TG_PRIVATE_RUNTIME_NAME\\((\\w+), ([^)]*)\\)$" options:0 error:nil];
        NSMutableDictionary<NSString *, NSString *> *result = [NSMutableDictionary dictionary];
        for (NSTextCheckingResult *match in [entry matchesInString:source options:0
                                                             range:NSMakeRange(0, source.length)]) {
            NSString *function = [source substringWithRange:[match rangeAtIndex:1]];
            NSMutableData *bytes = [NSMutableData data];
            for (NSString *token in [[source substringWithRange:[match rangeAtIndex:2]]
                     componentsSeparatedByString:@","]) {
                unsigned int value = 0;
                [[NSScanner scannerWithString:[token stringByTrimmingCharactersInSet:
                    NSCharacterSet.whitespaceCharacterSet]] scanHexInt:&value];
                uint8_t byte = (uint8_t)(value ^ 0x5A);
                [bytes appendBytes:&byte length:1];
            }
            result[function] = [[NSString alloc] initWithData:bytes encoding:NSUTF8StringEncoding];
        }
        names = result.copy;
    });
    return names;
}

NSString *IDNeutralSelectorName(NSString *privateSelectorName) {
    return [@"tgpn_" stringByAppendingString:privateSelectorName];
}
