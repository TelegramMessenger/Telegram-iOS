#ifndef __PICTURE_H
#define __PICTURE_H

#include <ogg/ogg.h>

typedef enum{
  PIC_FORMAT_JPEG,
  PIC_FORMAT_PNG,
  PIC_FORMAT_GIF
}picture_format;

#define BASE64_LENGTH(len) (((len)+2)/3*4)

/*Utility function for base64 encoding METADATA_BLOCK_PICTURE tags.
  Stores BASE64_LENGTH(len)+1 bytes in dst (including a terminating NUL).*/
void base64_encode(char *dst, const char *src, int len);

int oi_strncasecmp(const char *a, const char *b, int n);

int is_jpeg(const unsigned char *buf, size_t length);
int is_png(const unsigned char *buf, size_t length);
int is_gif(const unsigned char *buf, size_t length);

void extract_png_params(const unsigned char *data, size_t data_length,
                        ogg_uint32_t *width, ogg_uint32_t *height,
                        ogg_uint32_t *depth, ogg_uint32_t *colors,
                        int *has_palette);
void extract_gif_params(const unsigned char *data, size_t data_length,
                        ogg_uint32_t *width, ogg_uint32_t *height,
                        ogg_uint32_t *depth, ogg_uint32_t *colors,
                        int *has_palette);
void extract_jpeg_params(const unsigned char *data, size_t data_length,
                         ogg_uint32_t *width, ogg_uint32_t *height,
                         ogg_uint32_t *depth, ogg_uint32_t *colors,
                         int *has_palette);

char *parse_picture_specification(const char *spec,
                                  const char **error_message,
                                  int *seen_file_icons);

#define WRITE_U32_BE(buf, val) \
  do{ \
    (buf)[0]=(unsigned char)((val)>>24); \
    (buf)[1]=(unsigned char)((val)>>16); \
    (buf)[2]=(unsigned char)((val)>>8); \
    (buf)[3]=(unsigned char)(val); \
  } \
  while(0);

#endif /* __PICTURE_H */
