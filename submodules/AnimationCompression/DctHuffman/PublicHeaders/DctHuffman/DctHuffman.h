#ifndef DctHuffman_h
#define DctHuffman_h

#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

NSData * _Nullable writeDCTBlocks(int width, int height, float const * _Nonnull coefficients);
void readDCTBlocks(int width, int height, NSData * _Nonnull blockData, float * _Nonnull coefficients, int elementsPerRow);

#ifdef __cplusplus
}
#endif

#endif /* DctHuffman_h */
