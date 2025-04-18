#ifndef Telegram_FastBlur_h
#define Telegram_FastBlur_h

#import <Foundation/Foundation.h>

#import <FastBlur/ApplyScreenshotEffect.h>

void imageFastBlur(int imageWidth, int imageHeight, int imageStride, void * _Nonnull pixels);
void telegramFastBlurMore(int imageWidth, int imageHeight, int imageStride, void * _Nonnull pixels);
void stickerThumbnailAlphaBlur(int imageWidth, int imageHeight, int imageStride, void * _Nonnull pixels);
void telegramBrightenImage(int imageWidth, int imageHeight, int imageStride, void * _Nonnull pixels);

#endif
