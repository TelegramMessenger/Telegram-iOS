/*
 * Copyright (c) 2020 Samsung Electronics Co., Ltd. All rights reserved.

 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:

 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.

 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
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
    std::unique_ptr<Animation>      mAnimation;
    std::future<Surface>            mRenderTask;
    uint32_t                       *mBufferRef;
    LOTMarkerList                  *mMarkerList;
};

RLOTTIE_API Lottie_Animation_S *lottie_animation_from_file(const char *path)
{
    if (auto animation = Animation::loadFromFile(path) ) {
        Lottie_Animation_S *handle = new Lottie_Animation_S();
        handle->mAnimation = std::move(animation);
        return handle;
    } else {
        return nullptr;
    }
}

RLOTTIE_API Lottie_Animation_S *lottie_animation_from_data(const char *data, const char *key, const char *resourcePath)
{
    if (auto animation = Animation::loadFromData(data, key, resourcePath) ) {
        Lottie_Animation_S *handle = new Lottie_Animation_S();
        handle->mAnimation = std::move(animation);
        return handle;
    } else {
        return nullptr;
    }
}

RLOTTIE_API void lottie_animation_destroy(Lottie_Animation_S *animation)
{
    if (animation) {
        if (animation->mMarkerList) {
            for(size_t i = 0; i < animation->mMarkerList->size; i++) {
                if (animation->mMarkerList->ptr[i].name) free(animation->mMarkerList->ptr[i].name);
            }
            delete[] animation->mMarkerList->ptr;
            delete animation->mMarkerList;
        }

        if (animation->mRenderTask.valid()) {
            animation->mRenderTask.get();
        }
        animation->mAnimation = nullptr;
        delete animation;
    }
}

RLOTTIE_API void lottie_animation_get_size(const Lottie_Animation_S *animation, size_t *width, size_t *height)
{
   if (!animation) return;

   animation->mAnimation->size(*width, *height);
}

RLOTTIE_API double lottie_animation_get_duration(const Lottie_Animation_S *animation)
{
   if (!animation) return 0;

   return animation->mAnimation->duration();
}

RLOTTIE_API size_t lottie_animation_get_totalframe(const Lottie_Animation_S *animation)
{
   if (!animation) return 0;

   return animation->mAnimation->totalFrame();
}


RLOTTIE_API double lottie_animation_get_framerate(const Lottie_Animation_S *animation)
{
   if (!animation) return 0;

   return animation->mAnimation->frameRate();
}

RLOTTIE_API const LOTLayerNode * lottie_animation_render_tree(Lottie_Animation_S *animation, size_t frame_num, size_t width, size_t height)
{
    if (!animation) return nullptr;

    return animation->mAnimation->renderTree(frame_num, width, height);
}

RLOTTIE_API size_t
lottie_animation_get_frame_at_pos(const Lottie_Animation_S *animation, float pos)
{
    if (!animation) return 0;

    return animation->mAnimation->frameAtPos(pos);
}

RLOTTIE_API void
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

RLOTTIE_API void
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

RLOTTIE_API uint32_t *
lottie_animation_render_flush(Lottie_Animation_S *animation)
{
    if (!animation) return nullptr;

    if (animation->mRenderTask.valid()) {
        animation->mRenderTask.get();
    }

    return animation->mBufferRef;
}

RLOTTIE_API void
lottie_animation_property_override(Lottie_Animation_S *animation,
                                   const Lottie_Animation_Property type,
                                   const char *keypath,
                                   ...)
{
    va_list prop;
    va_start(prop, keypath);
    const int arg_count = [type](){
                             switch (type) {
                              case LOTTIE_ANIMATION_PROPERTY_FILLCOLOR:
                              case LOTTIE_ANIMATION_PROPERTY_STROKECOLOR:
                                return 3;
                              case LOTTIE_ANIMATION_PROPERTY_FILLOPACITY:
                              case LOTTIE_ANIMATION_PROPERTY_STROKEOPACITY:
                              case LOTTIE_ANIMATION_PROPERTY_STROKEWIDTH:
                              case LOTTIE_ANIMATION_PROPERTY_TR_ROTATION:
                                return 1;
                              case LOTTIE_ANIMATION_PROPERTY_TR_POSITION:
                              case LOTTIE_ANIMATION_PROPERTY_TR_SCALE:
                                return 2;
                              default:
                                return 0;
                             }
                          }();
    double v[3] = {0};
    for (int i = 0; i < arg_count ; i++) {
      v[i] = va_arg(prop, double);
    }
    va_end(prop);

    switch(type) {
    case LOTTIE_ANIMATION_PROPERTY_FILLCOLOR: {
        double r = v[0];
        double g = v[1];
        double b = v[2];
        if (r > 1 || r < 0 || g > 1 || g < 0 || b > 1 || b < 0) break;
        animation->mAnimation->setValue<rlottie::Property::FillColor>(keypath, rlottie::Color(r, g, b));
        break;
    }
    case LOTTIE_ANIMATION_PROPERTY_FILLOPACITY: {
        double opacity = v[0];
        if (opacity > 100 || opacity < 0) break;
        animation->mAnimation->setValue<rlottie::Property::FillOpacity>(keypath, (float)opacity);
        break;
    }
    case LOTTIE_ANIMATION_PROPERTY_STROKECOLOR: {
        double r = v[0];
        double g = v[1];
        double b = v[2];
        if (r > 1 || r < 0 || g > 1 || g < 0 || b > 1 || b < 0) break;
        animation->mAnimation->setValue<rlottie::Property::StrokeColor>(keypath, rlottie::Color(r, g, b));
        break;
    }
    case LOTTIE_ANIMATION_PROPERTY_STROKEOPACITY: {
        double opacity = v[0];
        if (opacity > 100 || opacity < 0) break;
        animation->mAnimation->setValue<rlottie::Property::StrokeOpacity>(keypath, (float)opacity);
        break;
    }
    case LOTTIE_ANIMATION_PROPERTY_STROKEWIDTH: {
        double width = v[0];
        if (width < 0) break;
        animation->mAnimation->setValue<rlottie::Property::StrokeWidth>(keypath, (float)width);
        break;
    }
    case LOTTIE_ANIMATION_PROPERTY_TR_POSITION: {
        double x = v[0];
        double y = v[1];
        animation->mAnimation->setValue<rlottie::Property::TrPosition>(keypath, rlottie::Point((float)x, (float)y));
        break;
    }
    case LOTTIE_ANIMATION_PROPERTY_TR_SCALE: {
        double w = v[0];
        double h = v[1];
        animation->mAnimation->setValue<rlottie::Property::TrScale>(keypath, rlottie::Size((float)w, (float)h));
        break;
    }
    case LOTTIE_ANIMATION_PROPERTY_TR_ROTATION: {
        double r = v[0];
        animation->mAnimation->setValue<rlottie::Property::TrRotation>(keypath, (float)r);
        break;
    }
    case LOTTIE_ANIMATION_PROPERTY_TR_ANCHOR:
    case LOTTIE_ANIMATION_PROPERTY_TR_OPACITY:
        //@TODO handle propery update.
        break;
    }
}

RLOTTIE_API const LOTMarkerList*
lottie_animation_get_markerlist(Lottie_Animation_S *animation)
{
   if (!animation) return nullptr;

   auto markers = animation->mAnimation->markers();
   if (markers.size() == 0) return nullptr;
   if (animation->mMarkerList) return (const LOTMarkerList*)animation->mMarkerList;

   animation->mMarkerList = new LOTMarkerList();
   animation->mMarkerList->size = markers.size();
   animation->mMarkerList->ptr = new LOTMarker[markers.size()]();

   for(size_t i = 0; i < markers.size(); i++) {
       animation->mMarkerList->ptr[i].name = strdup(std::get<0>(markers[i]).c_str());
       animation->mMarkerList->ptr[i].startframe= std::get<1>(markers[i]);
       animation->mMarkerList->ptr[i].endframe= std::get<2>(markers[i]);
   }
   return (const LOTMarkerList*)animation->mMarkerList;
}

}
