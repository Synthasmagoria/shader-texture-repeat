const rl = @cImport({
    @cInclude("raylib.h");
    @cInclude("rlgl.h");
});
const fmt = @import("std").fmt;
const std = @import("std");
const math = @import("std").math;

const FRAMERATE: i64 = 30;
const STEP: f64 = 1.0 / @as(f64, FRAMERATE);
const RESOLUTION: i64 = 256;
const WINDOW_WIDTH: i64 = 1280;
const WINDOW_HEIGHT: i64 = 720;
const INVALID_SHADER_ID: u64 = 9999999;

const STATE = enum {
    OPEN_FILE,
    VIEW,
};

const VERTEX_SHADER_CODE =
\\attribute vec3 vertexPosition;
\\attribute vec2 vertexTexCoord;
\\attribute vec4 vertexColor;
\\varying vec2 v_vTexcoord;
\\varying vec2 v_vPosition;
\\varying vec4 v_vColour;
\\uniform mat4 mvp;
\\uniform vec2 resolution;
\\uniform float;
\\uniform float _internal_scale;
\\void main() {
\\    v_vTexcoord = vertexTexCoord * _internal_scale;
\\    v_vColour = vertexColor;
\\    v_vPosition = vertexPosition.xy * _internal_scale;
\\    gl_Position = mvp * vec4(vertexPosition, 1.0);
\\}
;

const REPEAT_FRAGMENT_SHADER_CODE =
\\varying vec2 v_vPosition;
\\varying vec2 v_vTexcoord;
\\varying vec4 v_vColour;
\\uniform sampler2D texture0;
\\uniform vec2 repeatStart;
\\
\\void main() {
\\    vec2 uv = v_vTexcoord * 0.5 + 0.5;
\\    vec2 uv_l = uv - vec2(0.5, 0.0);
\\    vec2 uv_t = uv - vec2(0.0, 0.5);
\\    vec2 uv_tl = uv - 0.5;
\\
\\    vec2 fade = smoothstep(repeatStart, vec2(1.0), v_vTexcoord);
\\    vec4 img = texture2D(texture0, uv);
\\    vec4 img_l = texture2D(texture0, uv_l);
\\    vec4 img_t = texture2D(texture0, uv_t);
\\    vec4 img_tl = texture2D(texture0, uv_tl);
\\    vec4 hb = mix(img, img_l, fade.x);
\\    vec4 ht = mix(img_t, img_tl, fade.x);
\\    gl_FragColor = mix(hb, ht, fade.y);
\\}
;

pub fn UnloadShaderSafe(sh: rl.struct_Shader) void {
    if (sh.locs != null) {
        rl.UnloadShader(sh);
    }
}
pub fn UnloadRenderTextureSafe(rt: rl.struct_RenderTexture) void {
    if (rt.id != 0) {
        rl.UnloadRenderTexture(rt);
    }
}
pub fn UnloadImageSafe(img: rl.struct_Image) void {
    if (img.data != null) {
        rl.UnloadImage(img);
    }
}

pub fn SetRepeatShaderUniforms(sh: rl.struct_Shader, repeatStart: rl.struct_Vector2) void {
    rl.SetShaderValue(sh, rl.GetShaderLocation(sh, "repeatBegin"), &repeatStart, rl.SHADER_UNIFORM_VEC2);
    const scale: f32 = 1.0;
    rl.SetShaderValue(sh, rl.GetShaderLocation(sh, "_internal_scale"), &scale, rl.SHADER_UNIFORM_FLOAT);
}

const Transform = struct { padding: i64, position: rl.struct_Vector2, rotation: f32, scale: f32 };
pub fn UpdateTransform(padding: i64, texture: rl.struct_Texture, container_width: i64, container_height: i64) Transform {
    const h = @as(f32, @floatFromInt(container_height - padding * 2));
    const scale = h / @as(f32, @floatFromInt(texture.height));
    const w = @as(f32, @floatFromInt(texture.width)) * scale;
    const position = rl.struct_Vector2{ .x = math.floor(@as(f32, @floatFromInt(container_width)) / 2.0 - w / 2.0), .y = @as(f32, @floatFromInt(padding)) };
    return Transform{ .padding = padding, .position = position, .rotation = 0.0, .scale = scale };
}
pub fn RlCreateImageUndefined() rl.struct_Image {
    return .{ .data = null, .format = undefined, .height = undefined, .width = undefined, .mipmaps = undefined };
}
pub fn RlCreateRenderTextureUndefined() rl.struct_RenderTexture {
    return .{ .depth = undefined, .id = undefined, .texture = undefined };
}

