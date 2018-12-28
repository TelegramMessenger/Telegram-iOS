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
#include"vpath.h"
#include<iostream>
using namespace std;

EvasApp *APP;

static void
_on_resize(Ecore_Evas *ee)
{
   int w, h;
   ecore_evas_geometry_get(ee, NULL, NULL, &w, &h);
   APP->resize(w, h);
}

class PathTest
{
public:
  PathTest(EvasApp *app) {
      mApp = app;
      mShape = evas_vg_shape_add(mApp->root());
  }
  void setColor(int r, int g, int b, int a) {
    evas_vg_node_color_set(mShape, r, g, b, a);
  }

  void setStrokeColor(int r, int g, int b, int a) {
    evas_vg_shape_stroke_color_set(mShape, r, g, b, a);
  }

  void setStrokeWidth(int w) {
    evas_vg_shape_stroke_width_set(mShape, w);
  }

  void setPath(const VPath &path) {
    Efl_VG  *shape = mShape;
    evas_vg_shape_reset(shape);
    const std::vector<VPath::Element> &elm = path.elements();
    const std::vector<VPointF> &pts  = path.points();
    int i=0;
    for (auto e : elm) {
      switch(e) {
        case VPath::Element::MoveTo:
            {
                VPointF p = pts[i++];
                evas_vg_shape_append_move_to(shape, p.x(), p.y());
                break;
            }
        case VPath::Element::LineTo:
            {
                VPointF p = pts[i++];
                evas_vg_shape_append_line_to(shape, p.x(), p.y());
                break;
            }
        case VPath::Element::CubicTo:
            {
                VPointF p = pts[i++];
                VPointF p1 = pts[i++];
                VPointF p2 = pts[i++];
                evas_vg_shape_append_cubic_to(shape, p.x(), p.y(), p1.x(), p1.y(), p2.x(), p2.y());
                break;
            }
        case VPath::Element::Close:
            {
                evas_vg_shape_append_close(shape);
                break;
            }
      }
    }
  }

public:
  EvasApp *mApp;
  Efl_VG  *mShape;
};

int
main(void)
{
   APP = new EvasApp(800, 800);
   ecore_evas_callback_resize_set(APP->mEcoreEvas, _on_resize);
   APP->setup();

   VPath path;
   path.addRoundRect(VRectF(100, 100, 200, 200), 20, 20, VPath::Direction::CCW);
   path.addCircle(50, 50, 20, VPath::Direction::CCW);

   path.addOval(VRectF(300, 100, 100, 50), VPath::Direction::CCW);

   path.addPolystar(15.0, 106.0, 34.0, 0.0, 150,
                    150, 231.0, 88.0, VPath::Direction::CW);

   PathTest test(APP);
   test.setPath(path);
   test.setColor(255, 0, 0, 255);
   test.setStrokeColor(200, 200, 0, 200);
   test.setStrokeWidth(5);


   APP->run();
   delete APP;
   return 0;
}





