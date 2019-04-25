//
//  objects.c
//  IntroOpenGL
//
//  Created by Ilya Rimchikov on 29/03/14.
//  Copyright (c) 2014 IntroOpenGL. All rights reserved.
//


#include "objects.h"
#include "buffer.h"
#include "platform_gl.h"
#include "program.h"
#include "shader.h"
#include "linmath.h"
#include "matrix.h"
#include "math_helper.h"

#include "platform_log.h"
#include <math.h>
#include <stdlib.h>
#include "animations.h"

float scale_factor;
int width, height;
int y_offset_absolute;

static TextureProgram texture_program;
static TextureProgram texture_program_one;
static TextureProgram texture_program_red;
static TextureProgram texture_program_blue;
static TextureProgram texture_program_light_red;
static TextureProgram texture_program_light_blue;
static TextureProgram texture_program_black;
static TextureProgram texture_program_dark_blue;

static TextureProgram *texture_program_temp;

static ColorProgram color_program;
static GradientProgram gradient_program;

static float y_offset;

void set_y_offset_objects(float a)
{
    y_offset = a;
}

void setup_shaders()
{
    char *vshader =
    "uniform mat4 u_MvpMatrix;"
    "attribute vec4 a_Position;"
    "void main(){"
    "   gl_Position = u_MvpMatrix * a_Position;"
    "}";
    
    char *fshader =
    "precision lowp float;"
    "uniform vec4 u_Color;"
    "uniform float u_Alpha;"
    "void main() {"
    "   gl_FragColor = u_Color;"
    "   gl_FragColor.w*=u_Alpha;"
    "}";
    
    color_program = get_color_program(build_program(vshader, (GLint)strlen(vshader), fshader, (GLint)strlen(fshader)));
    
    
    char *vertex_gradient_shader =
    "uniform mat4 u_MvpMatrix;"
    "attribute vec4 a_Position;"
    "attribute vec4 a_Color;"
    "varying vec4 v_DestinationColor;"
    "void main(){"
    "   v_DestinationColor = a_Color;"
    "   gl_Position = u_MvpMatrix * a_Position;"
    "}";
    
    char *fragment_gradient_shader =
    "precision lowp float;"
    "uniform float u_Alpha;"
    "varying vec4 v_DestinationColor;"
    "void main() {"
    "   gl_FragColor = v_DestinationColor;"
    "   gl_FragColor.w*=u_Alpha;"
    "}";
    
    gradient_program = get_gradient_program(build_program(vertex_gradient_shader, (GLint)strlen(vertex_gradient_shader), fragment_gradient_shader, (GLint)strlen(fragment_gradient_shader)));
    
    
    char* vshader_texture  =
    "uniform mat4 u_MvpMatrix;"
    "attribute vec4 a_Position;"
    "attribute vec2 a_TextureCoordinates;"
    "varying vec2 v_TextureCoordinates;"
    "void main(){"
    "    v_TextureCoordinates = a_TextureCoordinates;"
    "    gl_Position = u_MvpMatrix * a_Position;"
    "}";
    
    char* fshader_texture  =
    "precision lowp float;"
    "uniform sampler2D u_TextureUnit;"
    "varying vec2 v_TextureCoordinates;"
    "uniform float u_Alpha;"
    "void main(){"
    "    gl_FragColor = texture2D(u_TextureUnit, v_TextureCoordinates);"
    "    gl_FragColor.w *= u_Alpha;"
    "}";
    
    texture_program = get_texture_program(build_program(vshader_texture, (GLint)strlen(vshader_texture), fshader_texture, (GLint)strlen(fshader_texture)));
    
    
    char* vshader_texture_blue  =
    "uniform mat4 u_MvpMatrix;"
    "attribute vec4 a_Position;"
    "attribute vec2 a_TextureCoordinates;"
    "varying vec2 v_TextureCoordinates;"
    "void main(){"
    "    v_TextureCoordinates = a_TextureCoordinates;"
    "    gl_Position = u_MvpMatrix * a_Position;"
    "}";
    
    char* fshader_texture_blue  =
    "precision lowp float;"
    "uniform sampler2D u_TextureUnit;"
    "varying vec2 v_TextureCoordinates;"
    "uniform float u_Alpha;"
    "void main(){"
    "    gl_FragColor = texture2D(u_TextureUnit, v_TextureCoordinates);"
    "   float p = u_Alpha*gl_FragColor.w;"
    "   gl_FragColor = vec4(0,0.6,0.898,p);"
    "}";
    
    texture_program_blue = get_texture_program(build_program(vshader_texture_blue, (GLint)strlen(vshader_texture_blue), fshader_texture_blue, (GLint)strlen(fshader_texture_blue)));
    
    
    char* vshader_texture_red  =
    "uniform mat4 u_MvpMatrix;"
    "attribute vec4 a_Position;"
    "attribute vec2 a_TextureCoordinates;"
    "varying vec2 v_TextureCoordinates;"
    "void main(){"
    "    v_TextureCoordinates = a_TextureCoordinates;"
    "    gl_Position = u_MvpMatrix * a_Position;"
    "}";
    
    char* fshader_texture_red  =
    "precision lowp float;"
    "uniform sampler2D u_TextureUnit;"
    "varying vec2 v_TextureCoordinates;"
    "uniform float u_Alpha;"
    "void main(){"
    "   gl_FragColor = texture2D(u_TextureUnit, v_TextureCoordinates);"
    "   float p = gl_FragColor.w*u_Alpha;"
    "   gl_FragColor = vec4(210./255.,57./255.,41./255.,p);"
    "}";
    
    texture_program_red = get_texture_program(build_program(vshader_texture_red, (GLint)strlen(vshader_texture_red), fshader_texture_red, (GLint)strlen(fshader_texture_red)));
    
    
    vshader  =
    "uniform mat4 u_MvpMatrix;"
    "attribute vec4 a_Position;"
    "attribute vec2 a_TextureCoordinates;"
    "varying vec2 v_TextureCoordinates;"
    "void main(){"
    "    v_TextureCoordinates = a_TextureCoordinates;"
    "    gl_Position = u_MvpMatrix * a_Position;"
    "}";
    
    fshader  =
    "precision lowp float;"
    "uniform sampler2D u_TextureUnit;"
    "varying vec2 v_TextureCoordinates;"
    "uniform float u_Alpha;"
    "void main(){"
    "    gl_FragColor = texture2D(u_TextureUnit, v_TextureCoordinates);"
    //"    float p = u_Alpha*gl_FragColor.w;"
    //"    gl_FragColor = vec4(237./255., 64./255., 27./255., p);"
    "    float p = u_Alpha*gl_FragColor.w;"
    "    gl_FragColor = vec4(246./255., 73./255., 55./255., p);"
    "}";
    
    texture_program_light_red = get_texture_program(build_program(vshader, (GLint)strlen(vshader), fshader, (GLint)strlen(fshader)));
    
    
    vshader  =
    "uniform mat4 u_MvpMatrix;"
    "attribute vec4 a_Position;"
    "attribute vec2 a_TextureCoordinates;"
    "varying vec2 v_TextureCoordinates;"
    "void main(){"
    "    v_TextureCoordinates = a_TextureCoordinates;"
    "    gl_Position = u_MvpMatrix * a_Position;"
    "}";
    
    fshader  =
    "precision lowp float;"
    "uniform sampler2D u_TextureUnit;"
    "varying vec2 v_TextureCoordinates;"
    "uniform float u_Alpha;"
    "void main(){"
    "    gl_FragColor = texture2D(u_TextureUnit, v_TextureCoordinates);"
    "   float p = u_Alpha*gl_FragColor.w;"
    //"    gl_FragColor = vec4(100./255.,182./255.,248./255.,p);"
    "    gl_FragColor = vec4(42./255.,180./255.,247./255.,p);"
    "}";
    
    texture_program_light_blue = get_texture_program(build_program(vshader, (GLint)strlen(vshader), fshader, (GLint)strlen(fshader)));
    
    
    vshader  =
    "uniform mat4 u_MvpMatrix;"
    "attribute vec4 a_Position;"
    "attribute vec2 a_TextureCoordinates;"
    "varying vec2 v_TextureCoordinates;"
    "void main(){"
    "    v_TextureCoordinates = a_TextureCoordinates;"
    "    gl_Position = u_MvpMatrix * a_Position;"
    "}";
    
    fshader  =
    "precision lowp float;"
    "uniform sampler2D u_TextureUnit;"
    "varying vec2 v_TextureCoordinates;"
    "uniform float u_Alpha;"
    "void main(){"
    "    gl_FragColor = texture2D(u_TextureUnit, v_TextureCoordinates);"
    "    gl_FragColor *= u_Alpha;"
    "}";
    
    texture_program_one = get_texture_program(build_program(vshader, (GLint)strlen(vshader), fshader, (GLint)strlen(fshader)));


    vshader =
        "uniform mat4 u_MvpMatrix;"
        "attribute vec4 a_Position;"
        "attribute vec2 a_TextureCoordinates;"
        "varying vec2 v_TextureCoordinates;"
        "void main(){"
        "    v_TextureCoordinates = a_TextureCoordinates;"
        "    gl_Position = u_MvpMatrix * a_Position;"
        "}";

    fshader =
        "precision lowp float;"
        "uniform sampler2D u_TextureUnit;"
        "varying vec2 v_TextureCoordinates;"
        "uniform float u_Alpha;"
        "void main(){"
        "    gl_FragColor = texture2D(u_TextureUnit, v_TextureCoordinates);"
        "   float p = u_Alpha*gl_FragColor.w;"
        "   gl_FragColor = vec4(0,0,0,p);"
        "}";

    texture_program_black = get_texture_program(build_program(vshader, (GLint)strlen(vshader), fshader, (GLint)strlen(fshader)));
    
    fshader =
        "precision lowp float;"
        "uniform sampler2D u_TextureUnit;"
        "varying vec2 v_TextureCoordinates;"
        "uniform float u_Alpha;"
        "void main(){"
        "    gl_FragColor = texture2D(u_TextureUnit, v_TextureCoordinates);"
        "   float p = u_Alpha*gl_FragColor.w;"
        "   gl_FragColor = vec4(0.09,0.133,0.176,p);"
        "}";
    
    texture_program_dark_blue = get_texture_program(build_program(vshader, (GLint)strlen(vshader), fshader, (GLint)strlen(fshader)));
}


