addon.name    = 'ledger';
addon.author  = 'Skold';
addon.version = '1.0';
addon.desc    = 'Movable gil display with a ledger of where your gil came from and where it went.';
addon.link    = 'https://phoenix-xi.com/';

require('common');

local chat      = require('chat');
local settings  = require('settings');
local theme     = require('theme');
local records   = require('records');
local tracker   = require('tracker');
local bags      = require('bags');
local mover     = require('mover');
local display   = require('display');
local breakdown = require('breakdown');

local GIL = 0xFFFF;

local default_settings = T{
    visible      = true,
    locked       = false,
    theme        = 'phoenix',
    scale        = 1.0,
    alpha        = 0.9,
    show_gil     = true,
    gil_each     = false,
    bag_counts   = true,
    move_items   = true,
    who          = 'me',
    period       = 'session',
    view         = 'overview',
    range_from   = 0,
    range_to     = 0,
    col_category = true,
    col_zone     = false,
    col_balance  = true,
    x            = 100,
    y            = 300,
    ledger_x     = 260,
    ledger_y     = 160,
    ledger_w     = 540,
    ledger_h     = 480,
};

local lg = T{
    settings       = settings.load(default_settings),
    place_display  = true,
    place_ledger   = true,
    reset_position = false,
    show_ledger    = false,
    pending        = T{},
    last_pos_save  = 0,
    category       = false,
    side           = 'all',
    order          = 'new',
    columns_set    = false,
    clip           = { rows = {}, days = {} },
    search         = { '' },
    item_search    = { '' },
    press          = nil,
    hover_since    = nil,
    saw_login      = false,
    history        = {},
};

local function say(message)
    print(chat.header(addon.name):append(chat.message(message)));
end

local function clamp(value, low, high, fallback)
    return math.min(high, math.max(low, tonumber(value) or fallback));
end

local function valid(list, key, fallback)
    for _, entry in ipairs(list) do
        if (entry.key == key) then
            return key;
        end
    end
    return fallback;
end

local function sanitize()
    for key, value in pairs(default_settings) do
        if (rawget(lg.settings, key) == nil) then
            lg.settings[key] = value;
        end
    end
    lg.settings.scale  = clamp(lg.settings.scale, 0.5, 3.0, default_settings.scale);
    lg.settings.alpha  = clamp(lg.settings.alpha, 0.0, 1.0, default_settings.alpha);
    lg.settings.theme  = theme.use(lg.settings.theme);
    lg.settings.period = valid(records.PERIODS, lg.settings.period, default_settings.period);
    lg.settings.view   = valid(breakdown.VIEWS, lg.settings.view, default_settings.view);
    if (type(lg.settings.who) ~= 'string' or lg.settings.who == '') then
        lg.settings.who = default_settings.who;
    end
    local from = math.floor(tonumber(lg.settings.range_from) or 0);
    local to   = math.floor(tonumber(lg.settings.range_to) or 0);
    if (from < 19700101 or to < from) then
        from = records.day_key(os.time());
        to   = from;
    end
    lg.settings.range_from = from;
    lg.settings.range_to   = to;
    if (not lg.settings.show_gil and not lg.settings.bag_counts) then
        lg.settings.show_gil = true;
    end
end

local function folder()
    return ('%s\\config\\addons\\%s\\'):fmt(AshitaCore:GetInstallPath(), addon.name);
end

local function switch_owner(name, id)
    if (name == nil or name == '' or id == nil or id == 0 or records.owner == ('%s_%d'):fmt(name, id)) then
        return;
    end
    tracker.flush();
    records.open(name, id, folder());
    bags.open(records.owner, folder());
    tracker.reset();
end

local function logged_in()
    return AshitaCore:GetMemoryManager():GetParty():GetMemberIsActive(0) == 1;
end

local function adopt(now)
    local memory = AshitaCore:GetMemoryManager();
    local party  = memory:GetParty();
    if (party:GetMemberIsActive(0) == 0) then
        return;
    end
    switch_owner(party:GetMemberName(0), party:GetMemberServerId(0));
    if (records.owner == nil or lg.saw_login or tracker.balance ~= nil) then
        return;
    end
    local gil = memory:GetInventory():GetContainerItem(0, 0);
    if (gil and gil.Id == GIL) then
        tracker.zone = party:GetMemberZone(0);
        tracker.set_balance(gil.Count, now);
    end
end

local function hidden()
    if (not AshitaCore:GetFontManager():GetVisible()) then
        return true;
    end
    return AshitaCore:GetMemoryManager():GetParty():GetMemberIsActive(0) == 0;
end

local function find(text)
    lg.item_search[1] = text or '';
    lg.show_ledger    = true;
    lg.settings.view  = 'bags';
    settings.save();
end

local function print_help()
    say('/ledger - show or hide the gil display');
    say('/ledger gil - show or hide the gil amount on the display');
    say('/ledger open - open or close the gil ledger (or click the display)');
    say('/ledger session - start a new session (for a fresh gil per hour)');
    say('/ledger bags - open the ledger on your bags and item search');
    say('/find <name> - find an item or key item on all your characters (* wildcards and item ids work)');
    say('In the Bags view, drag items between any bags that are open where you are, or right-click one to move it.');
    say('Pick All characters at the top of the ledger to add your characters together.');
    say(('/ledger theme <%s> - Phoenix colours, or one of the game\'s window styles'):fmt(table.concat(theme.THEME_ORDER, '|')));
    say('/ledger scale <0.5-3> - size of both windows');
    say('/ledger lock|unlock - stop or allow dragging the windows');
    say('/ledger reset - move both windows back to their starting places');
    say('/ledger export - save the whole ledger as a CSV file');
    say('Right-click the display for more options.');
