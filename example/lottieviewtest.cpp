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

#include "evasapp.h"
#include "lottieview.h"
#include<iostream>
#include <dirent.h>
#include <stdio.h>
using namespace std;

/*
 * To check the frame rate with rendermode off run
 * ECORE_EVAS_FPS_DEBUG=1 ./lottieviewTest --disable-render
 *
 * To check the frame rate with  render backend
 * ECORE_EVAS_FPS_DEBUG=1 ./lottieviewTest
 *
 */

class LottieViewTest
{
public:
  LottieViewTest(EvasApp *app, bool renderMode) {
      mApp = app;
      mRenderMode = renderMode;
      ecore_animator_frametime_set(1.0/120.0);
  }

  void show(int numberOfImage) {
    auto resource = EvasApp::jsonFiles(std::string(DEMO_DIR));

    if (resource.empty()) return;

    int count = numberOfImage;
    int colums = (int) ceil(sqrt(count));
    int offset = 3;
    int vw = (mApp->width() - (offset * colums))/colums;
    int vh = vw;
    int posx = offset;
    int posy = offset;
    int resourceSize = resource.size();
    for (int i = 0 ; i < numberOfImage; i++) {
        int index = i % resourceSize;
        std::unique_ptr<LottieView> view(new LottieView(mApp->evas(), mRenderMode));
        view->setFilePath(resource[index].c_str());
        view->setPos(posx, posy);
        view->setSize(vw, vh);
        view->show();
        view->play();
        view->loop(true);
        //view->setRepeatMode(LottieView::RepeatMode::Reverse);

        posx += vw+offset;
        if ((mApp->width() - posx) < vw) {
          posx = offset;
          posy = posy + vh + offset;
        }
        mViews.push_back(std::move(view));
    }
  }

  void render() {
      //auto clock = std::chrono::high_resolution_clock::now();
      for (auto &i : mViews) {
          i->render();
      }
      //double d = std::chrono::duration<double, std::milli>(std::chrono::high_resolution_clock::now()-clock).count();
      //printf("total time taken = %f\n", d);
  }

public:
  EvasApp     *mApp;
  bool         mRenderMode = false;
  std::vector<std::unique_ptr<LottieView>>   mViews;
};

static void
onExitCb(void *data, void *extra)
{
    LottieViewTest *view = (LottieViewTest *)data;
    delete view;
}

static void
onRenderPreCb(void *data, void *extra)
{
    LottieViewTest *view = (LottieViewTest *)data;
    view->render();
}

int
main(int argc, char **argv)
{
   EvasApp *app = new EvasApp(800, 800);
   app->setup();

   bool renderMode = true;
   if (argc > 1) {
       if (!strcmp(argv[1],"--disable-render"))
           renderMode = false;
   }
   LottieViewTest *view = new LottieViewTest(app, renderMode);
   view->show(250);

   app->addExitCb(onExitCb, view);
   app->addRenderPreCb(onRenderPreCb, view);

   app->run();
   delete app;
   return 0;
}





