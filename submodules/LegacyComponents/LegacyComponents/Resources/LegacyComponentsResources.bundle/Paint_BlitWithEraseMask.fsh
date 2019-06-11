precision highp float;

varying vec2 varTexcoord;

uniform sampler2D texture;
uniform sampler2D mask;

void main (void)
{
    vec4 dst = texture2D(texture, varTexcoord.st, 0.0);
    float srcAlpha = 1.0 - texture2D(mask, varTexcoord.st, 0.0).a;
    
    float outAlpha = dst.a * srcAlpha;
    
    gl_FragColor.rgb = dst.rgb * outAlpha;
    gl_FragColor.a = outAlpha;
}