end

ashita.events.register('command', 'ledger_command', function (e)
    local args = e.command:args();
    if (#args == 0) then
        return;
    end
    local command = args[1]:lower();
    if (command ~= '/ledger' and command ~= '/find') then
        return;
    end
    e.blocked = true;
    if (command == '/find') then
        find(e.command:match('^%S+%s*(.-)%s*$'));
        return;
    end

    local sub   = (args[2] or ''):lower();
    local value = args[3];
    if (sub == '') then
        lg.settings.visible = not lg.settings.visible;
        settings.save();
    elseif (sub == 'show' or sub == 'hide') then
        lg.settings.visible = sub == 'show';
        settings.save();
    elseif (sub == 'gil') then
        local on = not lg.settings.show_gil;
        if (value == 'on' or value == 'off') then
            on = value == 'on';
        end
        if (not on and not lg.settings.bag_counts) then
            say('Bag counts are off, so the display would be empty. Type /ledger to hide the whole display.');
            return;
        end
        lg.settings.show_gil = on;
        settings.save();
    elseif (sub == 'open') then
        lg.show_ledger = not lg.show_ledger;
    elseif (sub == 'session') then
        records.restart(os.time());
        say('Started a new session.');
    elseif (sub == 'bags') then
        lg.show_ledger   = true;
        lg.settings.view = 'bags';
        settings.save();
    elseif (sub == 'find') then
        find(e.command:match('^%S+%s+%S+%s*(.-)%s*$'));
    elseif (sub == 'theme') then
        local choice = (value or ''):lower();
        if (not theme.THEMES[choice]) then
            say(('Usage: /ledger theme <%s>'):fmt(table.concat(theme.THEME_ORDER, '|')));
            return;
        end
        lg.settings.theme = theme.use(choice);
        settings.save();
    elseif (sub == 'scale') then
        local number = tonumber(value);
        if (not number) then
            say('Usage: /ledger scale <0.5-3>');
            return;
        end
        lg.settings.scale = clamp(number, 0.5, 3.0, default_settings.scale);
        settings.save();
    elseif (sub == 'lock' or sub == 'unlock') then
        lg.settings.locked = sub == 'lock';
        settings.save();
    elseif (sub == 'reset') then
        lg.reset_position = true;
    elseif (sub == 'export') then
        local target = records.export();
        if (target) then
            say('Ledger saved to ' .. target);
        else
            say('Nothing to export yet.');
        end
    else
        print_help();
    end
end);

ashita.events.register('packet_in', 'ledger_packet_in', function (e)
    if (e.injected) then
        return;
    end
    mover.packet_in(e.id, e.data, os.clock());
    if (e.id == 0x00A) then
        local name, id = tracker.zone_in(e.data);
        lg.saw_login = true;
        switch_owner(name, id);
        bags.zone_in();
        return;
    end
    bags.packet_in(e.id, e.data, os.clock());
    if (e.id == 0x00B) then
        bags.save(os.clock(), logged_in(), true);
    end
    if (records.owner ~= nil) then
        tracker.packet_in(e.id, e.data, os.clock());
    end
end);

ashita.events.register('packet_out', 'ledger_packet_out', function (e)
    if (e.injected) then
        return;
    end
    mover.packet_out(e.id, e.data, os.clock());
    if (records.owner == nil) then
        return;
    end
    tracker.packet_out(e.id, e.data, os.clock());
end);

ashita.events.register('d3d_present', 'ledger_present', function ()
    local now = os.clock();
    if (records.owner == nil or (tracker.balance == nil and not lg.saw_login)) then
        adopt(now);
    end
    tracker.tick(now);
    if (logged_in()) then
        bags.scan(now);
        bags.save(now, true);
    end
    if (lg.settings.move_items) then
        mover.tick(now);
    else
        mover.clear();
    end

    if (lg.reset_position) then
        lg.settings.x        = default_settings.x;
        lg.settings.y        = default_settings.y;
        lg.settings.ledger_x = default_settings.ledger_x;
        lg.settings.ledger_y = default_settings.ledger_y;
        lg.settings.ledger_w = default_settings.ledger_w;
        lg.settings.ledger_h = default_settings.ledger_h;
        lg.place_display     = true;
        lg.place_ledger      = true;
        lg.reset_position    = false;
        settings.save();
    end

    if (hidden()) then
        return;
    end
    if (lg.settings.visible) then
        display.render(lg, tracker.balance);
    end
    if (lg.show_ledger) then
        breakdown.render(lg);
    end
end);

ashita.events.register('unload', 'ledger_unload', function ()
    tracker.flush();
    bags.save(os.clock(), logged_in(), true);
    settings.save();
end);

settings.register('settings', 'ledger_settings_update', function (s)
    if (s) then
        lg.settings = s;
    end
    sanitize();
    settings.save();
    lg.place_display = true;
    lg.place_ledger  = true;
    lg.columns_set   = false;
end);

tracker.on_baseline = function (balance)
    records.baseline(balance, tracker.zone);
end;
tracker.on_change = function (balance)
    records.store(balance);
end;
tracker.on_entry = function (entry)
    records.add(entry);
end;

sanitize();