CPoint CPointMake(float x, float y)
{
    CPoint p = {x, y};
    return p;
}

CSize CSizeMake(float width, float height)
{
    CSize s = {width, height};
    return s;
}


float D2R(float a)
{
    return (float)(a*M_PI/180.0);
}

float R2D(float a)
{
    return (float)(a*180.0/M_PI);
}


xyz xyzMake(float x, float y, float z) {
    xyz result;
    result.x = x;
    result.y = y;
    result.z = z;
    return result;
}



LayerParams default_layer_params()
{
    LayerParams params;
    params.anchor.x=params.anchor.y=params.anchor.z=0;
    params.position.x=params.position.y=params.position.z=0;
    params.rotation=0;
    params.scale.x=params.scale.y=params.scale.z=1.;
    
    return params;
}


Params default_params()
{
    Params params;
    params.anchor.x=params.anchor.y=params.anchor.z=0;
    params.position.x=params.position.y=params.position.z=0;
    params.rotation=0;
    params.scale.x=params.scale.y=params.scale.z=1.;
    params.alpha=1.;
    
    params.var_params.side_length=0;
    params.var_params.start_angle=0;
    params.var_params.end_angle=0;
    params.var_params.angle=0;
    params.var_params.size=CSizeMake(0, 0);
    params.var_params.radius=0;
    params.var_params.width=0;
    
    
    params.const_params.is_star=0;
    
    LayerParams p = default_layer_params();
    
    params.layer_params=&p;
    
    return params;
}






