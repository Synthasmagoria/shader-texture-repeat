varying vec2 v_vPosition;
varying vec2 v_vTexcoord;
varying vec4 v_vColour;
uniform sampler2D texture0;
uniform vec2 repeatStart;

void main() {
    vec2 uv = v_vTexcoord * 0.5 + 0.5;
    vec2 uv_l = uv - vec2(0.5, 0.0);
    vec2 uv_t = uv - vec2(0.0, 0.5);
    vec2 uv_tl = uv - 0.5;

    vec2 fade = smoothstep(repeatStart, vec2(1.0), v_vTexcoord);
    vec4 img = texture2D(texture0, uv);
    vec4 img_l = texture2D(texture0, uv_l);
    vec4 img_t = texture2D(texture0, uv_t);
    vec4 img_tl = texture2D(texture0, uv_tl);
    vec4 hb = mix(img, img_l, fade.x);
    vec4 ht = mix(img_t, img_tl, fade.x);
    gl_FragColor = mix(hb, ht, fade.y);
}
