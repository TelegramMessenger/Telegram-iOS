//
//  animations.c
//  IntroOpenGL
//
//  Created by Ilya Rimchikov on 29/03/14.
//  Copyright (c) 2014 IntroOpenGL. All rights reserved.
//


#include "animations.h"
#include "objects.h"
#include "linmath.h"
#include "math_helper.h"
#include "matrix.h"
#include "platform_gl.h"
#include "platform_log.h"
#include "rngs.h"
#include "timing.h"

#include <stdio.h>


static const vec4 black_color = {0,0,0, 1.0f};
static const vec4 white_color = {1,1,1, 1.0f};

/*
static const vec4 red_color = {1,0,0, 1.0f};
static const vec4 green_color = {0,1,0, 1.0f};
static const vec4 blue_color = {0,0,1, 1.0f};
*/

static LayerParams ribbonLayer, privateLayer;

static TexturedShape spiral;
static Shape mask1;
static Shape cloud_extra_mask1;
static Shape cloud_extra_mask2;
static Shape cloud_extra_mask3;
static Shape cloud_extra_mask4;

static Shape cloud_cover;

static Shape free_bg;
static TexturedShape fast_body;
static TexturedShape fast_arrow_shadow;
static TexturedShape fast_arrow;

static TexturedShape free_knot1;
static TexturedShape free_knot2;
static TexturedShape free_knot3;
static TexturedShape free_knot4;

static Shape powerful_bg;
static TexturedShape powerful_mask, powerful_infinity, powerful_infinity_white;

static Shape private_bg;

static TexturedShape telegram_sphere, telegram_plane;

static Shape cloud_bg;


#define starsCount 80
static TexturedShape star;
static Params stars[starsCount];

static TexturedShape test[6];

static Shape ribbon1;
static Shape ribbon2;
static Shape ribbon3;
static Shape ribbon4;


static mat4x4 stars_matrix;
static mat4x4 main_matrix;
static mat4x4 ribbons_layer;

static int test_texture[6];

static TexturedShape ic_bubble_dot, ic_bubble, ic_cam_lens, ic_cam, ic_pencil, ic_pin, ic_smile_eye, ic_smile, ic_videocam;
static int ic_bubble_dot_texture, ic_bubble_texture, ic_cam_lens_texture, ic_cam_texture, ic_pencil_texture, ic_pin_texture, ic_smile_eye_texture, ic_smile_texture, ic_videocam_texture;

static int telegram_sphere_texture, telegram_plane_texture;

static int fast_spiral_texture, fast_body_texture, fast_arrow_texture, fast_arrow_shadow_texture;

static int free_knot_up_texture, free_knot_down_texture;

static int powerful_mask_texture, powerful_star_texture, powerful_infinity_texture, powerful_infinity_white_texture;
static Shape infinity;

static int private_door_texture, private_screw_texture, private_keyhole_body_texture;
static TexturedShape private_door, private_screw, private_keyhole_body;
static Shape private_stroke;


static const float r1 = 58.5;
static const float r2 = 70;

static double ms0;
static int fps;



static double date, date0;

static int touch_x=0;

static double duration_const = .3;



static int direct;


static int frame_width;


static int i;

static int current_page, prev_page;

static double time;

static mat4x4 ic_matrix;
static LayerParams ic_pin_layer, ic_cam_layer, ic_videocam_layer, ic_smile_layer, ic_bubble_layer, ic_pencil_layer;



static float time_local = 0;

static int pagination_y, button_y;


static float knot_delays[4];


static float offset_y;


void set_page(int page)
{
    /*
     char str[15];
     sprintf(str, "set_page>%d", page);
     DEBUG_LOG_WRITE_D("fps>",str);
     */

    if (current_page == page) {
        return;
    }
    else
    {
        prev_page = current_page;
        current_page = page;
        //NSLog(@"_currentPage>%i", _currentPage);
        //[self animate];
        direct=current_page>prev_page?1:0;
        //direct = (direct == 0) ? 1 : 0;
        date0=date;
        time = 0;//.5;//0.01;
    }
}


void set_date(double a)
{
    date=a;
}


void set_date0(double a)
{
    direct = (direct == 0) ? 1 : 0;
    date0=a;
}


void set_touch_x(int a)
{
    touch_x = a;
}


void set_pages_textures(int a1, int a2, int a3, int a4, int a5, int a6)
{
    test_texture[0]=a1;
    test_texture[1]=a2;
    test_texture[2]=a3;
    test_texture[3]=a4;
    test_texture[4]=a5;
    test_texture[5]=a6;
}


void set_ic_textures(int a_ic_bubble_dot, int a_ic_bubble, int a_ic_cam_lens, int a_ic_cam, int a_ic_pencil, int a_ic_pin, int a_ic_smile_eye, int a_ic_smile, int a_ic_videocam)
{
    ic_bubble_dot_texture = a_ic_bubble_dot;
    ic_bubble_texture = a_ic_bubble;
    ic_cam_lens_texture = a_ic_cam_lens;
    ic_cam_texture = a_ic_cam;
    ic_pencil_texture = a_ic_pencil;
    ic_pin_texture = a_ic_pin;
    ic_smile_eye_texture = a_ic_smile_eye;
    ic_smile_texture = a_ic_smile;
    ic_videocam_texture = a_ic_videocam;
}

void set_telegram_textures(int a_telegram_sphere, int a_telegram_plane)
{
    telegram_sphere_texture = a_telegram_sphere;
    telegram_plane_texture = a_telegram_plane;
}

void set_fast_textures(int a_fast_body, int a_fast_spiral, int a_fast_arrow, int a_fast_arrow_shadow)
{
    fast_spiral_texture = a_fast_spiral;
    fast_body_texture = a_fast_body;
    fast_arrow_shadow_texture = a_fast_arrow_shadow;
    fast_arrow_texture = a_fast_arrow;
}

void set_free_textures(int a_knot_up, int a_knot_down)
{
    free_knot_up_texture = a_knot_up;
    free_knot_down_texture = a_knot_down;
}

void set_powerful_textures(int a_powerful_mask, int a_powerful_star, int a_powerful_infinity, int a_powerful_infinity_white)
{
    powerful_mask_texture = a_powerful_mask;
    powerful_star_texture = a_powerful_star;
    powerful_infinity_texture = a_powerful_infinity;
    powerful_infinity_white_texture = a_powerful_infinity_white;
}

void set_private_textures(int a_private_door, int a_private_screw)
{
    private_door_texture = a_private_door;
    private_screw_texture = a_private_screw;
}

float t(float start_value, float end_value, float start_time, float duration, timing_type type)
{
    if (time>start_time+duration) {
        return end_value;
    }

    if (type==Linear) {
        return start_value + (end_value - start_value)*MINf(duration+start_time, MAXf(.0, (time - start_time))) /duration;
    }
    return start_value + (end_value - start_value)*timing(MINf(duration+start_time, MAXf(.0, (time - start_time))) /duration, type);
}


float t_reversed(float end_value, float start_value, float start_time, float duration, timing_type type)
{
    if (time>start_time+duration) {
        return end_value;
    }

    if (type==Linear) {
        return start_value + (end_value - start_value)*MINf(duration+start_time, MAXf(.0, (time - start_time))) /duration;
    }
    return start_value + (end_value - start_value)*timing(MINf(duration+start_time, MAXf(.0, (time - start_time))) /duration, type);
}


float t_local(float start_value, float end_value, float start_time, float duration, timing_type type)
{
    if (type==Sin) {
        return start_value + (end_value - start_value)*sin(MINf(MAXf((time_local - start_time)/duration * M_PI, 0), M_PI));
    }

    if (time_local>start_time+duration) {
        return end_value;
    }

    if (type==Linear) {
        return start_value + (end_value - start_value)*MINf(duration+start_time, MAXf(.0, (time_local - start_time))) /duration;
    }
    return start_value + (end_value - start_value)*timing(MINf(duration+start_time, MAXf(.0, (time_local - start_time))) /duration, type);
}




static int ribbonLength = 86;
static int starsFar=500;

static float scroll_offset;

void set_scroll_offset(float a_offset)
{
    scroll_offset = a_offset;
}

static int star_order=0;

xyz star_create_position(float far)
{
    starsFar = 1500;

    int minR = 100;
    int maxR = 1000;

    star_order++;
    if (star_order == 4) star_order = 0;

    return xyzMake(signrand()*frand(minR, maxR), signrand()*frand(minR, maxR), far);
}


xyz star_initial_position(int randZ, int forward)
{
    starsFar=1500;

    int minR=100;
    int maxR=1000;

    float z = 0;
    if (forward == 1) {
        if (randZ == 0) {
            z = -starsFar;
        } else {
            z = frand(0, -starsFar);
        }
    }

    return xyzMake(signrand()*frand(minR, maxR), signrand()*frand(minR, maxR), z);
}


static int stars_rendered;
void inc_stars_rendered()
{
    stars_rendered++;
}


static int tt;
void draw_stars()
{
/*
set_y_offset_objects(0);

        star.params.scale = xyzMake(1000, 2, 1);
        star.params.alpha = 1;
        star.params.position = xyzMake(0,0,-1000);
        draw_textured_shape(&star, stars_matrix, NORMAL);

        star.params.scale = xyzMake(2, 1000, 1);
        draw_textured_shape(&star, stars_matrix, NORMAL);
*/
    //set_y_offset_objects(offset_y - 4*0);
    //set_y_offset_objects(0);

//set_y_offset_objects(offset_y * (float)width/(float)height*0);
float k = (float)width/(float)height;

set_y_offset_objects(-100*k*0);
    stars_rendered = 0;
    for (i = 0; i < starsCount; i++)
    {
        float stars_scroll_offset = MAXf(0,scroll_offset)*2;

        float transition_speed;
        if (direct == 1) {
            float s = 5;
            transition_speed = s - t(0, s, 0, duration_const+1 +.8, Linear);
        } else {
            transition_speed = t(-4, 0, 0, duration_const+1, EaseOut);
        }

        float speed = stars_scroll_offset + transition_speed;
        stars[i].position.z += speed;

        if (stars[i].position.z>0 && speed>0) {
            stars[i].position = star_initial_position(0, 1);
        }
        if (stars[i].position.z<-1500 && speed<0) {
            stars[i].position = star_initial_position(0, 0);
        }

        float inc = scroll_offset*100;
        stars[i].position.z = stars[i].position.z + inc;

        star.params.position = stars[i].position;
        float s = 1 + (-stars[i].position.z)/starsFar*5;

        star.params.scale = xyzMake(s, s, 1);
        float far = starsFar;
        float k = 10.;
        star.params.alpha = (1-(-stars[i].position.z)/far)*k;
        star.params.alpha = star.params.alpha*star.params.alpha/k;


        draw_textured_shape(&star, stars_matrix, NORMAL);

/*
        star.params.scale = xyzMake(1000, 2, 1);
        star.params.alpha = 1;
        star.params.position = xyzMake(0,0,-1000);
        draw_textured_shape(&star, stars_matrix, NORMAL);

        star.params.scale = xyzMake(2, 1000, 1);
        draw_textured_shape(&star, stars_matrix, NORMAL);
*/

        stars[i].position.z = stars[i].position.z - inc;
    }

    set_y_offset_objects(offset_y);
}


