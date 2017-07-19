#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    TGPluralFormZero,
    TGPluralFormOne,
    TGPluralFormTwo,
    TGPluralFormFew,
    TGPluralFormMany,
    TGPluralFormOther
} TGPluralFormValue;
    
TGPluralFormValue TGPluralForm(unsigned int, int n);

#ifdef __cplusplus
}
#endif