void mat4x4_translate_independed(mat4x4 m, float x, float y, float z)
{
    mat4x4 tr;
    mat4x4_identity(tr);
    
    mat4x4_translate_in_place(tr, x, y, z);
    
    
    //mat4x4 model_matrix2_tr;
    //mat4x4_mul(model_matrix2_tr, tr, m);
    
    
    mat4x4 m_dup;
    mat4x4_dup(m_dup, m);
    mat4x4_mul(m, tr, m_dup );
}




static inline void mvp_matrix(mat4x4 model_view_projection_matrix, Params params, mat4x4 view_projection_matrix)
{

    mat4x4 model_matrix;
    mat4x4_identity(model_matrix);
    
    mat4x4 id;
    mat4x4_identity(id);
    
    
    mat4x4_translate(model_matrix, -params.anchor.x, -params.anchor.y, params.anchor.z);
    
    mat4x4 scaled;
    mat4x4_identity(scaled);
    mat4x4_scale_aniso(scaled, scaled, params.scale.x, -params.scale.y, params.scale.z);
    
    
    mat4x4 tmp;
    mat4x4_dup(tmp, model_matrix);
    
    mat4x4_mul(model_matrix, scaled, tmp);
    
    
    
    
    
    mat4x4 rotate;
    mat4x4_dup(rotate, id);
    mat4x4_rotate_Z2(rotate, id, deg_to_radf(-params.rotation));
    
    
    mat4x4_dup(tmp, model_matrix);
    
    mat4x4_mul(model_matrix, rotate, tmp);
    
    mat4x4_translate_independed(model_matrix, params.position.x, -params.position.y, params.position.z);
    
    
    
    mat4x4 model_matrix3;
    mat4x4_identity(model_matrix3);
    
    

    mat4x4 mm;
    
    mat4x4_mul(mm, model_matrix3, view_projection_matrix);

    mat4x4_mul(model_view_projection_matrix, mm, model_matrix);

    mat4x4_translate_independed(model_view_projection_matrix, 0, -y_offset/view_projection_matrix[3][3], 0);
}



void mat4x4_log(__unused mat4x4 M)
{
    /*
    printf("\n\n");
    
    int i, j;
    for(i=0; i<4; ++i)
    {
        for(j=0; j<4; ++j)
        {
            printf("%6.2f ", M[i][j]);
        }
        printf("\n");
    }
    
    printf("\n\n");
    */
}

void vec4_log(__unused vec4 M)
{
    /*
    printf("\n\n");
    
    int i;
    for(i=0; i<4; ++i)
    {
        
        printf("%6.2f ", M[i]);
        
    }
    
    printf("\n\n");
    */
}

void draw_shape(const Shape* shape, mat4x4 view_projection_matrix)
{
    draw_colored_shape(shape, view_projection_matrix, shape->color);
}

void draw_colored_shape(const Shape* shape, mat4x4 view_projection_matrix, vec4 color) {
    if (shape->params.alpha>0 && (fabs(shape->params.scale.x)>0 && fabs(shape->params.scale.y)>0 && fabs(shape->params.scale.z)>0))
    {
        
        mat4x4 model_view_projection_matrix;
        mvp_matrix(model_view_projection_matrix, shape->params, view_projection_matrix);
        

        glUseProgram(color_program.program);
        
        
        glUniformMatrix4fv(color_program.u_mvp_matrix_location, 1, GL_FALSE, (GLfloat*)model_view_projection_matrix);
        if (shape->params.rotation==5.) {
            glUniform4fv(color_program.u_color_location, 1, color);
        }
        else if (shape->params.rotation==10.)
        {
            vec4 col ={0,1,0,1};
            glUniform4fv(color_program.u_color_location, 1, col);
            //glUniform4fv(color_program.u_color_location, 1, shape->color);
        }
        else
        {
            glUniform4fv(color_program.u_color_location, 1, color);
        }
        
        glUniform1f(color_program.u_alpha_loaction, shape->params.alpha);
        
        glVertexAttribPointer(color_program.a_position_location, 2, GL_FLOAT, GL_FALSE, sizeof(CPoint), &shape->data[0].x);
        glEnableVertexAttribArray(color_program.a_position_location);
        glDrawArrays(shape->params.const_params.triangle_mode, 0, shape->num_points);
        
        
    }
    
}

