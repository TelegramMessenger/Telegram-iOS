#ifndef __PSData_h
#define __PSData_h

typedef struct
{
    uint8_t *data;
    NSUInteger length;
} PSData;

typedef PSData PSConstData;

#define PSDataOffset(d, offset) {d.data += offset; d.length -= offset;}

#endif
