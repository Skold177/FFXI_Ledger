require('common');

local imgui = require('imgui');
local art   = require('art');

local theme = T{
    PADDING = 10,
    FRAME_X = 6,
    name    = 'phoenix',
    alpha   = 1.0,
    framed  = false,
};

local function rgb(hex, alpha)
    return {
        tonumber(hex:sub(1, 2), 16) / 255,
        tonumber(hex:sub(3, 4), 16) / 255,
        tonumber(hex:sub(5, 6), 16) / 255,
        alpha or 1.0,
    };
end

theme.THEMES = T{
    phoenix = T{
        label  = 'Phoenix',
        style  = T{ window = 8, frame = 4, tab = 4, grab = 3, cell = 4 },
        colors = T{
            abyss     = rgb('180e0e'),
            surface1  = rgb('291c1c'),
            surface2  = rgb('321f1f'),
            lane      = rgb('211515'),
            cell      = rgb('0d0707', 0.55),
            border    = rgb('d2abab', 0.20),
            subtle    = rgb('d2abab', 0.12),
            text      = rgb('fff8f8'),
            secondary = rgb('eae1e1'),
            peach     = rgb('d2abab'),
            muted     = rgb('8a6b6b'),
            faint     = rgb('5a4545'),
            royal     = rgb('c55151'),
            tint      = rgb('c55151', 0.30),
            hover     = rgb('d45e5e'),
            ember     = rgb('ff8d79'),
            danger    = rgb('e04040'),
            gold      = rgb('c5a131'),
            gain      = rgb('63ba8a'),
            loss      = rgb('e5736a'),
            coin      = rgb('e8c547'),
            coin_rim  = rgb('8a6d1c'),
            outline   = rgb('0d0707', 0.85),
            rule      = rgb('c55151'),
            clear     = { 0, 0, 0, 0 },
        },
    },
    classic = T{
        label  = 'Classic',
        style  = T{ window = 0, frame = 2, tab = 2, grab = 2, cell = 2 },
        colors = T{
            abyss     = rgb('0a1530'),
            surface1  = rgb('13244a'),
            surface2  = rgb('1d3463'),
            lane      = rgb('070f24'),
            cell      = rgb('02050f', 0.50),
            border    = rgb('8e8158', 0.45),
            subtle    = rgb('8e8158', 0.20),
            text      = rgb('f4f6fa'),
            secondary = rgb('dfe3ea'),
            peach     = rgb('e2c27e'),
            muted     = rgb('9ea8b8'),
            faint     = rgb('5f6b82'),
            royal     = rgb('35599e'),
            tint      = rgb('8fb4ff', 0.18),
            hover     = rgb('4670b8'),
            ember     = rgb('e9c46a'),
            danger    = rgb('f05a4a'),
            gold      = rgb('e2c27e'),
            gain      = rgb('7ed6a0'),
            loss      = rgb('f0786a'),
            coin      = rgb('e8c547'),
            coin_rim  = rgb('8a6d1c'),
            outline   = rgb('05070d', 0.85),
            rule      = rgb('8e8158'),
            clear     = { 0, 0, 0, 0 },
        },
    },
};

local GAME_STYLE = T{ window = 0, frame = 2, tab = 2, grab = 2, cell = 2 };

local function game_theme(label, window, colors)
    local merged = T{
        ember    = rgb('f2c66d'),
        danger   = rgb('f05a4a'),
        gold     = rgb('f2d27a'),
        gain     = rgb('7ed98a'),
        loss     = rgb('f0786a'),
        coin     = rgb('e8c547'),
        coin_rim = rgb('8a6d1c'),
        outline  = rgb('05050d', 0.85),
        clear    = { 0, 0, 0, 0 },
    };
    for key, value in pairs(colors) do
        merged[key] = value;
    end
    merged.cell = { merged.lane[1], merged.lane[2], merged.lane[3], 0.55 };
    return T{ label = label, window = window, style = GAME_STYLE, colors = merged };
