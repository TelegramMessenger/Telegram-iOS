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
  LottieViewTest(EvasApp *app, Strategy st) {
      mStrategy = st;
      mApp = app;
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
        std::unique_ptr<LottieView> view(new LottieView(mApp->evas(), mStrategy));
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
  Strategy     mStrategy;
  std::vector<std::unique_ptr<LottieView>>   mViews;
};

static void
onExitCb(void *data, void */*extra*/)
{
    LottieViewTest *view = (LottieViewTest *)data;
    delete view;
}

static void
onRenderPreCb(void *data, void */*extra*/)
{
    LottieViewTest *view = (LottieViewTest *)data;
    view->render();
}

int
main(int argc, char **argv)
{
    if (argc > 1) {
        if (!strcmp(argv[1],"--help") || !strcmp(argv[1],"-h")) {
            printf("Usage ./lottieviewTest 1 \n");
            printf("\t 0  - Test Lottie SYNC Renderer with CPP API\n");
            printf("\t 1  - Test Lottie ASYNC Renderer with CPP API\n");
            printf("\t 2  - Test Lottie SYNC Renderer with C API\n");
            printf("\t 3  - Test Lottie ASYNC Renderer with C API\n");
            printf("\t 4  - Test Lottie Tree Api using Efl VG Render\n");
            printf("\t Default is ./lottieviewTest 1 \n");
            return 0;
        }
    } else {
        printf("Run ./lottieviewTest -h  for more option\n");
    }

   EvasApp *app = new EvasApp(800, 800);
   app->setup();

   Strategy st = Strategy::renderCppAsync;
   if (argc > 1) {
       int option = atoi(argv[1]);
       st = static_cast<Strategy>(option);
   }
   LottieViewTest *view = new LottieViewTest(app, st);
   view->show(250);

   app->addExitCb(onExitCb, view);
   app->addRenderPreCb(onRenderPreCb, view);

   app->run();
   delete app;
   return 0;
}





