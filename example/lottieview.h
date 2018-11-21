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
#include "lottieanimation.h"
#include "lottieanimation_capi.h"
#include<future>
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
    void loadFromData(const std::string &jsonData, const std::string &key);
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
private:
    void createVgNode(LOTNode *node, Efl_VG *root);
    void update(const std::vector<LOTNode *> &);
    void restart();
public:
    int                      mw;
    int                      mh;
    Evas                    *mEvas;
    Efl_VG                  *mRoot;
    Evas_Object             *mVg;
    int                      mRepeatCount;
    LottieView::RepeatMode   mRepeatMode;
    std::unique_ptr<lottie::Animation>       mPlayer;
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
    float                    mStartPos;
    float                    mPos;
    float                    mFrameRate;
    long                     mTotalFrame;
    std::future<lottie::Surface>        mRenderTask;
};

class LottieViewCApi
{
public:
private:
    Evas                    *mEvas;
    Lottie_Animation        *mAnimation;
};

#endif //LOTTIEVIEW_H
