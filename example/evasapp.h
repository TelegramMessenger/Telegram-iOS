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
    int           mw{0};
    int           mh{0};
    Ecore_Evas   *mEcoreEvas{nullptr};
    Evas         *mEvas{nullptr};
    Evas_Object  *mBackground{nullptr};
    appCb        mResizeCb{nullptr};
    void        *mResizeData{nullptr};
    appCb        mExitCb{nullptr};
    void        *mExitData{nullptr};
    appCb        mKeyCb{nullptr};
    void        *mKeyData{nullptr};
    appCb        mRenderPreCb{nullptr};
    void        *mRenderPreData{nullptr};
    appCb        mRenderPostCb{nullptr};
    void        *mRenderPostData{nullptr};
};
#endif //EVASAPP_H
