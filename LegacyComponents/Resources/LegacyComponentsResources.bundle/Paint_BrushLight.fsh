precision highp float;

varying vec2 varTexcoord;
varying float varIntensity;

uniform sampler2D texture;

void main (void)
{
    vec4 f = texture2D(texture, varTexcoord.st, 0.0);
    gl_FragColor = vec4(f.r * varIntensity, f.g, f.b, 0.0);
}
