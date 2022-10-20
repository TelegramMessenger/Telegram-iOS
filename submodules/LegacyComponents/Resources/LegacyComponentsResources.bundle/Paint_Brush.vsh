precision highp float;

uniform mat4 mvpMatrix;

attribute vec4 inPosition;
attribute vec2 inTexcoord;
attribute float alpha;
varying vec2 varTexcoord;
varying float varIntensity;

void main (void) 
{
	gl_Position	= mvpMatrix * inPosition;
    varTexcoord = inTexcoord;
    varIntensity = alpha;
}
