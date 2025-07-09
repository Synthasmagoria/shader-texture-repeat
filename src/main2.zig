const c = @cImport({
    @cInclude("raylib.h");
    @cInclude("rlgl.h");
});

const math = @import("std").math;

const FPS: i32 = 30;
const STEP: f32 = 1.0 / @as(f32, FPS);
const RESOLUTION: i32 = 256;
const WINDOW_WIDTH: i32 = 1280;
const WINDOW_HEIGHT: i32 = 720;

pub fn main() !void {
    c.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "window");
    c.SetTargetFPS(FPS);
    defer c.CloseWindow();

    const shaderVsCode =
        \\attribute vec3 vertexPosition;
        \\attribute vec2 vertexTexCoord;
        \\attribute vec4 vertexColor;
        \\varying vec2 v_vTexcoord;
        \\varying vec2 v_vPosition;
        \\varying vec4 v_vColour;
        \\uniform mat4 mvp;
        \\uniform vec2 resolution;
        \\uniform float _internal_scale;
        \\void main() {
        \\    v_vTexcoord = vertexTexCoord * _internal_scale;
        \\    v_vColour = vertexColor;
        \\    v_vPosition = vertexPosition.xy * _internal_scale;
        \\    gl_Position = mvp * vec4(vertexPosition, 1.0);
        \\}
    ;
    const shaderFsCode = c.LoadFileText("noise.fs");
    const sh = c.LoadShaderFromMemory(shaderVsCode, shaderFsCode);
    const tex = c.LoadTexture("input.png");
    var time: f32 = 0.0;

    const surfaceSize = RESOLUTION * 2;
    const surface = c.LoadRenderTexture(surfaceSize, surfaceSize);
    c.BeginTextureMode(surface);
    c.BeginShaderMode(sh);
    const res = [2]f32{ RESOLUTION, RESOLUTION };
    c.SetShaderValue(sh, c.GetShaderLocation(sh, "resolution"), &res, c.SHADER_UNIFORM_VEC2);
    time += STEP;
    c.SetShaderValue(sh, c.GetShaderLocation(sh, "time"), &time, c.SHADER_UNIFORM_FLOAT);
    const scale: f32 = 2.0;
    c.SetShaderValue(sh, c.GetShaderLocation(sh, "_internal_scale"), &scale, c.SHADER_UNIFORM_FLOAT);
    c.DrawTexture(tex, 0, 0, c.WHITE);
    c.EndShaderMode();
    c.EndTextureMode();

    const image = c.LoadImageFromTexture(surface.texture);
    if (!c.ExportImage(image, "noise.png")) {}
    c.UnloadImage(image);

    const repeatFsCode = c.LoadFileText("repeat.fs");
    const repeatSh = c.LoadShaderFromMemory(shaderVsCode, repeatFsCode);

    while (!c.WindowShouldClose()) {
        c.BeginDrawing();
        defer c.EndDrawing();
        c.ClearBackground(c.BLACK);
        c.BeginShaderMode(repeatSh);
        const fadeStart = [2]f32{ 0.76, 0.76 };
        c.SetShaderValue(repeatSh, c.GetShaderLocation(repeatSh, "fadeStart"), &fadeStart, c.SHADER_UNIFORM_VEC2);
        const repeatScale: f32 = 1.0;
        c.SetShaderValue(repeatSh, c.GetShaderLocation(repeatSh, "_internal_scale"), &repeatScale, c.SHADER_UNIFORM_FLOAT);
        const repeatSize = WINDOW_HEIGHT - 32 * 2;
        const repeatScaleTex = @as(f32, repeatSize) / @as(f32, surfaceSize) / 3.0;
        const repeatPosition = c.struct_Vector2{ .x = @as(f32, WINDOW_WIDTH) / 2.0 - @as(f32, repeatSize) / 2.0, .y = 32.0 };
        const repeatSize3rd = @as(f32, repeatSize / 3);
        var i: i32 = 0;
        while (i < 9) : (i += 1) {
            const x = @mod(i, 3);
            const y = @divTrunc(i, 3);
            const pos = c.struct_Vector2{ .x = repeatPosition.x + @as(f32, x) * repeatSize3rd, .y = repeatPosition.y + @as(f32, y) * repeatSize3rd };
            c.DrawTextureEx(surface.texture, pos, 0.0, repeatScaleTex);
        }
        c.EndShaderMode();

        if (c.IsKeyPressed(c.KEY_DOWN)) {
            const render = c.LoadRenderTexture(RESOLUTION * 2, RESOLUTION * 2);
            c.BeginTextureMode(render);
            c.BeginShaderMode(repeatSh);
            const fadeStartRender = [2]f32{ 0.76, 0.76 };
            c.SetShaderValue(repeatSh, c.GetShaderLocation(repeatSh, "fadeStart"), &fadeStartRender, c.SHADER_UNIFORM_VEC2);
            c.DrawTexture(surface.texture, 0, 0, c.WHITE);
            c.EndShaderMode();
            c.EndTextureMode();
            const renderImage = c.LoadImageFromTexture(render.texture);
            if (c.ExportImage(renderImage, "render.png")) {}
            c.UnloadImage(renderImage);
            c.UnloadRenderTexture(render);
        }
    }
}