void draw_textured_shape(const TexturedShape* shape, mat4x4 view_projection_matrix, texture_program_type program_type)
{
    if (shape->params.alpha>0 && (fabs(shape->params.scale.x)>0 && fabs(shape->params.scale.y)>0 && fabs(shape->params.scale.z)>0))
    {
        
        mat4x4 model_view_projection_matrix;
        mvp_matrix(model_view_projection_matrix, shape->params, view_projection_matrix);

        if (shape->params.const_params.is_star==1) {
            vec4 pos;
            vec4 vertex = {0,0,0,1};
            mat4x4_mul_vec4(pos, model_view_projection_matrix, vertex);

            vec4 p_NDC = {pos[0]/pos[3], pos[1]/pos[3], pos[2]/pos[3], pos[3]/pos[3]};

            // p_window = (p_NDC + 1)/2 * viewport.{width, height} + viewport{x, y}
            //vec4 p_window={p_NDC[0]*width, -p_NDC[1]*height, 0, 0};
            vec4 p_window={p_NDC[0]*width, -p_NDC[1]*height, 0, 0};

            int d = 160;
            if (fabs(p_window[0])>d || p_window[1] > y_offset_absolute*2 + d || p_window[1] < y_offset_absolute*2 - d) {
                return;
            }

        }


        if (program_type==RED) {
            texture_program_temp=&texture_program_red;
        }
        else if (program_type==BLUE)
        {
            texture_program_temp=&texture_program_blue;
        }
        else if (program_type==LIGHT_RED)
        {
            texture_program_temp=&texture_program_light_red;
        }
        else if (program_type==LIGHT_BLUE)
        {
            texture_program_temp=&texture_program_light_blue;
        }
        else if (program_type==NORMAL_ONE)
        {
            texture_program_temp=&texture_program_one;
        }
        else if (program_type==DARK)
        {
            texture_program_temp=&texture_program_black;
        }
        else if (program_type==DARK_BLUE)
        {
            texture_program_temp=&texture_program_dark_blue;
        }
        else if (program_type==LIGHT)
        {
            texture_program_temp=&texture_program_one;
        }
        else
        {
            texture_program_temp=&texture_program;
        }
        
        
        glUseProgram(texture_program_temp->program);
        
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, shape->texture);
        glUniformMatrix4fv(texture_program_temp->u_mvp_matrix_location, 1, GL_FALSE, (GLfloat*)model_view_projection_matrix);
        glUniform1i(texture_program_temp->u_texture_unit_location, 0);
        glUniform1f(texture_program_temp->u_alpha_loaction, shape->params.alpha);
        
        glBindBuffer(GL_ARRAY_BUFFER, shape->buffer);
        // glVertexAttribPointer (GLuint indx, GLint size, GLenum type, GLboolean normalized, GLsizei stride, const GLvoid* ptr)
        glVertexAttribPointer(texture_program_temp->a_position_location, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(GL_FLOAT), BUFFER_OFFSET(0));
        glVertexAttribPointer(texture_program_temp->a_texture_coordinates_location, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(GL_FLOAT), BUFFER_OFFSET(2 * sizeof(GL_FLOAT)));
        glEnableVertexAttribArray(texture_program_temp->a_position_location);
        glEnableVertexAttribArray(texture_program_temp->a_texture_coordinates_location);
        glDrawArrays(shape->params.const_params.triangle_mode, 0, shape->num_points);
        
        glBindBuffer(GL_ARRAY_BUFFER, 0);
        
    }
}





// Rounded rectangle

static inline int size_of_rounded_rectangle_in_vertices(int round_count) {
    return 4*(2+round_count)+2;
}

static inline void gen_rounded_rectangle(CPoint* out, CSize size, float radius, int round_count)
{
    //printf("gen_rounded_rectangle> %d \n", round_count);
    int offset=0;

    out[offset++] = CPointMake(0, 0);

    float k = (float)(M_PI/2/(round_count+1));

    int i=0;
    int n=0;


    for (i=(round_count+2)*n; i<=round_count+1 + (round_count+1)*n; i++) {
        out[offset++] = CPointMake(size.width/2-radius + cosf(i*k)*radius, size.height/2-radius + sinf(i*k)*radius);
    }
    n++;

    for (i=(round_count+1)*n; i<=round_count+1 + (round_count+1)*n; i++) {
        out[offset++] = CPointMake(-size.width/2+radius + cosf(i*k)*radius, size.height/2-radius + sinf(i*k)*radius);
    }
    n++;

    for (i=(round_count+1)*n; i<=round_count+1 + (round_count+1)*n; i++) {
        out[offset++] = CPointMake(-size.width/2+radius + cosf(i*k)*radius, -size.height/2+radius + sinf(i*k)*radius);
    }
    n++;

    for (i=(round_count+1)*n; i<=round_count+1 + (round_count+1)*n; i++) {
        out[offset++] = CPointMake(size.width/2-radius + cosf(i*k)*radius, -size.height/2+radius + sinf(i*k)*radius);
    }
    n++;

    out[offset++] = CPointMake(size.width/2, size.height/2-radius);
}

Shape create_rounded_rectangle(CSize size, float radius, int round_count, const vec4 color)
{
    int real_vertex_count = size_of_rounded_rectangle_in_vertices(round_count);

    Params params = default_params();
    params.const_params.datasize = sizeof(CPoint)*real_vertex_count*2;
    params.const_params.round_count=round_count;
    params.const_params.triangle_mode = GL_TRIANGLE_FAN;

    params.var_params.size=size;
    params.var_params.radius=radius;


    CPoint *data = malloc(params.const_params.datasize);
    gen_rounded_rectangle(data, params.var_params.size, params.var_params.radius, params.const_params.round_count);

    /*
    char str[150];
    sprintf(str, "rounded_rectangle_data_size(%d) = %d", real_vertex_count, rounded_rectangle_data_size(real_vertex_count));
    DEBUG_LOG_WRITE_D("fps>",str);
    */

    return (Shape) {{color[0], color[1], color[2], color[3]},
        data,
        create_vbo(params.const_params.datasize, data, GL_DYNAMIC_DRAW),
        real_vertex_count,
        params};

}

void change_rounded_rectangle(Shape* shape, CSize size, float radius)
{

    if ((*shape).params.var_params.size.width != size.width || (*shape).params.var_params.size.height != size.height || (*shape).params.var_params.radius != radius )
    {
        //DEBUG_LOG_WRITE_D("fps","change_rounded_rectangle");

        (*shape).params.var_params.size.width = size.width;
        (*shape).params.var_params.size.height = size.height;
        (*shape).params.var_params.radius = radius;

        gen_rounded_rectangle((*shape).data, (*shape).params.var_params.size, (*shape).params.var_params.radius, (*shape).params.const_params.round_count);

        glBindBuffer(GL_ARRAY_BUFFER, shape->buffer);
        glBufferSubData(GL_ARRAY_BUFFER, 0, shape->params.const_params.datasize, shape->data); // proved
        glBindBuffer(GL_ARRAY_BUFFER, 0);
    }

}




