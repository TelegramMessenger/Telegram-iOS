#include "lottieanimation.h"
#include "vdebug.h"

using namespace lottie;

extern "C" {

struct Lottie_Animation_S
{
    std::unique_ptr<Animation> mAnimation;
    size_t                     mCurFrame{0};
    std::future<Surface>       mRenderTask;
    size_t                     mFrameNo{0};
    size_t                     mArraySize{0};
    size_t                     mWidth{0};
    size_t                     mHeight{0};
};

LOT_EXPORT Lottie_Animation_S *lottie_animation_from_file(const char *file)
{
    if (auto animation = Animation::loadFromFile(file) ) {
        Lottie_Animation_S *handle = new Lottie_Animation_S();
        handle->mAnimation = std::move(animation);
        return handle;
    } else {
        return nullptr;
    }
}

LOT_EXPORT Lottie_Animation_S *lottie_animation_from_data(const char *data, const char *key)
{
    if (auto animation = Animation::loadFromData(data, key) ) {
        Lottie_Animation_S *handle = new Lottie_Animation_S();
        handle->mAnimation = std::move(animation);
        return handle;
    } else {
        return nullptr;
    }
}

LOT_EXPORT void lottie_animation_destroy(Lottie_Animation_S *animation)
{
    if (animation)
        delete animation;
}

LOT_EXPORT void lottie_animation_get_size(const Lottie_Animation_S *animation, size_t *w, size_t *h)
{
   if (!animation) return;

   animation->mAnimation->size(*w, *h);
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

LOT_EXPORT const LOTLayerNode * lottie_animation_render_tree(Lottie_Animation_S *animation, size_t frameNo, size_t w, size_t h)
{
    if (!animation) return nullptr;

    animation->mFrameNo = frameNo;
    animation->mWidth = w;
    animation->mHeight = h;
    return animation->mAnimation->renderTree(frameNo, w, h);
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

    lottie::Surface surface(buffer, width, height, bytes_per_line);
    animation->mRenderTask = animation->mAnimation->render(frame_number, surface);
}

LOT_EXPORT void
lottie_animation_render_flush(Lottie_Animation_S *animation)
{
    if (!animation) return;

    if (animation->mRenderTask.valid()) {
        animation->mRenderTask.get();
    }
}

}
