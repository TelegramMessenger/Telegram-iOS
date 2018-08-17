#include <Elementary.h>
#include "lottieview.h"
#include<iostream>
#include <stdio.h>

using namespace std;

static void
_win_del_cb(void *data, Evas_Object *obj, void *event_info EINA_UNUSED)
{
    LottieView *view = (LottieView *)data;
    delete view;
}

static void
_slider_cb(void *data, Evas_Object *obj, void *event_info EINA_UNUSED)
{
   double val = elm_slider_value_get(obj);
   LottieView *view = (LottieView *)data;

   view->seek(val);
   view->render();
}

EAPI_MAIN int
elm_main(int argc EINA_UNUSED, char **argv EINA_UNUSED)
{
   Evas_Object *win, *layout, *slider, *image;
   bool renderMode = true;

   if (argc > 1) {
      if (!strcmp(argv[1], "--disable-render"))
         renderMode = false;
   }

   elm_policy_set(ELM_POLICY_QUIT, ELM_POLICY_QUIT_LAST_WINDOW_CLOSED);
   win = elm_win_util_standard_add("lottie", "LottieViewer");
   elm_win_autodel_set(win, EINA_TRUE);
   evas_object_resize(win, 500, 700);
   evas_object_show(win);

   layout = elm_layout_add(win);
   evas_object_show(layout);
   evas_object_size_hint_weight_set(layout, EVAS_HINT_EXPAND, EVAS_HINT_EXPAND);

   std::string edjPath = DEMO_DIR;
   edjPath +="layout.edj";

   elm_layout_file_set(layout, edjPath.c_str(), "layout");
   elm_win_resize_object_add(win, layout);

   std::string filePath = DEMO_DIR;
   filePath +="insta_camera.json";

   LottieView *view = new LottieView(evas_object_evas_get(win), renderMode);
   view->setFilePath(filePath.c_str());
   view->setSize(500, 500);

   evas_object_smart_callback_add(win, "delete,request", _win_del_cb, (void *)view);

   image = view->getImage();
   evas_object_show(image);
   evas_object_size_hint_min_set(image, 500, 500);
   elm_object_part_content_set(layout, "lottie", image);

   slider = elm_slider_add(layout);
   evas_object_show(slider);
   elm_object_part_content_set(layout, "slider", slider);
   evas_object_smart_callback_add(slider, "changed", _slider_cb, (void *)view);

   view->seek(0.0);
   view->render();

   elm_run();

   return 0;
}
ELM_MAIN()
