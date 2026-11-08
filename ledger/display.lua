require('common');

local chat     = require('chat');
local imgui    = require('imgui');
local settings = require('settings');
local theme    = require('theme');
local records  = require('records');
local icon     = require('icon');
local bags     = require('bags');

local COLOR = theme.COLOR;

local CLICK_SLOP   = 4;
local MENU_WIDTH   = 160;
local BALANCE_FONT = 1.25;
local SMALL_FONT   = 0.85;
local MIN_HOURS    = 5 / 60;
local TIP_DELAY    = 0.6;
local LOW_FREE     = 5;
local GIL_GAP      = 16;
local ICON_GAP     = 6;
local BAG_GAP      = 6;

local display = T{};

local function toggle(lg, key)
    lg.settings[key] = not lg.settings[key];
    settings.save();
end

local function slider(lg, id, key, low, high, format, step, width, live)
    imgui.SetNextItemWidth(width);
    local buffer = { lg.pending[key] or lg.settings[key] };
    if (imgui.SliderFloat(('##lg_%s_%s'):fmt(id, key), buffer, low, high, format, ImGuiSliderFlags_AlwaysClamp)) then
        local value = math.floor(buffer[1] / step + 0.5) * step;
        if (live) then
            lg.settings[key] = value;
        else
            lg.pending[key] = value;
        end
    end
    if (imgui.IsItemDeactivatedAfterEdit()) then
        if (lg.pending[key]) then
            lg.settings[key] = lg.pending[key];
            lg.pending[key]  = nil;
        end
        settings.save();
    end
end

display.slider = slider;

local function draw_coin(draw, x, y, size)
    local radius = size * 0.42;
    local center = { x + size / 2, y + size / 2 };
    draw:AddCircleFilled(center, radius, theme.u32(COLOR.coin), 24);
    draw:AddCircle(center, radius, theme.u32(COLOR.coin_rim), 24, math.max(1, size / 12));
    draw:AddCircle(center, radius * 0.6, theme.u32(theme.fade(COLOR.coin_rim, 0.6)), 24, 1);
end

function display.rate(net, seconds)
    return net / math.max(seconds / 3600, MIN_HOURS);
end

function display.fullness(state)
    local free = state.max - state.used;
    if (free <= 0) then
        return COLOR.danger;
    elseif (free <= LOW_FREE) then
        return COLOR.ember;
    end
    return COLOR.secondary;
end

