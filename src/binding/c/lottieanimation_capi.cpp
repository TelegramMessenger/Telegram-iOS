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
#include "vdebug.h"

using namespace rlottie;

extern "C" {

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

}