end

theme.THEMES.lines = game_theme('Lines', 14, T{
    abyss = rgb('17143a'), surface1 = rgb('1f1b4a'), surface2 = rgb('29245e'), lane = rgb('100d2a'),
    border = rgb('c9c6ee', 0.35), subtle = rgb('c9c6ee', 0.15),
    text = rgb('f7f7ff'), secondary = rgb('e4e3f5'), peach = rgb('c8c3ff'), muted = rgb('a5a2c9'), faint = rgb('625f8c'),
    royal = rgb('4a43a6'), tint = rgb('a9a3ff', 0.18), hover = rgb('5a53bd'), rule = rgb('d8d6f2'),
});
theme.THEMES.silver = game_theme('Silver', 15, T{
    abyss = rgb('25252f'), surface1 = rgb('30303b'), surface2 = rgb('3b3b48'), lane = rgb('191920'),
    border = rgb('cfcde6', 0.35), subtle = rgb('cfcde6', 0.15),
    text = rgb('fafafd'), secondary = rgb('e8e8ef'), peach = rgb('d9d6f2'), muted = rgb('aeadc2'), faint = rgb('6c6b7d'),
    royal = rgb('5d5b8a'), tint = rgb('cfcde6', 0.16), hover = rgb('6e6ca0'), rule = rgb('cfcde6'),
});
theme.THEMES.violet = game_theme('Violet', 16, T{
    abyss = rgb('170f3c'), surface1 = rgb('20164e'), surface2 = rgb('2a1e63'), lane = rgb('0f0a2a'),
    border = rgb('d8d6f2', 0.35), subtle = rgb('d8d6f2', 0.15),
    text = rgb('f7f5ff'), secondary = rgb('e6e2f7'), peach = rgb('cbbfff'), muted = rgb('a69ecb'), faint = rgb('5f578a'),
    royal = rgb('5038b0'), tint = rgb('b0a0ff', 0.18), hover = rgb('6048c4'), rule = rgb('d8d6f2'),
});
theme.THEMES.stone = game_theme('Stone', 17, T{
    abyss = rgb('1c201f'), surface1 = rgb('252a29'), surface2 = rgb('2f3534'), lane = rgb('131615'),
    border = rgb('cfcde6', 0.30), subtle = rgb('cfcde6', 0.14),
    text = rgb('f5f7f6'), secondary = rgb('e2e6e4'), peach = rgb('d2dcd7'), muted = rgb('a2aaa7'), faint = rgb('5f6764'),
    royal = rgb('4d5e58'), tint = rgb('b8d0c8', 0.16), hover = rgb('5e716a'), rule = rgb('cfcde6'),
});
theme.THEMES.gray = game_theme('Gray', 18, T{
    abyss = rgb('262626'), surface1 = rgb('303030'), surface2 = rgb('3a3a3a'), lane = rgb('1a1a1a'),
    border = rgb('e2e2e2', 0.30), subtle = rgb('e2e2e2', 0.14),
    text = rgb('f8f8f8'), secondary = rgb('e6e6e6'), peach = rgb('dcdcdc'), muted = rgb('a8a8a8'), faint = rgb('666666'),
    royal = rgb('585866'), tint = rgb('ffffff', 0.12), hover = rgb('6a6a7a'), rule = rgb('e2e2e2'),
});
theme.THEMES.parchment = game_theme('Parchment', 20, T{
    abyss = rgb('4a4230'), surface1 = rgb('554b36'), surface2 = rgb('625740'), lane = rgb('2b261b'),
    border = rgb('e6d6a0', 0.40), subtle = rgb('e6d6a0', 0.18),
    text = rgb('fffbf2'), secondary = rgb('f6efdc'), peach = rgb('f6e2a8'), muted = rgb('e3d8bb'), faint = rgb('9c8f6c'),
    royal = rgb('7d6b3c'), tint = rgb('f6e2a8', 0.20), hover = rgb('8f7c49'), rule = rgb('dcc98e'),
    ember = rgb('ffd27a'), danger = rgb('ff6a5a'), gold = rgb('ffd986'), gain = rgb('8de09a'), loss = rgb('ff8a7a'), outline = rgb('120d05', 0.90),
});
theme.THEMES.teal = game_theme('Teal', 21, T{
    abyss = rgb('0e1e24'), surface1 = rgb('142c35'), surface2 = rgb('1b3944'), lane = rgb('09161a'),
    border = rgb('86d6dc', 0.35), subtle = rgb('86d6dc', 0.15),
    text = rgb('f2fbfc'), secondary = rgb('d9eff1'), peach = rgb('a4e4e8'), muted = rgb('93b9be'), faint = rgb('527378'),
    royal = rgb('2c6f7a'), tint = rgb('86d6dc', 0.18), hover = rgb('378593'), rule = rgb('86d6dc'), outline = rgb('03080a', 0.85),
    gain = rgb('9be37a'),
});

