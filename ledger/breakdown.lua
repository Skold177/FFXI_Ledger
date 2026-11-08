require('common');

local chat     = require('chat');
local imgui    = require('imgui');
local settings = require('settings');
local theme    = require('theme');
local records  = require('records');
local names    = require('names');
local display  = require('display');
local bags     = require('bags');
local mover    = require('mover');
local icons    = require('icons');

local COLOR = theme.COLOR;

local MIN_WIDTH     = 470;
local MIN_HEIGHT    = 380;
local SMALL_FONT    = 0.85;
local TILE_HEIGHT   = 46;
local CHART_HEIGHT  = 84;
local MIN_BAR       = 4;
local DAY           = 86400;
local SLOT          = 36;
local ICON          = 32;
local SLOT_GAP      = 3;
local MIN_COLS      = 5;
local MAX_COLS      = 10;
local RESULT_ROWS   = 8;
local COUNT_FONT    = 0.78;
local CALENDAR_CELL = 30;
local CALENDAR_GAP  = 3;
local CALENDAR_DAYS = 42;
local OPTION_WIDTH  = 160;
local PAIR_GAP      = 14;
local DRAG_SLOP     = 4;
local HISTORY_MAX   = 20;

local breakdown = T{};

breakdown.VIEWS = T{
    T{ key = 'overview', label = 'Overview' },
    T{ key = 'days',     label = 'Days' },
    T{ key = 'sources',  label = 'Top Sources' },
    T{ key = 'ledger',   label = 'Ledger' },
    T{ key = 'bags',     label = 'Bags' },
};

local VIEWS = breakdown.VIEWS;

