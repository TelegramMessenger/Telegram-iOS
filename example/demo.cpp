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

#include "evasapp.h"
#include "lottieview.h"
#include<iostream>
#include <stdio.h>
#include <fstream>
#include <sstream>
using namespace std;

static void
onExitCb(void *data, void *extra)
{
    LottieView *view = (LottieView *)data;
    delete view;
}

static void
onRenderPreCb(void *data, void *extra)
{
    LottieView *view = (LottieView *)data;
    view->render();
}

int
main(void)
{
   EvasApp *app = new EvasApp(800, 800);
   app->setup();

   std::string filePath = DEMO_DIR;
   filePath +="mask.json";

   std::ifstream f;
   f.open(filePath);
   std::stringstream buf;
   buf << f.rdbuf();
   f.close();

   LottieView *view = new LottieView(app->evas());
   view->loadFromData(buf.str().data(), "test_key");
   view->setPos(0, 0);
   view->setSize(800, 800);
   view->show();
   view->play();
   view->loop(true);
   view->setRepeatMode(LottieView::RepeatMode::Reverse);

   app->addExitCb(onExitCb, view);
   app->addRenderPreCb(onRenderPreCb, view);
   app->run();
   delete app;
   return 0;
}





