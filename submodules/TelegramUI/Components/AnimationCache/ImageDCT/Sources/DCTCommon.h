#ifndef DCT_COMMON_H
#define DCT_COMMON_H

#ifdef __cplusplus
extern "C" {
#endif

typedef short DCTELEM;

typedef short JCOEF;
typedef JCOEF *JCOEFPTR;

typedef unsigned char JSAMPLE;
typedef JSAMPLE *JSAMPROW;

struct DctAuxiliaryData;
struct DctAuxiliaryData *createDctAuxiliaryData();
void freeDctAuxiliaryData(struct DctAuxiliaryData *data);

void dct_jpeg_idct_ifast(struct DctAuxiliaryData *auxiliaryData, void *dct_table, JCOEFPTR coef_block, JSAMPROW output_buf);
void dct_jpeg_fdct_ifast(DCTELEM *data);

#ifdef __cplusplus
}
#endif

#endif