void on_surface_created() {
    setup_shaders();

    mask1 = create_rounded_rectangle(CSizeMake(60, 60), 0, 16, black_color);



    // Telegram
    telegram_sphere = create_textured_rectangle(CSizeMake(148, 148), telegram_sphere_texture);
    telegram_plane = create_textured_rectangle(CSizeMake(82, 74), telegram_plane_texture);
    telegram_plane.params.anchor=xyzMake(6, -5, 0);



    // Fast
    fast_body = create_textured_rectangle(CSizeMake(148, 148), fast_body_texture);

    fast_arrow_shadow = create_textured_rectangle(CSizeMake(164/2, 44/2), fast_arrow_shadow_texture);
    fast_arrow_shadow.params.position.x=-1;
    fast_arrow_shadow.params.position.y=2;

    fast_arrow = create_textured_rectangle(CSizeMake(164/2, 44/2), fast_arrow_texture);
    fast_arrow.params.anchor.x=fast_arrow_shadow.params.anchor.x=-19;

    int ang = 180;
    spiral = create_segmented_square(r1, D2R(35+1), D2R(35+1-10 + ang), fast_spiral_texture);



    // Free
    vec4 free_bg_color = {246/255., 73/255., 55/255., 1};
    free_bg = create_rectangle(CSizeMake(160*2, 160*2), free_bg_color);

    free_knot1 = create_textured_rectangle(CSizeMake(138/3, 138/3), free_knot_up_texture);
    free_knot1.params.anchor.x = -23+10;
    free_knot1.params.anchor.y = 23-10;

    free_knot2 = create_textured_rectangle(CSizeMake(138/3, 138/3), free_knot_up_texture);
    free_knot2.params.anchor.x = -23+10;
    free_knot2.params.anchor.y = 23-10;

    free_knot3 = create_textured_rectangle(CSizeMake(150/3, 150/3), free_knot_down_texture);
    free_knot3.params.anchor.x = -100/4.+20/2.;
    free_knot3.params.anchor.y = -100/4.+20/2.;

    free_knot4 = create_textured_rectangle(CSizeMake(150/3, 150/3), free_knot_down_texture);
    free_knot4.params.anchor.x = -100/4.+20/2.;
    free_knot4.params.anchor.y = -100/4.+20/2.;


    ribbonLayer = default_layer_params();

    ribbon1 = create_ribbon(ribbonLength, white_color);
    ribbon1.params.layer_params = &ribbonLayer;

    ribbon2 = create_ribbon(ribbonLength, white_color);
    ribbon2.params.rotation=90;
    ribbon2.params.layer_params = &ribbonLayer;

    ribbon3 = create_ribbon(ribbonLength, white_color);
    ribbon3.params.rotation=180;
    ribbon3.params.layer_params = &ribbonLayer;

    ribbon4 = create_ribbon(ribbonLength, white_color);
    ribbon4.params.rotation=270;
    ribbon4.params.layer_params = &ribbonLayer;

    ribbon1.params.position.y=ribbon2.params.position.y=ribbon3.params.position.y=ribbon4.params.position.y=-9;


    ic_bubble_dot = create_textured_rectangle(CSizeMake(18/3, 18/3), ic_bubble_dot_texture);
    ic_bubble = create_textured_rectangle(CSizeMake(102/3, 102/3), ic_bubble_texture);
    ic_cam_lens = create_textured_rectangle(CSizeMake(36/3, 36/3), ic_cam_lens_texture);
    ic_cam = create_textured_rectangle(CSizeMake(108/3, 96/3), ic_cam_texture);
    ic_pencil = create_textured_rectangle(CSizeMake(86/3, 86/3), ic_pencil_texture);
    ic_pin = create_textured_rectangle(CSizeMake(90/3, 120/3), ic_pin_texture);
    ic_smile_eye = create_textured_rectangle(CSizeMake(18/3, 18/3), ic_smile_eye_texture);
    ic_smile = create_textured_rectangle(CSizeMake(120/3, 120/3), ic_smile_texture);
    ic_videocam = create_textured_rectangle(CSizeMake(144/3, 84/3), ic_videocam_texture);

    ic_pin_layer = ic_cam_layer = ic_videocam_layer = ic_smile_layer = ic_bubble_layer = ic_pencil_layer = default_layer_params();

    ic_pin_layer.anchor = xyzMake(0, 50/2, 0);
    ic_pencil_layer.anchor = xyzMake(-30/2, 30/2, 0);



    // Powerful
    infinity = create_infinity(11.7, .0, 32, white_color);

    vec4 powerful_bg_color = {47/255., 90/255., 131/255., 1};
    powerful_bg = create_rectangle(CSizeMake(200, 200), powerful_bg_color);
    powerful_mask = create_textured_rectangle(CSizeMake(200, 200), powerful_mask_texture);

    powerful_infinity = create_textured_rectangle(CSizeMake(366/3, 180/3), powerful_infinity_texture);
    powerful_infinity_white = create_textured_rectangle(CSizeMake(366/3, 180/3), powerful_infinity_white_texture);

    float star_radius = 5.25;//4.5;
    star = create_textured_rectangle(CSizeMake(star_radius, star_radius), powerful_star_texture);
    star.params.const_params.is_star=1;
    for (i=0; i<starsCount; i++) {
        stars[i]=default_params();
        stars[i].position = star_create_position(-(i*1500.)/starsCount);
        //stars[i].const_params.is_star = 1;
    }



    // Private
    privateLayer = default_layer_params();

    vec4 private_bg_color = {200/255., 207/255., 212/255., 1};
    private_bg = create_rectangle(CSizeMake(240, 240), private_bg_color);

    private_door = create_textured_rectangle(CSizeMake(408/3, 408/3), private_door_texture);
    private_keyhole_body = create_textured_rectangle(CSizeMake(216/3, 216/3), private_keyhole_body_texture);
    private_screw = create_textured_rectangle(CSizeMake(30/3, 30/3), private_screw_texture);
    private_stroke = create_rounded_rectangle_stroked(CSizeMake(244/2, 244/2), 21, 9, 16, white_color);



    // Cloud-Based
    int cloud_polygons_count = 64;
    cloud_extra_mask1 = create_circle(1, cloud_polygons_count, black_color);
    cloud_extra_mask2 = create_circle(1, cloud_polygons_count, black_color);
    cloud_extra_mask3 = create_circle(1, cloud_polygons_count, black_color);
    cloud_extra_mask4 = create_circle(1, cloud_polygons_count, black_color);

    cloud_cover = create_rectangle(CSizeMake(240, 100), white_color);
    cloud_cover.params.anchor.y = -50;

    vec4 cloud_color = {42/255., 180/255., 247/255., 1};
    cloud_bg = create_rectangle(CSizeMake(160*2, 160*2), cloud_color);
}



static inline void mat4x4_plain(mat4x4 M, int width, int height)
{
    int i, j;
    for(i=0; i<4; ++i)
        for(j=0; j<4; ++j)
            M[i][j] = 0.;

    M[0][0]=1;
    M[1][1]=1;
    M[2][2]=1;

    M[0][0]=1;
    M[1][1]=(float)width/(float)height;
    M[2][2]=1;

    //for iphone retina width = 320
    M[3][3]=(float)width/2.;
}




static inline void mat4x4_stars(mat4x4 m, float y_fov_in_degrees, float aspect, float n, float f, int width, int height)
{
    int is_iOS = 1;
    if (height >= width) {
        float k = (float)width/(float)height;
        
        
        float q = !is_iOS ? 1.4 : 0.7;

        m[0][0] = 1.0f/q;
        m[1][0] = 0.0f;
        m[2][0] = 0.0f;
        m[3][0] = 0.0f;

        m[1][0] = 0.0f;
        m[1][1] = k/q;
        m[1][2] = 0.0f;
        m[1][3] = 0.0f;

        m[2][0] = 0.0f;
        m[2][1] = 0.0f;
        m[2][2] = 1.0f;
        m[2][3] = -1.25;

        m[3][0] = 0.0f;
        m[3][1] = 0.0f;
        m[3][2] = 0.0f;
        m[3][3] = width*k;
    }
    else
    {
        float k = (float)height/(float)width;

        float q = !is_iOS ? 2.0 : 0.7;

        m[0][0] = 1.0f/q;
        m[1][0] = 0.0f;
        m[2][0] = 0.0f;
        m[3][0] = 0.0f;

        m[1][0] = 0.0f;
        m[1][1] = (1.0/k)/q;
        m[1][2] = 0.0f;
        m[1][3] = 0.0f;

        m[2][0] = 0.0f;
        m[2][1] = 0.0f;
        m[2][2] = 1.0f;
        m[2][3] = -1.25;

        m[3][0] = 0.0f;
        m[3][1] = 0.0f;
        m[3][2] = 0.0f;
        m[3][3] = height*k;
    }

    mat4x4_translate_independed(m, 0, - 2*y_offset_absolute/(float)height + 4*scale_factor/(float)height, 0);
}




void on_surface_changed(int a_width_px, int a_height_px, float a_scale_factor, int a1, int a2, int a3, int a4, int a5)
{
    glViewport(0, 0, a_width_px, a_height_px);

    width = a_width_px/a_scale_factor;
    height = a_height_px/a_scale_factor;

    scale_factor = a_scale_factor;

    offset_y = a1;
    button_y = a3;
    pagination_y = a4;

    for (i = 0; i < 6; i++) {
        test[i].params.position.y = a2;//170-18-4+10+12;
    }

    frame_width=a_width_px/a_scale_factor;
    mat4x4_plain(main_matrix, (int)((float)a_width_px/a_scale_factor), (int)((float)a_height_px/a_scale_factor));

    offset_y = a1*main_matrix[1][1];
    set_y_offset_objects(offset_y);

    y_offset_absolute = a1;

    mat4x4_stars(stars_matrix, 45, 1, -1000, 0, (int)((float)a_width_px/a_scale_factor), (int)((float)a_height_px/a_scale_factor));
}

void rglNormalDraw()
{
    glDisable(GL_DEPTH_TEST);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glColorMask(1,1,1,1);
    glDepthMask(0);
}

void rglMaskDraw()
{
    glEnable(GL_DEPTH_TEST);
    glDisable(GL_BLEND);
    glDepthMask(1);
    glColorMask(0,0,0,0);
    glDepthFunc(GL_GREATER);
    glClearDepthf(0);
    glClear(GL_DEPTH_BUFFER_BIT);
}

void rglNormalDrawThroughMask()
{
    glColorMask(1,1,1,1);
    glDepthFunc(GL_LESS);
    glDepthMask(0);
}

void mat4x4_scaled(mat4x4 matrix, float s)
{
    mat4x4_identity(matrix);
    mat4x4_scale_aniso(matrix, matrix, s, s, s);
}

void mat4x4_layer(mat4x4 matrix, LayerParams params, float s, float r)
{
    float a=main_matrix[1][1];
    tt++;

    mat4x4 model_matrix;
    mat4x4_identity(model_matrix);

    mat4x4 id;
    mat4x4_identity(id);


    float sc=main_matrix[3][3];
    //printf("sc>%f\n", sc);

    mat4x4_translate(model_matrix, -params.anchor.x/sc, params.anchor.y/sc*a, params.anchor.z/sc);

    mat4x4 scaled;
    mat4x4_identity(scaled);
    float f=1;//.01;
    mat4x4_scale_aniso(scaled, scaled, params.scale.x*f, params.scale.y*f, params.scale.z*f);


    mat4x4 tmp;
    mat4x4_dup(tmp, model_matrix);

    mat4x4_mul(model_matrix, scaled, tmp);

    mat4x4 rotate;
    mat4x4_dup(rotate, id);



    //mat4x4_translate(id, 0, 100./sc, 0);

    mat4x4_rotate_Z2(rotate, id, -deg_to_radf(params.rotation) );


    mat4x4_dup(tmp, model_matrix);

    mat4x4_mul(model_matrix, rotate, tmp);



    mat4x4_translate_independed(model_matrix, params.position.x/sc, -params.position.y/sc*a, params.position.z/sc);

    //mat4x4_translate(model_matrix, params.position.x/sc, -params.position.y/sc*a - 100./sc*a, params.position.z/sc);



    mat4x4 m;
    mat4x4_mul(m, model_matrix, main_matrix);

    //mat4x4_translate_independed(m, 0, +100*a, 0);

    m[1][0]/=a;
    m[0][1]*=a;


    mat4x4 scale_m;
    mat4x4_scaled(scale_m, s);

    mat4x4_rotate_Z(scale_m, r);


    scale_m[1][0]/=a;
    scale_m[0][1]*=a;

    mat4x4_mul(matrix, scale_m, m );


}


