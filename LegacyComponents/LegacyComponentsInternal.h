#import "LegacyComponentsGlobals.h"

@class TGLocalization;

#ifdef __cplusplus
extern "C" {
#endif
    
TGLocalization *effectiveLocalization();
NSString *TGLocalized(NSString *s);
bool TGObjectCompare(id obj1, id obj2);
bool TGStringCompare(NSString *s1, NSString *s2);
void TGLog(NSString *format, ...);
    
#ifdef __cplusplus
}
#endif

