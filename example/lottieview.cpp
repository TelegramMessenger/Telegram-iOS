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

#include"lottieview.h"

using namespace rlottie;

static Eina_Bool
animator(void *data , double pos)
{
    LottieView *view = static_cast<LottieView *>(data);

    view->seek(pos);
    if (pos == 1.0) {
      view->mAnimator = NULL;
      view->finished();
      return EINA_FALSE;
    }
    return EINA_TRUE;
}

void LottieView::createVgNode(LOTNode *node, Efl_VG *root)
{
    Efl_VG *shape = evas_vg_shape_add(root);

    //0: Path
    const float *data = node->mPath.ptPtr;
    if (!data) return;

    for (int i = 0; i < node->mPath.elmCount; i++) {
        switch (node->mPath.elmPtr[i]) {
        case 0:
            evas_vg_shape_append_move_to(shape, data[0], data[1]);
            data += 2;
            break;
        case 1:
            evas_vg_shape_append_line_to(shape, data[0], data[1]);
            data += 2;
            break;
        case 2:
            evas_vg_shape_append_cubic_to(shape, data[0], data[1], data[2], data[3], data[4], data[5]);
            data += 6;
            break;
        case 3:
            evas_vg_shape_append_close(shape);
            break;
        default:
            break;
        }
    }

    //1: Stroke
    if (node->mStroke.enable) {
        //Stroke Width
        evas_vg_shape_stroke_width_set(shape, node->mStroke.width);

        //Stroke Cap
        Efl_Gfx_Cap cap;
        switch (node->mStroke.cap) {
        case CapFlat: cap = EFL_GFX_CAP_BUTT; break;
        case CapSquare: cap = EFL_GFX_CAP_SQUARE; break;
        case CapRound: cap = EFL_GFX_CAP_ROUND; break;
        default: cap = EFL_GFX_CAP_BUTT; break;
        }
        evas_vg_shape_stroke_cap_set(shape, cap);

        //Stroke Join
        Efl_Gfx_Join join;
        switch (node->mStroke.join) {
        case JoinMiter: join = EFL_GFX_JOIN_MITER; break;
        case JoinBevel: join = EFL_GFX_JOIN_BEVEL; break;
        case JoinRound: join = EFL_GFX_JOIN_ROUND; break;
        default: join = EFL_GFX_JOIN_MITER; break;
        }
        evas_vg_shape_stroke_join_set(shape, join);

        //Stroke Dash
        if (node->mStroke.dashArraySize > 0) {
            int size = (node->mStroke.dashArraySize / 2);
            Efl_Gfx_Dash *dash = static_cast<Efl_Gfx_Dash*>(malloc(sizeof(Efl_Gfx_Dash) * size));
            if (dash) {
                for (int i = 0; i <= size; i+=2) {
                    dash[i].length = node->mStroke.dashArray[i];
                    dash[i].gap = node->mStroke.dashArray[i + 1];
                }
                evas_vg_shape_stroke_dash_set(shape, dash, size);
                free(dash);
            }
        }
    }

    //2: Fill Method
    switch (node->mBrushType) {
    case BrushSolid: {
        float pa = ((float)node->mColor.a) / 255;
        int r = (int)(((float) node->mColor.r) * pa);
        int g = (int)(((float) node->mColor.g) * pa);
        int b = (int)(((float) node->mColor.b) * pa);
        int a = node->mColor.a;
        if (node->mStroke.enable)
          evas_vg_shape_stroke_color_set(shape, r, g, b, a);
        else
          evas_vg_node_color_set(shape, r, g, b, a);
        break;
    }
    case BrushGradient: {
        Efl_VG* grad = NULL;
        if (node->mGradient.type == GradientLinear) {
            grad = evas_vg_gradient_linear_add(root);
            evas_vg_gradient_linear_start_set(grad, node->mGradient.start.x, node->mGradient.start.y);
            evas_vg_gradient_linear_end_set(grad, node->mGradient.end.x, node->mGradient.end.y);

        }
        else if (node->mGradient.type == GradientRadial) {
            grad = evas_vg_gradient_radial_add(root);
            evas_vg_gradient_radial_center_set(grad, node->mGradient.center.x, node->mGradient.center.y);
            evas_vg_gradient_radial_focal_set(grad, node->mGradient.focal.x, node->mGradient.focal.y);
            evas_vg_gradient_radial_radius_set(grad, node->mGradient.cradius);
        }

        if (grad) {
            //Gradient Stop
            Efl_Gfx_Gradient_Stop* stops = static_cast<Efl_Gfx_Gradient_Stop*>(malloc(sizeof(Efl_Gfx_Gradient_Stop) * node->mGradient.stopCount));
            if (stops) {
                for (unsigned int i = 0; i < node->mGradient.stopCount; i++) {
                    stops[i].offset = node->mGradient.stopPtr[i].pos;
                    float pa = ((float)node->mGradient.stopPtr[i].a) / 255;
                    stops[i].r = (int)(((float)node->mGradient.stopPtr[i].r) * pa);
                    stops[i].g = (int)(((float)node->mGradient.stopPtr[i].g) * pa);
                    stops[i].b = (int)(((float)node->mGradient.stopPtr[i].b) * pa);
                    stops[i].a = node->mGradient.stopPtr[i].a;
                }
                evas_vg_gradient_stop_set(grad, stops, node->mGradient.stopCount);
                free(stops);
            }
            if (node->mStroke.enable)
              evas_vg_shape_stroke_fill_set(shape, grad);
            else
              evas_vg_shape_fill_set(shape, grad);
        }
        break;
    }
    default:
      break;
    }

    //3: Fill Rule
    if (node->mFillRule == FillEvenOdd)
      efl_gfx_shape_fill_rule_set(shape, EFL_GFX_FILL_RULE_ODD_EVEN);
    else if (node->mFillRule == FillWinding)
      efl_gfx_shape_fill_rule_set(shape, EFL_GFX_FILL_RULE_WINDING);
}

