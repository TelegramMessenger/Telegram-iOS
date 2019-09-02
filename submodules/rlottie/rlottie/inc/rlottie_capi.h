/* 
 * Copyright (c) 2018 Samsung Electronics Co., Ltd. All rights reserved.
 * 
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 * 
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 */

#ifndef _RLOTTIE_CAPI_H_
#define _RLOTTIE_CAPI_H_

#include <stddef.h>
#include <stdint.h>
#include <rlottiecommon.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    LOTTIE_ANIMATION_PROPERTY_FILLCOLOR,      /*!< Color property of Fill object , value type is float [0 ... 1] */
    LOTTIE_ANIMATION_PROPERTY_FILLOPACITY,    /*!< Opacity property of Fill object , value type is float [ 0 .. 100] */
    LOTTIE_ANIMATION_PROPERTY_STROKECOLOR,    /*!< Color property of Stroke object , value type is float [0 ... 1] */
    LOTTIE_ANIMATION_PROPERTY_STROKEOPACITY,  /*!< Opacity property of Stroke object , value type is float [ 0 .. 100] */
    LOTTIE_ANIMATION_PROPERTY_STROKEWIDTH,    /*!< stroke with property of Stroke object , value type is float */
    LOTTIE_ANIMATION_PROPERTY_TR_ANCHOR,      /*!< Transform Anchor property of Layer and Group object , value type is int */
    LOTTIE_ANIMATION_PROPERTY_TR_POSITION,    /*!< Transform Position property of Layer and Group object , value type is int */
    LOTTIE_ANIMATION_PROPERTY_TR_SCALE,       /*!< Transform Scale property of Layer and Group object , value type is float range[0 ..100] */
    LOTTIE_ANIMATION_PROPERTY_TR_ROTATION,    /*!< Transform Scale property of Layer and Group object , value type is float. range[0 .. 360] in degrees*/
    LOTTIE_ANIMATION_PROPERTY_TR_OPACITY      /*!< Transform Opacity property of Layer and Group object , value type is float [ 0 .. 100] */
}Lottie_Animation_Property;

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
 *  @param[in] resource_path the path that will be used to load external resource needed by the JSON data.
 *
 *  @return Animation object that can build the contents of the
 *          Lottie resource represented by JSON string data.
 *
 *  @ingroup Lottie_Animation
 *  @internal
 */
LOT_EXPORT Lottie_Animation *lottie_animation_from_data(const char *data, const char *key, const char *resource_path);

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
 *  @param[in] frame_num Content corresponds to the @p frame_num needs to be drawn
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
LOT_EXPORT const LOTLayerNode *lottie_animation_render_tree(Lottie_Animation *animation, size_t frame_num, size_t width, size_t height);

/**
 *  @brief Maps position to frame number and returns it.
 *
 *  @param[in] animation Animation object.
 *  @param[in] pos position in the range [ 0.0 .. 1.0 ].
 *
 *  @return mapped frame numbe in the range [ start_frame .. end_frame ].
 *          @c 0 if the Lottie resource has no animation.
 *
 *
 *  @ingroup Lottie_Animation
 *  @internal
 */
LOT_EXPORT size_t lottie_animation_get_frame_at_pos(const Lottie_Animation *animation, float pos);

/**
 *  @brief Request to render the content of the frame @p frame_num to buffer @p buffer.
 *
 *  @param[in] animation Animation object.
 *  @param[in] frame_num the frame number needs to be rendered.
 *  @param[in] buffer surface buffer use for rendering.
 *  @param[in] width width of the surface
 *  @param[in] height height of the surface
 *  @param[in] bytes_per_line stride of the surface in bytes.
 *
 *
 *  @ingroup Lottie_Animation
 *  @internal
 */
LOT_EXPORT void lottie_animation_render(Lottie_Animation *animation, size_t frame_num, uint32_t *buffer, size_t width, size_t height, size_t bytes_per_line);

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
LOT_EXPORT void lottie_animation_render_async(Lottie_Animation *animation, size_t frame_num, uint32_t *buffer, size_t width, size_t height, size_t bytes_per_line);

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
 *  @return the pixel buffer it finished rendering.
 *
 *  @ingroup Lottie_Animation
 *  @internal
 */
LOT_EXPORT uint32_t *lottie_animation_render_flush(Lottie_Animation *animation);


/**
 *  @brief Request to change the properties of this animation object.
 *  Keypath should conatin object names separated by (.) and can handle globe(**) or wildchar(*)
 *
 *  @usage
 *  To change fillcolor property of fill1 object in the layer1->group1->fill1 hirarchy to RED color
 *
 *      lottie_animation_property_override(animation, LOTTIE_ANIMATION_PROPERTY_FILLCOLOR, "layer1.group1.fill1", 1.0, 0.0, 0.0);
 *
 *  if all the color property inside group1 needs to be changed to GREEN color
 *
 *      lottie_animation_property_override(animation, LOTTIE_ANIMATION_PROPERTY_FILLCOLOR, "**.group1.**", 1.0, 0.0, 0.0);
 *
 *  @param[in] animation Animation object.
 *  @param[in] type Property type. (@p Lottie_Animation_Property)
 *  @param[in] keypath Specific content of target.
 *  @param[in] ... Property values.
 *
 *  @ingroup Lottie_Animation
 *  @internal
 * */
LOT_EXPORT void lottie_animation_property_override(Lottie_Animation *animation, const Lottie_Animation_Property type, const char *keypath, ...);

#ifdef __cplusplus
}
#endif

#endif //_RLOTTIE_CAPI_H_

