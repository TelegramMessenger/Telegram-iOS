#import "TryCatchCpp.h"

void tryCatchCpp(void (^block)()) {
    try {
        block();
    } catch(...) {
    }
}