void LottieView::update(const std::vector<LOTNode *> &renderList)
{
    Efl_VG *root = evas_vg_container_add(mVg);
    for(auto i : renderList) {
        createVgNode(i, root);
    }
    evas_object_vg_root_node_set(mVg, root);
}

void LottieView::updateTree(const LOTLayerNode * node)
{
    Efl_VG *root = evas_vg_container_add(mVg);
    update(node, root);
    evas_object_vg_root_node_set(mVg, root);
}

void LottieView::update(const LOTLayerNode * node, Efl_VG *parent)
{
    // if the layer is invisible return
    if (!node->mVisible) return;

    // check if this layer is a container layer
    bool hasMatte = false;
    if (node->mLayerList.size) {
        for (unsigned int i = 0; i < node->mLayerList.size; i++) {
            if (hasMatte) {
                hasMatte = false;
                continue;
            }
            // if the layer has matte then
            // the next layer has to be rendered using this layer
            // as matte source
            if (node->mLayerList.ptr[i]->mMatte != MatteNone) {
                hasMatte = true;
                printf("Matte is not supported Yet\n");
                continue;
            }
            update(node->mLayerList.ptr[i], parent);
        }
    }

    // check if this layer has drawable
    if (node->mNodeList.size) {
        for (unsigned int i = 0; i < node->mNodeList.size; i++) {
            createVgNode(node->mNodeList.ptr[i], parent);
        }
    }
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


    mPos = mapProgress(pos);

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
            rlottie::Surface surface(buffer, width, height, bytesperline);
            mRenderTask = mPlayer->render(mCurFrame, surface);
            // to force a redraw
            evas_object_image_data_update_add(mImage, 0 , 0, surface.width(), surface.height());
        } else {
            auto buffer = (uint32_t *)evas_object_image_data_get(mImage, EINA_TRUE);
            size_t bytesperline =  evas_object_image_stride_get(mImage);
            rlottie::Surface surface(buffer, width, height, bytesperline);
            mPlayer->renderSync(mCurFrame, surface);
            evas_object_image_data_set(mImage, surface.buffer());
            evas_object_image_data_update_add(mImage, 0 , 0, surface.width(), surface.height());
        }
    } else {
        const LOTLayerNode *root = mPlayer->renderTree(mCurFrame, mw, mh);
        updateTree(root);
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

void LottieView::loadFromData(const std::string &jsonData, const std::string &key, const std::string &resourcePath)
{
    if (mPlayer = Animation::loadFromData(jsonData, key, resourcePath)) {
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

    if (mAnimator) ecore_animator_del(mAnimator);
    mAnimator = ecore_animator_timeline_add(duration()/mSpeed, animator, this);
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

        if (mAnimator) ecore_animator_del(mAnimator);
        mAnimator = ecore_animator_timeline_add(duration()/mSpeed, animator, this);
    }
}
