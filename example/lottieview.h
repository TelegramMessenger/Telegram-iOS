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

#ifndef LOTTIEVIEW_H
#define LOTTIEVIEW_H

#ifndef EFL_BETA_API_SUPPORT
#define EFL_BETA_API_SUPPORT
#endif

#ifndef EFL_EO_API_SUPPORT
#define EFL_EO_API_SUPPORT
#endif

#include <Eo.h>
#include <Efl.h>
#include <Evas.h>
#include <Ecore.h>
#include <Ecore_Evas.h>
#include "rlottie.h"
#include "rlottie_capi.h"
#include<future>
#include <cmath>

class RenderStrategy {
public:
    virtual ~RenderStrategy() {
        evas_object_del(renderObject());
    }
    RenderStrategy(Evas_Object *obj):_renderObject(obj){
        addCallback();
    }
    virtual rlottie::Animation *player() {return nullptr;}
    virtual void loadFromFile(const char *filePath) = 0;
    virtual void loadFromData(const std::string &jsonData, const std::string &key, const std::string &resourcePath) = 0;
    virtual size_t totalFrame() = 0;
    virtual double frameRate() = 0;
    virtual size_t frameAtPos(double pos) = 0;
    virtual double duration() = 0;
    void render(int frame) {
        _redraw = renderRequest(frame);
        if (_redraw)
            evas_object_image_pixels_dirty_set(renderObject(), EINA_TRUE);
    }
    void dataCb() {
        if (_redraw) {
            evas_object_image_data_set(renderObject(), buffer());
        }
        _redraw = false;
    }
    virtual void resize(int width, int height) = 0;
    virtual void setPos(int x, int y) {evas_object_move(renderObject(), x, y);}
    void show() {evas_object_show(_renderObject);}
    void hide() {evas_object_hide(_renderObject);}
    void addCallback();
    Evas_Object* renderObject() const {return _renderObject;}
protected:
    virtual bool renderRequest(int) = 0;
    virtual uint32_t* buffer() = 0;
private:
    bool         _redraw{false};
    Evas_Object *_renderObject;
};

class CppApiBase : public RenderStrategy {
public:
    CppApiBase(Evas_Object *renderObject): RenderStrategy(renderObject) {}
    rlottie::Animation *player() {return mPlayer.get();}
    void loadFromFile(const char *filePath)
    {
        mPlayer = rlottie::Animation::loadFromFile(filePath);

        if (!mPlayer) {
            printf("load failed file %s\n", filePath);
        }
    }

    void loadFromData(const std::string &jsonData, const std::string &key, const std::string &resourcePath)
    {
        mPlayer = rlottie::Animation::loadFromData(jsonData, key, resourcePath);
        if (!mPlayer) {
            printf("load failed from data\n");
        }
    }

    size_t totalFrame() {
        return mPlayer->totalFrame();

    }
    double duration() {
        return mPlayer->duration();
    }

    double frameRate() {
        return mPlayer->frameRate();
    }

    size_t frameAtPos(double pos) {
        return  mPlayer->frameAtPos(pos);
    }
protected:
   std::unique_ptr<rlottie::Animation>       mPlayer;
};

class RlottieRenderStrategyCBase : public RenderStrategy {
public:
    RlottieRenderStrategyCBase(Evas *evas):RenderStrategy(evas_object_image_filled_add(evas)) {
        evas_object_image_colorspace_set(renderObject(), EVAS_COLORSPACE_ARGB8888);
        evas_object_image_alpha_set(renderObject(), EINA_TRUE);
    }
    void resize(int width, int height) {
        evas_object_resize(renderObject(), width, height);
        evas_object_image_size_set(renderObject(), width, height);
    }
};

class RlottieRenderStrategy : public CppApiBase {
public:
    RlottieRenderStrategy(Evas *evas):CppApiBase(evas_object_image_filled_add(evas)) {
        evas_object_image_colorspace_set(renderObject(), EVAS_COLORSPACE_ARGB8888);
        evas_object_image_alpha_set(renderObject(), EINA_TRUE);
    }
    void resize(int width, int height) {
        evas_object_resize(renderObject(), width, height);
        evas_object_image_size_set(renderObject(), width, height);
    }
};

class RlottieRenderStrategy_CPP : public RlottieRenderStrategy {
public:
    RlottieRenderStrategy_CPP(Evas *evas):RlottieRenderStrategy(evas) {}

