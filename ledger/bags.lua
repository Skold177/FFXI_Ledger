require('common');

local names = require('names');

local GIL          = 0xFFFF;
local SCAN_EVERY   = 0.5;
local SAVE_EVERY   = 30;
local LOAD_SETTLE  = 1;
local KEY_SETTLE   = 1;
local KEY_ITEMS    = 3584;
local KEY_BAG      = 99;
local TEMPORARY    = 3;
local ALL_LOADED   = 1;
local OTHERS_EVERY = 30;
local MIN_SEARCH   = 2;
local MAX_RESULTS  = 200;
local MAGIC        = '[%^%$%(%)%%%.%[%]%+%-%?]';

local bags = {
    CONTAINERS = {
        { id = 0, carried = true  },
        { id = 5, carried = true  },
        { id = 1, carried = false },
        { id = 2, carried = false },
        { id = 4, carried = false },
    },
    SEARCHED   = { 0, 5, 6, 7, 1, 9, 2, 4, 8, 10, 11, 12, 13, 14, 15, 16, TEMPORARY },
    LABEL      = {
        [0]       = 'Inventory',
        [1]       = 'Mog Safe',
        [2]       = 'Storage',
        [3]       = 'Temporary Items',
        [4]       = 'Mog Locker',
        [5]       = 'Mog Satchel',
        [6]       = 'Mog Sack',
        [7]       = 'Mog Case',
        [8]       = 'Mog Wardrobe',
        [9]       = 'Mog Safe 2',
        [10]      = 'Mog Wardrobe 2',
        [11]      = 'Mog Wardrobe 3',
        [12]      = 'Mog Wardrobe 4',
        [13]      = 'Mog Wardrobe 5',
        [14]      = 'Mog Wardrobe 6',
        [15]      = 'Mog Wardrobe 7',
        [16]      = 'Mog Wardrobe 8',
        [KEY_BAG] = 'Key Item',
    },
    KEY_BAG     = KEY_BAG,
    ORDER       = {},
    state       = {},
    key_items   = {},
    keys_due    = 0,
    loading     = false,
    version     = 0,
    scanned_at  = -math.huge,
    owner       = false,
    folder      = false,
    saved_text  = false,
    saved_at    = 0,
    quiet_until = 0,
    others      = {},
    others_at   = -math.huge,
    search_key  = false,
    results     = {},
    total       = 0,
};

for _, bag in ipairs(bags.CONTAINERS) do
    bag.label = bags.LABEL[bag.id];
end
for index, id in ipairs(bags.SEARCHED) do
    bags.ORDER[id] = index;
    bags.state[id] = { max = 0, used = 0, slots = {} };
end
bags.ORDER[KEY_BAG] = #bags.SEARCHED + 1;

local function display_name(owner)
    return (owner:gsub('_%d+$', ''));
end

local function snapshot_path(owner)
    return ('%s%s_items.tsv'):fmt(bags.folder, owner);
end

