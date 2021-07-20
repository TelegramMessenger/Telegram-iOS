#import <Foundation/Foundation.h>

typedef NS_ENUM(int32_t, StringPluralizationForm) {
    StringPluralizationFormZero,
    StringPluralizationFormOne,
    StringPluralizationFormTwo,
    StringPluralizationFormFew,
    StringPluralizationFormMany,
    StringPluralizationFormOther
};

StringPluralizationForm getStringPluralizationForm(unsigned int lc, int n);
