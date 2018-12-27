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

#include <Elementary.h>
#include "lottieview.h"
#include<iostream>
#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <dirent.h>
#include <error.h>
#include <algorithm>

using namespace std;

typedef struct _AppInfo AppInfo;
struct _AppInfo {
   LottieView *view;
   Evas_Object *layout;
   Evas_Object *slider;
   Evas_Object *button;
   Ecore_Evas *ee;
   Eina_Bool autoPlaying;
};

typedef struct _ItemData ItemData;
struct _ItemData {
   int index;
};


std::vector<std::string> jsonFiles;
bool renderMode = true;

static void
_layout_del_cb(void *data, Evas *, Evas_Object *, void *)
{
   AppInfo *info = (AppInfo *)data;
   if (info->view) delete info->view;
   info->view = NULL;

   ecore_evas_data_set(info->ee, "AppInfo", NULL);

   free(info);
}

static void
_update_frame_info(AppInfo *info, double pos)
{
   int frameNo = pos * info->view->getTotalFrame();
   char buf[64];

   sprintf(buf, "%d / %ld", frameNo, info->view->getTotalFrame());
   elm_object_part_text_set(info->layout, "text", buf);
}

static void
_toggle_start_button(AppInfo *info)
{
   if (!info->autoPlaying)
     {
        info->autoPlaying = EINA_TRUE;
        info->view->play();
        elm_object_text_set(info->button, "Stop");
     }
   else
     {
        info->autoPlaying = EINA_FALSE;
        info->view->stop();
        elm_object_text_set(info->button, "Start");
     }
}

static void
_ee_pre_render_cb(Ecore_Evas *ee)
{
    AppInfo *info = (AppInfo *)ecore_evas_data_get(ee, "AppInfo");

    if (info && info->autoPlaying && info->view)
      {
         float pos = info->view->getPos();
         _update_frame_info(info, pos);
         elm_slider_value_set(info->slider, (double)pos);
         info->view->render();

         if (pos >= 1.0)
           _toggle_start_button(info);
      }
}

static void
_slider_cb(void *data, Evas_Object *obj, void *event_info EINA_UNUSED)
{
   double val = elm_slider_value_get(obj);
   AppInfo *info = (AppInfo *)data;

   _update_frame_info(info, val);

   if (!info->autoPlaying)
     {
        info->view->seek(val);
        info->view->render();
     }
}

static void
_button_clicked_cb(void *data, Evas_Object *obj, void *event_info)
{
   AppInfo *info = (AppInfo *)data;

   _toggle_start_button(info);
}

Evas_Object *
create_layout(Evas_Object *parent, const char *file)
{
   Evas_Object *layout, *slider, *image, *button;
   Evas *e;
   Ecore_Evas *ee;
   char buf[64];
   AppInfo *info = (AppInfo *)calloc(sizeof(AppInfo), 1);

   //LAYOUT
   layout = elm_layout_add(parent);
   evas_object_show(layout);
   evas_object_size_hint_weight_set(layout, EVAS_HINT_EXPAND, EVAS_HINT_EXPAND);

   std::string edjPath = DEMO_DIR;
   edjPath +="layout.edj";

   elm_layout_file_set(layout, edjPath.c_str(), "layout");

   //LOTTIEVIEW
   LottieView *view = new LottieView(evas_object_evas_get(layout), renderMode);
   std::string filePath = DEMO_DIR;
   filePath +=file;

   view->setFilePath(filePath.c_str());
   view->setSize(500, 500);

   //IMAGE from LOTTIEVIEW
   image = view->getImage();
   evas_object_show(image);
   evas_object_size_hint_min_set(image, 500, 500);
   elm_object_part_content_set(layout, "lottie", image);

   //SLIDER
   slider = elm_slider_add(layout);
   elm_object_part_content_set(layout, "slider", slider);
   evas_object_smart_callback_add(slider, "changed", _slider_cb, (void *)info);

   button = elm_button_add(layout);
   elm_object_text_set(button, "Start");
   elm_object_part_content_set(layout, "button", button);
   evas_object_smart_callback_add(button, "clicked", _button_clicked_cb, (void *)info);

   e = evas_object_evas_get(layout);
   ee = ecore_evas_ecore_evas_get(e);
   ecore_evas_data_set(ee, "AppInfo", info);
   ecore_evas_callback_pre_render_set(ee, _ee_pre_render_cb);

   info->view = view;
   info->layout = layout;
   info->slider = slider;
   info->button = button;
   info->ee = ee;
   evas_object_event_callback_add(layout, EVAS_CALLBACK_DEL, _layout_del_cb, (void *)info);

   sprintf(buf, "%d / %ld", 0, view->getTotalFrame());
   elm_object_part_text_set(layout, "text", buf);

   view->seek(0.0);
   view->render();

   return layout;
}

