#ifndef LIBYUV_BINDING_H
#define LIBYUV_BINDING_H

#import <Foundation/Foundation.h>

bool libyuv_I420ToNV12(
	const uint8_t* src_y,
	int src_stride_y,
	const uint8_t* src_u,
	int src_stride_u,
	const uint8_t* src_v,
	int src_stride_v,
	uint8_t* dst_y,
	int dst_stride_y,
	uint8_t* dst_uv,
	int dst_stride_uv,
	int width,
	int height
);

#endif
