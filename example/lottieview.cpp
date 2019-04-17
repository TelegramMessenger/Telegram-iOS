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

LottieView::LottieView(Evas *evas, Strategy s) {
    mPalying = false;
    mReverse = false;
    mRepeatCount = 0;
    mRepeatMode = LottieView::RepeatMode::Restart;
    mLoop = false;
    mSpeed = 1;

    switch (s) {
    case Strategy::renderCpp: {
        mRenderDelegate = std::make_unique<RlottieRenderStrategy_CPP>(evas);
        break;
    }
    case Strategy::renderCppAsync: {
        mRenderDelegate = std::make_unique<RlottieRenderStrategy_CPP_ASYNC>(evas);
        break;
    }
    case Strategy::renderC: {
        mRenderDelegate = std::make_unique<RlottieRenderStrategy_C>(evas);
        break;
    }
    case Strategy::renderCAsync: {
        mRenderDelegate = std::make_unique<RlottieRenderStrategy_C_ASYNC>(evas);
        break;
    }
    case Strategy::eflVg: {
        mRenderDelegate = std::make_unique<EflVgRenderStrategy>(evas);
        break;
    }
    default:
        mRenderDelegate = std::make_unique<RlottieRenderStrategy_CPP>(evas);
        break;
    }
}

LottieView::~LottieView()
{
    if (mAnimator) ecore_animator_del(mAnimator);
}

Evas_Object *LottieView::getImage() {
    return mRenderDelegate->renderObject();
}

void LottieView::show()
{
    mRenderDelegate->show();
    seek(0);
}

void LottieView::hide()
{
    mRenderDelegate->hide();
}

void LottieView::seek(float pos)
{
    if (!mRenderDelegate) return;


    mPos = mapProgress(pos);

    // check if the pos maps to the current frame
    if (mCurFrame == mRenderDelegate->frameAtPos(mPos)) return;

    mCurFrame = mRenderDelegate->frameAtPos(mPos);

    mRenderDelegate->renderRequest(mCurFrame);
}

float LottieView::getPos()
{
   return mPos;
}

void LottieView::render()
{
    mRenderDelegate->renderFlush();
}

void LottieView::setFilePath(const char *filePath)
{
    mRenderDelegate->loadFromFile(filePath);
}

void LottieView::loadFromData(const std::string &jsonData, const std::string &key, const std::string &resourcePath)
{
    mRenderDelegate->loadFromData(jsonData, key, resourcePath);
}

void LottieView::setSize(int w, int h)
{
    mRenderDelegate->resize(w, h);
}

void LottieView::setPos(int x, int y)
{
    mRenderDelegate->setPos(x, y);
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