// Segmented square

static inline int size_of_segmented_square_in_vertices() {
    return 7;
}

static inline CPoint square_point(float angle, float radius)
{
    CPoint p = {0.0f, 0.0f};
    
    if (angle<=M_PI/2*.5 || angle>M_PI/2*3.5)
    {
        p = CPointMake(radius, radius * sinf(angle)/cosf(angle));
    }
    else if (angle<=M_PI/2*1.5)
    {
        p = CPointMake(radius * cosf(angle)/sinf(angle), radius);
    }
    else if (angle<=M_PI/2*2.5)
    {
        p = CPointMake(-radius, -radius * sinf(angle)/cosf(angle));
    }
    else if (angle<=(float)(M_PI/2*3.5))
    {
        p = CPointMake(-radius * cosf(angle)/sinf(angle), -radius);
    }
    
    return p;
}

static inline CPoint square_texture_point(CPoint p, float side_length)
{
    return CPointMake((-p.x/side_length*.5f +.5f), -p.y/side_length*.5f +.5f);
}

static inline void gen_segmented_square(CPoint* out, float side_length, float start_angle, float end_angle)
{
    CPoint p;
    
    float radius = side_length;
    
    int offset=0;
    
    float k=1;
    
    float da=D2R(-2.6f*2)*k;
    

    p = CPointMake(sinf(start_angle+end_angle)*6*k, - cosf(start_angle+end_angle)*6*k);
    //p = CPointMake(0, 0);
    
    out[offset++] = p;
    out[offset++] = square_texture_point(p, side_length);
    
    
    //1
    p = square_point(start_angle+da, radius);
    //p.y=p.y;
    //p.y=side_length;
    out[offset++] = p;
    out[offset++] = square_texture_point(p, side_length);
    
    
    int q=0;
    
    
    int i;
    for (i=(int)start_angle; i<floorf(R2D(start_angle+end_angle+da)); i++) {
        if ((i+45)%90==0) {
            p = square_point(D2R(i), radius);
            out[offset++] = p;
            out[offset++] = square_texture_point(p, side_length);
            q++;
        }
    }


    p = square_point(start_angle + end_angle+da, radius);
    //p.x = p.x + sin(end_angle)*6*k;
    //p.y = p.y - cos(end_angle)*6*k;
    out[offset++] = p;
    out[offset++] = square_texture_point(p, side_length);
    

    for (i=0; i<4-q; i++) {
        p = square_point(start_angle +end_angle+da, radius);
        //p.x = p.x + sin(end_angle)*6*k;
        //p.y = p.y - cos(end_angle)*6*k;
        out[offset++] = p;
        out[offset++] = square_texture_point(p, side_length);
    }

}

TexturedShape create_segmented_square(float side_length, float start_angle, float end_angle, GLuint texture)
{
    int real_vertex_count = size_of_segmented_square_in_vertices();

    Params params = default_params();
    params.const_params.datasize = sizeof(CPoint) * real_vertex_count * 2 * 2;
    params.const_params.triangle_mode = GL_TRIANGLE_FAN;

    CPoint *data = malloc(params.const_params.datasize);
    gen_segmented_square(data, side_length, start_angle, end_angle);

    return (TexturedShape) {texture,
        data,
        create_vbo(params.const_params.datasize, data, GL_DYNAMIC_DRAW),
        real_vertex_count,
        params};
}

void change_segmented_square(TexturedShape* shape, float side_length, float start_angle, float end_angle)
{
    if ((*shape).params.var_params.side_length != side_length ||
        (*shape).params.var_params.start_angle != start_angle ||
        (*shape).params.var_params.end_angle != end_angle )
    {
        //DEBUG_LOG_WRITE_D("fps","change_segmented_square");
        
        (*shape).params.var_params.side_length = side_length;
        (*shape).params.var_params.start_angle = start_angle;
        (*shape).params.var_params.end_angle = end_angle;

        gen_segmented_square((*shape).data, side_length, start_angle, end_angle);
        
        glBindBuffer(GL_ARRAY_BUFFER, shape->buffer);
        glBufferSubData(GL_ARRAY_BUFFER, 0, shape->params.const_params.datasize, shape->data); // proved
        glBindBuffer(GL_ARRAY_BUFFER, 0);
    }
}





// ok
// Rectangle

static inline void gen_rectangle(CPoint* out, CSize size)
{
    int offset=0;
    
    out[offset++] = CPointMake(-size.width/2, -size.height/2);
    out[offset++] = CPointMake(size.width/2, -size.height/2);
    out[offset++] = CPointMake(-size.width/2, size.height/2);
    out[offset++] = CPointMake(size.width/2, size.height/2);
    
}

Shape create_rectangle(CSize size, const vec4 color)
{
    int real_vertex_count = 4;
    
    Params params = default_params();
    params.const_params.datasize = sizeof(CPoint)*real_vertex_count;
    params.const_params.triangle_mode = GL_TRIANGLE_STRIP;

    CPoint *data = malloc(params.const_params.datasize);
    gen_rectangle(data, size);
    
    return (Shape) {{color[0], color[1], color[2], color[3]},
        data,
        create_vbo(params.const_params.datasize, data, GL_DYNAMIC_DRAW),
        real_vertex_count,
        params};
}





// ok
// Textured rectangle

static inline CPoint rectangle_texture_point(CPoint p, CSize size)
{
    return CPointMake(1-(-p.x/size.width+.5f), p.y/size.height+.5f);
}

