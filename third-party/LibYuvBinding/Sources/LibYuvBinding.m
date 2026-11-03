#include <LibYuvBinding/LibYuvBinding.h>

#include "libyuv/convert_from.h"

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
) {
	return I420ToNV12(
		src_y,
		src_stride_y,
		src_u,
		src_stride_u,
		src_v,
		src_stride_v,
		dst_y,
		dst_stride_y,
		dst_uv,
		dst_stride_uv,
		width,
		height
	) == 0;
}
