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

#define EFL_BETA_API_SUPPORT 1
#define EFL_EO_API_SUPPORT 1

#include <Elementary.h>

#define WIDTH 400
#define HEIGHT 400

void
win_del(void *data EINA_UNUSED, Eo *o EINA_UNUSED, void *event_info EINA_UNUSED)
{
   elm_exit();
}

static void
btn_clicked_cb(void *data, Eo *obj, void *event_info EINA_UNUSED)
{
   Eo *anim_view = (Eo *) data;
   const char *text = elm_object_text_get(obj);

   if (!text) return;

   if (!strcmp("Play", text))
     elm_animation_view_play(anim_view);
   else if (!strcmp("Pause", text))
     elm_animation_view_pause(anim_view);
   else if (!strcmp("Resume", text))
     elm_animation_view_resume(anim_view);
   else if (!strcmp("Play Back", text))
     elm_animation_view_play_back(anim_view);
   else if (!strcmp("Stop", text))
     elm_animation_view_stop(anim_view);
}

static void
check_changed_cb(void *data, Eo *obj, void *event_info EINA_UNUSED)
{
   Eo *anim_view = (Eo *) data;
   elm_animation_view_auto_repeat_set(anim_view, elm_check_state_get(obj));
}

static void
speed_changed_cb(void *data, Eo *obj, void *event_info EINA_UNUSED)
{
   Eo *anim_view = (Eo *) data;
   double speed = 1;
   if (elm_check_state_get(obj)) speed = 0.25;
   elm_animation_view_speed_set(anim_view, speed);
}

static void
update_anim_view_state(Eo *anim_view, Eo *label)
{
   Elm_Animation_View_State state = elm_animation_view_state_get(anim_view);

   switch (state)
     {
      case ELM_ANIMATION_VIEW_STATE_NOT_READY:
         elm_object_text_set(label, "State = Not Ready");
         break;
      case ELM_ANIMATION_VIEW_STATE_PLAY:
         elm_object_text_set(label, "State = Playing");
         break;
      case ELM_ANIMATION_VIEW_STATE_PLAY_BACK:
         elm_object_text_set(label, "State = Playing Back");
         break;
      case ELM_ANIMATION_VIEW_STATE_PAUSE:
         elm_object_text_set(label, "State = Paused");
         break;
      case ELM_ANIMATION_VIEW_STATE_STOP:
         elm_object_text_set(label, "State = Stopped");
         break;
     }
}

static void
_play_done(void *data EINA_UNUSED, Eo *obj EINA_UNUSED, void *event_info EINA_UNUSED)
{
   printf("done!\n");
}

static void
_play_updated(void *data, Eo *obj, void *event_info EINA_UNUSED)
{
   Eo *slider = (Eo *) data;
   elm_slider_value_set(slider, elm_animation_view_progress_get(obj));
}

static void
_state_update(void *data, Eo *obj, void *event_info EINA_UNUSED)
{
   Eo *label = (Eo *) data;
   update_anim_view_state(obj, label);
}

static void
_play_repeated(void *data EINA_UNUSED, Eo *obj EINA_UNUSED, void *event_info EINA_UNUSED)
{
   printf("repeated!\n");
}

static void
_slider_drag_cb(void *data, Eo *obj, void *event_info EINA_UNUSED)
{
   Eo *anim_view = (Eo *) data;
   elm_animation_view_progress_set(anim_view, elm_slider_value_get(obj));
}

static void
_slider_reset(void *data, Eo *obj EINA_UNUSED, void *event_info EINA_UNUSED)
{
   Eo *slider = (Eo *) data;
   elm_slider_value_set(slider, 0);
}