theme.THEME_ORDER = T{ 'phoenix', 'classic', 'lines', 'silver', 'violet', 'stone', 'gray', 'parchment', 'teal' };

local CLASSIC_TOP    = rgb('1d3a6e');
local CLASSIC_BOTTOM = rgb('0a1530');
local CLASSIC_TINT   = rgb('c4fbc4');
local CLASSIC_SHADE  = 0.38;
local CLASSIC_TILE   = 256;
local GAME_TILE      = 128;
local GAME_STRIP     = 8;
local GAME_TEXTURE   = 32;
local GAME_GRID      = 4;
local GAME_CORNER    = 24;

theme.COLOR = T{};
theme.style = T{};

function theme.use(name)
    local chosen = theme.THEMES[name] and name or 'phoenix';
    theme.name   = chosen;
    theme.framed = chosen == 'classic' or theme.THEMES[chosen].window ~= nil;
    for key, value in pairs(theme.THEMES[chosen].colors) do
        theme.COLOR[key] = value;
    end
    for key, value in pairs(theme.THEMES[chosen].style) do
        theme.style[key] = value;
    end
    return chosen;
end

theme.use('phoenix');

function theme.u32(color)
    return imgui.GetColorU32(color);
end

function theme.fade(color, alpha)
    return { color[1], color[2], color[3], alpha };
end

function theme.text_width(text)
    local width = imgui.CalcTextSize(text);
    if (type(width) == 'table') then
        return width.x or width[1] or 0;
    end
    return width or 0;
end

function theme.label(list, x, y, color, text)
    local outline = theme.u32(theme.COLOR.outline);
    list:AddText({ x - 1, y }, outline, text);
    list:AddText({ x + 1, y }, outline, text);
    list:AddText({ x, y - 1 }, outline, text);
    list:AddText({ x, y + 1 }, outline, text);
    list:AddText({ x, y }, theme.u32(color), text);
end

