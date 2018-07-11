#include"lottieview.h"
#include"lottieplayer.h"

static Eina_Bool
animator(void *data , double pos)
{
    LottieView *view = static_cast<LottieView *>(data);
    view->seek(pos);
    if (pos == 1.0) {
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
    if (node->mType == LOTNode::BrushSolid) {
        int r = (node->mColor.r * node->mColor.a)/255;
        int g = (node->mColor.g * node->mColor.a)/255;
        int b = (node->mColor.b * node->mColor.a)/255;
        int a = node->mColor.a;
        if (node->mStroke.enable) {
            evas_vg_shape_stroke_color_set(shape, r, g, b, a);
        } else {
           evas_vg_node_color_set(shape, r, g, b, a);
        }

    } else if (node->mType == LOTNode::BrushGradient) {
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

LottieView::LottieView(Evas *evas, bool renderMode)
{
    mPalying = false;
    mReverse = false;
    mRepeatCount = 0;
    mRepeatMode = LottieView::RepeatMode::Restart;
    mLoop = false;
    mSpeed = 1;

    mEvas = evas;
    mPlayer = new LOTPlayer();
    mRenderMode = renderMode;

    if (mRenderMode) {
        mImage = evas_object_image_filled_add(evas);
        evas_object_image_colorspace_set(mImage, EVAS_COLORSPACE_ARGB8888);
        evas_object_image_alpha_set(mImage, EINA_TRUE);
    } else {
        mVg = evas_object_vg_add(evas);
    }
}

LottieView::~LottieView()
{
    ecore_animator_del(mAnimator);
    delete mPlayer;
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
    if (mPalying && mReverse)
        pos = 1.0 - pos;

    if (mRenderMode) {
        LOTBuffer buf;
        buf.buffer = (uint32_t *)evas_object_image_data_get(mImage, EINA_TRUE);
        buf.bytesPerLine =  evas_object_image_stride_get(mImage);
        evas_object_image_size_get(mImage, &buf.width, &buf.height);
        bool changed = mPlayer->renderSync(pos, buf);
        evas_object_image_data_set(mImage, buf.buffer);
        // if the buffer is updated notify the image object
        if (changed) {
            evas_object_image_data_update_add(mImage, 0 , 0, buf.width, buf.height);
        }
    } else {
        mPlayer->seek(pos);
        const std::vector<LOTNode *> &renderList = mPlayer->renderList();
        update(renderList);
    }
}

void LottieView::setFilePath(const char *filePath)
{
    mPlayer->setFilePath(filePath);
}

void LottieView::setSize(int w, int h)
{
    if (mRenderMode) {
        evas_object_resize(mImage, w, h);
        evas_object_image_size_set(mImage, w, h);
    } else {
        evas_object_resize(mVg, w, h);
    }
    mPlayer->setSize(w, h);
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
    mAnimator = ecore_animator_timeline_add(mPlayer->playTime()/mSpeed, animator, this);
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
}

void LottieView::restart()
{
    mCurCount--;
    if (mLoop || mRepeatCount) {
        if (mRepeatMode == LottieView::RepeatMode::Reverse)
            mReverse = !mReverse;
        else
            mReverse = false;
        mAnimator = ecore_animator_timeline_add(mPlayer->playTime()/mSpeed, animator, this);
    }
}
