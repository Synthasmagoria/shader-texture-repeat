const rl = @cImport({
    @cDefine("GRAPHICS_API_OPENGL_11", {});
    @cInclude("raylib.h");
    @cInclude("rlgl.h");
    @cInclude("raymath.h");
});
const fmt = @import("std").fmt;
const std = @import("std");
const math = @import("std").math;

const FRAMERATE: i64 = 30;
const STEP: f64 = 1.0 / @as(f64, FRAMERATE);
const WINDOW_WIDTH: i64 = 1280;
const WINDOW_HEIGHT: i64 = 720;
const PADDING: i64 = 128;

const STATE = enum {
    OPEN_FILE,
    VIEW,
};

const VERTEX_SHADER_CODE =
\\attribute vec3 vertexPosition;
\\attribute vec2 vertexTexCoord;
\\attribute vec4 vertexColor;
\\varying vec2 v_vTexcoord;
\\varying vec2 {s};
\\varying vec4 v_vColour;
\\uniform mat4 mvp;
\\uniform vec2 resolution;
\\uniform float _internal_scale;
\\void main() {{
\\    v_vTexcoord = vertexTexCoord * _internal_scale;
\\    v_vColour = vertexColor;
\\    {s} = vertexPosition.xy * _internal_scale;
\\    gl_Position = mvp * vec4(vertexPosition, 1.0);
\\}}
;

const REPEAT_FRAGMENT_SHADER_CODE =
\\varying vec2 v_vTexcoord;
\\varying vec4 v_vColour;
\\uniform sampler2D texture0;
\\uniform vec2 repeatStart;
\\uniform vec4 colDiffuse;
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
\\    gl_FragColor = mix(hb, ht, fade.y) * colDiffuse * v_vColour;
\\}
;

const ColorString = struct {color: rl.struct_Color, str: []const u8};
const InteractableBar = struct {x: i32, y: i32, w: i32, h: i32, progress: f32, vertical: bool};
pub fn InsideInteractableBar(bar: InteractableBar, x: i32, y: i32) bool {
    return x >= bar.x and y >= bar.y and x < bar.x + bar.w and y < bar.y + bar.h;
}
pub fn HandleInteractableBarInput(bar: InteractableBar, inputX: i32, inputY: i32) InteractableBar {
    var newBar = bar;
    if (!newBar.vertical) {
        const progressPosition = math.clamp(inputX, newBar.x, newBar.x + newBar.w);
        const w = @as(f32, @floatFromInt(newBar.w));
        newBar.progress = @as(f32, @floatFromInt(progressPosition - newBar.x)) / w;
    } else {
        const progressPosition = math.clamp(inputY, newBar.y, newBar.y + newBar.h);
        const h = @as(f32, @floatFromInt(newBar.h));
        newBar.progress = @as(f32, @floatFromInt(progressPosition - newBar.y)) / h;
    }
    return newBar;
}
pub fn GetInteractableBarProgressPosition(bar: InteractableBar) i32 {
    if (!bar.vertical) {
        return @as(i32, @intFromFloat(@as(f32, @floatFromInt(bar.w)) * bar.progress));
    } else {
        return @as(i32, @intFromFloat(@as(f32, @floatFromInt(bar.h)) * bar.progress));
    }
}
pub fn DrawInteractableBar(bar: InteractableBar) void {
    const vacantColor = rl.struct_Color{.r = 128, .g = 0, .b = 128, .a = 64};
    const fullColor = rl.struct_Color{.r = 255, .g = 0, .b = 255, .a = 128};
    rl.DrawRectangle(bar.x, bar.y, bar.w, bar.h, vacantColor);
    if (!bar.vertical) {
        rl.DrawRectangle(bar.x, bar.y, GetInteractableBarProgressPosition(bar), bar.h, fullColor);
    } else {
        rl.DrawRectangle(bar.x, bar.y, bar.w, GetInteractableBarProgressPosition(bar), fullColor);
    }
    rl.DrawRectangleLines(bar.x, bar.y, bar.w, bar.h, rl.WHITE);
    rl.DrawText(rl.TextFormat("%f", bar.progress), bar.x + @divFloor(bar.w, 2), bar.y + @divFloor(bar.h, 2), 16, rl.WHITE);
}
pub fn CreateInteractableBar() InteractableBar {
    return InteractableBar{.x = 0, .y = 0, .w = 0, .h = 0, .progress = 0.0, .vertical = false};
}
pub fn CopyInteractableBar(dest: *InteractableBar, src: InteractableBar) void {
    dest.x = src.x;
    dest.y = src.y;
    dest.w = src.w;
    dest.h = src.h;
    dest.progress = src.progress;
}

