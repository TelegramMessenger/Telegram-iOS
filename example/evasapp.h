/*
 * Copyright (c) 2018 Samsung Electronics Co., Ltd. All rights reserved.
 *
 * Licensed under the Flora License, Version 1.1 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://floralicense.org/license/
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

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
