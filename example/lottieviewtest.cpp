/*
 * Copyright (c) 2018 Samsung Electronics Co., Ltd. All rights reserved.
 *
 * Licensed under the LGPL License, Version 2.1 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     https://www.gnu.org/licenses/
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
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





