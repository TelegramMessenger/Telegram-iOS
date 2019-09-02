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

#include "rlottie.h"
#include "rlottie_capi.h"
#include "vdebug.h"

using namespace rlottie;

extern "C" {
#include <string.h>
#include <stdarg.h>

struct Lottie_Animation_S
{
    std::unique_ptr<Animation> mAnimation;
    std::future<Surface>       mRenderTask;
    uint32_t                  *mBufferRef;
};

LOT_EXPORT Lottie_Animation_S *lottie_animation_from_file(const char *path)
{
    if (auto animation = Animation::loadFromFile(path) ) {
        Lottie_Animation_S *handle = new Lottie_Animation_S();
        handle->mAnimation = std::move(animation);
        return handle;
    } else {
        return nullptr;
    }
}

LOT_EXPORT Lottie_Animation_S *lottie_animation_from_data(const char *data, const char *key, const char *resourcePath)
{
    if (auto animation = Animation::loadFromData(data, key, resourcePath) ) {
        Lottie_Animation_S *handle = new Lottie_Animation_S();
        handle->mAnimation = std::move(animation);
        return handle;
    } else {
        return nullptr;
    }
}

LOT_EXPORT void lottie_animation_destroy(Lottie_Animation_S *animation)
{
    if (animation) {
        if (animation->mRenderTask.valid()) {
            animation->mRenderTask.get();
        }
        animation->mAnimation = nullptr;
        delete animation;
    }
}

LOT_EXPORT void lottie_animation_get_size(const Lottie_Animation_S *animation, size_t *width, size_t *height)
{
   if (!animation) return;

   animation->mAnimation->size(*width, *height);
}

LOT_EXPORT double lottie_animation_get_duration(const Lottie_Animation_S *animation)
{
   if (!animation) return 0;

   return animation->mAnimation->duration();
}

LOT_EXPORT size_t lottie_animation_get_totalframe(const Lottie_Animation_S *animation)
{
   if (!animation) return 0;

   return animation->mAnimation->totalFrame();
}


LOT_EXPORT double lottie_animation_get_framerate(const Lottie_Animation_S *animation)
{
   if (!animation) return 0;

   return animation->mAnimation->frameRate();
}

LOT_EXPORT const LOTLayerNode * lottie_animation_render_tree(Lottie_Animation_S *animation, size_t frame_num, size_t width, size_t height)
{
    if (!animation) return nullptr;

    return animation->mAnimation->renderTree(frame_num, width, height);
}

LOT_EXPORT size_t
lottie_animation_get_frame_at_pos(const Lottie_Animation_S *animation, float pos)
{
    if (!animation) return 0;

    return animation->mAnimation->frameAtPos(pos);
}

LOT_EXPORT void
lottie_animation_render(Lottie_Animation_S *animation,
                        size_t frame_number,
                        uint32_t *buffer,
                        size_t width,
                        size_t height,
                        size_t bytes_per_line)
{
    if (!animation) return;

    rlottie::Surface surface(buffer, width, height, bytes_per_line);
    animation->mAnimation->renderSync(frame_number, surface);
}

LOT_EXPORT void
lottie_animation_render_async(Lottie_Animation_S *animation,
                              size_t frame_number,
                              uint32_t *buffer,
                              size_t width,
                              size_t height,
                              size_t bytes_per_line)
{
    if (!animation) return;

    rlottie::Surface surface(buffer, width, height, bytes_per_line);
    animation->mRenderTask = animation->mAnimation->render(frame_number, surface);
    animation->mBufferRef = buffer;
}

LOT_EXPORT uint32_t *
lottie_animation_render_flush(Lottie_Animation_S *animation)
{
    if (!animation) return nullptr;

    if (animation->mRenderTask.valid()) {
        animation->mRenderTask.get();
    }

    return animation->mBufferRef;
}

LOT_EXPORT void
lottie_animation_property_override(Lottie_Animation_S *animation,
                                   const Lottie_Animation_Property type,
                                   const char *keypath,
                                   ...)
{
    va_list prop;
    va_start(prop, keypath);

    switch(type) {
    case LOTTIE_ANIMATION_PROPERTY_FILLCOLOR: {
        double r = va_arg(prop, double);
        double g = va_arg(prop, double);
        double b = va_arg(prop, double);
        if (r > 1 || r < 0 || g > 1 || g < 0 || b > 1 || b < 0) break;
        animation->mAnimation->setValue<rlottie::Property::FillColor>(keypath, rlottie::Color(r, g, b));
        break;
    }
    case LOTTIE_ANIMATION_PROPERTY_FILLOPACITY: {
        double opacity = va_arg(prop, double);
        if (opacity > 100 || opacity < 0) break;
        animation->mAnimation->setValue<rlottie::Property::FillOpacity>(keypath, (float)opacity);
        break;
    }
    case LOTTIE_ANIMATION_PROPERTY_STROKECOLOR: {
        double r = va_arg(prop, double);
        double g = va_arg(prop, double);
        double b = va_arg(prop, double);
        if (r > 1 || r < 0 || g > 1 || g < 0 || b > 1 || b < 0) break;
        animation->mAnimation->setValue<rlottie::Property::StrokeColor>(keypath, rlottie::Color(r, g, b));
        break;
    }
    case LOTTIE_ANIMATION_PROPERTY_STROKEOPACITY: {
        double opacity = va_arg(prop, double);
        if (opacity > 100 || opacity < 0) break;
        animation->mAnimation->setValue<rlottie::Property::StrokeOpacity>(keypath, (float)opacity);
        break;
    }
    case LOTTIE_ANIMATION_PROPERTY_STROKEWIDTH: {
        double width = va_arg(prop, double);
        if (width < 0) break;
        animation->mAnimation->setValue<rlottie::Property::StrokeWidth>(keypath, (float)width);
        break;
    }
    case LOTTIE_ANIMATION_PROPERTY_TR_ANCHOR:
    case LOTTIE_ANIMATION_PROPERTY_TR_POSITION:
    case LOTTIE_ANIMATION_PROPERTY_TR_SCALE:
    case LOTTIE_ANIMATION_PROPERTY_TR_ROTATION:
    case LOTTIE_ANIMATION_PROPERTY_TR_OPACITY:
        //@TODO handle propery update.
        break;
    }
    va_end(prop);
}
}