function theme.push(alpha)
    local COLOR  = theme.COLOR;
    local style  = theme.style;
    local window = { COLOR.abyss[1], COLOR.abyss[2], COLOR.abyss[3], alpha };
    if (theme.framed) then
        window = COLOR.clear;
    end
    theme.alpha = alpha;
    local colors = {
        { ImGuiCol_WindowBg,             window         },
        { ImGuiCol_ChildBg,              COLOR.clear    },
        { ImGuiCol_Border,               COLOR.border   },
        { ImGuiCol_Separator,            COLOR.border   },
        { ImGuiCol_Text,                 COLOR.text     },
        { ImGuiCol_TextDisabled,         COLOR.muted    },
        { ImGuiCol_FrameBg,              COLOR.surface2 },
        { ImGuiCol_FrameBgHovered,       COLOR.tint     },
        { ImGuiCol_FrameBgActive,        COLOR.surface2 },
        { ImGuiCol_SliderGrab,           COLOR.royal    },
        { ImGuiCol_SliderGrabActive,     COLOR.hover    },
        { ImGuiCol_Header,               COLOR.surface2 },
        { ImGuiCol_HeaderHovered,        COLOR.tint     },
        { ImGuiCol_HeaderActive,         COLOR.royal    },
        { ImGuiCol_PopupBg,              COLOR.surface1 },
        { ImGuiCol_CheckMark,            COLOR.royal    },
        { ImGuiCol_Button,               COLOR.royal    },
        { ImGuiCol_ButtonHovered,        COLOR.hover    },
        { ImGuiCol_ButtonActive,         COLOR.royal    },
        { ImGuiCol_ResizeGrip,           COLOR.clear    },
        { ImGuiCol_TableHeaderBg,        COLOR.surface2 },
        { ImGuiCol_TableRowBg,           COLOR.clear    },
        { ImGuiCol_TableRowBgAlt,        COLOR.cell     },
        { ImGuiCol_TableBorderLight,     COLOR.subtle   },
        { ImGuiCol_TableBorderStrong,    COLOR.border   },
        { ImGuiCol_ScrollbarBg,          COLOR.clear    },
        { ImGuiCol_ScrollbarGrab,        COLOR.surface2 },
        { ImGuiCol_ScrollbarGrabHovered, COLOR.tint     },
        { ImGuiCol_ScrollbarGrabActive,  COLOR.royal    },
    };
    for _, color in ipairs(colors) do
        imgui.PushStyleColor(color[1], color[2]);
    end

    imgui.PushStyleVar(ImGuiStyleVar_WindowRounding, style.window);
    imgui.PushStyleVar(ImGuiStyleVar_FrameRounding, style.frame);
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { theme.PADDING, theme.PADDING });
    imgui.PushStyleVar(ImGuiStyleVar_ItemSpacing, { 8, 6 });
    imgui.PushStyleVar(ImGuiStyleVar_FramePadding, { theme.FRAME_X, 4 });
    imgui.PushStyleVar(ImGuiStyleVar_CellPadding, { 6, 3 });
    imgui.PushStyleVar(ImGuiStyleVar_TabRounding, style.tab);
    imgui.PushStyleVar(ImGuiStyleVar_GrabMinSize, 6.0);
    imgui.PushStyleVar(ImGuiStyleVar_GrabRounding, style.grab);
    if (not theme.framed) then
        return #colors, 9;
    end
    imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, 0);
    return #colors, 10;
end

local function vertex(color, alpha)
    return { math.min(1, color[1]), math.min(1, color[2]), math.min(1, color[3]), math.min(1, color[4] * 2) * alpha };
end

local function mix(a, b, t)
    return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t, a[4] + (b[4] - a[4]) * t };
end