static float speedometer, calculated_speedometer_sin;
float speedometer_sin()
{
    speedometer += scroll_offset*.1;
    return sin(sin(time*1000*.15*0.08+speedometer)*M_PI)*5;
}

double ms0_anim, time_anim;
int fps_anim;
int count_anim_fps;

static float speedometer_scroll_offset=0, free_scroll_offset=0, private_scroll_offset=0;

double anim_pencil_stage_duration, anim_pencil_start_time, anim_pencil_start_all_time, anim_pencil_start_all_end_time;
int anim_pencil_stage;



int anim_bubble_dots_stage, anim_bubble_dots_q, anim_bubble_dots_count;
double anim_bubble_dots_next_time, anim_bubble_dots_duration;

int anim_bubble_dots_start_period, anim_bubble_dots_end_period;



double anim_videocam_start_time, anim_videocam_next_time, anim_videocam_duration, anim_videocam_angle, anim_videocam_old_angle;
double anim_cam_start_time, anim_cam_next_time, anim_cam_duration, anim_cam_angle, anim_cam_old_angle;
CPoint anim_cam_position, anim_cam_old_position;
int qShot;
int firstShot;
double anim_camshot_start_time, anim_camshot_next_time, anim_camshot_duration, anim_cambutton_start_time, anim_cambutton_end_time;


double anim_smile_start_time1, anim_smile_start_time2, anim_smile_blink_start_time;
int anim_smile_blink_one;
int anim_smile_stage;


static float scale;


double anim_pin_start_time, anim_pin_duration;
int anim_pin_start_period, anim_pin_end_period;
static int anim_pencil_period;

float pin_sin(float a)
{
    if (a > M_PI*2*anim_pin_start_period && a < M_PI*2*anim_pin_end_period) {

        return sin(a*.1);
    }
    if (a > M_PI*2*(anim_pin_end_period)) {
        int p = 1;
        anim_pin_start_period = anim_pin_end_period + p;
        anim_pin_end_period = anim_pin_end_period + p + 1;
    }

    return 0;
}


float bubble_dots_sin(float a)
{
    if (a < M_PI*2*anim_bubble_dots_end_period) {
        return sin(a);
    }

    return 0;
}


float pencil_v_sin(float a)
{
    return sin(a);
}





static mat4x4 private_matrix;

float cloud_scroll_offset, commonDelay;

static float ic_layer_scale=1, ic_layer_alpha=1;


static void reset_ic()
{
    anim_smile_start_time1 = time_local;
    anim_pencil_start_time = 0;
    anim_pencil_start_all_end_time = 0;
    anim_cam_next_time = time_local + 0;
    anim_smile_stage = 0;
    anim_smile_blink_one = 0;
    anim_pencil_stage = 0;
    anim_bubble_dots_end_period = 4;
    anim_pencil_period = 1;
}