local function scan_keys(now)
    if (not bags.keys_due or now < bags.keys_due) then
        return false;
    end
    bags.keys_due = false;
    local player = AshitaCore:GetMemoryManager():GetPlayer();
    local held   = {};
    for id = 1, KEY_ITEMS - 1 do
        if (player:HasKeyItem(id)) then
            held[#held + 1] = id;
        end
    end
    local changed = table.concat(held, ',') ~= table.concat(bags.key_items, ',');
    bags.key_items = held;
    return changed;
end

function bags.scan(now, force)
    if (not force and now - bags.scanned_at < SCAN_EVERY) then
        return;
    end
    bags.scanned_at = now;
    local inventory = AshitaCore:GetMemoryManager():GetInventory();
    local changed   = scan_keys(now);
    for _, id in ipairs(bags.SEARCHED) do
        local entry = bags.state[id];
        local max   = inventory:GetContainerCountMax(id) or 0;
        local slots = {};
        local used  = 0;
        for slot = 1, max do
            local item = inventory:GetContainerItem(id, slot);
            if (item ~= nil and item.Id ~= 0 and item.Id ~= GIL) then
                slots[slot] = { id = item.Id, count = item.Count };
                used = used + 1;
                local old = entry.slots[slot];
                if (old == nil or old.id ~= item.Id or old.count ~= item.Count) then
                    changed = true;
                end
            elseif (entry.slots[slot] ~= nil) then
                changed = true;
            end
        end
        if (max ~= entry.max or used ~= entry.used) then
            changed = true;
        end
        entry.max   = max;
        entry.used  = used;
        entry.slots = slots;
    end
    if (changed) then
        bags.version = bags.version + 1;
    end
end

function bags.unlocked()
    local list = {};
    for _, bag in ipairs(bags.CONTAINERS) do
        if (bags.state[bag.id].max > 0) then
            list[#list + 1] = bag;
        end
    end
    return list;
end

local function snapshot_text()
    local lines = {};
    for _, bag_id in ipairs(bags.SEARCHED) do
        if (bag_id ~= TEMPORARY) then
            local totals = {};
            local order  = {};
            for _, item in pairs(bags.state[bag_id].slots) do
                if (totals[item.id] == nil) then
                    totals[item.id] = 0;
                    order[#order + 1] = item.id;
                end
                totals[item.id] = totals[item.id] + item.count;
            end
            table.sort(order);
            for _, id in ipairs(order) do
                lines[#lines + 1] = ('%d\t%d\t%d'):fmt(bag_id, id, totals[id]);
            end
        end
    end
    for _, id in ipairs(bags.key_items) do
        lines[#lines + 1] = ('k\t%d'):fmt(id);
    end
    return table.concat(lines, '\n');
end

function bags.open(owner, folder)
    bags.owner       = owner;
    bags.folder      = folder;
    bags.saved_text  = false;
    bags.saved_at    = 0;
    bags.others_at   = -math.huge;
    bags.search_key  = false;
    bags.key_items   = {};
    bags.keys_due    = 0;
end

function bags.zone_in()
    bags.loading = true;
end

function bags.packet_in(id, data, now)
    if (id == 0x01D) then
        if (data:byte(0x04 + 1) == ALL_LOADED) then
            bags.loading     = false;
            bags.quiet_until = now + LOAD_SETTLE;
        end
    elseif (id == 0x055) then
        bags.keys_due = now + KEY_SETTLE;
    end
end

function bags.save(now, active, force)
    if (not bags.owner or not active or bags.loading or now < bags.quiet_until or bags.state[0].max == 0) then
        return;
    end
    if (not force and now - bags.saved_at < SAVE_EVERY) then
        return;
    end
    bags.saved_at = now;
    local text = snapshot_text();
    if (text == bags.saved_text) then
        return;
    end
    local file = io.open(snapshot_path(bags.owner), 'w');
    if (file) then
        file:write(('#\t%d\n'):fmt(os.time()), text, '\n');
        file:close();
        bags.saved_text = text;
    end
end

local function load_others(now)
    if (now - bags.others_at < OTHERS_EVERY) then
        return;
    end
    bags.others_at = now;
    bags.others    = {};
    if (not bags.folder) then
        return;
    end
    local files = ashita.fs.get_directory(bags.folder, '.*_items\\.tsv', false) or {};
    for _, path in ipairs(files) do
        local name  = path:match('([^\\/]+)$') or path;
        local owner = name:match('^(.+_%d+)_items%.tsv$');
        if (owner and owner ~= bags.owner) then
            local file = io.open(bags.folder .. name, 'r');
            if (file) then
                local other = { name = display_name(owner), time = 0, items = {}, key_items = {} };
                for line in file:lines() do
                    local stamp = line:match('^#\t(%d+)');
                    local key   = line:match('^k\t(%d+)');
                    if (stamp) then
                        other.time = tonumber(stamp);
                    elseif (key) then
                        other.key_items[#other.key_items + 1] = tonumber(key);
                    else
                        local bag, id, count = line:match('^(%d+)\t(%d+)\t(%d+)');
                        if (bag) then
                            other.items[#other.items + 1] = { bag = tonumber(bag), id = tonumber(id), count = tonumber(count) };
                        end
                    end
                end
                file:close();
                bags.others[#bags.others + 1] = other;
            end
        end
    end
end

local function compile(text)
    local needle = (text or ''):lower():match('^%s*(.-)%s*$');
    if (#needle < MIN_SEARCH) then
        return nil;
    end
    local number = tonumber(needle);
    if (number) then
        return function (id)
            return id == number;
        end, nil, needle;
    end
    local test;
    if (needle:find('*', 1, true)) then
        local pattern = '^' .. needle:gsub(MAGIC, '%%%0'):gsub('%*', '.*') .. '$';
        test = function (name)
            return name:find(pattern) ~= nil;
        end;
    else
        test = function (name)
            return name:find(needle, 1, true) ~= nil;
        end;
    end
    local function item(id)
        for _, name in ipairs(names.terms(id)) do
            if (test(name)) then
                return true;
            end
        end
        return false;
    end
    local function key(id)
        return test(names.key_item(id):lower());
    end
    return item, key, needle;
end

function bags.matcher(text)
    return (compile(text));
end

local function add(results, id, count, bag, who, mine, time)
    local name = bag == KEY_BAG and names.key_item(id) or names.item(id);
    results[#results + 1] = { id = id, name = name, count = count, bag = bag, who = who, mine = mine, time = time };
end

function bags.search(text, now)
    local item, key, needle = compile(text);
    if (not item) then
        return {}, 0;
    end
    load_others(now);
    local cache = ('%s|%d|%d'):fmt(needle, bags.version, bags.others_at);
    if (bags.search_key == cache) then
        return bags.results, bags.total;
    end

    local results = {};
    local mine    = bags.owner and display_name(bags.owner) or '';
    for _, bag_id in ipairs(bags.SEARCHED) do
        local totals = {};
        for _, entry in pairs(bags.state[bag_id].slots) do
            if (item(entry.id)) then
                totals[entry.id] = (totals[entry.id] or 0) + entry.count;
            end
        end
        for id, count in pairs(totals) do
            add(results, id, count, bag_id, mine, true, false);
        end
    end
    if (key) then
        for _, id in ipairs(bags.key_items) do
            if (key(id)) then
                add(results, id, 0, KEY_BAG, mine, true, false);
            end
        end
    end
    for _, other in ipairs(bags.others) do
        for _, entry in ipairs(other.items) do
            if (item(entry.id)) then
                add(results, entry.id, entry.count, entry.bag, other.name, false, other.time);
            end
        end
        if (key) then
            for _, id in ipairs(other.key_items) do
                if (key(id)) then
                    add(results, id, 0, KEY_BAG, other.name, false, other.time);
                end
            end
        end
    end
    table.sort(results, function (a, b)
        if (a.mine ~= b.mine) then
            return a.mine;
        end
        if (a.name ~= b.name) then
            return a.name < b.name;
        end
        if (a.who ~= b.who) then
            return a.who < b.who;
        end
        return (bags.ORDER[a.bag] or a.bag) < (bags.ORDER[b.bag] or b.bag);
    end);
    local total = #results;
    while (#results > MAX_RESULTS) do
        table.remove(results);
    end
    bags.search_key = cache;
    bags.results    = results;
    bags.total      = total;
    return results, total;
end

return bags;