local function game_window(draw, x, y, w, h, scale, title, title_color)
    local COLOR     = theme.COLOR;
    local alpha     = theme.alpha;
    local art_style = art.style(theme.THEMES[theme.name].window);
    local corner    = math.max(1, math.min(GAME_CORNER * scale, math.floor(w / 2), math.floor(h / 2)));
    local top_line  = math.floor(2 * scale + 0.5);

    if (not art_style) then
        local top    = theme.u32({ COLOR.surface2[1], COLOR.surface2[2], COLOR.surface2[3], alpha });
        local bottom = theme.u32({ COLOR.abyss[1], COLOR.abyss[2], COLOR.abyss[3], alpha });
        draw:AddRectFilledMultiColor({ x, y }, { x + w, y + h }, top, top, bottom, bottom);
        draw:AddRect({ x, y }, { x + w, y + h }, theme.u32(COLOR.rule), 0, 0, math.max(1, math.floor(scale + 0.5)));
    else
        local tile  = GAME_TILE * scale;
        local strip = GAME_STRIP * scale;
        local span  = GAME_STRIP / GAME_TILE;
        for _, part in ipairs(art_style.parts) do
            if (part.name == 'newtex') then
                draw:PushClipRect({ x, y }, { x + w, y + h }, true);
                for row = 0, math.ceil(h / strip) - 1 do
                    local sy    = y + row * strip;
                    local color = theme.u32(vertex(mix(part.colors[1], part.colors[3], math.min(1, (row + 0.5) * strip / h)), alpha));
                    local v0    = (row % (GAME_TILE / GAME_STRIP)) * span;
                    for tx = x, x + w - 1, tile do
                        draw:AddImage(art_style.background, { tx, sy }, { tx + tile, sy + strip }, { 0, v0 }, { 1, v0 + span }, color);
                    end
                end
                draw:PopClipRect();
                break;
            end
        end

        for _, part in ipairs(art_style.parts) do
            if (part.name == 'corner') then
                local cx   = part.right and (x + w - corner) or x;
                local cy   = part.bottom and (y + h - corner) or y;
                local u0   = part.right and (8 / GAME_TEXTURE) or 0;
                local v0   = part.bottom and (8 / GAME_TEXTURE) or 0;
                local cell = corner / GAME_GRID;
                local uv   = GAME_CORNER / GAME_TEXTURE / GAME_GRID;
                for gy = 0, GAME_GRID - 1 do
                    for gx = 0, GAME_GRID - 1 do
                        local fx, fy = (gx + 0.5) / GAME_GRID, (gy + 0.5) / GAME_GRID;
                        local color  = mix(mix(part.colors[1], part.colors[2], fx), mix(part.colors[3], part.colors[4], fx), fy);
                        draw:AddImage(art_style.corner, { cx + gx * cell, cy + gy * cell }, { cx + (gx + 1) * cell, cy + (gy + 1) * cell },
                            { u0 + gx * uv, v0 + gy * uv }, { u0 + (gx + 1) * uv, v0 + (gy + 1) * uv }, theme.u32(vertex(color, alpha)));
                    end
                end
            elseif (part.name == 'hfr1' or part.name == 'vfr1') then
                local band    = part.name == 'hfr1' and part.height or part.width;
                local average = mix(mix(part.colors[1], part.colors[2], 0.5), mix(part.colors[3], part.colors[4], 0.5), 0.5);
                local color   = theme.u32(vertex(average, alpha));
                local far     = (part.name == 'hfr1' and part.bottom) or (part.name == 'vfr1' and part.right);
                local t0      = far and ((GAME_TEXTURE - band) / GAME_TEXTURE) or 0;
                local t1      = t0 + band / GAME_TEXTURE;
                local length  = GAME_TEXTURE * scale;
                if (part.name == 'hfr1') then
                    local by   = far and (y + h - band * scale) or y;
                    local stop = x + w - corner;
                    for sx = x + corner, stop - 1, length do
                        local ex = math.min(stop, sx + length);
                        draw:AddImage(art_style.edge, { sx, by }, { ex, by + band * scale }, { 0, t0 }, { (ex - sx) / length, t1 }, color);
                    end
                else
                    local bx   = far and (x + w - band * scale) or x;
                    local stop = y + h - corner;
                    for sy = y + corner, stop - 1, length do
                        local ey = math.min(stop, sy + length);
                        draw:AddImage(art_style.side, { bx, sy }, { bx + band * scale, ey }, { t0, 0 }, { t1, (ey - sy) / length }, color);
                    end
                end
            end
        end
    end

    if (not title) then
        return 0;
    end
    local size = imgui.GetFontSize();
    theme.label(draw, math.floor(x + (w - theme.text_width(title)) / 2), math.floor(y + top_line - size / 2), title_color or COLOR.text, title);
    return top_line + size / 2 + 3;
end