static void draw_ic(int type)
{
    float rotation;
    float beginTimeK;
    float commonDelay;

    float beginY = 250;

    int bounce = 1;

    texture_program_type COLOR, LIGHT_COLOR;
    if (type == 0) {

        beginTimeK = 2.;
        commonDelay = duration_const*.5;
        bounce = 1;

        rotation = -D2R(free_scroll_offset);

        cloud_scroll_offset = 0;
        COLOR = RED, LIGHT_COLOR = LIGHT_RED;

    } else {

        rotation = 0;

        beginTimeK = 2.5;
        commonDelay = 0;
        bounce = 1;

        COLOR = BLUE, LIGHT_COLOR = LIGHT_BLUE;
    }


    float scale;
    float t_y;


    CPoint ic_pos;


    ic_layer_alpha = 1;
    if (current_page == 1 && direct == 0) {
        ic_layer_alpha = t(1, 0, 0, duration_const*.25, EaseOut);
    }
    ic_pin.params.alpha = ic_layer_alpha;
    ic_cam.params.alpha = ic_layer_alpha;
    ic_cam_lens.params.alpha = ic_layer_alpha;
    ic_smile.params.alpha = ic_layer_alpha;
    ic_smile_eye.params.alpha = ic_layer_alpha;
    ic_videocam.params.alpha = ic_layer_alpha;
    ic_bubble.params.alpha = ic_layer_alpha;
    ic_bubble_dot.params.alpha = ic_layer_alpha;
    ic_pencil.params.alpha = ic_layer_alpha;


    ic_layer_scale = 1;
    if (current_page == 1 && direct == 0) {
        // ic_layer_scale = t(1, 1.5, 0, duration_const, EaseOut);
        // t_y = t(0, -200, /*commonDelay + duration_const*(.5-.2)*beginTimeK*/0, duration_const, EaseOut);
    }


    if (type == 0) {
        ic_pos = CPointMake(-106/2, 61/2);
        if (current_page == 1 && direct == 0) {
            t_y = 0;//t(0, -200, /*commonDelay + duration_const*(.5-.2)*beginTimeK*/0, duration_const, EaseOut);
        }
        else
        {
            t_y = t(beginY, 0, commonDelay + duration_const*.2*beginTimeK, duration_const, EaseOut);

            float value = 0;
            float e = 2.71;
            float arg = MAXf(0, time-(commonDelay + duration_const*.2*beginTimeK))*50;

            value = beginY * pow(e, -0.055*arg * 2) * cos(0.08*arg) * .4;

            t_y -= value*bounce;
            //t_y = value;// + t(200, 0, commonDelay + duration_const*.2*beginTimeK, duration_const, EaseOut);
        }
        //t_y = t(200, 0, commonDelay + duration_const*.2*beginTimeK, duration_const, EaseOut);
    }
    else
    {
        ic_pos = CPointMake(-162/2+4, +26/2+20);
        t_y = t(beginY, 0, commonDelay + duration_const*.2*beginTimeK, duration_const, EaseOut);

        float value = 0;
        float e = 2.71;
        float arg = MAXf(0, time-(commonDelay + duration_const*.2*beginTimeK))*50;
        value = beginY * pow(e, -0.055*arg * 2) * cos(0.08*arg-M_PI/8.) * .4;

        t_y -= value*bounce;
    }

    float pink = 0;
    if (time_local > anim_pin_start_time) {
        pink = t_local(0, 1, anim_pin_start_time, anim_pin_duration, Sin);
        if (time_local > anim_pin_start_time + anim_pin_duration) {
            anim_pin_start_time = time_local + duration_const * frand(10, 20)*2;
            anim_pin_duration = duration_const * frand(10, 20)*2;
        }
    }
    float pinasin = 0;//sin(time_local*.1) * pink;
    ic_pin_layer.position = xyzMake(ic_pos.x + cos(time_local*5)*3*pinasin + cloud_scroll_offset, ic_pos.y + sin(time_local*5)*1.5*pinasin + t_y , 0);
    mat4x4_layer(ic_matrix, ic_pin_layer, ic_layer_scale, rotation);
    draw_textured_shape(&ic_pin, ic_matrix, COLOR);



    // videocam
    if (type == 1) {

        ic_videocam_layer.rotation = -30 + t_local(anim_videocam_old_angle, anim_videocam_angle, anim_videocam_start_time, anim_videocam_duration, EaseOut);
        t_y = t(beginY, 0, commonDelay + duration_const*.45*beginTimeK, duration_const, EaseOut);

        float value = 0;
        float e = 2.71;
        float arg = MAXf(0, time-(commonDelay + duration_const*.45*beginTimeK))*50;
        value = beginY * pow(e, -0.055*arg * 2) * cos(0.08*arg) * .4;

        t_y -= value*bounce;

        if (t_y <= 1 && time_local > anim_videocam_next_time) {
            anim_videocam_duration = duration_const*frand(1., 1.5)*1.5;
            anim_videocam_old_angle = anim_videocam_angle;
            anim_videocam_angle = 15 * irand(-1, 1);
            anim_videocam_start_time = time_local;
            anim_videocam_next_time = time_local + 1000000 + duration_const*frand(5, 8);
        }

        ic_videocam_layer.position = xyzMake(-68/2 + cloud_scroll_offset, +80/2 + t_y, 0);
        mat4x4_layer(ic_matrix, ic_videocam_layer, ic_layer_scale, rotation);
        draw_textured_shape(&ic_videocam, ic_matrix, COLOR);
    }



    // cam
    if (type == 0) {
        ic_pos = CPointMake(107/2, 78/2);

        if (current_page == 1 && direct == 0) {
            t_y = 0;
            //t_y = t(0, -200, /*commonDelay + duration_const*(.5-.2)*beginTimeK*/0, duration_const, EaseOut);
        }
        else
        {
            t_y = t(beginY, 0, commonDelay + duration_const*.3*beginTimeK, duration_const, EaseOut);

            float value = 0;
            float e = 2.71;
            float arg=MAXf(0, time-(commonDelay + duration_const*.3*beginTimeK))*50;

            value = beginY * pow(e, -0.055*arg * 2) * cos(0.08*arg) * .4;

            t_y -= value*bounce;

        }
        //t_y = t(200, 0, commonDelay + duration_const*.3*beginTimeK, duration_const, EaseOut);
    }
    else
    {
        ic_pos = CPointMake(-28/2, -20/2+2);
        t_y = t(beginY, 0, commonDelay + duration_const*.15*beginTimeK, duration_const, EaseOut);

        float value = 0;
        float e = 2.71;
        float arg = MAXf(0, time-(commonDelay + duration_const*.15*beginTimeK))*50;
        value = beginY * pow(e, -0.055*arg * 2) * cos(0.08*arg) * .4;

        t_y -= value*bounce;
    }


    if (t_y <= 1 && time_local > anim_cam_next_time) {
        anim_cam_duration = duration_const*frand(1., 1.5);
        anim_cam_old_angle = anim_cam_angle;
        anim_cam_old_position = anim_cam_position;
        anim_cam_start_time = time_local;
        anim_cam_next_time = time_local + 10000000;//duration_const*frand(5, 8);

        int r=irand(0, 1);
        if (r == 0) {
            anim_cam_position = CPointMake(-8+4, 0);
            anim_cam_angle = signrand()*10;
        }
        else if (r == 1) {
            anim_cam_position = CPointMake(4, -5);
            anim_cam_angle = signrand()*10;
        }
        else if (r == 2) {
            anim_cam_position = CPointMake(0, 0);
            anim_cam_angle = 0;
        }

        qShot = irand(1, 2);
        if (qShot <= 0) {
            //anim_cam_next_time = MAXf;//time_local + duration_const*frand(5, 8);//frand(1, 2);
        }
        firstShot=1;

        anim_camshot_start_time = time_local + duration_const * .5;//frand(1, 2)*5;

        anim_camshot_duration = duration_const * .4;
    }

    ic_cam_layer.rotation = 15 + t_local(anim_cam_old_angle, anim_cam_angle, anim_cam_start_time, anim_cam_duration, EaseOut);
    ic_cam_layer.position = xyzMake(
                                    ic_pos.x + 0*t_local(anim_cam_old_position.x, anim_cam_position.x, anim_cam_start_time, anim_cam_duration, EaseOut) + cloud_scroll_offset,
                                    ic_pos.y + 0*t_local(anim_cam_old_position.y, anim_cam_position.y, anim_cam_start_time, anim_cam_duration, EaseOut)
                                    + t_y,
                                    0);

    mat4x4_layer(ic_matrix, ic_cam_layer, ic_layer_scale, rotation);
    draw_textured_shape(&ic_cam, ic_matrix, COLOR);



    float lens_scale;
    lens_scale = 1;
    if (qShot >= 0 && time_local > anim_camshot_start_time) {

        lens_scale = t_local(1, 0, anim_camshot_start_time, anim_camshot_duration, Sin);

        if (time_local > anim_camshot_start_time + anim_camshot_duration) {
            /*
             if (qShot<=0) {
             anim_cam_next_time = time_local + duration_const*frand(1, 2);
             }
             */
            qShot--;
            anim_camshot_start_time = time_local + anim_camshot_duration;
        }
    }
    ic_cam_lens.params.scale = xyzMake(lens_scale, lens_scale, 1);
    ic_cam_lens.params.position = xyzMake(0, 1.7, 0);
    draw_textured_shape(&ic_cam_lens, ic_matrix, COLOR);







    // smile
    if (type == 0) {
        ic_pos = CPointMake(70/2, -116/2);

        if (current_page == 1 && direct == 0) {
            t_y = 0;
            //t_y = t(0, -200, /*commonDelay + duration_const*(.5-.2)*beginTimeK*/0, duration_const, EaseOut);
        }
        else
        {
            t_y = t(beginY, 0, commonDelay + duration_const*.0*beginTimeK, duration_const, EaseOut);

            float value = 0;
            float e = 2.71;
            float arg = MAXf(0, time-(commonDelay + duration_const*.0*beginTimeK))*50;

            value = beginY * pow(e, -0.055*arg * 2) * cos(0.08*arg) * .4;

            t_y -= value*bounce;
        }
        //t_y = t(200, 0, commonDelay + duration_const*.0*beginTimeK, duration_const, EaseOut);
    }
    else
    {
        ic_pos = CPointMake(+60/2, 50/2);
        t_y = t(beginY, 0, commonDelay + duration_const*.25*beginTimeK, duration_const, EaseOut);

        float value = 0;
        float e = 2.71;
        float arg = MAXf(0, time-(commonDelay + duration_const*.25*beginTimeK))*50;
        value = beginY * pow(e, -0.055*arg * 2) * cos(0.08*arg-M_PI/8.) * .4;

        t_y -= value*bounce;
    }
    float smile_laught = 0;
    float anim_smile_fade_duration = duration_const*2;
    float anim_smile_duration = duration_const*2;
    if (anim_smile_stage == 0) {
        //printf("stage=0\n");
        smile_laught = t_local(0, 1, anim_smile_start_time1, anim_smile_fade_duration, Linear);
        if (time_local > anim_smile_duration*3 + anim_smile_start_time1) {
            anim_smile_stage = 1;
            anim_smile_start_time2 = time_local;// + anim_smile_fade_duration;
        }
    }

    if (anim_smile_stage == 1) {
        //printf("stage=1\n");
        smile_laught = t_local(1, 0, anim_smile_start_time2, anim_smile_fade_duration, Linear);
        
        
        if (time_local > anim_smile_duration + anim_smile_start_time2) {
            smile_laught = 0;
            anim_smile_stage = 2;//0;

            //int zero_or = MAXf(0, irand(-2, 2));
            //if (zero_or != 0 && irand(0, 10) >= 7) {
            
            anim_smile_blink_one = 1;
            anim_smile_blink_start_time = time_local + duration_const;
            
            //}
            //anim_smile_start_time1 = time_local + zero_or*frand(10, 20)*duration_const;
        }

    }

    float y = 0;
    if (anim_smile_stage < 2) {
        y = sin(time_local*M_PI*10)*1.5*smile_laught;
    }

    ic_smile_layer.position = xyzMake(ic_pos.x + cloud_scroll_offset, y + ic_pos.y + t_y, 0);
    mat4x4_layer(ic_matrix, ic_smile_layer, ic_layer_scale, rotation);
    draw_textured_shape(&ic_smile, ic_matrix, COLOR);


    if (time_local > anim_smile_blink_start_time+.1) {

        float blink_pause = frand(3, 6);
        if (irand(0, 3) == 0) {
            blink_pause = .3;
        }
        if (anim_smile_blink_one == 1) {
            blink_pause = frand(3, 6);
        }
        anim_smile_blink_start_time = time_local + blink_pause;

        anim_smile_blink_one = 0;
    }

    int stop_time = 5;
    float eye_scale = t_local(1, 0, anim_smile_blink_start_time, .1, Sin);
    ic_smile_eye.params.scale = xyzMake(1, eye_scale, 1);
    if (time > stop_time) ic_smile_eye.params.scale=xyzMake(1, 1, 1);

    ic_smile_eye.params.position = xyzMake(-7, -4.5, 0);
    draw_textured_shape(&ic_smile_eye, ic_matrix, COLOR);

    if (anim_smile_blink_one == 1) ic_smile_eye.params.scale=xyzMake(1, 1, 1);
    if (time > stop_time) ic_smile_eye.params.scale=xyzMake(1, 1, 1);
    ic_smile_eye.params.position = xyzMake(7, -4.5, 0);
    draw_textured_shape(&ic_smile_eye, ic_matrix, COLOR);





    // bubble
    if (type == 0) {
        ic_pos = CPointMake(-60/2, 110/2);

        if (current_page == 1 && direct == 0) {
            t_y = 0;
            //t_y = t(0, -200, /*commonDelay + duration_const*(.5-.2)*beginTimeK*/0, duration_const, EaseOut);
        }
        else
        {
            t_y = t(beginY, 0, commonDelay + duration_const*.45*beginTimeK, duration_const, EaseOut);

            float value = 0;
            float e = 2.71;
            float arg=MAXf(0, time-(commonDelay + duration_const*.45*beginTimeK))*50;

            value = beginY * pow(e, -0.055*arg * 2) * cos(0.08*arg) * .4;

            t_y -= value*bounce;
        }
        //t_y = t(200, 0, commonDelay + duration_const*.4*beginTimeK, duration_const, EaseOut);
    }
    else
    {
        ic_pos = CPointMake(72/2, -74/2);
        t_y = t(beginY, 0, commonDelay + duration_const*.0*beginTimeK, duration_const, EaseOut);

        float value = 0;
        float e = 2.71;
        float arg = MAXf(0, time-(commonDelay + duration_const*.0*beginTimeK))*50;
        value = beginY * pow(e, -0.055*arg * 2) * cos(0.08*arg) * .4;


        t_y -= value*bounce;
    }
    ic_bubble_layer.position = xyzMake(ic_pos.x + cloud_scroll_offset, ic_pos.y + t_y, 0);
    mat4x4_layer(ic_matrix, ic_bubble_layer, ic_layer_scale, rotation);
    draw_textured_shape(&ic_bubble, ic_matrix, COLOR);

    scale=.7 + 0.2*bubble_dots_sin(time*10);
    ic_bubble_dot.params.scale = xyzMake(scale, scale, scale);
    ic_bubble_dot.params.position = xyzMake(0-8.5, -9/2., 0);
    draw_textured_shape(&ic_bubble_dot, ic_matrix, LIGHT_COLOR);

    scale=.7 + 0.2*bubble_dots_sin(-M_PI*2/3 + time*10);
    if (anim_bubble_dots_stage == 0) scale = MAXf(.7, scale);
    ic_bubble_dot.params.scale = xyzMake(scale, scale, scale);
    ic_bubble_dot.params.position = xyzMake(0, -9/2., 0);
    draw_textured_shape(&ic_bubble_dot, ic_matrix, LIGHT_COLOR);

    scale=.7 + 0.2*bubble_dots_sin(-M_PI*2/3*2 + time*10);
    if (anim_bubble_dots_stage == 0) scale = MAXf(.7, scale);
    ic_bubble_dot.params.scale = xyzMake(scale, scale, scale);
    ic_bubble_dot.params.position = xyzMake(0+8.5, -9/2., 0);
    draw_textured_shape(&ic_bubble_dot, ic_matrix, LIGHT_COLOR);




    // pencil
    float begin_k;
    if (type == 0) {
        ic_pos = CPointMake(-88/2-15, -100/2+13);

        if (current_page == 1 && direct == 0) {
            t_y = 0;
            //t_y = t(0, -200, /*commonDelay + duration_const*(.5-.2)*beginTimeK*/0, duration_const, EaseOut);
        }
        else
        {
            begin_k=.1;
            t_y = t(beginY, 0, commonDelay + duration_const*.1*beginTimeK, duration_const, EaseOut);

            float value = 0;
            float e = 2.71;
            float arg = MAXf(0, time-(commonDelay + duration_const*.1*beginTimeK))*50;
            value = beginY * pow(e, -0.055*arg * 2) * cos(0.08*arg) * .4;

            t_y -= value*bounce;
        }
        //t_y = t(200, 0, commonDelay + duration_const*.1*beginTimeK, duration_const, EaseOut);

    }
    else
    {
        ic_pos = CPointMake(+152/2-17, +66/2+14);

        begin_k = .4;
        t_y = t(beginY, 0, commonDelay + duration_const*.35*beginTimeK, duration_const, EaseOut);

        float value = 0;
        float e = 2.71;
        float arg = MAXf(0, time-(commonDelay + duration_const*.35*beginTimeK))*50;
        value = beginY * pow(e, -0.055*arg * 2) * cos(0.08*arg) * .4;

        t_y -= value*bounce;
    }

    float pencil_x = 0;
    if (anim_pencil_stage == 0) {
        ic_pencil_layer.rotation = t_local(0, -5, anim_pencil_start_all_time, duration_const*.5, EaseOut);

        pencil_x = t_local(0, 14, anim_pencil_start_time, 1.5*0.85, Linear);
        if (time_local > anim_pencil_start_time + 1.5*0.85) {
            //printf("anim_pencil_stage==0\n");
            anim_pencil_start_time = time_local;
            anim_pencil_stage = 1;
        }
    }
    else if (anim_pencil_stage == 1)
    {
        pencil_x = t_local(14, 0, anim_pencil_start_time, 1.5*0.15, Linear);

        if (time_local > anim_pencil_start_time + 1.5*0.15) {
            if (anim_pencil_period == 0) {
                anim_pencil_start_all_end_time = time_local;
                anim_pencil_start_time = time_local + duration_const*1;//frand(7, 10)*4;
                anim_pencil_stage = 2;
                //printf("anim_pencil_stage==1\nif-1\n");
            }
            else
            {
                anim_pencil_period--;
                //printf("anim_pencil_stage==1\nif-2\n");
                anim_pencil_start_time = time_local;
                anim_pencil_stage = 0;
            }
        }
    }
    else if (anim_pencil_stage == 2)
    {
        ic_pencil_layer.rotation = t_local(-5, 0, anim_pencil_start_all_end_time, duration_const*.5, EaseOut);
        if (time_local > anim_pencil_start_time) {
            //printf("anim_pencil_stage==3\n");
            anim_pencil_start_all_time = time_local;
            anim_pencil_start_time=time_local;
            anim_pencil_stage = 3;
            //printf("anim_pencil_start_time>%f", anim_pencil_start_time);
            //anim_pencil_stage=0;
        }
    }

    float pencil_v = (anim_pencil_stage < 2 ) ? pencil_v_sin(time_local*2*M_PI*4)*.8 : 0;
    ic_pencil_layer.position = xyzMake(pencil_x + ic_pos.x + cloud_scroll_offset, pencil_v + ic_pos.y + t_y, 0);
    mat4x4_layer(ic_matrix, ic_pencil_layer, ic_layer_scale, rotation);
    draw_textured_shape(&ic_pencil, ic_matrix, COLOR);

}





int anim_safe_button_i, anim_safe_button_j, anim_safe_button_q = 0;
float anim_safe_button_start_time, anim_safe_shake_start_time, anim_safe_shake_duration;


