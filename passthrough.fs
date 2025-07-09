varying vec2 v_vPosition;
varying vec2 v_vTexcoord;
varying vec4 v_vColour;
uniform vec2 resolution;
uniform float time;
uniform sampler2D texture0;

void main() {
    vec2 uv = v_vPosition / resolution;
    vec4 img = texture2D(texture0, uv);
    gl_FragColor = img;
}