local CATEGORY_ITEMS = { { key = false, label = 'All categories' } };
for _, category in ipairs(records.CATEGORIES) do
    CATEGORY_ITEMS[#CATEGORY_ITEMS + 1] = { key = category.key, label = category.label };
end

local SIDES = {
    { key = 'all',  label = 'Gains and spending' },
    { key = 'gain', label = 'Gains only' },
    { key = 'loss', label = 'Spending only' },
};

local ORDERS = {
    { key = 'new', label = 'Newest first' },
    { key = 'old', label = 'Oldest first' },
    { key = 'big', label = 'Largest first' },
};

local HIDEABLE = {
    { column = 2, setting = 'col_category' },
    { column = 4, setting = 'col_zone' },
    { column = 5, setting = 'col_balance' },
};

local WEEKDAYS = { 'Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa' };

local function money_color(value)
    if (value > 0) then
        return COLOR.gain;
    elseif (value < 0) then
        return COLOR.loss;
    end
    return COLOR.muted;
end

local function plural(count, one, many)
    return ('%s %s'):fmt(records.commas(count), count == 1 and one or many);
end

local function right_text(color, text)
    local avail = theme.available();
    local width = theme.text_width(text);
    if (avail > width) then
        imgui.SetCursorPosX(imgui.GetCursorPosX() + avail - width);
    end
    imgui.TextColored(color, text);
end

local function combo(id, items, current, width)
    local preview = items[1].label;
    for _, item in ipairs(items) do
        if (item.key == current) then
            preview = item.label;
        end
    end
    imgui.SetNextItemWidth(width);
    local chosen = nil;
    if (imgui.BeginCombo(id, preview)) then
        for _, item in ipairs(items) do
            if (imgui.Selectable(item.label, item.key == current)) then
                chosen = item.key;
            end
        end
        imgui.EndCombo();
    end
    return chosen;
end

local function range_of(lg)
    if (lg.settings.period ~= 'range') then
        return 0, 0;
    end
    return lg.settings.range_from, lg.settings.range_to;
end

local function pick_range(lg, from, to)
    lg.settings.range_from = math.min(from, to);
    lg.settings.range_to   = math.max(from, to);
    lg.settings.period     = 'range';
    settings.save();
end

local function remember_place(lg)
    local history = lg.history;
    history[#history + 1] = { view = lg.settings.view, period = lg.settings.period, from = lg.settings.range_from, to = lg.settings.range_to, category = lg.category };
    if (#history > HISTORY_MAX) then
        table.remove(history, 1);
    end
end

local function go_back(lg)
    local place = table.remove(lg.history);
    if (place == nil) then
        return;
    end
    lg.settings.view       = place.view;
    lg.settings.period     = place.period;
    lg.settings.range_from = place.from;
    lg.settings.range_to   = place.to;
    lg.category            = place.category;
    settings.save();
end

local function show_day(lg, day)
    remember_place(lg);
    pick_range(lg, day, day);
    lg.settings.view = 'ledger';
    settings.save();
end

local function day_tooltip(key, row)
    local title = records.day_label(key, '%A %m/%d/%Y');
    if (row == nil or row.entries == 0) then
        return title .. '\nNo gil moved';
    end
    return ('%s\nEarned %s\nSpent %s\nNet %s\n%s'):fmt(title, records.commas(row.earned), records.commas(row.spent), records.signed(row.earned - row.spent), plural(row.entries, 'entry', 'entries'));
end

local function clipped(state, count, view, key, draw_row)
    local height = state.row or (imgui.GetTextLineHeight() + 6);
    local scroll = 0;
    if (state.key == key) then
        scroll = imgui.GetScrollY() or 0;
    else
        state.key = key;
        imgui.SetScrollY(0);
    end
    local first = math.max(0, math.min(count - 1, math.floor(scroll / height)));
    local shown = math.min(count - first, math.ceil(view / height) + 2);
    if (first > 0) then
        if (first % 2 == 0) then
            imgui.TableNextRow(ImGuiTableRowFlags_None, (first - 1) * height);
            imgui.TableNextRow(ImGuiTableRowFlags_None, height);
        else
            imgui.TableNextRow(ImGuiTableRowFlags_None, first * height);
        end
    end
    local top, bottom = nil, nil;
    for index = first + 1, first + shown do
        imgui.TableNextRow();
        imgui.TableNextColumn();
        local y = imgui.GetCursorPosY();
        top    = top or y;
        bottom = y;
        draw_row(index);
    end
    if (shown >= 3 and top and bottom > top) then
        state.row = (bottom - top) / (shown - 1);
    end
    local rest = count - first - shown;
    if (rest > 0) then
        imgui.TableNextRow(ImGuiTableRowFlags_None, rest * height);
    end
end

local function draw_who(lg)
    local mine = records.display_name(records.owner);
    if (#records.roster == 0) then
        imgui.TextColored(COLOR.muted, mine);
        return;
    end
    local items = { { key = 'me', label = mine } };
    for _, owner in ipairs(records.roster) do
        items[#items + 1] = { key = owner, label = records.display_name(owner) };
    end
    items[#items + 1] = { key = 'all', label = 'All characters' };
    local widest = 0;
    for _, item in ipairs(items) do
        widest = math.max(widest, theme.text_width(item.label));
    end
    local chosen = combo('##lg_who', items, records.who, widest + imgui.GetFrameHeight() + theme.FRAME_X * 2);
    if (imgui.IsItemHovered()) then
        imgui.SetTooltip('Pick a character, or All characters to add them together');
    end
    if (chosen) then
        lg.settings.who = chosen;
        settings.save();
    end
end

local function draw_header(lg, width, scale)
    local close = 'Close';
    local close_width = theme.text_width(close) + theme.FRAME_X * 2;
    imgui.AlignTextToFramePadding();
    if (not theme.framed) then
        imgui.TextColored(COLOR.peach, 'GIL LEDGER');
        imgui.SameLine();
    end
    if (records.owner) then
        draw_who(lg);
    end
    local balance = records.balance_for(records.who, os.clock());
    if (balance) then
        imgui.SameLine(0, 12);
        display.gil(imgui.GetFontSize(), imgui.GetFrameHeight());
        imgui.SameLine(0, 6);
        imgui.TextColored(COLOR.text, records.commas(balance));
        if (records.who ~= 'me' and imgui.IsItemHovered()) then
            imgui.SetTooltip(records.who == 'all' and 'Gil on all your characters together\nOther characters count the gil they had when you last played them' or 'Gil from when you last played this character');
        end
    end
    local back_width = theme.text_width('Back') + theme.FRAME_X * 2;
    local stuck      = #lg.history == 0;
    imgui.SameLine(theme.PADDING + width - close_width - back_width - 6);
    if (stuck) then
        imgui.BeginDisabled(true);
    end
    if (theme.toggle_button('Back##lg_back', false, back_width)) then
        go_back(lg);
    end
    if (stuck) then
        imgui.EndDisabled();
    end
    imgui.SameLine(theme.PADDING + width - close_width);
    if (theme.toggle_button('Close##lg_close', false, close_width)) then
        lg.show_ledger = false;
    end
end

local function open_calendar(lg, now)
    local today = records.day_key(now);
    remember_place(lg);
    if (lg.settings.range_from == 0 or lg.settings.range_to == 0) then
        lg.settings.range_from = today;
        lg.settings.range_to   = today;
    end
    lg.settings.period = 'range';
    lg.cal_month = math.floor(lg.settings.range_to / 100);
    lg.cal_pick  = nil;
    settings.save();
    imgui.OpenPopup('##lg_calendar');
end

local function draw_periods(lg, width, now)
    local labels = T{};
    local states = T{};
    for _, period in ipairs(records.PERIODS) do
        local label = period.label;
        if (period.key == 'range' and lg.settings.period == 'range') then
            label = records.range_label(lg.settings.range_from, lg.settings.range_to, now);
        end
        labels:append(label);
        states:append(lg.settings.period == period.key);
    end
    local clicked = theme.button_row('lg_period', labels, states, width);
    if (not clicked) then
        return;
    end
    if (records.PERIODS[clicked].key == 'range') then
        open_calendar(lg, now);
        return;
    end
    if (records.PERIODS[clicked].key ~= lg.settings.period) then
        remember_place(lg);
    end
    lg.settings.period = records.PERIODS[clicked].key;
    settings.save();
end

local function draw_span(lg, stats, width, now)
    local from, to = range_of(lg);
    imgui.AlignTextToFramePadding();
    imgui.TextColored(COLOR.muted, records.span_label(lg.settings.period, now, from, to, stats.oldest));
    if (lg.settings.period ~= 'session') then
        return;
    end
    local label  = 'New Session';
    local button = theme.text_width(label) + theme.FRAME_X * 2;
    imgui.SameLine(theme.PADDING + width - button);
    if (theme.toggle_button(label .. '##lg_new_session', false, button)) then
        records.restart(now);
    end
    if (imgui.IsItemHovered()) then
        imgui.SetTooltip('Start the session over from now for a fresh gil per hour.\nNothing is removed from the ledger.');
    end
end

local function month_step(month, step)
    local year  = math.floor(month / 100);
    local index = month % 100 - 1 + step;
    year  = year + math.floor(index / 12);
    index = index % 12;
    return year * 100 + index + 1;
end

local function calendar_colors(key, row, largest, from, to)
    if (key == from or key == to) then
        return COLOR.royal, COLOR.hover, COLOR.text;
    end
    if (key > from and key < to) then
        return theme.fade(COLOR.royal, 0.45), COLOR.hover, COLOR.text;
    end
    if (row and row.entries > 0) then
        local net  = row.earned - row.spent;
        local base = net >= 0 and COLOR.gain or COLOR.loss;
        return theme.fade(base, 0.18 + 0.5 * math.min(1, math.abs(net) / largest)), COLOR.tint, COLOR.text;
    end
    return COLOR.cell, COLOR.tint, COLOR.muted;
end

local function draw_calendar(lg, scale, now)
    if (not imgui.BeginPopup('##lg_calendar')) then
        lg.cal_pick = nil;
        return;
    end
    local today  = records.day_key(now);
    local month  = lg.cal_month or math.floor(today / 100);
    local year   = math.floor(month / 100);
    local number = month % 100;
    local first  = os.time({ year = year, month = number, day = 1, hour = 12 });
    local offset = os.date('*t', first).wday - 1;
    local length = os.date('*t', os.time({ year = year, month = number + 1, day = 0, hour = 12 })).day;
    local cell   = math.floor(CALENDAR_CELL * scale);
    local gap    = math.floor(CALENDAR_GAP * scale);
    local width  = cell * 7 + gap * 6;
    local totals = records.day_totals();
    local x0     = imgui.GetCursorPosX();

    if (imgui.ArrowButton('##lg_cal_prev', ImGuiDir_Left)) then
        lg.cal_month = month_step(month, -1);
    end
    local title = os.date('%B %Y', first);
    imgui.SameLine(x0 + (width - theme.text_width(title)) / 2);
    imgui.TextColored(COLOR.peach, title);
    imgui.SameLine(x0 + width - imgui.GetFrameHeight());
    if (imgui.ArrowButton('##lg_cal_next', ImGuiDir_Right)) then
        lg.cal_month = month_step(month, 1);
    end

    for column, name in ipairs(WEEKDAYS) do
        local x = x0 + (column - 1) * (cell + gap) + (cell - theme.text_width(name)) / 2;
        if (column > 1) then
            imgui.SameLine(x);
        else
            imgui.SetCursorPosX(x);
        end
        imgui.TextColored(COLOR.muted, name);
    end

    local largest = 1;
    for day = 1, length do
        local row = totals[year * 10000 + number * 100 + day];
        if (row) then
            largest = math.max(largest, math.abs(row.earned - row.spent));
        end
    end

    local from, to = lg.settings.range_from, lg.settings.range_to;
    imgui.PushStyleVar(ImGuiStyleVar_ItemSpacing, { gap, gap });
    for slot = 0, CALENDAR_DAYS - 1 do
        if (slot % 7 ~= 0) then
            imgui.SameLine();
        end
        local day = slot - offset + 1;
        if (day < 1 or day > length) then
            imgui.Dummy({ cell, cell });
        else
            local key = year * 10000 + number * 100 + day;
            local row = totals[key];
            local fill, hover, text = calendar_colors(key, row, largest, from, to);
            if (key == today) then
                text = COLOR.ember;
            elseif (key > today) then
                text = COLOR.faint;
            end
            imgui.PushStyleColor(ImGuiCol_Button, fill);
            imgui.PushStyleColor(ImGuiCol_ButtonHovered, hover);
            imgui.PushStyleColor(ImGuiCol_ButtonActive, COLOR.royal);
            imgui.PushStyleColor(ImGuiCol_Text, text);
            local clicked = imgui.Button(('%d##lg_day_%d'):fmt(day, key), { cell, cell });
            imgui.PopStyleColor(4);
            if (imgui.IsItemHovered()) then
                imgui.SetTooltip(day_tooltip(key, row));
            end
            if (clicked) then
                if (lg.cal_pick == nil) then
                    lg.cal_pick = key;
                    pick_range(lg, key, key);
                else
                    pick_range(lg, lg.cal_pick, key);
                    lg.cal_pick = nil;
                end
                from, to = lg.settings.range_from, lg.settings.range_to;
            end
        end
    end
    imgui.PopStyleVar();

    theme.caption(lg.cal_pick and 'Now click the last day' or 'Click a day, or two days for a range');
    local month_start = math.floor(today / 100) * 100 + 1;
    local quick = theme.button_row('lg_cal_quick', { 'Today', 'This Month', 'Last Month' }, { false, false, false }, width);
    if (quick == 1) then
        pick_range(lg, today, today);
    elseif (quick == 2) then
        pick_range(lg, month_start, today);
    elseif (quick == 3) then
        pick_range(lg, month_step(math.floor(today / 100), -1) * 100 + 1, records.shift(month_start, -1));
    end
    if (quick) then
        lg.cal_pick  = nil;
        lg.cal_month = math.floor(lg.settings.range_to / 100);
    end
    if (theme.toggle_button('Done##lg_cal_done', false, width)) then
        imgui.CloseCurrentPopup();
    end
    imgui.EndPopup();
end

local function draw_views(lg, width)
    local labels = T{};
    local states = T{};
    for _, view in ipairs(VIEWS) do
        labels:append(view.label);
        states:append(lg.settings.view == view.key);
    end
    local clicked = theme.button_row('lg_view', labels, states, width);
    if (clicked and VIEWS[clicked].key ~= lg.settings.view) then
        remember_place(lg);
        lg.settings.view = VIEWS[clicked].key;
        settings.save();
    end
end

local function fourth_tile(lg, stats, now)
    local period = lg.settings.period;
    local net    = stats.earned - stats.spent;
    if (period == 'session') then
        return 'Per Hour', records.short(display.rate(net, now - records.session)), money_color(net);
    elseif (period == 'today') then
        return 'Entries', records.commas(stats.count), COLOR.text;
    end
    local days = 7;
    if (period == 'month') then
        days = 30;
    elseif (period == 'all') then
        days = math.max(1, math.ceil((now - (stats.oldest or now)) / DAY));
    elseif (period == 'range') then
        local from, to = range_of(lg);
        days = math.max(1, math.floor((records.day_time(records.shift(to, 1)) - records.day_time(from)) / DAY + 0.5));
        if (days == 1) then
            return 'Entries', records.commas(stats.count), COLOR.text;
        end
    end
    local average = math.floor(net / days);
    return 'Per Day', records.short(average), money_color(average);
end

local function draw_tiles(lg, stats, width, scale, now)
    local net    = stats.earned - stats.spent;
    local label, value, color = fourth_tile(lg, stats, now);
    local tiles  = T{
        T{ 'Earned', records.commas(stats.earned), stats.earned > 0 and COLOR.gain or COLOR.muted },
        T{ 'Spent',  records.commas(stats.spent),  stats.spent > 0 and COLOR.loss or COLOR.muted },
        T{ 'Net',    records.signed(net),          money_color(net) },
        T{ label,    value,                       color },
    };
    local gap    = 6 * scale;
    local height = TILE_HEIGHT * scale;
    local tile   = (width - gap * 3) / 4;
    local x, y   = theme.cursor();
    local draw   = imgui.GetWindowDrawList();
    local font   = imgui.GetFontSize();
    for index, entry in ipairs(tiles) do
        local x0 = x + (index - 1) * (tile + gap);
        draw:AddRectFilled({ x0, y }, { x0 + tile, y + height }, theme.u32(COLOR.cell), theme.style.cell);
        draw:AddRect({ x0, y }, { x0 + tile, y + height }, theme.u32(COLOR.subtle), theme.style.cell);
        imgui.PushFont(imgui.GetFont(), font * SMALL_FONT);
        draw:AddText({ math.floor(x0 + 8 * scale), math.floor(y + 6 * scale) }, theme.u32(COLOR.muted), entry[1]);
        imgui.PopFont();
        draw:AddText({ math.floor(x0 + 8 * scale), math.floor(y + height - font - 6 * scale) }, theme.u32(entry[3]), entry[2]);
    end
    imgui.Dummy({ width, height });
end

local function bar_row(id, label, label_w, value_text, value_color, parts, scale, width)
    local height  = imgui.GetFrameHeight();
    local clicked = imgui.Selectable(id, false, 0, { width, height });
    local x0, y0  = imgui.GetItemRectMin();
    local draw    = imgui.GetWindowDrawList();
    local font    = imgui.GetFontSize();
    local text_y  = math.floor(y0 + (height - font) / 2);
    local value_w = 110 * scale;
    draw:PushClipRect({ x0, y0 }, { x0 + label_w - 6 * scale, y0 + height }, true);
    draw:AddText({ math.floor(x0 + 6 * scale), text_y }, theme.u32(COLOR.secondary), label);
    draw:PopClipRect();

    local bar_x0 = x0 + label_w;
    local bar_x1 = x0 + width - value_w;
    local bar_y0 = y0 + height * 0.3;
    local bar_y1 = y0 + height * 0.7;
    if (bar_x1 > bar_x0) then
        draw:AddRectFilled({ bar_x0, bar_y0 }, { bar_x1, bar_y1 }, theme.u32(COLOR.lane), 2);
        local cursor = bar_x0;
        for _, part in ipairs(parts) do
            local length = (bar_x1 - bar_x0) * part[1];
            if (length >= 1) then
                draw:AddRectFilled({ cursor, bar_y0 }, { cursor + length, bar_y1 }, theme.u32(part[2]), 2);
                cursor = cursor + length;
            end
        end
    end
    draw:AddText({ math.floor(x0 + width - theme.text_width(value_text) - 6 * scale), text_y }, theme.u32(value_color), value_text);
    return clicked;
end

local function draw_overview(lg, stats, width, scale)
    if (stats.count == 0) then
        theme.caption('No gil has moved in this period yet.');
        return;
    end
    local largest = 1;
    for _, cat in pairs(stats.cats) do
        largest = math.max(largest, cat.earned + cat.spent);
    end
    theme.caption('BY CATEGORY  (click a row to see its entries)');
    for _, category in ipairs(records.CATEGORIES) do
        local cat = stats.cats[category.key];
        if (cat) then
            local net   = cat.earned - cat.spent;
            local parts = T{
                T{ cat.earned / largest, COLOR.gain },
                T{ cat.spent / largest, COLOR.loss },
            };
            if (bar_row(('##lg_cat_%s'):fmt(category.key), category.label, 150 * scale, records.signed(net), money_color(net), parts, scale, width)) then
                remember_place(lg);
                lg.category       = category.key;
                lg.settings.view  = 'ledger';
                settings.save();
            end
            if (imgui.IsItemHovered()) then
                imgui.SetTooltip(('%s\nEarned %s\nSpent %s\n%s'):fmt(category.label, records.commas(cat.earned), records.commas(cat.spent), plural(cat.count, 'entry', 'entries')));
            end
        end
    end
    if (stats.moved > 0) then
        imgui.Spacing();
        theme.caption(('%s between your characters left out'):fmt(plural(stats.moved, 'transfer', 'transfers')));
    end
end

local function chart_days(lg, rows, now, width, scale)
    local today = records.day_key(now);
    local first, last;
    if (lg.settings.period == 'range') then
        first, last = range_of(lg);
    else
        local since = records.span(lg.settings.period, now);
        first = since > 0 and records.day_key(since) or rows[#rows].day;
        last  = today;
    end
    local limit = math.max(2, math.floor(width / (MIN_BAR * scale + 1)));
    local id    = ('%d|%d|%d'):fmt(first, last, limit);
    if (lg.chart and lg.chart.id == id) then
        return lg.chart.keys;
    end
    local keys = {};
    local key  = last;
    while (key >= first and #keys < limit) do
        table.insert(keys, 1, key);
        key = records.shift(key, -1);
    end
    lg.chart = { id = id, keys = keys };
    return keys;
end

local function draw_chart(lg, keys, map, width, scale)
    local height  = CHART_HEIGHT * scale;
    local x, y    = theme.cursor();
    local draw    = imgui.GetWindowDrawList();
    local count   = #keys;
    local slot    = width / count;
    local bar     = math.max(1, slot - math.max(1, slot * 0.25));
    local mid     = math.floor(y + height / 2);
    local reach   = height / 2 - 2;
    local largest = 1;
    for _, key in ipairs(keys) do
        local row = map[key];
        if (row) then
            largest = math.max(largest, row.earned, row.spent);
        end
    end

    draw:AddRectFilled({ x, y }, { x + width, y + height }, theme.u32(COLOR.cell), theme.style.cell);
    draw:AddLine({ x, mid }, { x + width, mid }, theme.u32(COLOR.border), 1);
    for index, key in ipairs(keys) do
        local row = map[key];
        if (row) then
            local x0   = x + (index - 1) * slot + (slot - bar) / 2;
            local up   = reach * row.earned / largest;
            local down = reach * row.spent / largest;
            if (up >= 1) then
                draw:AddRectFilled({ x0, mid - up }, { x0 + bar, mid }, theme.u32(COLOR.gain));
            end
            if (down >= 1) then
                draw:AddRectFilled({ x0, mid }, { x0 + bar, mid + down }, theme.u32(COLOR.loss));
            end
        end
    end

    local clicked = imgui.InvisibleButton('##lg_chart', { width, height });
    if (imgui.IsItemHovered()) then
        local mx    = theme.mouse();
        local index = math.max(1, math.min(count, math.floor((mx - x) / slot) + 1));
        local key   = keys[index];
        local x0    = x + (index - 1) * slot;
        draw:AddRectFilled({ x0, y }, { x0 + slot, y + height }, theme.u32(COLOR.tint));
        imgui.SetTooltip(day_tooltip(key, map[key]) .. '\nClick to see this day');
        if (clicked) then
            show_day(lg, key);
        end
    end

    imgui.PushFont(imgui.GetFont(), imgui.GetFontSize() * SMALL_FONT);
    local font = imgui.GetFontSize();
    draw:AddText({ math.floor(x + 4 * scale), math.floor(y + 2 * scale) }, theme.u32(COLOR.muted), records.short(largest));
    draw:AddText({ math.floor(x + 4 * scale), math.floor(y + height - font - 2 * scale) }, theme.u32(COLOR.muted), records.short(-largest));
    imgui.TextColored(COLOR.muted, records.day_label(keys[1], '%m/%d'));
    imgui.SameLine();
    right_text(COLOR.muted, records.day_label(keys[count], '%m/%d'));
    imgui.PopFont();
end

local function draw_days(lg, width, scale, now)
    local from, to   = range_of(lg);
    local rows, map  = records.days(lg.settings.period, now, from, to);
    if (#rows == 0) then
        theme.caption('No gil has moved in this period yet.');
        return;
    end
    local keys = chart_days(lg, rows, now, width, scale);
    if (#keys > 1) then
        draw_chart(lg, keys, map, width, scale);
    end
    theme.caption(('%s with gil moving  (click a day to see its entries)'):fmt(plural(#rows, 'day', 'days')));

    local _, height = theme.available();
    local flags = bit.bor(ImGuiTableFlags_ScrollY, ImGuiTableFlags_RowBg, ImGuiTableFlags_BordersInnerH, ImGuiTableFlags_SizingFixedFit, ImGuiTableFlags_PadOuterX);
    if (not imgui.BeginTable('##lg_days', 6, flags, { 0, 0 })) then
        return;
    end
    local number = theme.text_width('+00,000,000');
    imgui.TableSetupScrollFreeze(0, 1);
    imgui.TableSetupColumn('Day', ImGuiTableColumnFlags_WidthStretch);
    imgui.TableSetupColumn('Earned', ImGuiTableColumnFlags_WidthFixed, number);
    imgui.TableSetupColumn('Spent', ImGuiTableColumnFlags_WidthFixed, number);
    imgui.TableSetupColumn('Net', ImGuiTableColumnFlags_WidthFixed, number);
    imgui.TableSetupColumn('Entries', ImGuiTableColumnFlags_WidthFixed, theme.text_width('Entries'));
    imgui.TableSetupColumn('Balance', ImGuiTableColumnFlags_WidthFixed, theme.text_width('000,000,000'));
    imgui.TableHeadersRow();
    clipped(lg.clip.days, #rows, height, ('%s|%s|%d|%d'):fmt(records.who, lg.settings.period, from, to), function (index)
        local row = rows[index];
        local net = row.earned - row.spent;
        if (imgui.Selectable(('%s##lg_day_row_%d'):fmt(records.day_label(row.day, '%a %m/%d/%y'), row.day), false, ImGuiSelectableFlags_SpanAllColumns)) then
            show_day(lg, row.day);
        end
        if (imgui.IsItemHovered()) then
            imgui.SetTooltip(day_tooltip(row.day, row) .. '\nClick to see its entries');
        end
        imgui.TableNextColumn();
        right_text(row.earned > 0 and COLOR.gain or COLOR.muted, records.commas(row.earned));
        imgui.TableNextColumn();
        right_text(row.spent > 0 and COLOR.loss or COLOR.muted, records.commas(row.spent));
        imgui.TableNextColumn();
        right_text(money_color(net), records.signed(net));
        imgui.TableNextColumn();
        right_text(COLOR.muted, records.commas(row.entries));
        imgui.TableNextColumn();
        right_text(COLOR.muted, row.close and records.commas(row.close) or '');
    end);
    imgui.EndTable();
end

local function draw_top(title, rows, color, sign, width, scale)
    theme.caption(title);
    if (#rows == 0) then
        imgui.TextColored(COLOR.faint, 'Nothing yet');
        return;
    end
    local largest = math.max(1, rows[1].total);
    for index, row in ipairs(rows) do
        local label = row.label;
        if (row.cat == 'mob' and row.count > 1) then
            label = ('%s (%d)'):fmt(label, row.count);
        end
        bar_row(('##lg_top_%s_%d'):fmt(title, index), label, 210 * scale, sign .. records.commas(row.total), color, T{ T{ row.total / largest, theme.fade(color, 0.7) } }, scale, width);
        if (imgui.IsItemHovered()) then
            imgui.SetTooltip(('%s\n%s\n%s'):fmt(row.label, records.LABEL[row.cat] or row.cat, plural(row.count, 'entry', 'entries')));
        end
    end
end

local function draw_sources(stats, width, scale)
    draw_top('TOP EARNINGS', stats.income, COLOR.gain, '+', width, scale);
    imgui.Spacing();
    draw_top('TOP SPENDING', stats.spend, COLOR.loss, '-', width, scale);
end

local function draw_filters(lg, width)
    local third = (width - 16) / 3;
    local category = combo('##lg_filter', CATEGORY_ITEMS, lg.category, third);
    if (category ~= nil) then
        lg.category = category;
    end
    imgui.SameLine();
    local side = combo('##lg_side', SIDES, lg.side, third);
    if (side) then
        lg.side = side;
    end
    imgui.SameLine();
    local order = combo('##lg_order', ORDERS, lg.order, third);
    if (order) then
        lg.order = order;
    end
    imgui.SetNextItemWidth(width);
    imgui.InputTextWithHint('##lg_search', 'Search details or zone', lg.search, 64);
end

local function entry_tooltip(entry)
    local lines = { records.describe(entry), records.LABEL[entry.cat] or entry.cat };
    if (records.who == 'all' and entry.char) then
        lines[#lines + 1] = entry.char;
    end
    if (entry.item and entry.qty and entry.qty > 1) then
        lines[#lines + 1] = ('%s gil each (x%d)'):fmt(records.commas(math.floor(math.abs(entry.amount) / entry.qty + 0.5)), entry.qty);
    end
    if (entry.balance) then
        lines[#lines + 1] = ('Balance %s -> %s'):fmt(records.commas(entry.balance - entry.amount), records.commas(entry.balance));
    end
    if (records.who == 'all' and entry.total) then
        lines[#lines + 1] = ('All characters %s'):fmt(records.commas(entry.total));
    end
    local zone = names.zone(entry.zone);
    if (zone ~= '') then
        lines[#lines + 1] = zone;
    end
    lines[#lines + 1] = os.date('%A %Y-%m-%d %H:%M:%S', entry.time);
    return table.concat(lines, '\n');
end

local function draw_item(item)
    if (item.header) then
        local net = item.earned - item.spent;
        imgui.TableSetBgColor(ImGuiTableBgTarget_RowBg1, theme.u32(COLOR.surface2));
        imgui.TextColored(COLOR.peach, records.day_label(item.day));
        imgui.TableNextColumn();
        right_text(money_color(net), records.signed(net));
        imgui.TableNextColumn();
        imgui.TextColored(COLOR.muted, plural(item.entries, 'entry', 'entries'));
        imgui.TableNextColumn();
        if (item.earned > 0) then
            imgui.TextColored(COLOR.gain, ('+%s earned'):fmt(records.commas(item.earned)));
            if (item.spent > 0) then
                imgui.SameLine(0, 12);
            end
        end
        if (item.spent > 0) then
            imgui.TextColored(COLOR.loss, ('-%s spent'):fmt(records.commas(item.spent)));
        end
        imgui.TableNextColumn();
        imgui.TableNextColumn();
        right_text(COLOR.muted, item.close and records.commas(item.close) or '');
        return;
    end
    imgui.TextColored(COLOR.muted, os.date('%m/%d %H:%M', item.time));
    imgui.TableNextColumn();
    right_text(money_color(item.amount), records.signed(item.amount));
    imgui.TableNextColumn();
    imgui.TextColored(COLOR.muted, records.LABEL[item.cat] or item.cat);
    imgui.TableNextColumn();
    if (records.who == 'all' and item.char) then
        imgui.TextColored(COLOR.peach, item.char);
        imgui.SameLine(0, 8);
    end
    imgui.TextColored(COLOR.secondary, records.describe(item));
    if (imgui.IsItemHovered()) then
        imgui.SetTooltip(entry_tooltip(item));
    end
    imgui.TableNextColumn();
    imgui.TextColored(COLOR.muted, names.zone(item.zone));
    imgui.TableNextColumn();
    local balance = records.balance_of(item);
    right_text(COLOR.muted, balance and records.commas(balance) or '');
end

local function apply_columns(lg)
    if (lg.columns_set) then
        return false;
    end
    for _, entry in ipairs(HIDEABLE) do
        imgui.TableSetColumnEnabled(entry.column, lg.settings[entry.setting] == true);
    end
    lg.columns_set = true;
    return true;
end

local function read_columns(lg)
    local changed = false;
    for _, entry in ipairs(HIDEABLE) do
        local on = bit.band(imgui.TableGetColumnFlags(entry.column) or 0, ImGuiTableColumnFlags_IsEnabled) ~= 0;
        if (on ~= (lg.settings[entry.setting] == true)) then
            lg.settings[entry.setting] = on;
            changed = true;
        end
    end
    if (changed) then
        settings.save();
    end
end

local function draw_ledger(lg, width, scale, now)
    draw_filters(lg, width);
    local from, to = range_of(lg);
    local query = {
        period = lg.settings.period,
        from   = from,
        to     = to,
        cat    = lg.category or nil,
        search = lg.search[1] or '',
        side   = lg.side,
        order  = lg.order,
    };
    local items, total, key = records.rows(query, now);
    if (total == 0) then
        theme.caption('No entries match.');
        return;
    end
    theme.caption(('%s  (right-click the headers to pick columns)'):fmt(plural(total, 'entry', 'entries')));

    local _, height = theme.available();
    local flags = bit.bor(ImGuiTableFlags_ScrollY, ImGuiTableFlags_RowBg, ImGuiTableFlags_BordersInnerH, ImGuiTableFlags_SizingFixedFit, ImGuiTableFlags_PadOuterX, ImGuiTableFlags_Resizable, ImGuiTableFlags_Hideable);
    if (not imgui.BeginTable('##lg_rows', 6, flags, { 0, 0 })) then
        return;
    end
    local fixed = bit.bor(ImGuiTableColumnFlags_WidthFixed, ImGuiTableColumnFlags_NoHide);
    imgui.TableSetupScrollFreeze(0, 1);
    imgui.TableSetupColumn('Date', fixed, math.max(theme.text_width('Wed 00/00'), theme.text_width('00/00 00:00')));
    imgui.TableSetupColumn('Amount', fixed, theme.text_width('-00,000,000'));
    imgui.TableSetupColumn('Category', ImGuiTableColumnFlags_WidthFixed, theme.text_width('Training Regimes'));
    imgui.TableSetupColumn('Details', bit.bor(ImGuiTableColumnFlags_WidthStretch, ImGuiTableColumnFlags_NoHide));
    imgui.TableSetupColumn('Zone', ImGuiTableColumnFlags_WidthFixed, theme.text_width("Port San d'Oria"));
    imgui.TableSetupColumn('Balance', ImGuiTableColumnFlags_WidthFixed, theme.text_width('000,000,000'));
    local applied = apply_columns(lg);
    imgui.TableHeadersRow();
    if (not applied) then
        read_columns(lg);
    end
    clipped(lg.clip.rows, #items, height, key, function (index)
        draw_item(items[index]);
    end);
    imgui.EndTable();
end

local function option(lg, label, key, locked)
    if (locked) then
        imgui.BeginDisabled(true);
    end
    local buffer = { lg.settings[key] == true };
    if (imgui.Checkbox(('%s##lg_opt_%s'):fmt(label, key), buffer)) then
        lg.settings[key] = buffer[1];
        settings.save();
    end
    if (locked) then
        imgui.EndDisabled();
    end
end

local function draw_options(lg)
    if (not imgui.BeginPopup('##lg_options')) then
        return;
    end
    local s = lg.settings;
    option(lg, 'Show the gil display', 'visible', false);
    option(lg, 'Gil amount on the display', 'show_gil', s.show_gil and not s.bag_counts);
    option(lg, 'Gil for every character', 'gil_each', not s.show_gil);
    option(lg, 'Bag counts on the display', 'bag_counts', s.bag_counts and not s.show_gil);
    option(lg, 'Move items between bags', 'move_items', false);
    option(lg, 'Lock windows', 'locked', false);
    imgui.Separator();
    theme.caption('Scale');
    display.slider(lg, 'options', 'scale', 0.5, 3.0, '%.2f', 0.05, OPTION_WIDTH * s.scale, false);
    theme.caption('Opacity');
    display.slider(lg, 'options', 'alpha', 0.0, 1.0, '%.2f', 0.01, OPTION_WIDTH * s.scale, true);
    imgui.EndPopup();
end

local function draw_footer(lg, width)
    local gap       = 8;
    local count     = plural(#records.active(), 'entry', 'entries');
    local export_w  = theme.text_width('Export CSV') + theme.FRAME_X * 2;
    local options_w = theme.text_width('Options') + theme.FRAME_X * 2;
    local widest    = 0;
    for _, name in ipairs(theme.THEME_ORDER) do
        widest = math.max(widest, theme.text_width(theme.THEMES[name].label));
    end
    local combo_w = widest + imgui.GetFrameHeight() + theme.FRAME_X * 2;
    local right   = theme.PADDING + width;
    local start   = right - export_w - options_w - combo_w - theme.text_width('Theme') - gap * 3;
    imgui.AlignTextToFramePadding();
    imgui.TextColored(COLOR.faint, count);
    imgui.SameLine(math.max(theme.PADDING + theme.text_width(count) + gap, start));
    imgui.TextColored(COLOR.muted, 'Theme');
    imgui.SameLine(0, gap);
    imgui.SetNextItemWidth(combo_w);
    if (imgui.BeginCombo('##lg_theme', theme.THEMES[theme.name].label)) then
        for _, name in ipairs(theme.THEME_ORDER) do
            if (imgui.Selectable(theme.THEMES[name].label, lg.settings.theme == name)) then
                lg.settings.theme = theme.use(name);
                settings.save();
            end
        end
        imgui.EndCombo();
    end
    imgui.SameLine(0, gap);
    if (theme.toggle_button('Options##lg_options_button', false, options_w)) then
        imgui.OpenPopup('##lg_options');
    end
    imgui.SameLine(math.max(right - export_w, imgui.GetCursorPosX()));
    if (theme.toggle_button('Export CSV##lg_export', false, export_w)) then
        local target = records.export();
        local header = chat.header(addon.name);
        if (target) then
            print(header:append(chat.message('Ledger saved to ')):append(chat.success(target)));
        else
            print(header:append(chat.error('Could not write the CSV file.')));
        end
    end
    draw_options(lg);
end

local function remember(lg)
    local x, y = theme.window_position();
    local w, h = theme.window_size();
    if (not x or not w) then
        return;
    end
    x, y, w, h = math.floor(x), math.floor(y), math.floor(w), math.floor(h);
    if (x == lg.settings.ledger_x and y == lg.settings.ledger_y and w == lg.settings.ledger_w and h == lg.settings.ledger_h) then
        return;
    end
    lg.settings.ledger_x = x;
    lg.settings.ledger_y = y;
    lg.settings.ledger_w = w;
    lg.settings.ledger_h = h;
    if (os.clock() - lg.last_pos_save > 1.0) then
        lg.last_pos_save = os.clock();
        settings.save();
    end
end

local function age(stamp, now)
    local seconds = math.max(0, now - stamp);
    if (seconds < 3600) then
        return ('%dm ago'):fmt(math.floor(seconds / 60));
    elseif (seconds < DAY) then
        return ('%dh ago'):fmt(math.floor(seconds / 3600));
    end
    return ('%dd ago'):fmt(math.floor(seconds / DAY));
end

local function draw_results(lg, width, now)
    local results, total = bags.search(lg.item_search[1], now);
    if (total == 0) then
        theme.caption('No items match on any character.');
        return;
    end
    if (total > #results) then
        theme.caption(('Showing %d of %d matches'):fmt(#results, total));
    else
        theme.caption(('%d %s'):fmt(total, total == 1 and 'match' or 'matches'));
    end
    local height = (math.min(#results, RESULT_ROWS) + 1) * (imgui.GetFrameHeight() + 2);
    local flags  = bit.bor(ImGuiTableFlags_ScrollY, ImGuiTableFlags_RowBg, ImGuiTableFlags_BordersInnerH, ImGuiTableFlags_SizingFixedFit, ImGuiTableFlags_PadOuterX);
    if (not imgui.BeginTable('##lg_results', 4, flags, { width, height })) then
        return;
    end
    imgui.TableSetupScrollFreeze(0, 1);
    imgui.TableSetupColumn('Item', ImGuiTableColumnFlags_WidthStretch);
    imgui.TableSetupColumn('Qty', ImGuiTableColumnFlags_WidthFixed, 50 * lg.settings.scale);
    imgui.TableSetupColumn('Where', ImGuiTableColumnFlags_WidthFixed, 120 * lg.settings.scale);
    imgui.TableSetupColumn('Character', ImGuiTableColumnFlags_WidthFixed, 130 * lg.settings.scale);
    imgui.TableHeadersRow();
    for index, result in ipairs(results) do
        imgui.TableNextRow();
        imgui.TableNextColumn();
        imgui.Selectable(('%s##lg_result_%d'):fmt(result.name, index), false, ImGuiSelectableFlags_SpanAllColumns);
        imgui.TableNextColumn();
        if (result.bag ~= bags.KEY_BAG) then
            right_text(COLOR.text, records.commas(result.count));
        end
        imgui.TableNextColumn();
        imgui.TextColored(COLOR.secondary, bags.LABEL[result.bag] or ('Bag %d'):fmt(result.bag));
        imgui.TableNextColumn();
        if (result.mine) then
            imgui.TextColored(COLOR.text, result.who);
        else
            imgui.TextColored(COLOR.muted, ('%s (%s)'):fmt(result.who, age(result.time, now)));
        end
    end
    imgui.EndTable();
end

local function draw_count(draw, x1, y1, scale, count)
    imgui.PushFont(imgui.GetFont(), imgui.GetFontSize() * COUNT_FONT);
    local text = tostring(count);
    theme.label(draw, math.floor(x1 - theme.text_width(text) - 3 * scale), math.floor(y1 - imgui.GetFontSize() - 2 * scale), COLOR.text, text);
    imgui.PopFont();
end

local function grid_cols(width, scale)
    local size = SLOT * scale;
    local gap  = SLOT_GAP * scale;
    return math.max(MIN_COLS, math.min(MAX_COLS, math.floor((width + gap) / (size + gap))));
end

local function item_tip(item, bag_id)
    return ('%s\nx%s  %s'):fmt(names.item(item.id), records.commas(item.count), bags.LABEL[bag_id]);
end

local function draw_grid(draw, bag_id, x, y, cols, scale, match, inside)
    local state   = bags.state[bag_id];
    local size    = SLOT * scale;
    local gap     = SLOT_GAP * scale;
    local rows    = math.ceil(state.max / cols);
    local mx, my  = theme.mouse();
    local white   = theme.u32({ 1, 1, 1, 1 });
    local shade   = theme.u32({ 0, 0, 0, 0.65 });
    local round   = theme.style.cell;
    local pad     = (size - ICON * scale) / 2;
    local hovered = nil;
    local spot    = nil;
    for slot = 1, state.max do
        local index  = slot - 1;
        local x0     = x + (index % cols) * (size + gap);
        local y0     = y + math.floor(index / cols) * (size + gap);
        local x1, y1 = x0 + size, y0 + size;
        local item   = state.slots[slot];
        local over   = inside and mx >= x0 and mx < x1 and my >= y0 and my < y1;
        local edge   = COLOR.subtle;
        local thick  = 1;
        draw:AddRectFilled({ x0, y0 }, { x1, y1 }, theme.u32(COLOR.cell), round);
        if (item) then
            local texture = icons.get(item.id);
            if (texture) then
                draw:AddImage(texture, { x0 + pad, y0 + pad }, { x1 - pad, y1 - pad }, { 0, 0 }, { 1, 1 }, white);
            end
            if (item.count > 1) then
                draw_count(draw, x1, y1, scale, item.count);
            end
            edge = COLOR.border;
            if (match) then
                if (match(item.id)) then
                    edge  = COLOR.ember;
                    thick = 2;
                else
                    draw:AddRectFilled({ x0, y0 }, { x1, y1 }, shade, round);
                end
            end
            if (over) then
                hovered = item;
                spot    = slot;
            end
        end
        if (over) then
            draw:AddRectFilled({ x0, y0 }, { x1, y1 }, theme.u32(COLOR.tint), round);
            edge = COLOR.ember;
        end
        draw:AddRect({ x0, y0 }, { x1, y1 }, theme.u32(edge), round, 0, thick);
    end
    return hovered, spot, cols * size + (cols - 1) * gap, rows * size + (rows - 1) * gap;
end

local function draw_group(lg, group, width, scale, match)
    local movable = lg.settings.move_items;
    local size   = SLOT * scale;
    local gap    = SLOT_GAP * scale;
    local space  = PAIR_GAP * scale;
    local half   = (width - space) / 2;
    local across = half >= MIN_COLS * (size + gap) - gap and 2 or 1;
    local cols   = grid_cols(across == 2 and half or width, scale);
    local head   = imgui.GetFontSize() + 6 * scale;
    local x, y   = theme.cursor();
    local draw   = imgui.GetWindowDrawList();
    local inside = imgui.IsWindowHovered();
    local mx, my = theme.mouse();
    local shade  = theme.u32({ 0, 0, 0, 0.55 });
    local blocks = {};
    local top    = y;
    local bottom = y;
    for index, bag_id in ipairs(group) do
        local column = (index - 1) % across;
        if (column == 0 and index > 1) then
            top = bottom + space;
        end
        local state = bags.state[bag_id];
        local open  = not movable or mover.usable(bag_id);
        local bx    = x + column * (half + space);
        local count = ('%d / %d'):fmt(state.used, state.max);
        local label = open and bags.LABEL[bag_id] or ('%s  (locked here)'):fmt(bags.LABEL[bag_id]);
        local hovered, spot, w, h = draw_grid(draw, bag_id, bx, top + head, cols, scale, match, inside);
        if (not open) then
            draw:AddRectFilled({ bx, top + head }, { bx + w, top + head + h }, shade, theme.style.cell);
        end
        draw:AddText({ math.floor(bx), math.floor(top) }, theme.u32(open and COLOR.secondary or COLOR.muted), label);
        draw:AddText({ math.floor(bx + w - theme.text_width(count)), math.floor(top) }, theme.u32(open and display.fullness(state) or COLOR.muted), count);
        blocks[bag_id] = { x0 = bx, y0 = top + head, x1 = bx + w, y1 = top + head + h, item = hovered, slot = spot, open = open };
        bottom = math.max(bottom, top + head + h);
    end

    imgui.InvisibleButton('##lg_bag_group', { width, math.max(1, bottom - y) });
    local over = nil;
    for bag_id, block in pairs(blocks) do
        if (mx >= block.x0 and mx < block.x1 and my >= block.y0 and my < block.y1) then
            over = bag_id;
        end
    end
    local block = over and blocks[over];
    if (not movable) then
        lg.drag = nil;
        if (block and block.item) then
            imgui.SetTooltip(item_tip(block.item, over));
        end
        return;
    end
    if (imgui.IsItemActivated() and block and block.open and block.item) then
        lg.drag = { from = over, slot = block.slot, id = block.item.id, x = mx, y = my, moving = false };
    end

    local drag = lg.drag;
    if (drag and (blocks[drag.from] == nil or not blocks[drag.from].open)) then
        lg.drag, drag = nil, nil;
    end
    if (drag) then
        local target = block and block.open and over ~= drag.from and over or nil;
        if (not drag.moving and (math.abs(mx - drag.x) > DRAG_SLOP or math.abs(my - drag.y) > DRAG_SLOP)) then
            drag.moving = true;
        end
        if (drag.moving) then
            if (target) then
                draw:AddRect({ block.x0 - 2, block.y0 - 2 }, { block.x1 + 2, block.y1 + 2 }, theme.u32(COLOR.ember), theme.style.cell, 0, 2);
                imgui.SetTooltip(('Drop to move to %s'):fmt(bags.LABEL[target]));
            elseif (block and not block.open) then
                imgui.SetTooltip(mover.shut(over));
            else
                imgui.SetTooltip('Drag onto another bag');
            end
            local texture = icons.get(drag.id);
            if (texture) then
                local reach = ICON * scale / 2;
                imgui.GetForegroundDrawList():AddImage(texture, { mx - reach, my - reach }, { mx + reach, my + reach }, { 0, 0 }, { 1, 1 }, theme.u32({ 1, 1, 1, 0.85 }));
            end
        end
        if (imgui.IsMouseReleased(0) or not imgui.IsMouseDown(0)) then
            if (drag.moving and target) then
                mover.request(drag.from, drag.slot, target, drag.id, os.clock());
            end
            lg.drag = nil;
        end
    elseif (block and block.item) then
        if (not block.open) then
            imgui.SetTooltip(('%s\n%s'):fmt(item_tip(block.item, over), mover.shut(over)));
        elseif (imgui.IsItemHovered() and imgui.IsMouseClicked(1)) then
            lg.move = { from = over, slot = block.slot, id = block.item.id };
            imgui.OpenPopup('##lg_move_menu');
        else
            imgui.SetTooltip(('%s\nDrag to another bag, or right-click to move'):fmt(item_tip(block.item, over)));
        end
    end

    local text, problem = mover.status_text(os.clock());
    if (text) then
        imgui.TextColored(problem and COLOR.ember or COLOR.muted, text);
    end
end

local function draw_move_menu(lg)
    if (not imgui.BeginPopup('##lg_move_menu')) then
        return;
    end
    local move = lg.move;
    if (move) then
        local reasons = {};
        imgui.TextColored(COLOR.peach, names.item(move.id));
        imgui.Separator();
        for _, to in ipairs(mover.targets(move.from)) do
            local reason = mover.reason(move.from, move.slot, to, move.id, os.clock());
            if (imgui.MenuItem(('Move to %s'):fmt(bags.LABEL[to]), nil, false, reason == nil)) then
                mover.request(move.from, move.slot, to, move.id, os.clock());
            end
            if (reason and not reasons[reason]) then
                reasons[reason] = true;
                reasons[#reasons + 1] = reason;
            end
        end
        for _, reason in ipairs(reasons) do
            imgui.TextColored(COLOR.muted, reason);
        end
    end
    imgui.EndPopup();
end

local function draw_bags(lg, width, scale, now)
    imgui.SetNextItemWidth(width);
    imgui.InputTextWithHint('##lg_item_search', 'Find items or key items on all characters', lg.item_search, 64);
    local match = bags.matcher(lg.item_search[1]);
    if (match) then
        draw_results(lg, width, now);
        imgui.Spacing();
    end
    local group = mover.group();
    if (#group == 0) then
        theme.caption('No bags loaded yet.');
        return;
    end
    draw_group(lg, group, width, scale, match);
    draw_move_menu(lg);
end

function breakdown.render(lg)
    local scale = lg.settings.scale;
    local flags = bit.bor(ImGuiWindowFlags_NoTitleBar, ImGuiWindowFlags_NoCollapse, ImGuiWindowFlags_NoScrollbar, ImGuiWindowFlags_NoScrollWithMouse, ImGuiWindowFlags_NoNav, ImGuiWindowFlags_NoSavedSettings);
    if (lg.settings.locked) then
        flags = bit.bor(flags, ImGuiWindowFlags_NoMove);
    end

    local color_count, var_count = theme.push(lg.settings.alpha);
    imgui.PushStyleColor(ImGuiCol_ResizeGrip, COLOR.subtle);
    imgui.PushStyleColor(ImGuiCol_ResizeGripHovered, COLOR.tint);
    imgui.PushStyleColor(ImGuiCol_ResizeGripActive, COLOR.royal);
    imgui.SetNextWindowSizeConstraints({ MIN_WIDTH * scale, MIN_HEIGHT * scale }, { 4096, 4096 });
    if (lg.place_ledger) then
        imgui.SetNextWindowPos({ lg.settings.ledger_x, lg.settings.ledger_y }, ImGuiCond_Always);
        imgui.SetNextWindowSize({ math.max(lg.settings.ledger_w, MIN_WIDTH * scale), math.max(lg.settings.ledger_h, MIN_HEIGHT * scale) }, ImGuiCond_Always);
        lg.place_ledger = false;
    end

    if (imgui.Begin('Gil Ledger##ledger_window', { true }, flags)) then
        imgui.PushFont(imgui.GetFont(), imgui.GetFontSize() * scale);
        theme.decorate(scale, nil, 0, 'Gil Ledger');
        local now      = os.time();
        local width    = theme.available();
        local from, to = range_of(lg);
        lg.settings.who = records.refresh(os.clock(), lg.settings.who);
        local stats    = records.stats(lg.settings.period, now, from, to);

        draw_header(lg, width, scale);
        draw_views(lg, width);
        if (lg.settings.view ~= 'bags') then
            draw_periods(lg, width, now);
            draw_calendar(lg, scale, now);
            draw_span(lg, stats, width, now);
            draw_tiles(lg, stats, width, scale, now);
        end
        imgui.Separator();

        local footer = imgui.GetFrameHeight() + 10;
        if (imgui.BeginChild('##lg_view', { 0, -footer }, ImGuiChildFlags_None, 0)) then
            local inner = theme.available();
            if (lg.settings.view == 'sources') then
                draw_sources(stats, inner, scale);
            elseif (lg.settings.view == 'ledger') then
                draw_ledger(lg, inner, scale, now);
            elseif (lg.settings.view == 'days') then
                draw_days(lg, inner, scale, now);
            elseif (lg.settings.view == 'bags') then
                draw_bags(lg, inner, scale, now);
            else
                draw_overview(lg, stats, inner, scale);
            end
        end
        imgui.EndChild();
        draw_footer(lg, width);
        remember(lg);
        imgui.PopFont();
    end
    imgui.End();
    imgui.PopStyleColor(3);
    imgui.PopStyleVar(var_count);
    imgui.PopStyleColor(color_count);
end

return breakdown;
