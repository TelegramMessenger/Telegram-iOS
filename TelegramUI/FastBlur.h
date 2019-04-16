#ifndef Telegram_FastBlur_h
#define Telegram_FastBlur_h

#import <Foundation/Foundation.h>

void telegramFastBlur(int imageWidth, int imageHeight, int imageStride, void *pixels);
void telegramFastBlurMore(int imageWidth, int imageHeight, int imageStride, void *pixels);
void stickerThumbnailAlphaBlur(int imageWidth, int imageHeight, int imageStride, void *pixels);
void telegramBrightenImage(int imageWidth, int imageHeight, int imageStride, void *pixels);

#endif
