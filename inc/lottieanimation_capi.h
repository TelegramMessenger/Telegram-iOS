#ifndef _LOTTIE_ANIMATION_CAPI_H_
#define _LOTTIE_ANIMATION_CAPI_H_

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>
#include <lottiecommon.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct Lottie_Animation_S Lottie_Animation;

LOT_EXPORT Lottie_Animation *lottie_animation_from_file(const char *file);
LOT_EXPORT Lottie_Animation *lottie_animation_from_data(const char *data, const char *key);
LOT_EXPORT void lottie_animation_destroy(Lottie_Animation *animation);
LOT_EXPORT void lottie_animation_get_size(const Lottie_Animation *animation, size_t *w, size_t *h);
LOT_EXPORT double lottie_animation_get_duration(const Lottie_Animation *animation);
LOT_EXPORT size_t lottie_animation_get_totalframe(const Lottie_Animation *animation);
LOT_EXPORT double lottie_animation_get_framerate(const Lottie_Animation *animation);


/*
 * Request to update the content of the frame $frame_number in to Animation object.
 * frame_number, the content of the animation in that frame number
 * width  , width of the viewbox
 * height , height of the viewbox
 *
 * PS : user must call lottie_animation_get_node_count and  lottie_animation_get_node
 * to get the renderlist.
 */
LOT_EXPORT size_t lottie_animation_prepare_frame(Lottie_Animation *animation,
                                                 size_t frameNo,
                                                 size_t w, size_t h);
LOT_EXPORT size_t lottie_animation_get_node_count(const Lottie_Animation *animation);
LOT_EXPORT const LOTNode* lottie_animation_get_node(Lottie_Animation *animation, size_t idx);


/*
 * Get the render tree which contains the snapshot of the animation object at frame $frame_number
 * frame_number, the content of the animation in that frame number
 * width  , width of the viewbox
 * height , height of the viewbox
 *
 * PS : user has to traverse the tree for rendering. @see LOTLayerNode and @see LOTNode
 */
LOT_EXPORT const LOTLayerNode * lottie_animation_render_tree(Lottie_Animation *animation,
                                                             size_t frameNo,
                                                             size_t w, size_t h);

/*
 * Request to render the content of the frame $frame_number to buffer $buffer asynchronously.
 * frame_number, the frame number needs to be rendered.
 * buffer , surface buffer use for rendering
 * width  , width of the surface
 * height , height of the surface
 * bytes_per_line, stride of the surface in bytes.
 *
 * PS : user must call lottie_animation_render_flush to make sure render is finished.
 */
LOT_EXPORT void
lottie_animation_render_async(Lottie_Animation *animation,
                              size_t frame_number,
                              uint32_t *buffer,
                              size_t width,
                              size_t height,
                              size_t bytes_per_line);


/*
 * Request to finish the current asyn renderer job for this animation object.
 * if render is finished then this call returns immidiately
 * if not it waits till render job finish and then return.
 * user must use lottie_animation_render_async and lottie_animation_render_flush
 * together to get the benefit of async rendering.
 */
LOT_EXPORT void
lottie_animation_render_flush(Lottie_Animation *animation);

#ifdef __cplusplus
}
#endif

#endif //_LOTTIE_ANIMATION_CAPI_H_