static void
_gl_selected_cb(void *data, Evas_Object *obj, void *event_info)
{
   Evas_Object *nf = (Evas_Object *)data;
   Elm_Object_Item *it = (Elm_Object_Item *)event_info;
   elm_genlist_item_selected_set(it, EINA_FALSE);

   Evas_Object *layout = create_layout(nf, jsonFiles[elm_genlist_item_index_get(it) - 1].c_str());
   elm_naviframe_item_push(nf, NULL, NULL, NULL, layout, NULL);
}

static char *
_gl_text_get(void *data, Evas_Object *obj, const char *part)
{
   ItemData *id = (ItemData *) data;
   return strdup(jsonFiles[id->index].c_str());
}

static void
_gl_del(void *data, Evas_Object *obj)
{
}

EAPI_MAIN int
elm_main(int argc EINA_UNUSED, char **argv EINA_UNUSED)
{
   Evas_Object *win, *nf, *genlist;
   Elm_Genlist_Item_Class *itc = elm_genlist_item_class_new();
   ItemData *itemData;
   DIR *dir;
   struct dirent *ent;

   if (argc > 1) {
      if (!strcmp(argv[1], "--disable-render"))
         renderMode = false;
   }

   //WIN	
   elm_policy_set(ELM_POLICY_QUIT, ELM_POLICY_QUIT_LAST_WINDOW_CLOSED);
   win = elm_win_util_standard_add("lottie", "LottieViewer");
   elm_win_autodel_set(win, EINA_TRUE);
   evas_object_resize(win, 500, 700);
   evas_object_show(win);

   //NAVIFRAME
   nf = elm_naviframe_add(win);
   evas_object_size_hint_weight_set(nf, EVAS_HINT_EXPAND, EVAS_HINT_EXPAND);
   elm_win_resize_object_add(win, nf);
   evas_object_show(nf);

   //GENLIST
   genlist = elm_genlist_add(nf);
   elm_genlist_mode_set(genlist, ELM_LIST_COMPRESS);
   evas_object_smart_callback_add(genlist, "selected", _gl_selected_cb, nf);

   itc->item_style = "default";
   itc->func.text_get = _gl_text_get;
   itc->func.del = _gl_del;

   std::string rscPath = DEMO_DIR;

   dir = opendir(rscPath.c_str());
   while ((ent = readdir(dir)) != NULL) {
      if (!strncmp(ent->d_name + (strlen(ent->d_name) - 4), "json", 4)) {
         jsonFiles.push_back(ent->d_name);
      }
   }
   closedir(dir);

   std::sort(jsonFiles.begin(), jsonFiles.end(), [](auto & a, auto &b){return a < b;});

   for (uint i = 0; i < jsonFiles.size(); i++) {
      itemData = (ItemData *)calloc(sizeof(ItemData), 1);
      itemData->index = i;
      elm_genlist_item_append(genlist, itc, (void *)itemData, NULL, ELM_GENLIST_ITEM_NONE, NULL, NULL);
   }

   elm_naviframe_item_push(nf, "Lottie Viewer", NULL, NULL, genlist, NULL);

   elm_run();

   return 0;
}
ELM_MAIN()