pub fn main() !void {
    rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Generate repeating texture");
    defer rl.CloseWindow();
    rl.SetTargetFPS(FRAMERATE);

    var state = STATE.OPEN_FILE;
    var noiseShader = rl.struct_Shader{ .id = 0, .locs = null };
    defer UnloadShaderSafe(noiseShader);
    const noiseTexture = rl.LoadRenderTexture(RESOLUTION * 2, RESOLUTION * 2);
    defer UnloadRenderTextureSafe(noiseTexture);
    var noiseImage = rl.struct_Image{
        .data = null,
        .format = 0,
        .height = 0,
        .width = 0,
        .mipmaps = 0 };
    defer UnloadImageSafe(noiseImage);
    var noiseTextureTransform = Transform{
        .padding = 0,
        .position = rl.struct_Vector2{ .x = 0.0, .y = 0.0 },
        .rotation = 0.0,
        .scale = 0.0 };
    const padding = 32;

    const repeatShader = rl.LoadShaderFromMemory(VERTEX_SHADER_CODE, REPEAT_FRAGMENT_SHADER_CODE);
    const repeatStart = rl.struct_Vector2{.x = 0.78, .y = 0.78};

    while (!rl.WindowShouldClose()) {
        rl.BeginDrawing();
        defer rl.EndDrawing();
        rl.ClearBackground(rl.BLACK);
        switch (state) {
            STATE.OPEN_FILE => {
                if (rl.IsFileDropped()) {
                    const files = rl.LoadDroppedFiles();
                    defer rl.UnloadDroppedFiles(files);
                    const fragmentCode = rl.LoadFileText(files.paths[0]);
                    defer rl.UnloadFileText(fragmentCode);
                    noiseShader = rl.LoadShaderFromMemory(VERTEX_SHADER_CODE, fragmentCode);
                    if (noiseShader.locs != null) {
                        rl.BeginTextureMode(noiseTexture);
                        rl.BeginShaderMode(noiseShader);
                        defer rl.EndShaderMode();
                        const resolution = [_]f32{
                            @as(f32, @floatFromInt(noiseTexture.texture.width)),
                            @as(f32, @floatFromInt(noiseTexture.texture.height)) };
                        rl.SetShaderValue(
                            noiseShader,
                            rl.GetShaderLocation(noiseShader, "resolution"),
                            &resolution,
                            rl.SHADER_UNIFORM_VEC2);
                        const scale: f32 = 2.0;
                        rl.SetShaderValue(
                            noiseShader,
                            rl.GetShaderLocation(noiseShader, "_internal_scale"),
                            &scale,
                            rl.SHADER_UNIFORM_FLOAT);
                        rl.DrawRectangle(0, 0, noiseTexture.texture.width, noiseTexture.texture.height, rl.WHITE);
                        noiseTextureTransform = UpdateTransform(padding, noiseTexture.texture, WINDOW_WIDTH, WINDOW_HEIGHT);
                        state = STATE.VIEW;
                        rl.EndTextureMode();
                        noiseImage = rl.LoadImageFromTexture(noiseTexture.texture);
                    }
                }
            },
            STATE.VIEW => {
                rl.BeginShaderMode(repeatShader);
                SetRepeatShaderUniforms(repeatShader, repeatStart);
                rl.DrawTextureEx(
                    noiseTexture.texture,
                    noiseTextureTransform.position,
                    noiseTextureTransform.rotation,
                    noiseTextureTransform.scale,
                    rl.WHITE);
                rl.EndShaderMode();

                if (rl.IsKeyPressed(rl.KEY_S)) {
                    const repeatTexture = rl.LoadRenderTexture(RESOLUTION, RESOLUTION);
                    defer rl.UnloadRenderTexture(repeatTexture);
                    rl.BeginTextureMode(repeatTexture);
                    rl.BeginShaderMode(repeatShader);
                    const pos = rl.struct_Vector2{.x = 0.0, .y = 0.0};
                    rl.DrawTextureEx(noiseTexture.texture, pos, @as(f32, 0.0), @as(f32, 0.5), rl.WHITE);
                    rl.EndShaderMode();
                    rl.EndTextureMode();

                    const repeatImage = rl.LoadImageFromTexture(repeatTexture.texture);
                    defer rl.UnloadImage(repeatImage);
                    _ = rl.ExportImage(repeatImage, "out.png");
                }
            },
        }
    }
}
