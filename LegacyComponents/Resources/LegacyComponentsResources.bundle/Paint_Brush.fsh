precision highp float;

varying vec2 varTexcoord;
varying float varIntensity;

uniform sampler2D texture;

void main (void)
{
    float f = texture2D(texture, varTexcoord.st, 0.0).a;
    float v = varIntensity * f;
    
    gl_FragColor = vec4(0, 0, 0, v);
}