    bool renderRequest(int frame) {
        int width , height;
        Evas_Object *image = renderObject();
        evas_object_image_size_get(image, &width, &height);
        mBuffer = (uint32_t *)evas_object_image_data_get(image, EINA_TRUE);
        size_t bytesperline =  evas_object_image_stride_get(image);
        rlottie::Surface surface(mBuffer, width, height, bytesperline);
        mPlayer->renderSync(frame, surface);
        return true;
    }
    uint32_t* buffer() {
        return mBuffer;
    }

private:
    uint32_t *              mBuffer;
};

class RlottieRenderStrategy_CPP_ASYNC : public RlottieRenderStrategy {
public:
    RlottieRenderStrategy_CPP_ASYNC(Evas *evas):RlottieRenderStrategy(evas) {}
    ~RlottieRenderStrategy_CPP_ASYNC() {
        if (mRenderTask.valid())
            mRenderTask.get();
    }
    bool renderRequest(int frame) {
        //addCallback();
        if (mRenderTask.valid()) return true;
        int width , height;
        Evas_Object *image = renderObject();
        evas_object_image_size_get(image, &width, &height);
        auto buffer = (uint32_t *)evas_object_image_data_get(image, EINA_TRUE);
        size_t bytesperline =  evas_object_image_stride_get(image);
        rlottie::Surface surface(buffer, width, height, bytesperline);
        mRenderTask = mPlayer->render(frame, surface);
        return true;
    }

    uint32_t* buffer() {
        auto surface = mRenderTask.get();
        return surface.buffer();
    }
private:
   std::future<rlottie::Surface>        mRenderTask;
};


class RlottieRenderStrategy_C : public RlottieRenderStrategyCBase {
public:
    RlottieRenderStrategy_C(Evas *evas):RlottieRenderStrategyCBase(evas) {}
    ~RlottieRenderStrategy_C() {
        if (mPlayer) lottie_animation_destroy(mPlayer);
    }
    void loadFromFile(const char *filePath)
    {
        mPlayer = lottie_animation_from_file(filePath);

        if (!mPlayer) {
            printf("load failed file %s\n", filePath);
        }
    }

    void loadFromData(const std::string &jsonData, const std::string &key, const std::string &resourcePath)
    {
        mPlayer = lottie_animation_from_data(jsonData.c_str(), key.c_str(), resourcePath.c_str());
        if (!mPlayer) {
            printf("load failed from data\n");
        }
    }

    size_t totalFrame() {
        return lottie_animation_get_totalframe(mPlayer);

    }

    double frameRate() {
        return lottie_animation_get_framerate(mPlayer);
    }

    size_t frameAtPos(double pos) {
        return  lottie_animation_get_frame_at_pos(mPlayer, pos);
    }

    double duration() {
        return lottie_animation_get_duration(mPlayer);
    }

    bool renderRequest(int frame) {
        int width , height;
        Evas_Object *image = renderObject();
        evas_object_image_size_get(image, &width, &height);
        mBuffer = (uint32_t *)evas_object_image_data_get(image, EINA_TRUE);
        size_t bytesperline =  evas_object_image_stride_get(image);
        lottie_animation_render(mPlayer, frame, mBuffer, width, height, bytesperline);
        return true;
    }

    uint32_t* buffer() {
        return mBuffer;
    }

private:
    uint32_t *              mBuffer;
protected:
   Lottie_Animation       *mPlayer;
};

class RlottieRenderStrategy_C_ASYNC : public RlottieRenderStrategy_C {
public:
    RlottieRenderStrategy_C_ASYNC(Evas *evas):RlottieRenderStrategy_C(evas) {}
    ~RlottieRenderStrategy_C_ASYNC() {
        if (mDirty) lottie_animation_render_flush(mPlayer);
    }
    bool renderRequest(int frame) {
        if (mDirty) return true;
        mDirty = true;
        Evas_Object *image = renderObject();
        evas_object_image_size_get(image, &mWidth, &mHeight);
        mBuffer = (uint32_t *)evas_object_image_data_get(image, EINA_TRUE);
        size_t bytesperline =  evas_object_image_stride_get(image);
        lottie_animation_render_async(mPlayer, frame, mBuffer, mWidth, mHeight, bytesperline);
        return true;
    }

    uint32_t* buffer() {
       lottie_animation_render_flush(mPlayer);
       mDirty =false;
       return mBuffer;
    }

private:
   uint32_t *              mBuffer;
   int                     mWidth;
   int                     mHeight;
   bool                    mDirty{false};
};

enum class  Strategy {
  renderCpp = 0,
  renderCppAsync,
  renderC,
  renderCAsync,
  eflVg
};