void draw_safe(int type, float alpha, float screw_alpha)
{
    float screw_distance = 53;

    float dk = .1;
    float k = dk * 0;

    private_screw.params.alpha = alpha * screw_alpha;

    scale = 1;//t(.0, 1., common_delay+duration_const*k, duration_const*durk, EaseOut);
    private_screw.params.scale = xyzMake(scale,scale,1);
    private_screw.params.position = xyzMake(-screw_distance, -screw_distance, 0);
    draw_textured_shape(&private_screw, private_matrix, NORMAL_ONE);

    k = dk * 1;
    scale = 1;//t(.0, 1., common_delay+duration_const*k, duration_const*durk, EaseOut);
    private_screw.params.scale = xyzMake(scale,scale,1);
    private_screw.params.position = xyzMake(screw_distance, -screw_distance, 0);
    draw_textured_shape(&private_screw, private_matrix, NORMAL_ONE);

    k = dk * 2;
    scale = 1;//t(.0, 1., common_delay+duration_const*k, duration_const*durk, EaseOut);
    private_screw.params.scale = xyzMake(scale,scale,1);
    private_screw.params.position = xyzMake(-screw_distance, screw_distance, 0);
    draw_textured_shape(&private_screw, private_matrix, NORMAL_ONE);

    k = dk * 3;
    scale = 1;//t(.0, 1., common_delay+duration_const*k, duration_const*durk, EaseOut);
    private_screw.params.scale = xyzMake(scale,scale,1);
    private_screw.params.position = xyzMake(screw_distance, screw_distance, 0);
    draw_textured_shape(&private_screw, private_matrix, NORMAL_ONE);

}

static float backgroundColor[3] = {1.0, 1.0, 1.0};

void set_intro_background_color(float r, float g, float b) {
    backgroundColor[0] = r;
    backgroundColor[1] = g;
    backgroundColor[2] = b;
}


