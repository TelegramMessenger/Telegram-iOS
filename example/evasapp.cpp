#include "evasapp.h"

static void
_on_resize(Ecore_Evas *ee)
{
   EvasApp *app = (EvasApp *)ecore_evas_data_get(ee, "app");
   int w, h;
   ecore_evas_geometry_get(ee, NULL, NULL, &w, &h);
   app->resize(w, h);
   if (app->mResizeCb)
       app->mResizeCb(app->mResizeData, nullptr);
}

static void
_on_delete(Ecore_Evas *ee)
{
   EvasApp *app = (EvasApp *)ecore_evas_data_get(ee, "app");
   if (app->mExitCb)
       app->mExitCb(app->mExitData, nullptr);

   ecore_main_loop_quit();
   ecore_evas_free(ee);
}

static Eina_Bool
on_key_down(void *data, int type, void *event)
{
    Ecore_Event_Key *keyData = (Ecore_Event_Key *)event;

    EvasApp *app = (EvasApp *) data;
    if (app && app->mKeyCb)
        app->mKeyCb(app->mKeyData, (void *)keyData->key);

    return false;
}

EvasApp::EvasApp(int w, int h)
{
    if (!ecore_evas_init())
     return;
    mw = w;
    mh = h;
    //setenv("ECORE_EVAS_ENGINE", "opengl_x11", 1);
    mEcoreEvas = ecore_evas_new(NULL, 0, 0, mw, mh, NULL);
    if (!mEcoreEvas) return;
}

void
EvasApp::setup()
{
    ecore_evas_data_set(mEcoreEvas, "app", this);
    ecore_evas_callback_resize_set(mEcoreEvas, _on_resize);
    ecore_evas_callback_delete_request_set(mEcoreEvas, _on_delete);
    ecore_event_handler_add(ECORE_EVENT_KEY_DOWN, on_key_down, this);

    ecore_evas_show(mEcoreEvas);
    mEvas = ecore_evas_get(mEcoreEvas);
    mBackground = evas_object_rectangle_add(mEvas);
    evas_object_color_set(mBackground, 70, 70, 70, 255);
    evas_object_show(mBackground);

    mVg = evas_object_vg_add(mEvas);
    evas_object_show(mVg);

    mRoot = evas_vg_container_add(mVg);
    evas_object_vg_root_node_set(mVg, mRoot);
}

void
EvasApp::resize(int w, int h)
{
    evas_object_resize(mBackground, w, h);
    evas_object_resize(mVg, w, h);
    mw = w;
    mh = h;
}

void EvasApp::run()
{
    resize(mw, mh);
    ecore_main_loop_begin();
    ecore_evas_shutdown();
}
