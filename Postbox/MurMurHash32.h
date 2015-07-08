#ifndef Postbox_MurMurHash32_h
#define Postbox_MurMurHash32_h

#import <stdint.h>

int32_t murMurHash32(void *bytes, int length);
int32_t murMurHashString32(const char *s);

#endif
