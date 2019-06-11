precision highp float;

varying vec2 varTexcoord;

uniform sampler2D texture;
uniform sampler2D mask;
uniform vec4 color;

void main (void)
{
    vec4 dst = texture2D(texture, varTexcoord.st, 0.0);
    vec3 maskColor = texture2D(mask, varTexcoord.st, 0.0).rgb;
    
    float srcAlpha = clamp(0.78 * maskColor.r + maskColor.b + maskColor.g, 0.0, 1.0);
    
    vec3 borderColor = mix(color.rgb, vec3(1.0, 1.0, 1.0), 0.86);
    vec3 finalColor = mix(color.rgb, borderColor, maskColor.g);
    finalColor = mix(finalColor.rgb, vec3(1.0, 1.0, 1.0), maskColor.b);
    
    float outAlpha = srcAlpha + dst.a * (1.0 - srcAlpha);
    
    gl_FragColor.rgb = (finalColor * srcAlpha + dst.rgb * dst.a * (1.0 - srcAlpha)) / outAlpha;
    gl_FragColor.a = outAlpha;
    
    gl_FragColor.rgb *= gl_FragColor.a;
}
