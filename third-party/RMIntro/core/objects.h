//
//  objects.h
//  IntroOpenGL
//
//  Created by Ilya Rimchikov on 29/03/14.
//  Copyright (c) 2014 IntroOpenGL. All rights reserved.
//


#include "platform_gl.h"
#include "program.h"
#include "linmath.h"

extern float scale_factor;
extern int width, height;
extern int y_offset_absolute;

typedef enum {NORMAL, NORMAL_ONE, RED, BLUE, LIGHT_RED, LIGHT_BLUE, DARK, LIGHT, DARK_BLUE} texture_program_type;

typedef struct {
    float x;
    float y;
} CPoint;

typedef struct {
    float width;
    float height;
} CSize;

typedef struct {
    float r;
    float g;
    float b;
    float a;
} CColor;


CPoint CPointMake(float x, float y);
CSize CSizeMake(float width, float height);


float D2R(float a);
float R2D(float a);


typedef struct {
    float x;
    float y;
    float z;
} xyz;

xyz xyzMake(float x, float y, float z);


typedef struct {
    float side_length;
    float start_angle;
    float end_angle;
    float angle;
    CSize size;
    float radius;
    float width;
} VarParams;

typedef struct {
    int datasize;
    int round_count;
    GLenum triangle_mode;
    int is_star;
} ConstParams;

typedef struct {
    xyz anchor;
	xyz position;
    float rotation;
    xyz scale;
} LayerParams;

typedef struct {
    xyz anchor;
	xyz position;
    float rotation;
    xyz scale;
    float alpha;

    VarParams var_params;
    ConstParams const_params;
    
    LayerParams *layer_params;

} Params;



typedef struct {
	vec4 color;
    CPoint *data;
	GLuint buffer;
	int num_points;
    
    Params params;
} Shape;


typedef struct {
	GLuint texture;
    CPoint *data;
	GLuint buffer;
	int num_points;
    
    Params params;
} TexturedShape;



Params default_params();
LayerParams default_layer_params();

void mat4x4_translate_independed(mat4x4 m, float x, float y, float z);


void set_y_offset_objects(float a);



void setup_shaders();


void draw_shape(const Shape* shape, mat4x4 view_projection_matrix);
void draw_colored_shape(const Shape* shape, mat4x4 view_projection_matrix, vec4 color);

void draw_textured_shape(const TexturedShape* shape, mat4x4 view_projection_matrix, texture_program_type program_type);


TexturedShape create_segmented_square(float side_length, float start_angle, float end_angle, GLuint texture);
void change_segmented_square(TexturedShape* shape, float side_length, float start_angle, float end_angle);

Shape create_rounded_rectangle(CSize size, float radius, int round_count, const vec4 color);
void change_rounded_rectangle(Shape* shape, CSize size, float radius);


Shape create_rectangle(CSize size, const vec4 color);


Shape create_circle(float radius, int vertex_count, const vec4 color);
void change_circle(Shape* shape, float radius);


void draw_colored_rectangle(const Shape* shape, mat4x4 view_projection_matrix);

TexturedShape create_textured_rectangle(CSize size, GLuint texture);
void change_textured_rectangle(TexturedShape* shape, CSize size);

Shape create_ribbon(float length, const vec4 color);
void change_ribbon(Shape* shape, float length);






Shape create_segmented_circle(float radius, int vertex_count, float start_angle, float angle, const vec4 color);
void change_segmented_circle(Shape* shape, float radius, float start_angle, float angle);

Shape create_infinity(float width, float angle, int segment_count, const vec4 color);
void change_infinity(Shape* shape, float angle);
void draw_infinity(const Shape* shape, mat4x4 view_projection_matrix);

Shape create_rounded_rectangle_stroked(CSize size, float radius, float stroke_width, int round_count, const vec4 color);
void change_rounded_rectangle_stroked(Shape* shape, CSize size, float radius, float stroke_width);

Shape create_rounded_rectangle(CSize size, float radius, int round_count, const vec4 color);
void change_rounded_rectangle(Shape* shape, CSize size, float radius);


void mat4x4_log(mat4x4 M);

