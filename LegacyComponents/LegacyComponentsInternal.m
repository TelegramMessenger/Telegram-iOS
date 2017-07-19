#import "LegacyComponentsInternal.h"

#import "TGLocalization.h"

TGLocalization *effectiveLocalization() {
    return [[LegacyComponentsGlobals provider] effectiveLocalization];
}

NSString *TGLocalized(NSString *s) {
    return [effectiveLocalization() get:s];
}

bool TGObjectCompare(id obj1, id obj2) {
    if (obj1 == nil && obj2 == nil)
        return true;
    
    return [obj1 isEqual:obj2];
}

bool TGStringCompare(NSString *s1, NSString *s2) {
    if (s1.length == 0 && s2.length == 0)
        return true;
    
    if ((s1 == nil) != (s2 == nil))
        return false;
    
    return s1 == nil || [s1 isEqualToString:s2];
}

void TGLog(NSString *format, ...)
{
    va_list L;
    va_start(L, format);
    [[LegacyComponentsGlobals provider] log:format :L];
    va_end(L);
}