const testing = @import("std").testing;
pub fn WrapI(val: i64, min: i64, max: i64) i64 {
    return val - @divFloor(val - min, max - min) * (max - min);
}
test "wrap negative" {
    try testing.expect(WrapI(-2, 1, 7) == 4);
}
test "warp positive" {
    try testing.expect(WrapI(9, 2, 6) == 5);
}
test "warp negative minmax" {
    try testing.expect(WrapI(-8, -7, -2) == -3);
}
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

pub fn DrawTextList(list: []const ColorString, x: i32, y: i32, w: i32, sep: i32, pad: i32, inset: i32) void {
    const fontSize: i32 = @intCast(28);
    for (list, 0..) |item, ind| {
        const i: i32 = @intCast(ind);
        const dy: i32 = y + sep * i + pad * i;
        const cstr: [*c]const u8 = @ptrCast(item.str);
        rl.DrawRectangle(x, dy, w, sep, rl.struct_Color{.r = 0, .g = 0, .b = 0, .a = 128});
        rl.DrawText(cstr, x + 1 + inset, dy + 1 + inset, fontSize, rl.BLACK);
        rl.DrawText(cstr, x + inset, dy + inset, fontSize, item.color);
        rl.DrawRectangleLines(x, dy, w, sep, rl.WHITE);
    }
}

pub fn SetRepeatShaderUniforms(sh: rl.struct_Shader, repeatStart: rl.struct_Vector2) void {
    const repeat = [2]f32{repeatStart.x, repeatStart.y};
    rl.SetShaderValue(sh, rl.GetShaderLocation(sh, "repeatStart"), &repeat, rl.SHADER_UNIFORM_VEC2);
    const scale: f32 = 1.0;
    rl.SetShaderValue(sh, rl.GetShaderLocation(sh, "_internal_scale"), &scale, rl.SHADER_UNIFORM_FLOAT);
}

pub fn RenderTexture(shd: rl.struct_Shader, tex: rl.struct_RenderTexture) void {
    rl.BeginTextureMode(tex);
    rl.BeginShaderMode(shd);
    defer rl.EndShaderMode();
    const resolution = [_]f32{
        @as(f32, @floatFromInt(tex.texture.width)),
        @as(f32, @floatFromInt(tex.texture.height)) };
    rl.SetShaderValue(
        shd,
        rl.GetShaderLocation(shd, "resolution"),
        &resolution,
        rl.SHADER_UNIFORM_VEC2);
    const scale: f32 = 2.0;
    rl.SetShaderValue(
        shd,
        rl.GetShaderLocation(shd, "_internal_scale"),
        &scale,
        rl.SHADER_UNIFORM_FLOAT);
    rl.DrawRectangle(0, 0, tex.texture.width, tex.texture.height, rl.WHITE);
    rl.EndTextureMode();
}

const Transform = struct { padding: i64, position: rl.struct_Vector2, rotation: f32, scale: f32, size: rl.struct_Vector2};
pub fn UpdateTransform(padding: i64, texture: rl.struct_Texture, container_width: i64, container_height: i64) Transform {
    const h = @as(f32, @floatFromInt(container_height - padding * 2));
    const scale = h / @as(f32, @floatFromInt(texture.height));
    const w = @as(f32, @floatFromInt(texture.width)) * scale;
    const position = rl.struct_Vector2{ .x = math.floor(@as(f32, @floatFromInt(container_width)) / 2.0 - w / 2.0), .y = @as(f32, @floatFromInt(PADDING)) };
    const size = rl.struct_Vector2{.x = w, .y = h};
    return Transform{ .padding = padding, .position = position, .rotation = 0.0, .scale = scale, .size = size};
}
pub fn RlCreateImageUndefined() rl.struct_Image {
    return .{ .data = null, .format = undefined, .height = undefined, .width = undefined, .mipmaps = undefined };
}
pub fn RlCreateRenderTextureUndefined() rl.struct_RenderTexture {
    return .{ .depth = undefined, .id = undefined, .texture = undefined };
}

