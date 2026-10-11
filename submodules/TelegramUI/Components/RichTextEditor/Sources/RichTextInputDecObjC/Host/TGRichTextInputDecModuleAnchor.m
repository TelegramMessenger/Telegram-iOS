// Always compiled, on every platform, so the macOS object file for this target is never
// empty (`swift test` builds the package for arm64-apple-macosx).
#import <Foundation/Foundation.h>

void TGRichTextInputDecModuleAnchor(void);
void TGRichTextInputDecModuleAnchor(void) {}