local function bag_lines()
    local lines = {};
    for _, bag in ipairs(bags.CONTAINERS) do
        local state = bags.state[bag.id];
        if (bag.carried and state.max > 0) then
            lines[#lines + 1] = { label = bag.label, count = ('%d/%d'):fmt(state.used, state.max), color = display.fullness(state) };
        end
    end
    return lines;
end

local function bag_width(lines)
    imgui.PushFont(imgui.GetFont(), imgui.GetFontSize() * SMALL_FONT);
    local widest = 0;
    for _, line in ipairs(lines) do
        widest = math.max(widest, theme.text_width(line.label) + BAG_GAP + theme.text_width(line.count));
    end
    imgui.PopFont();
    return widest;
end

local function draw_bag_counts(lines, right)
    imgui.PushFont(imgui.GetFont(), imgui.GetFontSize() * SMALL_FONT);
    for _, line in ipairs(lines) do
        imgui.TextColored(COLOR.muted, line.label);
        if (right) then
            imgui.SameLine(right - theme.text_width(line.count));
        else
            imgui.SameLine(0, BAG_GAP);
        end
        imgui.TextColored(line.color, line.count);
    end
    imgui.PopFont();
end

local function draw_gil(size, height)
    local line = height or size;
    local x, y = theme.cursor();
    local draw = imgui.GetWindowDrawList();
    local gil  = icon.gil();
    y = math.floor(y + (line - size) / 2);
    if (gil) then
        draw:AddImage(gil, { x, y }, { x + size, y + size }, { 0, 0 }, { 1, 1 }, theme.u32({ 1, 1, 1, 1 }));
    else
        draw_coin(draw, x, y, size);
    end
    imgui.Dummy({ size, line });
end

display.gil = draw_gil;

local function draw_balance(lg, balance)
    local size = imgui.GetFontSize() * BALANCE_FONT;
    draw_gil(size);
    imgui.SameLine(0, ICON_GAP);
    imgui.PushFont(imgui.GetFont(), size);
    if (balance) then
        imgui.TextColored(COLOR.text, records.commas(balance));
    else
        imgui.TextColored(COLOR.muted, '---');
    end
    imgui.PopFont();
end

local function draw_each(balance, others, min_width)
    local rows  = { { name = records.display_name(records.owner), gil = balance, mine = true } };
    local total = balance or 0;
    for _, other in ipairs(others) do
        rows[#rows + 1] = other;
        total = total + other.gil;
    end
    local name_w = theme.text_width('Total');
    local gil_w  = theme.text_width(records.commas(total));
    for _, row in ipairs(rows) do
        name_w = math.max(name_w, theme.text_width(row.name));
        gil_w  = math.max(gil_w, theme.text_width(row.gil and records.commas(row.gil) or '---'));
    end
    local size  = imgui.GetFontSize();
    local right = imgui.GetCursorPosX() + math.max(name_w + GIL_GAP + size + ICON_GAP + gil_w, min_width);
    for _, row in ipairs(rows) do
        local amount = row.gil and records.commas(row.gil) or '---';
        local color  = row.mine and COLOR.text or COLOR.secondary;
        imgui.TextColored(color, row.name);
        imgui.SameLine(right - theme.text_width(amount));
        imgui.TextColored(color, amount);
    end
    imgui.Separator();
    local amount = records.commas(total);
    imgui.TextColored(COLOR.peach, 'Total');
    imgui.SameLine(right - theme.text_width(amount) - ICON_GAP - size);
    draw_gil(size);
    imgui.SameLine(0, ICON_GAP);
    imgui.TextColored(COLOR.text, amount);
    return right;
end

local function handle_click(lg, each)
    local hovered = imgui.IsWindowHovered();
    if (hovered and imgui.IsMouseClicked(0)) then
        local mx, my = theme.mouse();
        lg.press = { mx, my };
    end
    if (lg.press and imgui.IsMouseReleased(0)) then
        local mx, my = theme.mouse();
        if (hovered and math.abs(mx - lg.press[1]) <= CLICK_SLOP and math.abs(my - lg.press[2]) <= CLICK_SLOP) then
            lg.show_ledger = not lg.show_ledger;
        end
        lg.press = nil;
    end
    if (not hovered or imgui.IsMouseDown(0) or imgui.IsPopupOpen('##lg_context')) then
        lg.hover_since = nil;
        return;
    end
    lg.hover_since = lg.hover_since or os.clock();
    if (os.clock() - lg.hover_since >= TIP_DELAY) then
        local tip = (lg.show_ledger and 'Click to close the ledger' or 'Click for the gil ledger') .. '\nRight-click for theme and options';
        if (each) then
            tip = tip .. '\nOther characters show their gil from when you last played them';
        end
        imgui.SetTooltip(tip);
    end
end

local function draw_context_menu(lg)
    if (not imgui.BeginPopupContextWindow('##lg_context')) then
        return;
    end
    if (imgui.MenuItem('Gil Ledger', nil, lg.show_ledger)) then
        lg.show_ledger = not lg.show_ledger;
    end
    if (imgui.MenuItem('Gil Amount', nil, lg.settings.show_gil, lg.settings.bag_counts or not lg.settings.show_gil)) then
        toggle(lg, 'show_gil');
    end
    if (imgui.MenuItem('Gil Per Character', nil, lg.settings.gil_each, lg.settings.show_gil)) then
        toggle(lg, 'gil_each');
    end
    if (imgui.MenuItem('Bag Counts', nil, lg.settings.bag_counts, lg.settings.show_gil or not lg.settings.bag_counts)) then
        toggle(lg, 'bag_counts');
    end
    if (imgui.MenuItem('Lock Window', nil, lg.settings.locked)) then
        toggle(lg, 'locked');
    end
    if (imgui.BeginMenu('Theme')) then
        for _, name in ipairs(theme.THEME_ORDER) do
            if (imgui.MenuItem(theme.THEMES[name].label, nil, lg.settings.theme == name)) then
                lg.settings.theme = theme.use(name);
                settings.save();
            end
        end
        imgui.EndMenu();
    end
    if (imgui.MenuItem('Reset Position')) then
        lg.reset_position = true;
    end
    if (imgui.MenuItem('Hide')) then
        lg.settings.visible = false;
        settings.save();
        print(chat.header(addon.name):append(chat.message('Hidden. Type /ledger to show it again.')));
    end
    imgui.Separator();
    imgui.TextColored(COLOR.muted, 'Scale');
    slider(lg, 'menu', 'scale', 0.5, 3.0, '%.2f', 0.05, MENU_WIDTH, false);
    imgui.TextColored(COLOR.muted, 'Opacity');
    slider(lg, 'menu', 'alpha', 0.0, 1.0, '%.2f', 0.01, MENU_WIDTH, true);
    imgui.EndPopup();
end

local function remember_position(lg)
    local x, y = theme.window_position();
    if (not x or not y) then
        return;
    end
    x = math.floor(x);
    y = math.floor(y);
    if (x == lg.settings.x and y == lg.settings.y) then
        return;
    end
    lg.settings.x = x;
    lg.settings.y = y;
    if (os.clock() - lg.last_pos_save > 1.0) then
        lg.last_pos_save = os.clock();
        settings.save();
    end
end

function display.render(lg, balance)
    local scale = lg.settings.scale;
    local flags = bit.bor(ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoTitleBar, ImGuiWindowFlags_NoCollapse, ImGuiWindowFlags_NoScrollbar, ImGuiWindowFlags_NoScrollWithMouse, ImGuiWindowFlags_NoFocusOnAppearing, ImGuiWindowFlags_NoNav, ImGuiWindowFlags_NoSavedSettings);
    if (lg.settings.locked) then
        flags = bit.bor(flags, ImGuiWindowFlags_NoMove);
    end

    local color_count, var_count = theme.push(lg.settings.alpha);
    if (lg.place_display) then
        imgui.SetNextWindowPos({ lg.settings.x, lg.settings.y }, ImGuiCond_Always);
        lg.place_display = false;
    end

    if (imgui.Begin('Ledger##ledger_display', { true }, flags)) then
        imgui.PushFont(imgui.GetFont(), imgui.GetFontSize() * scale);
        theme.decorate(scale, nil, 0, nil);
        local others = lg.settings.show_gil and lg.settings.gil_each and records.other_gil(os.clock()) or {};
        local lines  = lg.settings.bag_counts and bag_lines() or {};
        local right  = nil;
        if (#others > 0) then
            right = draw_each(balance, others, bag_width(lines));
        elseif (lg.settings.show_gil) then
            draw_balance(lg, balance);
        end
        draw_bag_counts(lines, right);
        handle_click(lg, #others > 0);
        draw_context_menu(lg);
        remember_position(lg);
        imgui.PopFont();
    end
    imgui.End();
    imgui.PopStyleVar(var_count);
    imgui.PopStyleColor(color_count);
end

return display;