Eo *
anim_view_test(Eo *parent, const char *path)
{
   Eo *box = elm_box_add(parent);
   evas_object_size_hint_weight_set(box, 1, 1);
   evas_object_show(box);

   //State Text
   Eo *label = elm_label_add(box);
   evas_object_size_hint_weight_set(label, EVAS_HINT_EXPAND, 0);
   evas_object_size_hint_align_set(label, 0.5, 0);
   evas_object_show(label);
   elm_box_pack_end(box, label);

   //Animation View
   Eo *anim_view = elm_animation_view_add(box);
   evas_object_size_hint_align_set(anim_view, EVAS_HINT_FILL, EVAS_HINT_FILL);
   elm_animation_view_file_set(anim_view, path, NULL);
   evas_object_size_hint_weight_set(anim_view, 1, 1);
   evas_object_show(anim_view);
   elm_box_pack_end(box, anim_view);

   //Controller Set: 0
   Eo *box2 = elm_box_add(box);
   evas_object_size_hint_weight_set(box2, EVAS_HINT_EXPAND, 0);
   evas_object_size_hint_align_set(box2, EVAS_HINT_FILL, 1);
   elm_box_horizontal_set(box2, EINA_TRUE);
   elm_box_pack_end(box, box2);
   evas_object_show(box2);


   //Loop
   Eo *check = elm_check_add(box2);
   evas_object_size_hint_weight_set(check, EVAS_HINT_EXPAND, 0);
   evas_object_size_hint_align_set(check, EVAS_HINT_FILL, EVAS_HINT_FILL);
   elm_object_text_set(check, "Loop");
   evas_object_smart_callback_add(check, "changed", check_changed_cb, anim_view);
   evas_object_show(check);
   elm_box_pack_end(box2, check);

   //Speed: 0.5x
   Eo *check2 = elm_check_add(box2);
   evas_object_size_hint_weight_set(check2, EVAS_HINT_EXPAND, 0);
   evas_object_size_hint_align_set(check2, EVAS_HINT_FILL, EVAS_HINT_FILL);
   elm_object_text_set(check2, "Speed: 0.25x");
   evas_object_smart_callback_add(check2, "changed", speed_changed_cb, anim_view);
   evas_object_show(check2);
   elm_box_pack_end(box2, check2);

   //Duration Text
   Eo *label2 = elm_label_add(box2);
   evas_object_size_hint_weight_set(label2, EVAS_HINT_EXPAND, 0);
   evas_object_size_hint_align_set(label2, 0.5, 0);
   evas_object_show(label2);
   elm_box_pack_end(box2, label2);
   char buf[50];
   snprintf(buf, sizeof(buf), "Duration: %1.2fs", elm_animation_view_duration_time_get(anim_view));
   elm_object_text_set(label2, buf);

   //Slider
   Eo *slider = elm_slider_add(box);
   elm_slider_indicator_show_set(slider, EINA_TRUE);
   elm_slider_indicator_format_set(slider, "%1.2f");
   elm_slider_min_max_set(slider, 0, 1);
   evas_object_size_hint_weight_set(slider, EVAS_HINT_EXPAND, 0);
   evas_object_size_hint_align_set(slider, EVAS_HINT_FILL, EVAS_HINT_FILL);
   evas_object_smart_callback_add(slider, "changed", _slider_drag_cb, anim_view);
   evas_object_show(slider);
   elm_box_pack_end(box, slider);

   //Controller Set: 1
   Eo *box3 = elm_box_add(box);
   evas_object_size_hint_weight_set(box3, EVAS_HINT_EXPAND, 0);
   evas_object_size_hint_align_set(box3, EVAS_HINT_FILL, 1);
   elm_box_horizontal_set(box3, EINA_TRUE);
   elm_box_pack_end(box, box3);
   evas_object_show(box3);

   Eo *btn;

   //Play Button
   btn = elm_button_add(box3);
   evas_object_size_hint_weight_set(btn, EVAS_HINT_EXPAND, 0);
   evas_object_size_hint_align_set(btn, EVAS_HINT_FILL, EVAS_HINT_FILL);
   elm_object_text_set(btn, "Play");
   evas_object_show(btn);
   evas_object_smart_callback_add(btn, "clicked", btn_clicked_cb, anim_view);
   elm_box_pack_end(box3, btn);

   //Play Back Button
   btn = elm_button_add(box3);
   evas_object_size_hint_weight_set(btn, EVAS_HINT_EXPAND, 0);
   evas_object_size_hint_align_set(btn, EVAS_HINT_FILL, EVAS_HINT_FILL);
   elm_object_text_set(btn, "Play Back");
   evas_object_smart_callback_add(btn, "clicked", btn_clicked_cb, anim_view);
   evas_object_show(btn);
   elm_box_pack_end(box3, btn);

   //Stop Button
   btn = elm_button_add(box3);
   evas_object_size_hint_weight_set(btn, EVAS_HINT_EXPAND, 0);
   evas_object_size_hint_align_set(btn, EVAS_HINT_FILL, EVAS_HINT_FILL);
   elm_object_text_set(btn, "Stop");
   evas_object_smart_callback_add(btn, "clicked", btn_clicked_cb, anim_view);
   evas_object_show(btn);
   elm_box_pack_end(box3, btn);

   //Controller Set: 2
   Eo *box4 = elm_box_add(box);
   evas_object_size_hint_weight_set(box4, EVAS_HINT_EXPAND, 0);
   evas_object_size_hint_align_set(box4, EVAS_HINT_FILL, 1);
   elm_box_horizontal_set(box4, EINA_TRUE);
   elm_box_pack_end(box, box4);
   evas_object_show(box4);

   //Pause Button
   btn = elm_button_add(box4);
   elm_object_text_set(btn, "Pause");
   evas_object_size_hint_weight_set(btn, EVAS_HINT_EXPAND, 0);
   evas_object_size_hint_align_set(btn, EVAS_HINT_FILL, EVAS_HINT_FILL);
   evas_object_smart_callback_add(btn, "clicked", btn_clicked_cb, anim_view);
   evas_object_show(btn);
   elm_box_pack_end(box4, btn);

   //Resume Button
   btn = elm_button_add(box4);
   evas_object_size_hint_weight_set(btn, EVAS_HINT_EXPAND, 0);
   evas_object_size_hint_align_set(btn, EVAS_HINT_FILL, EVAS_HINT_FILL);
   elm_object_text_set(btn, "Resume");
   evas_object_smart_callback_add(btn, "clicked", btn_clicked_cb, anim_view);
   evas_object_show(btn);
   elm_box_pack_end(box4, btn);

   evas_object_smart_callback_add(anim_view, "play,start", _state_update, label);
   evas_object_smart_callback_add(anim_view, "play,stop", _state_update, label);
   evas_object_smart_callback_add(anim_view, "play,pause", _state_update, label);
   evas_object_smart_callback_add(anim_view, "play,resume", _state_update, label);

   evas_object_smart_callback_add(anim_view, "play,repeat", _play_repeated, label);
   evas_object_smart_callback_add(anim_view, "play,done", _play_done, label);

   evas_object_smart_callback_add(anim_view, "play,update", _play_updated, slider);
   evas_object_smart_callback_add(anim_view, "play,stop", _slider_reset, slider);

   update_anim_view_state(anim_view, label);

   return box;

}

int
main(int argc, char **argv)
{
   setenv("ECTOR_BACKEND", "default", 1);
   setenv("ELM_ACCEL", "gl", 1);

   elm_init(argc, argv);

   Eo *win = elm_win_util_standard_add(NULL, "test");
   evas_object_smart_callback_add(win, "delete,request", win_del, 0);
   elm_win_autodel_set(win, 1);

   char path[PATH_MAX];

   if (argc == 1)
     {
        printf("Usage: efl_animview [input_file]\n");
        return 0;
     }
   else snprintf(path, sizeof(path), "%s", argv[1]);

   Eo *content = anim_view_test(win, path);

   elm_win_resize_object_add(win, content);

   evas_object_resize(win, WIDTH, HEIGHT);
   evas_object_show(win);

   elm_run();

   elm_shutdown();

   return 0;
}
