precision highp float;

uniform mat4 mvpMatrix;

attribute vec4 inPosition;
attribute vec2 inTexcoord;
varying vec2 varTexcoord;

void main (void) 
{
	gl_Position = mvpMatrix * inPosition;
    varTexcoord = inTexcoord;
}
