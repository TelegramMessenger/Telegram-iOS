#import <Foundation/Foundation.h>

typedef NS_ENUM(int32_t, NumberPluralizationForm) {
    NumberPluralizationFormZero,
    NumberPluralizationFormOne,
    NumberPluralizationFormTwo,
    NumberPluralizationFormFew,
    NumberPluralizationFormMany,
    NumberPluralizationFormOther
};

NumberPluralizationForm numberPluralizationForm(unsigned int lc, int n);

NSString * _Nonnull formatNumberWithGroupingSeparator(NSString * _Nonnull groupingSeparator, int32_t value);