local function classic_window(draw, x, y, w, h, scale, title, title_color)
    local COLOR  = theme.COLOR;
    local alpha  = theme.alpha;
    local inset  = math.floor(3 * scale + 0.5);
    local line   = math.max(1, math.floor(scale + 0.5));
    local square = math.floor(3 * scale + 0.5);
    local x0, y0 = x + inset, y + inset;
    local x1, y1 = x + w - inset, y + h - inset;
    local id     = art.window();

    if (id) then
        local tile = math.floor(CLASSIC_TILE * scale);
        local tint = theme.u32({ CLASSIC_TINT[1], CLASSIC_TINT[2], CLASSIC_TINT[3], alpha });
        draw:PushClipRect({ x0, y0 }, { x1, y1 }, true);
        for ty = y0, y1, tile do
            for tx = x0, x1, tile do
                draw:AddImage(id, { tx, ty }, { tx + tile, ty + tile }, { 0, 0 }, { 1, 1 }, tint);
            end
        end
        draw:PopClipRect();
        local clear = theme.u32(COLOR.clear);
        local dark  = theme.u32({ 0, 0, 0, CLASSIC_SHADE * alpha });
        draw:AddRectFilledMultiColor({ x0, y0 }, { x1, y1 }, clear, clear, dark, dark);
    else
        local top    = theme.u32({ CLASSIC_TOP[1], CLASSIC_TOP[2], CLASSIC_TOP[3], alpha });
        local bottom = theme.u32({ CLASSIC_BOTTOM[1], CLASSIC_BOTTOM[2], CLASSIC_BOTTOM[3], alpha });
        draw:AddRectFilledMultiColor({ x0, y0 }, { x1, y1 }, top, top, bottom, bottom);
    end

    local rule   = theme.u32(COLOR.rule);
    local side   = theme.u32({ COLOR.rule[1], COLOR.rule[2], COLOR.rule[3], 0.4 });
    local shadow = theme.u32({ 0, 0, 0, 0.45 * alpha });
    local fill   = theme.u32({ CLASSIC_BOTTOM[1], CLASSIC_BOTTOM[2], CLASSIC_BOTTOM[3], alpha });
    draw:AddRectFilled({ x0, y0 + line }, { x1, y0 + 2 * line }, shadow);
    draw:AddRectFilled({ x0, y1 }, { x1, y1 + line }, shadow);
    draw:AddRectFilled({ x0, y0 }, { x1, y0 + line }, rule);
    draw:AddRectFilled({ x0, y1 - line }, { x1, y1 }, rule);
    draw:AddRectFilled({ x0, y0 }, { x0 + line, y1 }, side);
    draw:AddRectFilled({ x1 - line, y0 }, { x1, y1 }, side);
    for _, corner in ipairs({ { x0, y0 }, { x1, y0 }, { x0, y1 }, { x1, y1 } }) do
        local cx, cy = math.floor(corner[1]), math.floor(corner[2]);
        draw:AddRectFilled({ cx - square, cy - square }, { cx + square, cy + square }, fill);
        draw:AddRect({ cx - square, cy - square }, { cx + square, cy + square }, rule, 0, 0, line);
    end

    if (not title) then
        return 0;
    end
    local size = imgui.GetFontSize();
    theme.label(draw, math.floor(x + (w - theme.text_width(title)) / 2), math.floor(y0 + line / 2 - size / 2), title_color or COLOR.text, title);
    return inset + size / 2 + 3;
end

local function push_screen_clip(draw, x0, y0, x1, y1)
    local display       = imgui.GetIO().DisplaySize;
    local left, top     = math.max(0, x0), math.max(0, y0);
    local right, bottom = math.min(display.x, x1), math.min(display.y, y1);
    if (right <= left or bottom <= top) then
        return false;
    end
    draw:PushClipRect({ left, top }, { right, bottom }, false);
    return true;
end

