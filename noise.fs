varying vec2 v_vPosition;
varying vec2 v_vTexcoord;
varying vec4 v_vColour;
uniform vec2 resolution;
uniform float time;

float rand(vec2 coords) {
    return fract(sin(dot(coords, vec2(56.3456, 78.3456)) * 5.0) * 10000.0);
}

float noise(vec2 coords) {
    vec2 i = floor(coords);
    vec2 f = fract(coords);
    float a = rand(i);
    float b = rand(i + vec2(1.0, 0.0));
    float c = rand(i + vec2(0.0, 1.0));
    float d = rand(i + vec2(1.0, 1.0));
    vec2 cubic = f * f * (3.0 - 2.0 * f);
    return mix(a, b, cubic.x) + (c - a) * cubic.y * (1.0 - cubic.x) + (d - b) * cubic.x * cubic.y;
}

float fbm(vec2 coords) {
    float value = 0.0;
    float scale = 0.5;
    for (int i = 0; i < 5; i++) {
        value += noise(coords) * scale;
        coords *= 4.0;
        scale *= 0.5;
    }
    return value;
}

void main() {
    vec2 uv = v_vPosition / resolution;
    gl_FragColor = vec4(vec3(fbm(uv * 3.0)), 1.0);
}
