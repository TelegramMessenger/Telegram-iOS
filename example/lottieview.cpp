#include"lottieview.h"

using namespace lottie;

static Eina_Bool
animator(void *data , double pos)
{
    LottieView *view = static_cast<LottieView *>(data);
    float nextPos = pos + view->mStartPos;
    if (nextPos > 1.0) nextPos = 1.0;

    view->seek(nextPos);
    if (nextPos == 1.0) {
      view->mAnimator = NULL;
      view->finished();
      return EINA_FALSE;
    }
    return EINA_TRUE;
}

void LottieView::createVgNode(LOTNode *node, Efl_VG *parent)
{
    Efl_VG *shape = evas_vg_shape_add(parent);
    // update the path
    const float *data = node->mPath.ptPtr;
    for(int i=0; i <node->mPath.elmCount; i++) {
        switch (node->mPath.elmPtr[i]) {
        case 0:  //moveTo
        {
            evas_vg_shape_append_move_to(shape, data[0], data[1]);
            data += 2;
            break;
        }
        case 1:
        {
            evas_vg_shape_append_line_to(shape, data[0], data[1]);
            data += 2;
            break;
        }
        case 2:
        {
            evas_vg_shape_append_cubic_to(shape, data[0], data[1], data[2], data[3], data[4], data[5]);
            data += 6;
            break;
        }
        case 3:
        {
            evas_vg_shape_append_close(shape);
            break;
        }
        default:
            break;
        }
    }

    if (node->mStroke.enable) {
        evas_vg_shape_stroke_width_set(shape, node->mStroke.width);
        //evas_vg_shape_stroke_cap_set(shape, int(node->mStroke.cap));
        //evas_vg_shape_stroke_join_set(shape, int(node->mStroke.join));
        //evas_vg_shape_stroke_meter_limit_set(shape, node->mStroke.meterLimit);
    }
    // update paint info
    if (node->mBrushType == LOTBrushType::BrushSolid) {
        int r = (node->mColor.r * node->mColor.a)/255;
        int g = (node->mColor.g * node->mColor.a)/255;
        int b = (node->mColor.b * node->mColor.a)/255;
        int a = node->mColor.a;
        if (node->mStroke.enable) {
            evas_vg_shape_stroke_color_set(shape, r, g, b, a);
        } else {
           evas_vg_node_color_set(shape, r, g, b, a);
        }

    } else if (node->mBrushType == LOTBrushType::BrushGradient) {
        //TODO fill the gradient info
    }
}

void LottieView::update(const std::vector<LOTNode *> &renderList)
{
    Efl_VG *root = evas_vg_container_add(mVg);
    for(auto i : renderList) {
        createVgNode(i, root);
    }
    evas_object_vg_root_node_set(mVg, root);
}

static void mImageDelCb(void *data, Evas *evas, Evas_Object *obj, void *)
{
    LottieView *lottie = (LottieView *)data;

    if (lottie->mImage != obj) return;

    lottie->mImage = NULL;
    lottie->stop();
}

static void mVgDelCb(void *data, Evas *evas, Evas_Object *obj, void *)
{
    LottieView *lottie = (LottieView *)data;
    if (lottie->mVg != obj) return;

    lottie->mVg = NULL;
    lottie->stop();
}

void LottieView::initializeBufferObject(Evas *evas)
{
    if (mRenderMode) {
        mImage = evas_object_image_filled_add(evas);
        evas_object_image_colorspace_set(mImage, EVAS_COLORSPACE_ARGB8888);
        evas_object_image_alpha_set(mImage, EINA_TRUE);
        evas_object_event_callback_add(mImage, EVAS_CALLBACK_DEL, mImageDelCb, this);
    } else {
        mVg = evas_object_vg_add(evas);
        evas_object_event_callback_add(mVg, EVAS_CALLBACK_DEL, mVgDelCb, this);
    }
}

LottieView::LottieView(Evas *evas, bool renderMode, bool asyncRender):mVg(nullptr), mImage(nullptr)
{
    mPlayer = nullptr;
    mPalying = false;
    mReverse = false;
    mRepeatCount = 0;
    mRepeatMode = LottieView::RepeatMode::Restart;
    mLoop = false;
    mSpeed = 1;

    mEvas = evas;
    mRenderMode = renderMode;
    mAsyncRender = asyncRender;

    initializeBufferObject(evas);
}

LottieView::~LottieView()
{
    if (mRenderTask.valid())
        mRenderTask.get();

    if (mAnimator) ecore_animator_del(mAnimator);
    if (mVg) evas_object_del(mVg);
    if (mImage) evas_object_del(mImage);
}

Evas_Object *LottieView::getImage() {
    if (mRenderMode) {
        return mImage;
    } else {
        return mVg;
    }
}

