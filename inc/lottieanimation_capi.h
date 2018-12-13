#ifndef _LOTTIE_ANIMATION_CAPI_H_
#define _LOTTIE_ANIMATION_CAPI_H_

#include <stddef.h>
#include <stdint.h>
#include <lottiecommon.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct Lottie_Animation_S Lottie_Animation;

/**
 *  @brief Constructs an animation object from file path.
 *
 *  @param[in] path Lottie resource file path
 *
 *  @return Animation object that can build the contents of the
 *          Lottie resource represented by file path.
 *
 *  @see lottie_animation_destroy()
 *
 *  @ingroup Lottie_Animation
 *  @internal
 */
LOT_EXPORT Lottie_Animation *lottie_animation_from_file(const char *path);

/**
 *  @brief Constructs an animation object from JSON string data.
 *
 *  @param[in] data The JSON string data.
 *  @param[in] key the string that will be used to cache the JSON string data.
 *
 *  @return Animation object that can build the contents of the
 *          Lottie resource represented by JSON string data.
 *
 *  @ingroup Lottie_Animation
 *  @internal
 */
LOT_EXPORT Lottie_Animation *lottie_animation_from_data(const char *data, const char *key);

/**
 *  @brief Free given Animation object resource.
 *
 *  @param[in] animation Animation object to free.
 *
 *  @see lottie_animation_from_file()
 *  @see lottie_animation_from_data()
 *
 *  @ingroup Lottie_Animation
 *  @internal
 */
LOT_EXPORT void lottie_animation_destroy(Lottie_Animation *animation);

/**
 *  @brief Returns default viewport size of the Lottie resource.
 *
 *  @param[in] animation Animation object.
 *  @param[out] w default width of the viewport.
 *  @param[out] h default height of the viewport.
 *
 *  @ingroup Lottie_Animation
 *  @internal
 */
LOT_EXPORT void lottie_animation_get_size(const Lottie_Animation *animation, size_t *width, size_t *height);

/**
 *  @brief Returns total animation duration of Lottie resource in second.
 *         it uses totalFrame() and frameRate() to calculate the duration.
 *         duration = totalFrame() / frameRate().
 *
 *  @param[in] animation Animation object.
 *
 *  @return total animation duration in second.
 *          @c 0 if the Lottie resource has no animation.
 *
 *  @see lottie_animation_get_totalframe()
 *  @see lottie_animation_get_framerate()
 *
 *  @ingroup Lottie_Animation
 *  @internal
 */
LOT_EXPORT double lottie_animation_get_duration(const Lottie_Animation *animation);

/**
 *  @brief Returns total number of frames present in the Lottie resource.
 *
 *  @param[in] animation Animation object.
 *
 *  @return frame count of the Lottie resource.*
 *
 *  @note frame number starts with 0.
 *
 *  @see lottie_animation_get_duration()
 *  @see lottie_animation_get_framerate()
 *
 *  @ingroup Lottie_Animation
 *  @internal
 */
LOT_EXPORT size_t lottie_animation_get_totalframe(const Lottie_Animation *animation);

/**
 *  @brief Returns default framerate of the Lottie resource.
 *
 *  @param[in] animation Animation object.
 *
 *  @return framerate of the Lottie resource
 *
 *  @ingroup Lottie_Animation
 *  @internal
 *
 */
LOT_EXPORT double lottie_animation_get_framerate(const Lottie_Animation *animation);

/**
 *  @brief Get the render tree which contains the snapshot of the animation object
 *         at frame = @c frame_num, the content of the animation in that frame number.
 *
 *  @param[in] animation Animation object.
 *  @param[in] width requested snapshot viewport width.
 *  @param[in] height requested snapshot viewport height.
 *
 *  @return Animation snapshot tree.
 *
 * @note: User has to traverse the tree for rendering.
 *
 * @see LOTLayerNode
 * @see LOTNode
 *
 *  @ingroup Lottie_Animation
 *  @internal
 */
LOT_EXPORT const LOTLayerNode * lottie_animation_render_tree(Lottie_Animation *animation,
                                                             size_t frame_num,
                                                             size_t width, size_t height);

/**
 *  @brief Request to render the content of the frame @p frame_num to buffer @p buffer asynchronously.
 *
 *  @param[in] animation Animation object.
 *  @param[in] frame_num the frame number needs to be rendered.
 *  @param[in] buffer surface buffer use for rendering.
 *  @param[in] width width of the surface
 *  @param[in] height height of the surface
 *  @param[in] bytes_per_line stride of the surface in bytes.
 *
 *  @note user must call lottie_animation_render_flush() to make sure render is finished.
 *
 *  @ingroup Lottie_Animation
 *  @internal
 */
LOT_EXPORT void
lottie_animation_render_async(Lottie_Animation *animation,
                              size_t frame_num,
                              uint32_t *buffer,
                              size_t width,
                              size_t height,
                              size_t bytes_per_line);

/**
 *  @brief Request to finish the current async renderer job for this animation object.
 *  If render is finished then this call returns immidiately.
 *  If not, it waits till render job finish and then return.
 *
 *  @param[in] animation Animation object.
 *
 *  @warning User must call lottie_animation_render_async() and lottie_animation_render_flush()
 *  in pair to get the benefit of async rendering.
 *
 *  @ingroup Lottie_Animation
 *  @internal
 */
LOT_EXPORT void
lottie_animation_render_flush(Lottie_Animation *animation);

#ifdef __cplusplus
}
#endif

#endif //_LOTTIE_ANIMATION_CAPI_H_