pub fn main() !void {
    rl.SetTraceLogLevel(rl.LOG_WARNING);
    rl.SetConfigFlags(rl.FLAG_WINDOW_RESIZABLE);
    rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Generate repeating texture");
    defer rl.CloseWindow();
    rl.SetTargetFPS(FRAMERATE);

    const allocator = std.heap.page_allocator;
    var argsIterator = try std.process.ArgIterator.initWithAllocator(allocator);
    defer argsIterator.deinit();
    _ = argsIterator.next();
    const positionVaryingNameArg = argsIterator.next() orelse "fragPosition";
    const vertexShaderCode = try std.fmt.allocPrint(
        allocator,
        VERTEX_SHADER_CODE,
        .{positionVaryingNameArg, positionVaryingNameArg});
    rl.TraceLog(rl.LOG_INFO, "-----------------------\nVertex shader code looks like this: \n%s\n-----------------------", @as([*]u8, @ptrCast(vertexShaderCode)));
    defer allocator.free(vertexShaderCode);

    var textureSizeOptionStrings = [_]ColorString{
        ColorString{.color = rl.WHITE, .str = "x32"},
        ColorString{.color = rl.WHITE, .str = "x64"},
        ColorString{.color = rl.WHITE, .str = "x128"},
        ColorString{.color = rl.WHITE, .str = "x256"},
        ColorString{.color = rl.WHITE, .str = "x512"},
        ColorString{.color = rl.WHITE, .str = "x1024"},
        ColorString{.color = rl.WHITE, .str = "x2048"}
    };
    var textureSizeOptionIndex : usize = 2;
    const textureSizeOptions = [_]i32{32, 64, 128, 256, 512, 1024, 2048};
    const textureSizeOptionInset : i64 = 2;
    textureSizeOptionStrings[textureSizeOptionIndex].color = rl.YELLOW;

    var noiseTexture = rl.LoadRenderTexture(
        textureSizeOptions[textureSizeOptionIndex] * 2,
        textureSizeOptions[textureSizeOptionIndex] * 2);
    var noiseShaderCompiled = false;
    defer UnloadRenderTextureSafe(noiseTexture);
    var noiseShader = rl.struct_Shader{.id = rl.rlGetShaderIdDefault(), .locs = rl.rlGetShaderLocsDefault()};
    var noiseShaderCompileFailure = false;
    defer UnloadShaderSafe(noiseShader);
    var noiseTextureTransform = Transform{
        .padding = 0,
        .position = rl.struct_Vector2{ .x = 0.0, .y = 0.0 },
        .rotation = 0.0,
        .scale = 0.0,
        .size = rl.struct_Vector2{.x = 0.0, .y = 0.0}};

    const repeatShader = rl.LoadShaderFromMemory(@ptrCast(vertexShaderCode), REPEAT_FRAGMENT_SHADER_CODE);
    var repeatStart = rl.struct_Vector2{.x = 0.78, .y = 0.78};

    var barH = CreateInteractableBar();
    const barMargin : i32 = 24;
    const barWidth : i32 = 24;
    barH.h = barWidth;
    barH.progress = repeatStart.x;
    var barV = CreateInteractableBar();
    barV.vertical = true;
    barV.w = barWidth;
    barV.progress = repeatStart.y;
    var interactingBar : ?*InteractableBar = null;

    while (!rl.WindowShouldClose()) {
        rl.BeginDrawing();
        defer rl.EndDrawing();
        rl.ClearBackground(rl.BLACK);

        if (!noiseShaderCompiled) {
            rl.DrawText("Drop fragment shader\nfile into the window", 8, 8, 32, rl.RAYWHITE);
        }

        if (noiseShaderCompileFailure) {
            rl.DrawText("Check console for compile\nerror messages", 8, 92, 32, rl.RED);
        }

        if (rl.IsFileDropped()) {
            const files = rl.LoadDroppedFiles();
            defer rl.UnloadDroppedFiles(files);
            const fragmentCode = rl.LoadFileText(files.paths[0]);
            defer rl.UnloadFileText(fragmentCode);

            if (noiseShader.id != 0) {
                rl.UnloadShader(noiseShader);
            }
            noiseShader = rl.LoadShaderFromMemory(@ptrCast(vertexShaderCode), fragmentCode);

            if (noiseShader.id != 0) {
                RenderTexture(noiseShader, noiseTexture);
                noiseShaderCompiled = true;
                noiseShaderCompileFailure = false;
            } else {
                noiseShaderCompiled = false;
                noiseShaderCompileFailure = true;
            }
        }

        if (!noiseShaderCompiled) {continue;}

        if (rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT)) {
            const bars = [_]*InteractableBar{&barH, &barV};
            const m = rl.GetMousePosition();
            const mx = @as(i32, @intFromFloat(m.x));
            const my = @as(i32, @intFromFloat(m.y));
            for (bars) |bar| {
                if (InsideInteractableBar(bar.*, mx, my)) {
                    interactingBar = bar;
                    break;
                }
            }
        }
        if (rl.IsMouseButtonReleased(rl.MOUSE_BUTTON_LEFT)) {
            interactingBar = null;
        }
        if (interactingBar != null) {
            const m = rl.GetMousePosition();
            const mx = @as(i32, @intFromFloat(m.x));
            const my = @as(i32, @intFromFloat(m.y));
            const newBar = HandleInteractableBarInput(interactingBar.?.*, mx, my);
            CopyInteractableBar(interactingBar.?, newBar);
        }

        noiseTextureTransform = UpdateTransform(PADDING, noiseTexture.texture, rl.GetRenderWidth(), rl.GetRenderHeight());
        rl.BeginShaderMode(repeatShader);
        repeatStart = rl.struct_Vector2{.x = barH.progress, .y = barV.progress};
        SetRepeatShaderUniforms(repeatShader, repeatStart);
        rl.DrawTextureEx(
            noiseTexture.texture,
            noiseTextureTransform.position,
            noiseTextureTransform.rotation,
            noiseTextureTransform.scale,
            rl.WHITE);
        {
            const ntt = noiseTextureTransform;
            var transform = noiseTextureTransform;
            const v2 = rl.struct_Vector2;
            const offsets = [_]rl.struct_Vector2{
                rl.Vector2Scale(ntt.size, -1.0),
                v2{.x = 0.0, .y = -ntt.size.y},
                v2{.x = ntt.size.x, .y = -ntt.size.y},
                v2{.x = -ntt.size.x, .y = 0.0},
                v2{.x = ntt.size.x, .y = 0.0},
                v2{.x = -ntt.size.x, .y = ntt.size.y},
                v2{.x = 0.0, .y = ntt.size.y},
                ntt.size
            };
            for (offsets) |offset| {
                transform.position = rl.Vector2Add(ntt.position, offset);
                rl.DrawTextureEx(
                    noiseTexture.texture,
                    transform.position,
                    transform.rotation,
                    transform.scale,
                    rl.GRAY);
            }
        }
        rl.EndShaderMode();

        {
        const x = @as(i32, @intFromFloat(noiseTextureTransform.position.x));
        const y = @as(i32, @intFromFloat(noiseTextureTransform.position.y));
        const w = @as(i32, @intFromFloat(noiseTextureTransform.size.x));
        const h = @as(i32, @intFromFloat(noiseTextureTransform.size.y));

        barH.x = x;
        barH.y = y + h + barMargin;
        barH.w = w;
        DrawInteractableBar(barH);

        barV.x = x + w + barMargin;
        barV.y = y;
        barV.h = h;
        DrawInteractableBar(barV);
        }

        if (rl.IsKeyPressed(rl.KEY_UP) or rl.IsKeyPressed(rl.KEY_DOWN)) {
            textureSizeOptionStrings[textureSizeOptionIndex].color = rl.WHITE;
            const up = rl.IsKeyPressed(rl.KEY_UP);
            const down = rl.IsKeyPressed(rl.KEY_DOWN);
            const dir = @as(i64, @intFromBool(down)) - @as(i64, @intFromBool(up));
            const ind = @as(i64, @intCast(textureSizeOptionIndex));
            textureSizeOptionIndex = @as(u64, @intCast(WrapI(ind + dir, 0, textureSizeOptionStrings.len)));
            textureSizeOptionStrings[textureSizeOptionIndex].color = rl.YELLOW;

            const res = textureSizeOptions[textureSizeOptionIndex];
            rl.UnloadRenderTexture(noiseTexture);
            noiseTexture = rl.LoadRenderTexture(res * 2, res * 2);
            RenderTexture(noiseShader, noiseTexture);
        }
        DrawTextList(textureSizeOptionStrings[0..], @as(i32, 8), @as(i32, 8), @as(i32, 90), @as(i32, 32), @as(i32, 4), @as(i32, @intCast(textureSizeOptionInset)));

        if (rl.IsKeyPressed(rl.KEY_S)) {
            const res = textureSizeOptions[textureSizeOptionIndex];
            const repeatTexture = rl.LoadRenderTexture(res, res);
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
    }
}