static inline void gen_textured_rectangle(CPoint* out, CSize size)
{
    int offset=0;

    out[offset++] = CPointMake(-size.width/2, -size.height/2);
    out[offset++] = rectangle_texture_point(CPointMake(-size.width/2, -size.height/2), size);

    out[offset++] = CPointMake(size.width/2, -size.height/2);
    out[offset++] = rectangle_texture_point(CPointMake(size.width/2, -size.height/2), size);

    out[offset++] = CPointMake(-size.width/2, size.height/2);
    out[offset++] = rectangle_texture_point(CPointMake(-size.width/2, size.height/2), size);

    out[offset++] = CPointMake(size.width/2, size.height/2);
    out[offset++] = rectangle_texture_point(CPointMake(size.width/2, size.height/2), size);
}

TexturedShape create_textured_rectangle(CSize size, GLuint texture)
{
    int real_vertex_count = 4;
    
    Params params = default_params();
    params.const_params.datasize = sizeof(CPoint) * real_vertex_count * 2;
    params.const_params.triangle_mode = GL_TRIANGLE_STRIP;

    CPoint *data = malloc(params.const_params.datasize);
    gen_textured_rectangle(data, size);

    return (TexturedShape) {texture,
        data,
        create_vbo(params.const_params.datasize, data, GL_STATIC_DRAW),
        real_vertex_count,
        params};
}

void change_textured_rectangle(TexturedShape* shape, CSize size)
{
    //DEBUG_LOG_WRITE_D("fps","change_textured_rectangle");

    gen_textured_rectangle((*shape).data, size);

    glBindBuffer(GL_ARRAY_BUFFER, shape->buffer);
    glBufferSubData(GL_ARRAY_BUFFER, 0, shape->params.const_params.datasize, shape->data); // proved
    glBindBuffer(GL_ARRAY_BUFFER, 0);
}





// ok
// Ribbon

static inline void gen_ribbon(CPoint* out, float length)
{
    int offset=0;

    out[offset++] = CPointMake((float)(-MAXf(length-5.5f, 0)), -5.5f);
    out[offset++] = CPointMake(0, -5.5);
    out[offset++] = CPointMake((float)(-MAXf(length, 0)), 5.5f);
    out[offset++] = CPointMake(0, 5.5);

}

Shape create_ribbon(float length, const vec4 color)
{
    int real_vertex_count = 4;

    Params params=default_params();
    params.const_params.datasize = sizeof(CPoint)*real_vertex_count;
    params.const_params.triangle_mode = GL_TRIANGLE_STRIP;

    params.var_params.side_length=length;

    CPoint *data = malloc(params.const_params.datasize);
    gen_ribbon(data, length);

    return (Shape) {{color[0], color[1], color[2], color[3]},
        data,
        create_vbo(params.const_params.datasize, data, GL_DYNAMIC_DRAW),
        real_vertex_count,
        params};
}

void change_ribbon(Shape* shape, float length)
{
    if ((*shape).params.var_params.side_length != length)
    {
        //DEBUG_LOG_WRITE_D("fps","change_segmented_square");
        
        (*shape).params.var_params.side_length = length;
        
        gen_ribbon((*shape).data, length);
        
        glBindBuffer(GL_ARRAY_BUFFER, shape->buffer);
        glBufferSubData(GL_ARRAY_BUFFER, 0, shape->params.const_params.datasize, shape->data); // proved
        glBindBuffer(GL_ARRAY_BUFFER, 0);
    }
}





// ok
// Segmented circle

static inline int size_of_segmented_circle_in_vertices(int num_points) {
    return 1 + (num_points + 1);
}

static inline void gen_segmented_circle(CPoint* out, float radius, float start_angle, float angle, int vertex_count)
{
    int offset=0;
    
    out[offset++] = CPointMake(0, 0);
    
    int i;
    for (i = 0; i <= vertex_count; i++) {
        out[offset++] = CPointMake(radius*cosf(start_angle+(i/(float)vertex_count)*angle), radius*sinf(start_angle+(i/(float)vertex_count)*angle));
        //int o=offset-1;
    }
}

Shape create_segmented_circle(float radius, int vertex_count, float start_angle, float angle, const vec4 color)
{
    int real_vertex_count = size_of_segmented_circle_in_vertices(vertex_count);
    
    Params params=default_params();
    params.const_params.datasize = sizeof(CPoint)*real_vertex_count;
    params.const_params.triangle_mode=GL_TRIANGLE_FAN;
    params.const_params.round_count=vertex_count;

    CPoint *data = malloc(params.const_params.datasize);
    gen_segmented_circle(data, radius, start_angle, angle, vertex_count);

    return (Shape) {{color[0], color[1], color[2], color[3]},
        data,
        create_vbo(params.const_params.datasize, data, GL_DYNAMIC_DRAW),
        real_vertex_count,
        params};
}

void change_segmented_circle(Shape* shape, float radius, float start_angle, float angle)
{
    if ((*shape).params.var_params.radius != radius ||
        (*shape).params.var_params.start_angle != start_angle ||
        (*shape).params.var_params.angle != angle )
    {
        //DEBUG_LOG_WRITE_D("fps","change_segmented_square");
        
        (*shape).params.var_params.radius = radius;
        (*shape).params.var_params.start_angle = start_angle;
        (*shape).params.var_params.angle = angle;

        gen_segmented_circle((*shape).data, radius, start_angle, angle, (*shape).params.const_params.round_count);
        
        glBindBuffer(GL_ARRAY_BUFFER, shape->buffer);
        glBufferSubData(GL_ARRAY_BUFFER, 0, shape->params.const_params.datasize, shape->data); // proved
        glBindBuffer(GL_ARRAY_BUFFER, 0);
    }
}




// ok
// Circle

