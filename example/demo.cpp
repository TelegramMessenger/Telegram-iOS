#include "evasapp.h"
#include "lottieview.h"
#include<iostream>
#include <stdio.h>
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

   LottieView *view = new LottieView(app->evas());
   view->setFilePath(filePath.c_str());
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





