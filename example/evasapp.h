#ifndef EVASAPP_H
#define EVASAPP_H

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
#include <Ecore_Input.h>
#include<vector>
#include<string>


typedef void (*appCb)(void *userData, void *extra);
class EvasApp
{
public:
    EvasApp(int w, int h);
    void setup();
    void resize(int w, int h);
    int width() const{ return mw;}
    int height() const{ return mh;}
    void run();
    Ecore_Evas * ee() const{return mEcoreEvas;}
    Evas * evas() const {return mEvas;}
    void addExitCb(appCb exitcb, void *data) {mExitCb = exitcb; mExitData = data;}
    void addResizeCb(appCb resizecb, void *data) {mResizeCb = resizecb; mResizeData = data;}
    void addKeyCb(appCb keycb, void *data) {mKeyCb = keycb; mKeyData = data;}
    void addRenderPreCb(appCb renderPrecb, void *data) {mRenderPreCb = renderPrecb; mRenderPreData = data;}
    void addRenderPostCb(appCb renderPostcb, void *data) {mRenderPostCb = renderPostcb; mRenderPostData = data;}
    static std::vector<std::string> jsonFiles(const std::string &dir, bool recurse=false);
public:
    int           mw;
    int           mh;
    Ecore_Evas   *mEcoreEvas;
    Evas         *mEvas;
    Evas_Object  *mBackground;
    appCb        mResizeCb;
    void        *mResizeData;
    appCb        mExitCb;
    void        *mExitData;
    appCb        mKeyCb;
    void        *mKeyData;
    appCb        mRenderPreCb;
    void        *mRenderPreData;
    appCb        mRenderPostCb;
    void        *mRenderPostData;
};
#endif //EVASAPP_H
