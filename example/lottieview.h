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
class LottieView
{
public:
    enum class RepeatMode {
        Restart,
        Reverse
    };
    LottieView(Evas *evas, bool renderMode = true, bool asyncRender = true);
    ~LottieView();
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
    float getFrameRate() const { return mFrameRate; }
    long getTotalFrame() const { return mTotalFrame; }
public:
    void seek(float pos);
    float getPos();
    void finished();
    void play();
    void pause();
    void stop();
    void render();
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
        return  mPlayer->duration() * fabs(mMaxprogress - mMinProgress);
    }
    void createVgNode(LOTNode *node, Efl_VG *root);
    void update(const std::vector<LOTNode *> &);
    void updateTree(const LOTLayerNode *);
    void update(const LOTLayerNode *, Efl_VG *parent);
    void restart();
public:
    int                      mw;
    int                      mh;
    Evas                    *mEvas;
    Efl_VG                  *mRoot;
    Evas_Object             *mVg;
    int                      mRepeatCount;
    LottieView::RepeatMode   mRepeatMode;
    std::unique_ptr<rlottie::Animation>       mPlayer;
    size_t                   mCurFrame{UINT_MAX};
    Ecore_Animator          *mAnimator{nullptr};
    bool                     mLoop;
    int                      mCurCount;
    bool                     mReverse;
    bool                     mPalying;
    Evas_Object             *mImage;
    float                    mSpeed;
    bool                     mRenderMode;
    bool                     mAsyncRender;
    bool                     mDirty;
    float                    mPos;
    float                    mFrameRate;
    long                     mTotalFrame;
    std::future<rlottie::Surface>        mRenderTask;

    //keep a segment of the animation default is [0, 1]
    float                   mMinProgress{0};
    float                   mMaxprogress{1};
};

class LottieViewCApi
{
public:
private:
    Evas                    *mEvas;
    Lottie_Animation        *mAnimation;
};

#endif //LOTTIEVIEW_H