void LottieView::show()
{
    if (mRenderMode) {
        evas_object_show(mImage);
    } else {
        evas_object_show(mVg);
    }
    seek(0);
}

void LottieView::hide()
{
    if (mRenderMode) {
        evas_object_hide(mImage);
    } else {
        evas_object_hide(mVg);
    }
}

void LottieView::seek(float pos)
{
    if (!mPlayer) return;

    if (mPalying && mReverse)
        pos = 1.0 - pos;

    mPos = pos;

    // check if the pos maps to the current frame
    if (mCurFrame == mPlayer->frameAtPos(mPos)) return;

    mCurFrame = mPlayer->frameAtPos(mPos);

    if (mRenderMode) {
        int width , height;
        evas_object_image_size_get(mImage, &width, &height);
        if (mAsyncRender) {
            if (mRenderTask.valid()) return;
            mDirty = true;
            auto buffer = (uint32_t *)evas_object_image_data_get(mImage, EINA_TRUE);
            size_t bytesperline =  evas_object_image_stride_get(mImage);
            lottie::Surface surface(buffer, width, height, bytesperline);
            mRenderTask = mPlayer->render(mCurFrame, surface);
            // to force a redraw
            evas_object_image_data_update_add(mImage, 0 , 0, surface.width(), surface.height());
        } else {
            auto buffer = (uint32_t *)evas_object_image_data_get(mImage, EINA_TRUE);
            size_t bytesperline =  evas_object_image_stride_get(mImage);
            lottie::Surface surface(buffer, width, height, bytesperline);
            mPlayer->renderSync(mCurFrame, surface);
            evas_object_image_data_set(mImage, surface.buffer());
            evas_object_image_data_update_add(mImage, 0 , 0, surface.width(), surface.height());
        }
    } else {
        const std::vector<LOTNode *> &renderList = mPlayer->renderList(mCurFrame, mw, mh);
        update(renderList);
    }
}

float LottieView::getPos()
{
   return mPos;
}

void LottieView::render()
{
    if (!mPlayer) return;

    if (!mDirty) return;
    mDirty = false;

    if (mRenderMode) {
        if (!mRenderTask.valid()) return;
        auto surface = mRenderTask.get();
        evas_object_image_data_set(mImage, surface.buffer());
        evas_object_image_data_update_add(mImage, 0 , 0, surface.width(), surface.height());
    }
}

void LottieView::setFilePath(const char *filePath)
{
    if (mPlayer = Animation::loadFromFile(filePath)) {
        mFrameRate = mPlayer->frameRate();
        mTotalFrame = mPlayer->totalFrame();
    } else {
        printf("load failed file %s\n", filePath);
    }
}

void LottieView::loadFromData(const std::string &jsonData, const std::string &key)
{
    if (mPlayer = Animation::loadFromData(jsonData, key)) {
        mFrameRate = mPlayer->frameRate();
        mTotalFrame = mPlayer->totalFrame();
    } else {
        printf("load failed from data key : %s\n", key.c_str());
    }
}

void LottieView::setSize(int w, int h)
{
    mw = w; mh = h;

    if (mRenderMode) {
        evas_object_resize(mImage, w, h);
        evas_object_image_size_set(mImage, w, h);
    } else {
        evas_object_resize(mVg, w, h);
    }
}
void LottieView::setPos(int x, int y)
{
    if (mRenderMode) {
        evas_object_move(mImage, x, y);
    } else {
        evas_object_move(mVg, x, y);
    }
}

void LottieView::finished()
{
    restart();
}

void LottieView::loop(bool loop)
{
    mLoop = loop;
}

void LottieView::setRepeatCount(int count)
{
    mRepeatCount = count;
}

void LottieView::setRepeatMode(LottieView::RepeatMode mode)
{
    mRepeatMode = mode;
}

void LottieView::play()
{
    if (!mPlayer) return;

    mStartPos = mPos;
    if (mAnimator) ecore_animator_del(mAnimator);
    mAnimator = ecore_animator_timeline_add(mPlayer->duration()/mSpeed, animator, this);
    mReverse = false;
    mCurCount = mRepeatCount;
    mPalying = true;
}

void LottieView::pause()
{

}

void LottieView::stop()
{
    mPalying = false;
    if (mAnimator) {
        ecore_animator_del(mAnimator);
        mAnimator = NULL;
    }
}

void LottieView::restart()
{
    if (!mPlayer) return;

    mCurCount--;
    if (mLoop || mRepeatCount) {
        if (mRepeatMode == LottieView::RepeatMode::Reverse)
            mReverse = !mReverse;
        else
            mReverse = false;

        mStartPos = 0;
        if (mAnimator) ecore_animator_del(mAnimator);
        mAnimator = ecore_animator_timeline_add(mPlayer->duration()/mSpeed, animator, this);
    }
}