class LottieView
{
public:
    enum class RepeatMode {
        Restart,
        Reverse
    };
    LottieView(Evas *evas, Strategy s = Strategy::renderCppAsync);
    ~LottieView();
    rlottie::Animation *player(){return mRenderDelegate->player();}
    Evas_Object *getImage();
    void setSize(int w, int h);
    void setPos(int x, int y);
    void setFilePath(const char *filePath);
    void loadFromData(const std::string &jsonData, const std::string &key, const std::string &resourcePath="");
    void show();
    void hide();
    void loop(bool loop);
    void setSpeed(float speed) { mSpeed = speed;}
    void setRepeatCount(int count);
    void setRepeatMode(LottieView::RepeatMode mode);
    float getFrameRate() const { return mRenderDelegate->frameRate(); }
    long getTotalFrame() const { return mRenderDelegate->totalFrame(); }
public:
    void seek(float pos);
    float getPos();
    void finished();
    void play();
    void pause();
    void stop();
    void initializeBufferObject(Evas *evas);
    void setMinProgress(float progress)
    {
        //clamp it to [0,1]
        mMinProgress = progress;
    }
    void setMaxProgress(float progress)
    {
        //clamp it to [0,1]
        mMaxprogress = progress;
    }
private:
    float mapProgress(float progress) {
        //clamp it to the segment
        progress = (mMinProgress + (mMaxprogress - mMinProgress) * progress);

        // currently playing and in reverse mode
        if (mPalying && mReverse)
            progress = mMaxprogress > mMinProgress ?
                        mMaxprogress - progress : mMinProgress - progress;


        return progress;
    }
    float duration() const {
        // usually we run the animation for mPlayer->duration()
        // but now run animation for segmented duration.
        return  mRenderDelegate->duration() * fabs(mMaxprogress - mMinProgress);
    }
    void createVgNode(LOTNode *node, Efl_VG *root);
    void update(const std::vector<LOTNode *> &);
    void updateTree(const LOTLayerNode *);
    void update(const LOTLayerNode *, Efl_VG *parent);
    void restart();
public:
    int                      mRepeatCount;
    LottieView::RepeatMode   mRepeatMode;
    size_t                   mCurFrame{UINT_MAX};
    Ecore_Animator          *mAnimator{nullptr};
    bool                     mLoop;
    int                      mCurCount;
    bool                     mReverse;
    bool                     mPalying;
    float                    mSpeed;
    float                    mPos;
    //keep a segment of the animation default is [0, 1]
    float                   mMinProgress{0};
    float                   mMaxprogress{1};
    std::unique_ptr<RenderStrategy>  mRenderDelegate;
};

#include<assert.h>
class EflVgRenderStrategy : public CppApiBase {
    int mW;
    int mH;
public:
    EflVgRenderStrategy(Evas *evas):CppApiBase(evas_object_vg_add(evas)) {}

    void resize(int width, int height) {
        mW = width;
        mH = height;
        evas_object_resize(renderObject(), width, height);
    }

    uint32_t *buffer() {
        assert(false);
    }

    bool renderRequest(int frame) {
        const LOTLayerNode *root = mPlayer->renderTree(frame, mW, mH);
        updateTree(root);
        return false;
    }

    void updateTree(const LOTLayerNode * node)
    {
        Efl_VG *root = evas_vg_container_add(renderObject());
        update(node, root);
        evas_object_vg_root_node_set(renderObject(), root);
    }

    void createVgNode(LOTNode *node, Efl_VG *root)
    {
        Efl_VG *shape = evas_vg_shape_add(root);

        //0: Path
        const float *data = node->mPath.ptPtr;
        if (!data) return;

        for (size_t i = 0; i < node->mPath.elmCount; i++) {
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
//        if (node->mFillRule == FillEvenOdd)
//          efl_gfx_shape_fill_rule_set(shape, EFL_GFX_FILL_RULE_ODD_EVEN);
//        else if (node->mFillRule == FillWinding)
//          efl_gfx_shape_fill_rule_set(shape, EFL_GFX_FILL_RULE_WINDING);
    }

    void update(const std::vector<LOTNode *> &renderList)
    {
        Efl_VG *root = evas_vg_container_add(renderObject());
        for(auto i : renderList) {
            createVgNode(i, root);
        }
        evas_object_vg_root_node_set(renderObject(), root);
    }

    void update(const LOTLayerNode * node, Efl_VG *parent)
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
};

#endif //LOTTIEVIEW_H