static inline void gen_circle(CPoint* out, float radius, int vertex_count)
{
    int offset=0;
    
    out[offset++] = CPointMake(0, 0);
    
    int i;
    for (i = 0; i <= vertex_count; i++) {
        out[offset++] = CPointMake(radius*(float)(cos(2*M_PI*(i/(float)vertex_count))), radius*(float)(sin(2*M_PI*(i/(float)vertex_count))) );
    }
    
}

Shape create_circle(float radius, int vertex_count, const vec4 color)
{
    int real_vertex_count = size_of_segmented_circle_in_vertices(vertex_count);
    
    Params params=default_params();
    params.const_params.datasize = sizeof(CPoint)*real_vertex_count;
    params.const_params.triangle_mode=GL_TRIANGLE_FAN;
    params.const_params.round_count=vertex_count;

    CPoint *data = malloc(params.const_params.datasize);
    gen_circle(data, radius, vertex_count);
    
    return (Shape) {{color[0], color[1], color[2], color[3]},
        data,
        create_vbo(params.const_params.datasize, data, GL_STATIC_DRAW),
        real_vertex_count,
        params};
}

void change_circle(Shape* shape, float radius)
{
    if ((*shape).params.var_params.radius != radius)
    {
        //DEBUG_LOG_WRITE_D("fps","change_segmented_square");
        
        (*shape).params.var_params.radius = radius;
        
        gen_circle((*shape).data, radius, (*shape).params.const_params.round_count);
        
        glBindBuffer(GL_ARRAY_BUFFER, shape->buffer);
        glBufferSubData(GL_ARRAY_BUFFER, 0, shape->params.const_params.datasize, shape->data); // proved
        glBindBuffer(GL_ARRAY_BUFFER, 0);
    }
}




// ok
// Infinity

int size_of_infinity_in_vertices(int segment_count)
{
    return (segment_count+1)*2;
}

static inline void gen_infinity(CPoint* out, float width, float angle, int segment_count)
{
    
    CPoint path[13];
    path[0]=CPointMake(53,23);
    
    path[1]=CPointMake(49,31);
    path[2]=CPointMake(39,47);
    
    path[3]=CPointMake(22,47);
    
    path[4]=CPointMake(6,47);
    path[5]=CPointMake(0,31);
    
    path[6]=CPointMake(0,23);
    
    path[7]=CPointMake(0,16);
    path[8]=CPointMake(5,0);
    
    path[9]=CPointMake(23,0);
    
    path[10]=CPointMake(39,0);
    path[11]=CPointMake(48,15);
    
    path[12]=CPointMake(52,21);
    
    
    
    int offset=0;
    
    int seg;
    for (seg=0; seg<=segment_count; seg++) {
        float tt = ((float)seg/(float)segment_count)*angle;
        
        int q=4;
        float tstep=1.f/q;
        int n = (int)floor(tt/tstep);
        
        if (seg >= segment_count) {
            //n=n-1;//q-1;
        }
        //printf("n>%d\n", n);
        
        CPoint a = path[0+3*n];;
        CPoint p1 = path[1+3*n];
        CPoint p2 = path[2+3*n];
        CPoint b = path[3+3*n];
        
        float t=(tt-tstep*n)*q;
        float nt = 1.0f - t;
        
        
        vec2 p = {a.x * nt * nt * nt  +  3.0f * p1.x * nt * nt * t  +  3.0f * p2.x * nt * t * t  +  b.x * t * t * t,
            a.y * nt * nt * nt  +  3.0f * p1.y * nt * nt * t  +  3.0f * p2.y * nt * t * t  +  b.y * t * t * t};
        
        vec2 tangent = {-3.0f * a.x * nt * nt  +  3.0f * p1.x * (1.0f - 4.0f * t + 3.0f * t * t)  +  3.0f * p2.x * (2.0f * t - 3.0f * t * t)  +  3.0f * b.x * t * t,
            -3.0f * a.y * nt * nt  +  3.0f * p1.y * (1.0f - 4.0f * t + 3.0f * t * t)  +  3.0f * p2.y * (2.0f * t - 3.0f * t * t)  +  3.0f * b.y * t * t};
        
        vec2 tan_norm = {-tangent[1], tangent[0]};
        vec2 norm;
        vec2_norm(norm, tan_norm);
        
        
        vec2 v;
        vec2 norm_scaled;
        vec2_scale(norm_scaled, norm, +width/2.f);
        vec2_add(v, p, norm_scaled);
        
        out[offset] = CPointMake(v[0], v[1]);
        offset++;
        
        vec2_scale(norm_scaled, norm, -width/2.f);
        vec2_add(v, p, norm_scaled);
        
        out[offset] = CPointMake(v[0], v[1]);
        offset++;
    }
    //printf("infinity_q>%d", offset);
}

Shape create_infinity(float width, float angle, int segment_count, const vec4 color)
{
    int real_vertex_count = size_of_infinity_in_vertices(segment_count);

    Params params=default_params();

    params.const_params.datasize = sizeof(CPoint)*real_vertex_count;
    params.const_params.triangle_mode=GL_TRIANGLE_STRIP;
    params.const_params.round_count=segment_count;

    params.var_params.width = width;
    params.var_params.angle = angle;


    CPoint *data = malloc(params.const_params.datasize);
    gen_infinity(data, width, angle, segment_count);

    return (Shape) {{color[0], color[1], color[2], color[3]},
        data,
        create_vbo(params.const_params.datasize, data, GL_DYNAMIC_DRAW),
        real_vertex_count,
        params};
}

void change_infinity(Shape* shape, float angle)
{
    if ( (*shape).params.var_params.angle != angle )
    {
        (*shape).params.var_params.angle = angle;

        gen_infinity(shape->data, (*shape).params.var_params.width, (*shape).params.var_params.angle, (*shape).params.const_params.round_count);

        glBindBuffer(GL_ARRAY_BUFFER, shape->buffer);

        glBufferData(GL_ARRAY_BUFFER, shape->params.const_params.datasize, shape->data, GL_DYNAMIC_DRAW); // proved

        glBindBuffer(GL_ARRAY_BUFFER, 0);
    }
}