void on_draw_frame() {

    time_local += .016;

    if (current_page != prev_page) {
        reset_ic();
        ms0_anim=date;
        fps_anim=0;
        count_anim_fps=1;
    }

    float knotDelayStep = .075;
    if (prev_page != current_page) {
        for (i = 0; i < 4; i++) {
            knot_delays[i]=(.65+knotDelayStep*i)*duration_const;
        }

        for (i = 0; i < 10; i++) {
            int j1 = irand(0, 3);
            int j2 = irand(0, 3);
            float temp = knot_delays[j1];
            knot_delays[j1] = knot_delays[j2];
            knot_delays[j2] = temp;
        }

        if (current_page == 2) {
            ic_pin_layer.rotation = -15;
            ic_cam_layer.rotation = 15;
            ic_smile_layer.rotation = -15;
            ic_bubble_layer.rotation = -15;
        }

        if (current_page == 4) {
            anim_safe_button_q = 21;
            anim_safe_button_i = 2;
            anim_safe_button_j = 3;
            anim_safe_button_start_time = time_local + 1.5;
        }

        if (current_page == 5) {
            ic_pin_layer.rotation = -15;
            ic_videocam_layer.rotation = -30;
            ic_cam_layer.rotation = 15;
            ic_smile_layer.rotation = -15;
            ic_bubble_layer.rotation = -15;
        }
    }



    fps_anim++;
    if (count_anim_fps == 1 && date-ms0_anim >= duration_const) {
        /*
        char str[15];
        sprintf(str, "anim>%d", fps_anim);
        DEBUG_LOG_WRITE_D("fps>",str);
         */
        count_anim_fps=0;
    }


    fps++;
    if (date-ms0 >= 1.) {
        /*
        char str[15];
        sprintf(str, "%d", fps);
        DEBUG_LOG_WRITE_D("fps",str);
        */

        ms0=date;
        fps=0;
    }


    time = date - date0;


    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glEnable(GL_BLEND);


    float private_back_k = .8;

    glClearColor(backgroundColor[0], backgroundColor[1], backgroundColor[2], 1);
    glClear(GL_COLOR_BUFFER_BIT);

    /*
    rglNormalDraw();
    telegram_sphere.params.alpha = 1;
    //telegram_sphere.params.position.y = -offset_y;
    draw_textured_shape(&telegram_sphere, main_matrix, NORMAL);

    draw_stars();
    */
    //return;


    // LAYER0 - PREPARATION ///// ///// ///// ///// ///// ///// ///// /////
    if (current_page == 0)
    {
        rglNormalDraw();

        telegram_sphere.params.alpha = 1;

        scale = 1;

        float alpha = 1;
        if (direct == 0) {
            alpha = t(0, 1, 0, duration_const, Linear);

            scale = 1;

            fast_body.params.alpha = 1;
            fast_body.params.scale = xyzMake(scale, scale, 1);
            draw_textured_shape(&fast_body, main_matrix, NORMAL);
        }

        telegram_sphere.params.alpha = alpha;
        telegram_sphere.params.scale = xyzMake(scale, scale, 1);

        telegram_plane.params.alpha=1;

        float tt = MINf(0, -M_PI*125./180. + time * M_PI * 2 * 1.5);

        float dx = sin(tt)*75;
        float dy = -sin(tt)*60;

        telegram_plane.params.position = xyzMake(dx, dy, 0);

        float scale = (cos(tt)+1)*.5;

        telegram_plane.params.scale = xyzMake(cos(tt)*scale, scale, 1);

        if (tt < D2R(125)) {
            glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
        }
    }


    else if (current_page == 1)
    {
        rglNormalDraw();
        if (direct == 1) {
            fast_body.params.scale = xyzMake(1, 1, 1);
            fast_body.params.alpha = 1;
            draw_textured_shape(&fast_body, main_matrix, NORMAL);
        } else {
            fast_body.params.alpha = t(0, 1, .0, duration_const, Linear);;
            float scale = t(.95, 1, 0, duration_const, EaseInEaseOut);
            fast_body.params.scale = xyzMake(scale, scale, 1.);
            draw_textured_shape(&fast_body, main_matrix, NORMAL);
        }
    }


    else if (current_page == 2)
    {
        rglNormalDraw();
        if (direct == 1) {
            fast_body.params.alpha = t(1., .0, .0, duration_const, Linear);;
            float scale = t(1, .95, 0, duration_const, EaseInEaseOut);
            fast_body.params.scale = xyzMake(scale, scale, 1.);
            draw_textured_shape(&fast_body, main_matrix, NORMAL);
        }
    }


    else if (current_page == 4)
    {
        if (direct == 1) {
            privateLayer.rotation=private_scroll_offset + t(-90, 0, 0, duration_const, EaseOut);
        } else {
            privateLayer.rotation=private_scroll_offset + t(90, 0, 0, duration_const*private_back_k, EaseOut);
        }
        mat4x4_layer(private_matrix, privateLayer, 1., 0);
    }




    // LAYER1 - MASK ///// ///// ///// ///// ///// ///// ///// /////
    rglMaskDraw();
    mask1.params.position.z = cloud_extra_mask1.params.position.z = cloud_extra_mask2.params.position.z = cloud_extra_mask3.params.position.z = cloud_extra_mask4.params.position.z = 1;


    if (current_page == 0)
    {
        if (direct == 0) {
            change_rounded_rectangle(&mask1, CSizeMake(r1*2, r1*2), r1);
            mask1.params.rotation = 0;
        }
    }


    else if (current_page == 1)
    {
        if (direct == 1) {
            change_rounded_rectangle(&mask1, CSizeMake(r1*2, r1*2), r1);
            mask1.params.rotation = 0;
        } else {
            float size = t(r2*2, r1*2, 0, duration_const, EaseInEaseOut);
            float round = t(30, r1, 0, duration_const, EaseInEaseOut);
            change_rounded_rectangle(&mask1, CSizeMake(size, size), round);
            free_scroll_offset = 0;
            mask1.params.rotation=t(180, 0., 0, duration_const, EaseInEaseOut) + free_scroll_offset;
        }

    }




    else if (current_page == 2)
    {
        if (direct==1) {
            float size = t(r1*2, r2*2, 0, duration_const, EaseInEaseOut);
            float round = t(r1, 30, 0, duration_const, EaseInEaseOut);
            change_rounded_rectangle(&mask1, CSizeMake(size, size), round);
            free_scroll_offset = scroll_offset*5;
            mask1.params.rotation=t(0, 180., 0, duration_const, EaseInEaseOut) + free_scroll_offset;
        }
        else
        {
            free_scroll_offset = scroll_offset*5;
            float r=316/4.;
            float size = t_reversed(r2*2, r*2, 0, duration_const, EaseInEaseOut);
            float round = t_reversed(30, 20, 0, duration_const, EaseInEaseOut);
            change_rounded_rectangle(&mask1, CSizeMake(size, size), round);
            mask1.params.rotation=t_reversed(180.+free_scroll_offset, 180.+90., 0, duration_const, EaseInEaseOut);
        }
    }


    else if (current_page == 3)
    {
        if (direct == 1) {
            float r = 316/4.;
            float size = t(r2*2, r*2, 0, duration_const, EaseInEaseOut);
            float round = t(30, 20, 0, duration_const, EaseInEaseOut);
            change_rounded_rectangle(&mask1, CSizeMake(size, size), round);
            mask1.params.rotation = t(180.+free_scroll_offset, 180.+90., 0, duration_const, EaseInEaseOut);
        } else {
            float r = 316/4.;
            float size = t_reversed(r*2, r2*2, 0, duration_const, EaseOut);
            float round = t_reversed(20, 30, 0, duration_const, EaseOut);
            change_rounded_rectangle(&mask1, CSizeMake(size, size), round );
            mask1.params.rotation = t_reversed(180.+90., 180.+90.+90., 0, duration_const, EaseOut);
            mask1.params.position = xyzMake(0,0,mask1.params.position.z);
        }
    }


    else if (current_page == 4)
    {
        if (direct == 1) {

            float r=316/4.;
            float size = t(r*2, r2*2, 0, duration_const, EaseOut);
            float round = t(20, 30, 0, duration_const, EaseOut);
            change_rounded_rectangle(&mask1, CSizeMake(size, size), round );
            mask1.params.rotation=private_scroll_offset + t(180.+90., 180.+90.+90., 0, duration_const, EaseOut);
            mask1.params.position = xyzMake(0,0,mask1.params.position.z);

        } else {

            float k = 0;

            k=1.*private_back_k;
            float scale = t_reversed(r2*2, 100, 0, duration_const*k, EaseOut);
            change_rounded_rectangle(&mask1, CSizeMake(scale, scale), t_reversed(30, 50, 0, duration_const*k, EaseOut));
            mask1.params.position = xyzMake( t_reversed(0, 29/2, 0, duration_const*k, EaseOut), t_reversed(0, -19/2, 0, duration_const*k, EaseOut), mask1.params.position.z);
            mask1.params.rotation=private_scroll_offset + t_reversed(180.+90.+90., 180.+90.+90.+90., 0, duration_const*k, EaseOut);


            k=1.*private_back_k;
            int sublayer2_radius = 33;
            cloud_extra_mask1.params.position = xyzMake( t_reversed(0, -122/2, 0, duration_const*k, EaseOut), t_reversed(0, 54/2-1, 0, duration_const*k, EaseOut),  cloud_extra_mask1.params.position.z);
            scale = t_reversed(0, sublayer2_radius, 0, duration_const*k, EaseOut);
            cloud_extra_mask1.params.scale = xyzMake(scale, scale,1);
            draw_shape(&cloud_extra_mask1, main_matrix);


            k = 1.15*private_back_k;
            int sublayer3_radius = 94/4;
            cloud_extra_mask2.params.position = xyzMake( t_reversed(0, -84/2, 0, duration_const*k, EaseOut), t_reversed(0, -29/2, 0, duration_const*k, EaseOut),  cloud_extra_mask2.params.position.z);
            scale = t_reversed(0, sublayer3_radius, 0, duration_const*k, EaseOut);
            cloud_extra_mask2.params.scale = xyzMake(scale, scale,1);
            draw_shape(&cloud_extra_mask2, main_matrix);


            k=1.3*private_back_k;
            int sublayer4_radius = 124/4;
            cloud_extra_mask3.params.position = xyzMake( t_reversed(0, 128/2, 0, duration_const*k, EaseOut), t_reversed(0, 56/2, 0, duration_const*k, EaseOut),  cloud_extra_mask3.params.position.z);
            scale = t_reversed(0, sublayer4_radius, 0, duration_const*k, EaseOut);
            cloud_extra_mask3.params.scale = xyzMake(scale, scale,1);
            draw_shape(&cloud_extra_mask3, main_matrix);


            k=1.5*private_back_k;
            int sublayer5_radius = 64;
            cloud_extra_mask4.params.position = xyzMake( t_reversed(0, 0, 0, duration_const*k, EaseOut), t_reversed(0, 50, 0, duration_const*k, EaseOut),  cloud_extra_mask4.params.position.z);
            scale = t_reversed(0, sublayer5_radius, 0, duration_const*k, EaseOut);
            cloud_extra_mask4.params.scale = xyzMake(scale, scale,1);
            draw_shape(&cloud_extra_mask4, main_matrix);
        }

    }


    else if (current_page == 5)
    {

        float k = 0;

        k = 0.8;
        float scale = t(r2*2, 100, 0, duration_const*k, EaseOut);
        change_rounded_rectangle(&mask1, CSizeMake(scale, scale), t(30, 50, 0, duration_const*k, EaseOut));
        mask1.params.position = xyzMake( t(0, 29/2, 0, duration_const*k, EaseOut), t(0, -19/2, 0, duration_const*k, EaseOut), mask1.params.position.z);
        mask1.params.rotation = t(180.+90.+90., 180.+90.+90.+90., 0, duration_const*k, EaseOut);


        k = 1.;
        int sublayer2_radius = 33;
        cloud_extra_mask1.params.position = xyzMake( t(0, -122/2, 0, duration_const*k, EaseOut), t(0, 54/2-1, 0, duration_const*k, EaseOut),  cloud_extra_mask1.params.position.z);
        scale = t(0, sublayer2_radius, 0, duration_const*k, EaseOut);
        cloud_extra_mask1.params.scale = xyzMake(scale, scale,1);
        draw_shape(&cloud_extra_mask1, main_matrix);


        k = 1.15;
        int sublayer3_radius = 94/4;
        cloud_extra_mask2.params.position = xyzMake( t(0, -84/2, 0, duration_const*k, EaseOut), t(0, -29/2, 0, duration_const*k, EaseOut),  cloud_extra_mask2.params.position.z);
        scale = t(0, sublayer3_radius, 0, duration_const*k, EaseOut);
        cloud_extra_mask2.params.scale = xyzMake(scale, scale,1);
        draw_shape(&cloud_extra_mask2, main_matrix);


        k = 1.3;
        int sublayer4_radius = 124/4;
        cloud_extra_mask3.params.position = xyzMake( t(0, 128/2, 0, duration_const*k, EaseOut), t(0, 56/2, 0, duration_const*k, EaseOut),  cloud_extra_mask3.params.position.z);
        scale = t(0, sublayer4_radius, 0, duration_const*k, EaseOut);
        cloud_extra_mask3.params.scale = xyzMake(scale, scale,1);
        draw_shape(&cloud_extra_mask3, main_matrix);


        k = 1.5;
        int sublayer5_radius = 64;
        cloud_extra_mask4.params.position = xyzMake( t(0, 0, 0, duration_const*k, EaseOut), t(0, 50, 0, duration_const*k, EaseOut),  cloud_extra_mask4.params.position.z);
        scale = t(0, sublayer5_radius, 0, duration_const*k, EaseOut);
        cloud_extra_mask4.params.scale = xyzMake(scale, scale,1);
        draw_shape(&cloud_extra_mask4, main_matrix);

    }
    draw_shape(&mask1, main_matrix);





    // LAYER3 - THROUGH MASK ///// ///// ///// ///// ///// ///// ///// /////
    int rr = 30;
    int seg = 15;
    int ang = 180;
    rglNormalDrawThroughMask();
    if (current_page == 0)
    {
        if (direct == 0) {
            glEnable(GL_BLEND);
            glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);

            change_segmented_square(&spiral, r1, D2R(rr+seg),  D2R(speedometer_scroll_offset + calculated_speedometer_sin + t(-seg+ang, 0, 0, duration_const, EaseOut)));

            spiral.params.scale = xyzMake(1, 1, 1);
            spiral.params.rotation = t(180., 0, 0, duration_const, EaseOut);
            spiral.params.alpha = t(1,0,0,duration_const,Linear);
            draw_textured_shape(&spiral, main_matrix, NORMAL_ONE);

            fast_arrow.params.alpha = fast_arrow_shadow.params.alpha = t(1,0,0,duration_const,Linear);
            fast_arrow.params.rotation = fast_arrow_shadow.params.rotation = t(rr, rr-180-160, 0, duration_const, EaseOut) + speedometer_scroll_offset + calculated_speedometer_sin;
            draw_textured_shape(&fast_arrow_shadow, main_matrix, NORMAL_ONE);
            draw_textured_shape(&fast_arrow, main_matrix, NORMAL_ONE);
        }
    }
    else if (current_page == 1)
    {
        glEnable(GL_BLEND);
        glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);

        speedometer_scroll_offset = scroll_offset * 25;
        calculated_speedometer_sin = 0;

        if (direct == 1) {

            float value = 0;
            float e = 2.71;

            float arg = time * 50;

            value = 180 - 180 * pow(e, -0.055*arg * 2) * cos(0.08*arg*3);

            float ta = t(0, 180., 0, duration_const, EaseOut);

            change_segmented_square(&spiral, r1, D2R(rr+seg), D2R(-seg + value + speedometer_scroll_offset));

            spiral.params.scale = xyzMake(1, 1, 1);
            spiral.params.rotation = ta;
            spiral.params.alpha = t(0, 1, 0, duration_const, Linear);
            draw_textured_shape(&spiral, main_matrix, NORMAL_ONE);

            fast_arrow.params.alpha = fast_arrow_shadow.params.alpha = t(0, 1, 0, duration_const, Linear);
            fast_arrow.params.rotation = fast_arrow_shadow.params.rotation = -330 + value + ta + speedometer_scroll_offset;
            draw_textured_shape(&fast_arrow_shadow, main_matrix, NORMAL_ONE);
            draw_textured_shape(&fast_arrow, main_matrix, NORMAL_ONE);

        } else {

            spiral.params.alpha = fast_arrow.params.alpha = fast_arrow_shadow.params.alpha = 1;

            float value = 0;
            float e = 2.71;

            float arg = time*50;

            float dangle = 90;
            value = 180 - 90 - (180-90) * pow(e, -0.055*arg * 2) * cos(0.08*arg*3);
            value *= -1;

            change_segmented_square(&spiral, r1, D2R(rr+seg), D2R(speedometer_scroll_offset + value + calculated_speedometer_sin + t( 360, 360-dangle-seg, 0, duration_const, EaseInEaseOut)));

            float scale = t(1.18, 1, 0, duration_const, EaseInEaseOut);
            spiral.params.scale = xyzMake(scale, scale, 1);
            spiral.params.rotation = t(360, 180, 0, duration_const, EaseInEaseOut);
            draw_textured_shape(&spiral, main_matrix, NORMAL);

            fast_arrow.params.rotation = fast_arrow_shadow.params.rotation = speedometer_scroll_offset + value + calculated_speedometer_sin + t(rr+360+6, rr+360-180-dangle, 0, duration_const, EaseInEaseOut);
            draw_textured_shape(&fast_arrow_shadow, main_matrix, NORMAL);
            draw_textured_shape(&fast_arrow, main_matrix, NORMAL);

            glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
            free_bg.params.alpha = t(1, 0, 0, duration_const, Linear);
            draw_shape(&free_bg, main_matrix);

            draw_ic(0);
        }
    }
    else if (current_page == 2) {
        glEnable(GL_BLEND);
        glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);

        if (direct == 1) {
            spiral.params.alpha = fast_arrow.params.alpha = fast_arrow_shadow.params.alpha = 1;

            int ang = 180;
            change_segmented_square(&spiral, r1, D2R(rr+seg+speedometer_scroll_offset), D2R(t(-seg+ang, 360, 0, duration_const, EaseInEaseOut)));

            float scale = t(1, 1.18, 0, duration_const, EaseInEaseOut);
            spiral.params.scale = xyzMake(scale, scale, 1);
            spiral.params.rotation = t(180, 360, 0, duration_const, EaseInEaseOut);
            draw_textured_shape(&spiral, main_matrix, NORMAL);

            fast_arrow.params.rotation = fast_arrow_shadow.params.rotation = speedometer_scroll_offset + t(rr, rr+360+6, 0, duration_const, EaseInEaseOut);
            draw_textured_shape(&fast_arrow_shadow, main_matrix, NORMAL);
            draw_textured_shape(&fast_arrow, main_matrix, NORMAL);

            glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
            free_bg.params.alpha = t(0, 1, 0, duration_const, Linear);
            draw_shape(&free_bg, main_matrix);

            draw_ic(0);
        }
        else
        {
            glDisable(GL_BLEND);
            free_bg.params.alpha = 1;
            draw_shape(&free_bg, main_matrix);

            glEnable(GL_BLEND);
            glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
            draw_ic(0);

            powerful_bg.params.alpha = t_reversed(0, 1, 0, duration_const, Linear);
            draw_shape(&powerful_bg, main_matrix);
        }

        //back
        ribbon1.params.rotation = 0;
        ribbon2.params.rotation = 90;
        ribbon3.params.rotation = 180;
        ribbon4.params.rotation = 270;
    }
    else if (current_page == 3) {
        if (direct == 1) {
            glDisable(GL_BLEND);
            free_bg.params.alpha = 1;
            draw_shape(&free_bg, main_matrix);

            glEnable(GL_BLEND);
            glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
            powerful_bg.params.alpha = t(0, 1, 0, duration_const, Linear);
            draw_shape(&powerful_bg, main_matrix);

            draw_stars();

        } else {
            glDisable(GL_BLEND);
            private_bg.params.alpha = 1;
            draw_shape(&private_bg, main_matrix);

            float a = t(0, 1., 0, duration_const, EaseOut);

            glEnable(GL_BLEND);
            glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
            powerful_bg.params.rotation = 0;
            powerful_bg.params.alpha = a;
            draw_shape(&powerful_bg, main_matrix);

            draw_stars();
        }
    }
    else if (current_page == 4)
    {
        if (direct == 1) {
            glDisable(GL_BLEND);
            powerful_bg.params.alpha = 1;
            draw_shape(&powerful_bg, main_matrix);

            float a = t(0, 1., 0, duration_const, EaseOut);

            glEnable(GL_BLEND);
            glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
            private_bg.params.rotation = t(45, 0, 0, duration_const, EaseOut);
            private_bg.params.alpha = a;
            draw_shape(&private_bg, main_matrix);

        } else {

            glDisable(GL_BLEND);
            cloud_bg.params.alpha = 1;
            draw_shape(&cloud_bg, main_matrix);

            float a = t(0, 1., 0, duration_const*private_back_k, EaseOut);

            glEnable(GL_BLEND);
            glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
            private_bg.params.alpha = a;
            draw_shape(&private_bg, main_matrix);
        }
    }
    else if (current_page == 5)
    {
        glDisable(GL_BLEND);
        private_bg.params.alpha = 1.;
        draw_shape(&private_bg, main_matrix);

        float a = t(0, 1., 0, duration_const, EaseOut);

        glEnable(GL_BLEND);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        cloud_bg.params.alpha = a;
        draw_shape(&cloud_bg, main_matrix);


        if (scroll_offset > 0) {
            cloud_scroll_offset = -scroll_offset*40;
        } else {
            cloud_scroll_offset = -scroll_offset*15;
        }

        draw_ic(1);
    }