function theme.decorate(scale, accent, thickness, title, title_color)
    local x, y = theme.window_position();
    local w, h = theme.window_size();
    local draw = imgui.GetWindowDrawList();
    if (theme.framed) then
        local frame = game_window;
        if (theme.name == 'classic') then
            frame = classic_window;
        end
        local size = imgui.GetFontSize();
        if (not push_screen_clip(draw, x - 8 * scale, y - size, x + w + 8 * scale, y + h + 8 * scale)) then
            return;
        end
        local below = frame(draw, x, y, w, h, scale, title, title_color);
        draw:PopClipRect();
        if (below > imgui.GetCursorPosY()) then
            imgui.SetCursorPosY(math.ceil(below));
        end
        return;
    end
    if (accent == nil) then
        return;
    end
    if (not push_screen_clip(draw, x, y, x + w, y + h)) then
        return;
    end
    draw:AddRectFilled({ x + 10, y }, { x + w - 10, y + thickness }, theme.u32(accent));
    draw:PopClipRect();
end

function theme.toggle_button(label, on, width)
    local COLOR = theme.COLOR;
    imgui.PushStyleColor(ImGuiCol_Button, on and COLOR.royal or COLOR.surface2);
    imgui.PushStyleColor(ImGuiCol_ButtonHovered, on and COLOR.hover or COLOR.tint);
    imgui.PushStyleColor(ImGuiCol_ButtonActive, COLOR.royal);
    imgui.PushStyleColor(ImGuiCol_Text, on and COLOR.text or COLOR.muted);
    local clicked = imgui.Button(label, { width, 0 });
    imgui.PopStyleColor(4);
    return clicked;
end

function theme.button_row(id, labels, states, width)
    local gap    = 8;
    local widths = {};
    local lines  = {};
    local line   = { items = {}, used = 0 };
    for index, label in ipairs(labels) do
        widths[index] = theme.text_width(label) + theme.FRAME_X * 2;
        local need = widths[index] + (#line.items > 0 and gap or 0);
        if (#line.items > 0 and line.used + need > width) then
            lines[#lines + 1] = line;
            line = { items = {}, used = 0 };
            need = widths[index];
        end
        line.items[#line.items + 1] = index;
        line.used = line.used + need;
    end
    if (#line.items > 0) then
        lines[#lines + 1] = line;
    end

    local clicked = nil;
    for _, row in ipairs(lines) do
        local spare = math.max(0, (width - row.used) / #row.items);
        for position, index in ipairs(row.items) do
            if (position > 1) then
                imgui.SameLine(0, gap);
            end
            local size = math.max(1, math.min(width, widths[index] + spare));
            if (theme.toggle_button(('%s##%s_%d'):fmt(labels[index], id, index), states[index], size)) then
                clicked = index;
            end
        end
    end
    return clicked;
end

function theme.caption(text)
    imgui.TextColored(theme.COLOR.muted, text);
end

function theme.window_position()
    local x, y = imgui.GetWindowPos();
    if (type(x) == 'table') then
        y = x.y or x[2];
        x = x.x or x[1];
    end
    return x, y;
end

function theme.window_size()
    local w, h = imgui.GetWindowSize();
    if (type(w) == 'table') then
        h = w.y or w[2];
        w = w.x or w[1];
    end
    return w, h;
end

function theme.available()
    local w, h = imgui.GetContentRegionAvail();
    if (type(w) == 'table') then
        h = w.y or w[2];
        w = w.x or w[1];
    end
    return w, h;
end

function theme.cursor()
    local x, y = imgui.GetCursorScreenPos();
    if (type(x) == 'table') then
        y = x.y or x[2];
        x = x.x or x[1];
    end
    return x, y;
end

function theme.mouse()
    local x, y = imgui.GetMousePos();
    if (type(x) == 'table') then
        y = x.y or x[2];
        x = x.x or x[1];
    end
    return x, y;
end

return theme;