void draw_infinity(const Shape* shape, mat4x4 view_projection_matrix)
{
    if (shape->params.alpha>0 && (fabs(shape->params.scale.x)>0 && fabs(shape->params.scale.y)>0 && fabs(shape->params.scale.z)>0))
    {
        mat4x4 model_view_projection_matrix;
        mvp_matrix(model_view_projection_matrix, shape->params, view_projection_matrix);
        
        glUseProgram(color_program.program);
        
        glUniformMatrix4fv(color_program.u_mvp_matrix_location, 1, GL_FALSE, (GLfloat*)model_view_projection_matrix);
        glUniform4fv(color_program.u_color_location, 1, shape->color);
        glUniform1f(color_program.u_alpha_loaction, shape->params.alpha);
        
        glVertexAttribPointer(color_program.a_position_location, 2, GL_FLOAT, GL_FALSE, sizeof(CPoint), &shape->data[0].x);
        glEnableVertexAttribArray(color_program.a_position_location);
        glDrawArrays(shape->params.const_params.triangle_mode, 0, shape->num_points);
    }
}





// ok
// Rounded rectangle stroked

static inline int size_of_rounded_rectangle_stroked_in_vertices(int round_count) {
    return 4*(2+round_count)*2+2;
}

static inline void gen_rounded_rectangle_stroked(CPoint* out, CSize size, float radius, float stroke_width, int round_count)
{
    int offset=0;

    float k = (float)(M_PI/2/(round_count+1));
    float inner_radius = radius - stroke_width;
    
    int i=0;

    int n=0;
    for (i=(round_count+2)*n; i<=round_count+1 + (round_count+1)*n; i++) {
        out[offset++] = CPointMake(size.width/2-radius + cosf(i*k)*radius, size.height/2-radius + sinf(i*k)*radius);
        out[offset++] = CPointMake(size.width/2-radius + cosf(i*k)*inner_radius, size.height/2-radius + sinf(i*k)*inner_radius);
    }
    n++;

    for (i=(round_count+1)*n; i<=round_count+1 + (round_count+1)*n; i++) {
        out[offset++] = CPointMake(-size.width/2+radius + cosf(i*k)*radius, size.height/2-radius + sinf(i*k)*radius);
        out[offset++] = CPointMake(-size.width/2+radius + cosf(i*k)*inner_radius, size.height/2-radius + sinf(i*k)*inner_radius);
    }
    n++;
    
    for (i=(round_count+1)*n; i<=round_count+1 + (round_count+1)*n; i++) {
        out[offset++] = CPointMake(-size.width/2+radius + cosf(i*k)*radius, -size.height/2+radius + sinf(i*k)*radius);
        out[offset++] = CPointMake(-size.width/2+radius + cosf(i*k)*inner_radius, -size.height/2+radius + sinf(i*k)*inner_radius);
    }
    n++;
    
    for (i=(round_count+1)*n; i<=round_count+1 + (round_count+1)*n; i++) {
        out[offset++] = CPointMake(size.width/2-radius + cosf(i*k)*radius, -size.height/2+radius + sinf(i*k)*radius);
        out[offset++] = CPointMake(size.width/2-radius + cosf(i*k)*inner_radius, -size.height/2+radius + sinf(i*k)*inner_radius);
    }
    n++;
    
    i=0;
    out[offset++] = CPointMake(size.width/2-radius + cosf(i*k)*radius, size.height/2-radius + sinf(i*k)*radius);
    out[offset++] = CPointMake(size.width/2-radius + cosf(i*k)*inner_radius, size.height/2-radius + sinf(i*k)*inner_radius);
}

Shape create_rounded_rectangle_stroked(CSize size, float radius, float stroke_width, int round_count, const vec4 color)
{
    // round_count == 10 : polygons fall out
    int real_vertex_count = size_of_rounded_rectangle_stroked_in_vertices(round_count);

    Params params = default_params();
    params.const_params.round_count=round_count;
    params.const_params.datasize = sizeof(CPoint)*real_vertex_count*2;
    
    params.var_params.size=size;
    params.var_params.radius=radius;
    params.var_params.width=stroke_width;

    CPoint *data = malloc(params.const_params.datasize);
    gen_rounded_rectangle_stroked(data, params.var_params.size, params.var_params.radius, params.var_params.width, params.const_params.round_count);

    params.const_params.triangle_mode = GL_TRIANGLE_STRIP;
    return (Shape) {{color[0], color[1], color[2], color[3]},
        data,
        create_vbo(params.const_params.datasize, data, GL_DYNAMIC_DRAW),
        real_vertex_count,
        params};
}

void change_rounded_rectangle_stroked(Shape* shape, CSize size, float radius, __unused float stroke_width)
{
    if ((*shape).params.var_params.size.width != size.width || (*shape).params.var_params.size.height != size.height || (*shape).params.var_params.radius != radius )
    {
        //DEBUG_LOG_WRITE_D("fps","change_rounded_rectangle");
        
        (*shape).params.var_params.size.width = size.width;
        (*shape).params.var_params.size.height = size.height;
        (*shape).params.var_params.radius = radius;
        
        gen_rounded_rectangle_stroked((*shape).data, (*shape).params.var_params.size, (*shape).params.var_params.radius, (*shape).params.var_params.width, (*shape).params.const_params.round_count);

        glBindBuffer(GL_ARRAY_BUFFER, shape->buffer);
        glBufferSubData(GL_ARRAY_BUFFER, 0, shape->params.const_params.datasize, shape->data); //
        glBindBuffer(GL_ARRAY_BUFFER, 0);
    }
}