//powerful_mask.params.alpha = 0.0;


    // LAYER4 - DETAILS ///// ///// ///// ///// ///// ///// ///// /////
    if (current_page == 0)
    {
        rglNormalDraw();

        if (direct == 0) {

            telegram_sphere.params.alpha = t(0, 1, 0, duration_const*.8, Linear);

            scale = 1.005;

            telegram_sphere.params.scale = xyzMake(scale, scale, 1);
            draw_textured_shape(&telegram_sphere, main_matrix, NORMAL);

            float tt = MINf(0, -M_PI*125./180. + time * M_PI * 2 * 1.5);

            float dx = sin(tt)*75;
            float dy = -sin(tt)*60;

            telegram_plane.params.position = xyzMake(dx, dy, 0);

            float scale = (cos(tt)+1)*.5;

            telegram_plane.params.scale = xyzMake(cos(tt)*scale, scale, 1);

            if (tt < D2R(125)) {
                glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
                draw_textured_shape(&telegram_plane, main_matrix, NORMAL_ONE);
            }
        }
    }
    else if (current_page==1)
    {
        rglNormalDraw();

        if (direct == 1) {

            telegram_sphere.params.alpha = t(1, 0, 0, duration_const, Linear);
            draw_textured_shape(&telegram_sphere, main_matrix, NORMAL);

            float tt = time * M_PI*2*1.5;

            float dx = sin(tt)*75;
            float dy = -sin(tt)*60;

            telegram_plane.params.position = xyzMake(dx, dy, 0);// CGPointMake(planeCenter.x + dx, planeCenter.y + dy);

            float scale = (cos(tt)+1)*.5;

            telegram_plane.params.scale = xyzMake(cos(tt)*scale, scale, 1);

            if (tt < D2R(125)) {
                glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
                draw_textured_shape(&telegram_plane, main_matrix, NORMAL_ONE);
            }
        }
    }
    else if (current_page == 2)
    {
        rglNormalDrawThroughMask();

        float dribbon=87;

        if (direct == 1) {

            glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);

            ribbonLayer.rotation = scroll_offset*5 + t(180, 360, 0, duration_const, EaseInEaseOut);
            mat4x4_layer(ribbons_layer, ribbonLayer, 1., 0);

            float scale;
            float dur = duration_const*.5;


            free_knot1.params.position = xyzMake(5, -5-9, 0);
            scale = t(0, 1, knot_delays[0], dur, EaseOut);
            free_knot1.params.scale = xyzMake(scale, scale, 1);
            draw_textured_shape(&free_knot1, ribbons_layer, NORMAL_ONE);

            free_knot2.params.position = xyzMake(-5, -5-9, 0);
            scale = t(0, 1, knot_delays[1], dur, EaseOut);
            free_knot2.params.scale = xyzMake(-scale, scale, 1);
            draw_textured_shape(&free_knot2, ribbons_layer, NORMAL_ONE);

            free_knot3.params.position = xyzMake(-5, 5-9, 0);
            scale = t(0, 1, knot_delays[2], dur, EaseOut);
            free_knot3.params.scale = xyzMake(-scale, scale, 1);
            draw_textured_shape(&free_knot3, ribbons_layer, NORMAL_ONE);

            free_knot3.params.position = xyzMake(5, 5-9, 0);
            scale = t(0, 1, knot_delays[3], dur, EaseOut);
            free_knot3.params.scale = xyzMake(scale, scale, 1);
            draw_textured_shape(&free_knot3, ribbons_layer, NORMAL_ONE);


            glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
            ribbon1.params.alpha=ribbon2.params.alpha=ribbon3.params.alpha=ribbon4.params.alpha=t(0, 1, 0, dur, EaseInEaseOut);

            int ribbon_k = time > duration_const ? 1 : 0;

            change_ribbon(&ribbon1, ribbonLength -8.*ribbon_k - free_scroll_offset/5.*(30-8*ribbon_k) );
            ribbon1.params.position.x = scroll_offset*30*0 + t(-dribbon, 0, 0, duration_const, EaseInEaseOut);
            draw_shape(&ribbon1, ribbons_layer);

            change_ribbon(&ribbon2, ribbonLength -10.*ribbon_k - free_scroll_offset/5.*(22-10*ribbon_k) );
            ribbon2.params.position.y = scroll_offset*15 + t(-9-dribbon, -9, 0, duration_const, EaseInEaseOut);
            draw_shape(&ribbon2, ribbons_layer);

            ribbon3.params.position.x = t(dribbon, 0, 0, duration_const, EaseInEaseOut);;
            draw_shape(&ribbon3, ribbons_layer);

            ribbon4.params.position.y = t(-9+dribbon, -9, 0, duration_const, EaseInEaseOut);;
            draw_shape(&ribbon4, ribbons_layer);


            //back
            ribbonLayer.anchor.y = 0;
            ribbonLayer.position.y = 0;

            change_ribbon(&ribbon1, ribbonLength);
            change_ribbon(&ribbon2, ribbonLength);
            change_ribbon(&ribbon3, ribbonLength);
            change_ribbon(&ribbon4, ribbonLength);

        }
        else
        {
            glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);

            float scale = t(1, 2, 0, duration_const, EaseIn);
            powerful_mask.params.scale = xyzMake(scale, scale, 1);
            
            texture_program_type shape_texture_type;
            if (backgroundColor[1] < 0.01) {
                shape_texture_type = DARK;
            } else if (backgroundColor[1] > 0.99) {
                shape_texture_type = LIGHT;
            } else {
                shape_texture_type = DARK_BLUE;
            }
            
            draw_textured_shape(&powerful_mask, main_matrix, shape_texture_type);

            ribbonLayer.rotation = free_scroll_offset + t_reversed(360, 360+(45+30), 0, duration_const, EaseOut);
            ribbonLayer.position.y = t_reversed(0, -8, 0, duration_const*.8, EaseOut);
            ribbonLayer.anchor.y = t_reversed(0, -9, 0, duration_const*.8, EaseOut);
            mat4x4_layer(ribbons_layer, ribbonLayer, 1., 0);


            float dur = duration_const*.5;

            free_knot1.params.position = xyzMake(11/2, -11/2-9, 0);
            scale = t(0, 1, knot_delays[0], dur, EaseOut);
            free_knot1.params.scale = xyzMake(scale, scale, 1);
            draw_textured_shape(&free_knot1, ribbons_layer, NORMAL_ONE);

            free_knot2.params.position = xyzMake(-11/2, -11/2-9, 0);
            scale = t(0, 1, knot_delays[1], dur, EaseOut);
            free_knot2.params.scale = xyzMake(-scale, scale, 1);
            draw_textured_shape(&free_knot2, ribbons_layer, NORMAL_ONE);

            free_knot3.params.position = xyzMake(-11/2, 11/2-9, 0);
            scale = t(0, 1, knot_delays[2], dur, EaseOut);
            free_knot3.params.scale = xyzMake(-scale, scale, 1);
            draw_textured_shape(&free_knot3, ribbons_layer, NORMAL_ONE);

            free_knot3.params.position = xyzMake(11/2, 11/2-9, 0);
            scale = t(0, 1, knot_delays[3], dur, EaseOut);
            free_knot3.params.scale = xyzMake(scale, scale, 1);
            draw_textured_shape(&free_knot3, ribbons_layer, NORMAL_ONE);





            float a1=-25;
            ribbon1.params.rotation = t_reversed(0, a1, 0, duration_const, EaseOut);
            ribbon3.params.rotation = t_reversed(180, 180+a1, 0, duration_const, EaseOut);

            float a2=0;
            ribbon2.params.rotation = t_reversed(90, 90+a2, 0, duration_const, EaseOut);
            ribbon4.params.rotation = t_reversed(270, 270+a2, 0, duration_const, EaseOut);

            float k=.9;
            ribbon2.params.alpha = ribbon4.params.alpha = t_reversed(1, 0, duration_const*.5, duration_const*.1, Linear);


            int ribbon_k = time > duration_const ? 1 : 0;

            ribbon_k=0;
            change_ribbon(&ribbon1, t_reversed(ribbonLength-8.*ribbon_k, 0, 0, duration_const*.9, Linear) - free_scroll_offset/5.*(30-8*ribbon_k));
            ribbon1.params.position.x = 0;
            draw_shape(&ribbon1, ribbons_layer);

            change_ribbon(&ribbon2, t_reversed(ribbonLength-10.*ribbon_k, 0, 0, duration_const*k, Linear) - free_scroll_offset/5.*(22-10*ribbon_k));
            ribbon2.params.position.y = scroll_offset*15 + -9;
            draw_shape(&ribbon2, ribbons_layer);

            change_ribbon(&ribbon3, t_reversed(ribbonLength, 0, 0, duration_const*.9, Linear));
            draw_shape(&ribbon3, ribbons_layer);

            change_ribbon(&ribbon4, t_reversed(ribbonLength, 0, duration_const*.6*0, duration_const*k, Linear));
            draw_shape(&ribbon4, ribbons_layer);

            float infinityDurK = 1.3;

            rglMaskDraw();

            change_infinity(&infinity, t_reversed(0, 0.99, 0, duration_const*infinityDurK, EaseOut));

            float rot1 = t(0, -50, duration_const*.5, duration_const*.8, EaseOut);
            float rot2 = t(0, -30, duration_const*.8, duration_const, EaseOut);
            infinity.params.rotation = rot1;

            infinity.params.position.z = 1;
            infinity.params.position.y = -6;
            infinity.params.anchor = xyzMake(52.75, 23.5, 0);

            float infinity_scale = 1.025;
            infinity.params.scale = xyzMake(infinity_scale, infinity_scale, 1);
            draw_shape(&infinity, main_matrix);

            infinity.params.scale = xyzMake(-infinity_scale, -infinity_scale, 1);
            draw_shape(&infinity, main_matrix);



            rglNormalDrawThroughMask();
            glEnable(GL_BLEND);
            glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);

            powerful_infinity_white.params.rotation = rot1 + rot2;
            powerful_infinity_white.params.alpha = 1;
            powerful_infinity_white.params.position.y = -6;

            draw_textured_shape(&powerful_infinity_white, main_matrix, NORMAL_ONE);

        }
    }


    else if (current_page == 3) {
        if (direct == 1) {

            // reset ribbons positions
            ribbon1.params.position.x = 0;
            ribbon2.params.position.y = -9;
            ribbon3.params.position.x = 0;
            ribbon4.params.position.y = -9;


            rglNormalDraw();
            glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);

            texture_program_type shape_texture_type;
            if (backgroundColor[1] < 0.01) {
                shape_texture_type = DARK;
            } else if (backgroundColor[1] > 0.99) {
                shape_texture_type = LIGHT;
            } else {
                shape_texture_type = DARK_BLUE;
            }
            
            float scale = t(2, 1, 0, duration_const, EaseOut);
            powerful_mask.params.scale = xyzMake(scale, scale, 1);
            draw_textured_shape(&powerful_mask, main_matrix, shape_texture_type);


            glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
            ribbonLayer.rotation = free_scroll_offset + t(360, 360+(45+30), 0, duration_const*.8, EaseOut);
            ribbonLayer.position.y = t(0, -8, 0, duration_const*.8, EaseOut);
            ribbonLayer.anchor.y = t(0, -9, 0, duration_const*.8, EaseOut);


            mat4x4_layer(ribbons_layer, ribbonLayer, 1., 0);

            float a1=-25;
            ribbon1.params.rotation = t(0, a1, 0, duration_const, EaseOut);
            ribbon3.params.rotation = t(180, 180+a1, 0, duration_const, EaseOut);

            float a2=0;
            ribbon2.params.rotation = t(90, 90+a2, 0, duration_const, EaseOut);
            ribbon4.params.rotation = t(270, 270+a2, 0, duration_const, EaseOut);




            float k=.5;
            ribbon2.params.alpha = ribbon4.params.alpha = t(1, 0, duration_const*k*.5, duration_const*k*.1, Linear);

            int ribbon_k = time > duration_const ? 1 : 0;

            change_ribbon(&ribbon1, t(ribbonLength-8.*ribbon_k-free_scroll_offset/5.*(30-8*ribbon_k), 0, 0, duration_const*.9, Linear));
            draw_shape(&ribbon1, ribbons_layer);

            change_ribbon(&ribbon2, t(ribbonLength-10.*ribbon_k-free_scroll_offset/5.*(22-10*ribbon_k), 0, 0, duration_const*k, Linear));
            draw_shape(&ribbon2, ribbons_layer);

            change_ribbon(&ribbon3, t(ribbonLength, 0, 0, duration_const*.9, Linear));
            draw_shape(&ribbon3, ribbons_layer);

            change_ribbon(&ribbon4, t(ribbonLength, 0, 0, duration_const*k, Linear));
            draw_shape(&ribbon4, ribbons_layer);


            float infinityDurK = 1.1;
            if (time < duration_const*infinityDurK-.025) {

                rglMaskDraw();

                change_infinity(&infinity, t(0, 0.99, 0, duration_const*infinityDurK, Linear));

                infinity.params.rotation = 0;

                infinity.params.position.z = 1;
                infinity.params.position.y = -6;
                infinity.params.anchor = xyzMake(52.75, 23.5, 0);

                float infinity_scale = 1.025;
                infinity.params.scale = xyzMake(infinity_scale, infinity_scale, 1);
                draw_shape(&infinity, main_matrix);

                infinity.params.scale = xyzMake(-infinity_scale, -infinity_scale, 1);
                draw_shape(&infinity, main_matrix);


                rglNormalDrawThroughMask();
                glEnable(GL_BLEND);
                glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);

                powerful_infinity_white.params.rotation = 0;
                powerful_infinity_white.params.alpha = 1;
                powerful_infinity_white.params.position.y = -6;

                draw_textured_shape(&powerful_infinity_white, main_matrix, NORMAL_ONE);

            } else {

                rglNormalDraw();

                glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
                powerful_infinity.params.position.y = -6;
                powerful_infinity.params.alpha = 1;
                draw_textured_shape(&powerful_infinity, main_matrix, NORMAL_ONE);
            }

        }
        else
        {
            rglNormalDraw();
            glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);

            texture_program_type shape_texture_type;
            if (backgroundColor[1] < 0.01) {
                shape_texture_type = DARK;
            } else if (backgroundColor[1] > 0.99) {
                shape_texture_type = LIGHT;
            } else {
                shape_texture_type = DARK_BLUE;
            }
            
            float scale = t(2, 1, 0, duration_const, EaseOut);
            powerful_mask.params.scale = xyzMake(scale, scale, 1);
            draw_textured_shape(&powerful_mask, main_matrix, shape_texture_type);


            glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
            scale = t(1, 2, 0, duration_const, EaseOut);
            private_stroke.params.scale = xyzMake(scale, scale, 1);
            private_stroke.params.rotation = t(0, -90, 0, duration_const, EaseOut);
            private_stroke.params.alpha = t(1, 0, 0, duration_const, Linear);
            private_stroke.params.position = xyzMake(0, t(0, -6, 0, duration_const, EaseOut), 0);
            scale = t_reversed(63*2., 63*2, 0, duration_const, EaseOut);
            change_rounded_rectangle_stroked(&private_stroke, CSizeMake(scale, scale), scale/2., 9);
            draw_shape(&private_stroke, main_matrix);


            float infinityDurK = 1.1;
            if (time < duration_const*infinityDurK-.025) {

                rglMaskDraw();

                change_infinity(&infinity, t(0, 0.99, 0, duration_const*infinityDurK, Linear));

                infinity.params.rotation = 0;

                infinity.params.position.z = 1;
                infinity.params.position.y = -6;
                infinity.params.anchor = xyzMake(52.75, 23.5, 0);

                float infinity_scale = 1.025;
                infinity.params.scale = xyzMake(infinity_scale, infinity_scale, 1);
                draw_shape(&infinity, main_matrix);

                infinity.params.scale = xyzMake(-infinity_scale, -infinity_scale, 1);
                draw_shape(&infinity, main_matrix);


                rglNormalDrawThroughMask();
                glEnable(GL_BLEND);
                glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);

                powerful_infinity_white.params.rotation = 0;
                powerful_infinity_white.params.alpha = 1;
                powerful_infinity_white.params.position.y = -6;

                draw_textured_shape(&powerful_infinity_white, main_matrix, NORMAL_ONE);

            } else {
                rglNormalDraw();

                glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
                powerful_infinity.params.position.y = -6;
                powerful_infinity.params.alpha = 1;
                draw_textured_shape(&powerful_infinity, main_matrix, NORMAL_ONE);

            }

        }

    }


    else if (current_page == 4)
    {
        private_stroke.params.scale = xyzMake(1, 1, 1);

        private_scroll_offset = scroll_offset*5;

        rglNormalDraw();
        glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);

        scale = t(1, 2, 0, duration_const, EaseOut);//*1.6;
        if (scale < 1.5) {
            powerful_mask.params.scale=xyzMake(scale, scale, 1);
        }

        if (direct == 1) {
            privateLayer.rotation = private_scroll_offset + t(-90, 0, 0, duration_const, EaseOut);
        } else {
            privateLayer.rotation = private_scroll_offset + t(90, 0, 0, duration_const*private_back_k, EaseOut);
        }

        mat4x4_layer(private_matrix, privateLayer, 1, 0);

        if (direct == 1) {
            glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
            powerful_infinity.params.position.y = -6;
            powerful_infinity.params.alpha = t(1, 0, 0, duration_const*.5*.5, EaseIn);
            draw_textured_shape(&powerful_infinity, main_matrix, NORMAL_ONE);
        }

        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

        if (direct == 1) {

            glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
            scale = t(.5, 1., 0, duration_const, EaseOut);
            private_door.params.scale = xyzMake(scale,scale,1);
            private_door.params.alpha = t(.0, 1., 0, duration_const, EaseOut);
            draw_textured_shape(&private_door, main_matrix, NORMAL_ONE);

            glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
            private_stroke.params.rotation = private_scroll_offset;
            private_stroke.params.alpha = 1;
            private_stroke.params.position = xyzMake(0, 0, 0);
            scale = t(63, 63*2, 0, duration_const, EaseOut);
            change_rounded_rectangle_stroked(&private_stroke, CSizeMake(scale, scale), scale/2., 9);
            draw_shape(&private_stroke, main_matrix);


            glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
            float k = .0;
            scale = t(.5, 1., duration_const*k, duration_const, EaseOut);
            private_keyhole_body.params.rotation = private_scroll_offset;
            private_keyhole_body.params.scale = xyzMake(scale,scale,1);
            private_keyhole_body.params.alpha = t(.0, 1., duration_const*k, duration_const, EaseOut);

            draw_safe(0, 1, t(0, 1, 0, duration_const, Linear));

        }
        else
        {


            glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
            scale = t(.5, 1., 0, duration_const*private_back_k, EaseOut);
            private_door.params.scale = xyzMake(scale,scale,1);
            private_door.params.alpha = t(.0, 1., 0, duration_const*private_back_k, EaseOut);
            draw_textured_shape(&private_door, main_matrix, NORMAL_ONE);

            glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
            private_stroke.params.rotation = private_scroll_offset;
            private_stroke.params.alpha = t(0, 1, 0, duration_const*.25, Linear);
            private_stroke.params.position = xyzMake(0, 0, 0);
            scale = t(63, 63*2, 0, duration_const*private_back_k, EaseOut);
            change_rounded_rectangle_stroked(&private_stroke, CSizeMake(scale, scale), scale/2., 9);
            draw_shape(&private_stroke, main_matrix);

            glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
            scale = t(.5, 1., 0, duration_const*private_back_k, EaseOut);
            private_keyhole_body.params.rotation = private_scroll_offset;
            private_keyhole_body.params.scale = xyzMake(scale,scale,1);
            private_keyhole_body.params.alpha = t(.0, 1., 0, duration_const*private_back_k, EaseOut);


            if (time < duration_const*.4) {
                cloud_cover.params.position.y=t_reversed(118/2+50, 118/2, duration_const*.8*private_back_k, duration_const*private_back_k, EaseOut);
                if (backgroundColor[1] < 0.01) {
                    vec4 color = {0.0,0.0,0.0,1.0};
                    draw_colored_shape(&cloud_cover, main_matrix, color);
                } else if (backgroundColor[1] > 0.99) {
                    vec4 color = {1.0,1.0,1.0,1.0};
                    draw_colored_shape(&cloud_cover, main_matrix, color);
                } else {
                    vec4 color = {0.09,0.133,0.176, 1.0f};
                    draw_colored_shape(&cloud_cover, main_matrix, color);
                }
            }

            draw_safe(0, t(0,1,duration_const*private_back_k*.0, duration_const*private_back_k, Linear), t(0, 1, 0, duration_const, Linear));
        }
    }


    else if (current_page == 5) {
        float private_fade_k = .5;

        rglNormalDraw();

        glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
        scale = 1;
        private_door.params.scale = xyzMake(scale,scale,1);
        private_door.params.alpha = t(1, 0, 0, duration_const*private_fade_k*.5, EaseOut);
        draw_textured_shape(&private_door, main_matrix, NORMAL_ONE);


        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        private_stroke.params.rotation = private_scroll_offset;
        private_stroke.params.alpha = t(1, 0, 0, duration_const*private_fade_k*.5, EaseOut);
        scale = t(244/2, r2*2, 0, duration_const, EaseOut);
        change_rounded_rectangle_stroked(&private_stroke, CSizeMake(scale, scale), scale/2., 9);
        draw_shape(&private_stroke, main_matrix);


        glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
        scale = 1;
        private_keyhole_body.params.rotation = private_scroll_offset;
        private_keyhole_body.params.scale = xyzMake(scale,scale,1);
        private_keyhole_body.params.alpha = t(1.0, 0., 0, duration_const*private_fade_k*.5, EaseOut);


        privateLayer.rotation = private_scroll_offset;
        mat4x4_layer(private_matrix, privateLayer, t(1, .9, 0, duration_const*private_fade_k, EaseOut), 0);


        cloud_cover.params.position.y = t(118/2+50, 118/2, 0, duration_const, EaseOut);
        if (backgroundColor[1] < 0.01) {
            vec4 color = {0.0,0.0,0.0,1.0};
            draw_colored_shape(&cloud_cover, main_matrix, color);
        } else if (backgroundColor[1] > 0.99) {
            vec4 color = {1.0,1.0,1.0,1.0};
            draw_colored_shape(&cloud_cover, main_matrix, color);
        } else {
            vec4 color = {0.09,0.133,0.176, 1.0f};
            draw_colored_shape(&cloud_cover, main_matrix, color);
        }
    }

    prev_page = current_page;
}
