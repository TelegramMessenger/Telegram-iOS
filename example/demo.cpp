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
   filePath +="circuit.json";

   LottieView *view = new LottieView(app->evas());
   view->setFilePath(filePath.c_str());
   if (view->player()) {
       view->player()->setValue<rlottie::Property::FillColor>("**", rlottie::Color(0, 1, 0));
   }
   view->setPos(0, 0);
   view->setSize(800, 800);
   view->show();
//   view->setMinProgress(0.5);
//   view->setMaxProgress(0.0);
   view->play();
   view->loop(true);
   view->setRepeatMode(LottieView::RepeatMode::Reverse);

   app->addExitCb(onExitCb, view);
   app->addRenderPreCb(onRenderPreCb, view);
   app->run();
   delete app;
   return 0;
}





