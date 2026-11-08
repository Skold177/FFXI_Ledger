require('common');

local names = require('names');

local DAY          = 86400;
local TOP_COUNT    = 25;
local LIST_EVERY   = 30;
local RELOAD_EVERY = 10;
local GIL_EVERY    = 10;

local records = T{
    owner     = nil,
    folder    = nil,
    entries   = T{},
    saved     = nil,
    session   = os.time(),
    version   = 0,
    cache     = {},
    who       = 'me',
    roster    = {},
    others    = {},
    family    = {},
    listed_at = -math.huge,
    loaded_at = -math.huge,
    combined  = false,
    gil       = {},
    gil_key   = '',
    gil_at    = -math.huge,
};

records.CATEGORIES = T{
    T{ key = 'mob',       label = 'Monsters'         },
    T{ key = 'regime',    label = 'Training Regimes' },
    T{ key = 'shop',      label = 'NPC Shops'        },
    T{ key = 'guild',     label = 'Guild Shops'      },
    T{ key = 'ah',        label = 'Auction House'    },
    T{ key = 'bazaar',    label = 'Bazaars'          },
    T{ key = 'trade',     label = 'Player Trades'    },
    T{ key = 'delivery',  label = 'Delivery Box'     },
    T{ key = 'npc',       label = 'NPCs & Services'  },
    T{ key = 'untracked', label = 'Untracked'        },
    T{ key = 'other',     label = 'Other'            },
};

records.LABEL = T{};
for _, category in ipairs(records.CATEGORIES) do
    records.LABEL[category.key] = category.label;
end

records.PERIODS = T{
    T{ key = 'session', label = 'Session' },
    T{ key = 'today',   label = 'Today'   },
    T{ key = 'week',    label = '7 Days'  },
    T{ key = 'month',   label = '30 Days' },
    T{ key = 'all',     label = 'All'     },
    T{ key = 'range',   label = 'Dates'   },
};

function records.commas(value)
    local digits = tostring(math.floor(math.abs(value)));
    local out    = digits:reverse():gsub('(%d%d%d)', '%1,'):reverse();
    if (out:sub(1, 1) == ',') then
        out = out:sub(2);
    end
    return (value < 0 and '-' or '') .. out;
end

function records.signed(value)
    return (value > 0 and '+' or '') .. records.commas(value);
end

function records.short(value)
    local size = math.abs(value);
    local sign = value < 0 and '-' or (value > 0 and '+' or '');
    if (size >= 1000000) then
        return ('%s%.2fm'):fmt(sign, size / 1000000);
    elseif (size >= 10000) then
        return ('%s%.1fk'):fmt(sign, size / 1000);
    end
    return sign .. records.commas(size);
end

local FIELDS = T{ 'time', 'amount', 'balance', 'cat', 'zone', 'item', 'qty', 'who', 'verb' };
local NUMBER = T{ time = true, amount = true, balance = true, zone = true, item = true, qty = true };

local function split(line)
    local out   = T{};
    local start = 1;
    while (true) do
        local tab = line:find('\t', start, true);
        if (not tab) then
            out:append(line:sub(start));
            return out;
        end
        out:append(line:sub(start, tab - 1));
        start = tab + 1;
    end
end

local function field(value)
    if (value == nil) then
        return '';
    end
    return (tostring(value):gsub('[\t\r\n]', ' '));
end

local function path(suffix)
    return ('%s%s_%s'):fmt(records.folder, records.owner, suffix);
end

function records.display_name(owner)
    return ((owner or ''):gsub('_%d+$', ''));
end

local function parse(line)
    local parts = split(line);
    if (#parts < 4) then
        return nil;
    end
    local entry = T{};
    for index, key in ipairs(FIELDS) do
        local value = parts[index];
        if (value ~= nil and value ~= '') then
            entry[key] = NUMBER[key] and tonumber(value) or value;
        end
    end
    if (entry.time == nil or entry.amount == nil or entry.cat == nil) then
        return nil;
    end
    return entry;
end

function records.open(name, id, folder)
    if (name == nil or name == '' or id == nil or id == 0) then
        return false;
    end
    local owner = ('%s_%d'):fmt(name, id);
    if (records.owner == owner) then
        return false;
    end
    records.owner     = owner;
    records.folder    = folder;
    records.entries   = T{};
    records.saved     = nil;
    records.session   = os.time();
    records.who       = 'me';
    records.roster    = {};
    records.others    = {};
    records.family    = {};
    records.listed_at = -math.huge;
    records.loaded_at = -math.huge;
    records.combined  = false;
    records.gil       = {};
    records.gil_key   = '';
    records.gil_at    = -math.huge;
    if (not ashita.fs.exists(folder)) then
        ashita.fs.create_directory(folder);
    end

    local file = io.open(path('ledger.tsv'), 'r');
    if (file) then
        for line in file:lines() do
            local entry = parse(line);
            if (entry) then
                records.entries:append(entry);
            end
        end
        file:close();
    end

    file = io.open(path('balance.txt'), 'r');
    if (file) then
        records.saved = tonumber(file:read('*l') or '');
        file:close();
    end
    records.version = records.version + 1;
    return true;
end

function records.store(balance)
    if (records.owner == nil) then
        return;
    end
    records.saved = balance;
    local file = io.open(path('balance.txt'), 'w');
    if (file) then
        file:write(tostring(balance), '\n');
        file:close();
    end
end

function records.add(entry)
    if (records.owner == nil) then
        return;
    end
    records.entries:append(entry);
    records.version = records.version + 1;
    local values = T{};
    for _, key in ipairs(FIELDS) do
        values:append(field(entry[key]));
    end
    local file = io.open(path('ledger.tsv'), 'a');
    if (file) then
        file:write(table.concat(values, '\t'), '\n');
        file:close();
    end
end

function records.baseline(balance, zone)
    if (records.saved ~= nil and records.saved ~= balance) then
        records.add(T{ time = os.time(), amount = balance - records.saved, balance = balance, cat = 'untracked', zone = zone });
    end
    records.store(balance);
end

function records.restart(now)
    records.session = now;
    records.version = records.version + 1;
end

function records.other_gil(clock)
    if (records.owner == nil or clock - records.gil_at < GIL_EVERY) then
        return records.gil;
    end
    records.gil_at = clock;
    local list  = {};
    local files = ashita.fs.get_directory(records.folder, '.*_balance\\.txt', false) or {};
    for _, file in ipairs(files) do
        local name  = file:match('([^\\/]+)$') or file;
        local owner = name:match('^(.+_%d+)_balance%.txt$');
        if (owner and owner ~= records.owner) then
            local handle = io.open(records.folder .. name, 'r');
            if (handle) then
                local gil = tonumber(handle:read('*l') or '');
                handle:close();
                if (gil) then
                    list[#list + 1] = { owner = owner, name = records.display_name(owner), gil = gil };
                end
            end
        end
    end
    table.sort(list, function (a, b)
        return a.name < b.name;
    end);
    local parts = {};
    for _, other in ipairs(list) do
        parts[#parts + 1] = ('%s=%d'):fmt(other.owner, other.gil);
    end
    local key = table.concat(parts, ',');
    if (key ~= records.gil_key) then
        records.gil     = list;
        records.gil_key = key;
    end
    return records.gil;
end

function records.balance_for(who, clock)
    if (who == 'me') then
        return records.saved;
    end
    local total = records.saved or 0;
    for _, other in ipairs(records.other_gil(clock)) do
        if (other.owner == who) then
            return other.gil;
        end
        total = total + other.gil;
    end
    if (who == 'all') then
        return total;
    end
    return nil;
end

local function list_roster()
    local found = {};
    local files = ashita.fs.get_directory(records.folder, '.*_ledger\\.tsv', false) or {};
    for _, file in ipairs(files) do
        local name  = file:match('([^\\/]+)$') or file;
        local owner = name:match('^(.+_%d+)_ledger%.tsv$');
        if (owner and owner ~= records.owner) then
            found[#found + 1] = owner;
        end
    end
    table.sort(found);
    records.roster = found;
    records.family = { [records.display_name(records.owner):lower()] = true };
    for _, owner in ipairs(found) do
        records.family[records.display_name(owner):lower()] = true;
    end
end

local function load_other(owner)
    local info = records.others[owner];
    if (info == nil) then
        info = { name = records.display_name(owner), size = 0, entries = {} };
        records.others[owner] = info;
    end
    local file = io.open(('%s%s_ledger.tsv'):fmt(records.folder, owner), 'rb');
    if (not file) then
        return false;
    end
    local size  = file:seek('end') or 0;
    local reset = size < info.size;
    if (reset) then
        info.size    = 0;
        info.entries = {};
    end
    if (size == info.size) then
        file:close();
        return reset;
    end
    file:seek('set', info.size);
    local data = file:read('*a') or '';
    file:close();
    local used = 0;
    for line, stop in data:gmatch('([^\n]*)\n()') do
        used = stop - 1;
        local entry = parse((line:gsub('\r$', '')));
        if (entry) then
            entry.char = info.name;
            info.entries[#info.entries + 1] = entry;
        end
    end
    info.size = info.size + used;
    return reset or used > 0;
end

function records.refresh(clock, who)
    if (records.owner == nil) then
        return who;
    end
    if (clock - records.listed_at >= LIST_EVERY) then
        records.listed_at = clock;
        list_roster();
    end
    local valid = who == 'all' and #records.roster > 0;
    for _, owner in ipairs(records.roster) do
        valid = valid or owner == who;
    end
    if (not valid) then
        who = 'me';
    end
    if (who ~= records.who) then
        records.who       = who;
        records.loaded_at = -math.huge;
        records.version   = records.version + 1;
    end
    if (who == 'all') then
        local before = records.gil;
        if (records.other_gil(clock) ~= before) then
            records.version = records.version + 1;
        end
    end
    if (who ~= 'me' and clock - records.loaded_at >= RELOAD_EVERY) then
        records.loaded_at = clock;
        local changed = false;
        for _, owner in ipairs(records.roster) do
            if ((who == 'all' or who == owner) and load_other(owner)) then
                changed = true;
            end
        end
        if (changed) then
            records.version = records.version + 1;
        end
    end
    return who;
end

local function merge()
    local mine  = records.display_name(records.owner);
    local lists = { records.entries };
    local total = 0;
    for _, entry in ipairs(records.entries) do
        entry.char = mine;
    end
    if (#records.entries == 0) then
        total = records.saved or 0;
    end
    for _, owner in ipairs(records.roster) do
        local info = records.others[owner];
        if (info) then
            lists[#lists + 1] = info.entries;
        end
    end
    for _, other in ipairs(records.gil) do
        local info = records.others[other.owner];
        if (info == nil or #info.entries == 0) then
            total = total + other.gil;
        end
    end
    local heads = {};
    local held  = {};
    for index, list in ipairs(lists) do
        local first = list[1];
        heads[index] = 1;
        held[index]  = first and first.balance and (first.balance - first.amount) or 0;
        total = total + held[index];
    end
    local out = {};
    while (true) do
        local best, when = nil, math.huge;
        for index, list in ipairs(lists) do
            local entry = list[heads[index]];
            if (entry and entry.time < when) then
                best, when = index, entry.time;
            end
        end
        if (best == nil) then
            return out;
        end
        local entry = lists[best][heads[best]];
        if (entry.balance) then
            total = total + entry.balance - held[best];
            held[best] = entry.balance;
        end
        entry.total = total;
        out[#out + 1] = entry;
        heads[best] = heads[best] + 1;
    end
end

function records.active()
    if (records.who == 'me') then
        return records.entries;
    end
    if (records.who ~= 'all') then
        local info = records.others[records.who];
        return info and info.entries or {};
    end
    local cache = records.combined;
    if (not cache or cache.version ~= records.version) then
        cache = { version = records.version, list = merge() };
        records.combined = cache;
    end
    return cache.list;
end

local function transfer(entry)
    return records.who == 'all' and (entry.cat == 'delivery' or entry.cat == 'trade') and entry.who ~= nil and records.family[entry.who:lower()] == true;
end

function records.balance_of(entry)
    if (records.who == 'all') then
        return entry.total;
    end
    return entry.balance;
end

local function quantity(entry)
    if (entry.qty and entry.qty > 1) then
        return (' x%d'):fmt(entry.qty);
    end
    return '';
end

local function counterpart(entry)
    if (entry.who == nil) then
        return '';
    end
    if (entry.verb == 'Bought' or entry.verb == 'Received') then
        return ' from ' .. entry.who;
    end
    if (entry.verb == 'Sold' or entry.verb == 'Sent') then
        return ' to ' .. entry.who;
    end
    return ' - ' .. entry.who;
end

function records.describe(entry)
    if (entry.text) then
        return entry.text;
    end
    local item = names.item(entry.item);
    local text;
    if (entry.cat == 'mob') then
        text = entry.who or 'Defeated monster';
    elseif (entry.cat == 'regime') then
        text = 'Regime reward' .. (entry.who and (' (' .. entry.who .. ')') or '');
    elseif (entry.cat == 'trade') then
        text = entry.who and ('Trade with ' .. entry.who) or 'Player trade';
    elseif (entry.cat == 'npc') then
        if (entry.verb == 'Trade') then
            text = entry.who and ('Trade to ' .. entry.who) or 'NPC trade';
        else
            text = entry.who or 'Event';
        end
    elseif (entry.cat == 'untracked') then
        text = 'Changed while not tracking';
    elseif (entry.cat == 'ah' and entry.verb == 'Sold' and item == nil) then
        text = 'Auction sale' .. (entry.who and (' (' .. entry.who .. ')') or '');
    elseif (entry.verb == 'Listing fee') then
        text = 'Listing fee' .. (item and (': ' .. item .. quantity(entry)) or '');
    elseif (entry.verb) then
        text = entry.verb .. (item and (' ' .. item .. quantity(entry)) or '') .. counterpart(entry);
    elseif (entry.who) then
        text = entry.who;
    elseif (entry.cat == 'other') then
        text = 'Unknown source';
    else
        text = records.LABEL[entry.cat] or 'Unknown source';
    end
    entry.text = text;
    return text;
end

function records.source(entry)
    if (entry.cat == 'mob' or entry.cat == 'trade' or (entry.cat == 'npc' and entry.verb == nil)) then
        return entry.who or records.describe(entry);
    end
    if (entry.item) then
        local verb = entry.verb == 'Listing fee' and 'Listing fee:' or entry.verb;
        return (verb and (verb .. ' ') or '') .. names.item(entry.item);
    end
    return records.describe(entry);
end

function records.day_key(stamp)
    return tonumber(os.date('%Y%m%d', stamp));
end

local function date_of(key)
    return { year = math.floor(key / 10000), month = math.floor(key / 100) % 100, day = key % 100, hour = 12 };
end

function records.day_time(key)
    local date = date_of(key);
    date.hour = 0;
    return os.time(date);
end

function records.shift(key, days)
    local date = date_of(key);
    date.day = date.day + days;
    return records.day_key(os.time(date));
end

function records.day_label(key, pattern)
    return os.date(pattern or '%a %m/%d', os.time(date_of(key)));
end

function records.range_label(from, to, now)
    local year    = math.floor(records.day_key(now) / 10000);
    local pattern = '%m/%d';
    if (math.floor(from / 10000) ~= year or math.floor(to / 10000) ~= year) then
        pattern = '%m/%d/%y';
    end
    if (from == to) then
        return records.day_label(from, pattern);
    end
    return ('%s - %s'):fmt(records.day_label(from, pattern), records.day_label(to, pattern));
end

local function moment(stamp, now)
    local pattern = '%a %m/%d %H:%M';
    if (records.day_key(stamp) == records.day_key(now)) then
        pattern = '%H:%M';
    elseif (os.date('%Y', stamp) ~= os.date('%Y', now)) then
        pattern = '%a %m/%d/%y %H:%M';
    end
    return os.date(pattern, stamp);
end

function records.duration(seconds)
    local minutes = math.floor(math.max(0, seconds) / 60);
    if (minutes < 60) then
        return ('%dm'):fmt(minutes);
    end
    local hours = math.floor(minutes / 60);
    if (hours < 48) then
        return ('%dh %dm'):fmt(hours, minutes % 60);
    end
    return ('%dd %dh'):fmt(math.floor(hours / 24), hours % 24);
end

local function days_text(from, to)
    local count = math.floor((records.day_time(to) - records.day_time(from)) / DAY + 0.5) + 1;
    return count == 1 and '1 day' or ('%s days'):fmt(records.commas(count));
end

function records.span_label(period, now, from, to, oldest)
    if (period == 'session') then
        return ('Since %s  (%s)'):fmt(moment(records.session, now), records.duration(now - records.session));
    elseif (period == 'today') then
        return records.day_label(records.day_key(now), '%A %m/%d/%Y');
    elseif (period == 'week' or period == 'month') then
        return 'Since ' .. moment((records.span(period, now)), now);
    elseif (period == 'range' and from and to and from > 0 and to >= from) then
        if (from == to) then
            return records.day_label(from, '%A %m/%d/%Y');
        end
        return ('%s - %s  (%s)'):fmt(records.day_label(from, '%a %m/%d/%y'), records.day_label(to, '%a %m/%d/%y'), days_text(from, to));
    end
    if (not oldest) then
        return 'Nothing recorded yet';
    end
    local first = records.day_key(oldest);
    return ('Since %s  (%s)'):fmt(records.day_label(first, '%a %m/%d/%Y'), days_text(first, records.day_key(now)));
end

function records.span(period, now, from, to)
    if (period == 'session') then
        return records.session, math.huge;
    elseif (period == 'today') then
        return records.day_time(records.day_key(now)), math.huge;
    elseif (period == 'week') then
        return now - 7 * DAY, math.huge;
    elseif (period == 'month') then
        return now - 30 * DAY, math.huge;
    elseif (period == 'range' and from and to and from > 0 and to >= from) then
        return records.day_time(from), records.day_time(records.shift(to, 1));
    end
    return 0, math.huge;
end

local function day_of(entry)
    local day = rawget(entry, 'day');
    if (day == nil) then
        day = records.day_key(entry.time);
        entry.day = day;
    end
    return day;
end

records.day_of = day_of;

local function counted(entry, since, before, period)
    return entry.time >= since and entry.time < before and entry.amount ~= 0 and not (period == 'session' and entry.cat == 'untracked') and not transfer(entry);
end

local function fresh(cache, now)
    return cache and cache.version == records.version and cache.stamp == math.floor(now / 60);
end

local function top(map, total_key)
    local list = T{};
    for _, row in pairs(map) do
        list:append(row);
    end
    table.sort(list, function (a, b)
        return a[total_key] > b[total_key];
    end);
    while (#list > TOP_COUNT) do
        table.remove(list);
    end
    return list;
end

function records.stats(period, now, from, to)
    local key   = ('stats|%s|%d|%d'):fmt(period, from or 0, to or 0);
    local cache = records.cache[key];
    if (fresh(cache, now)) then
        return cache.stats;
    end

    local since, before = records.span(period, now, from, to);
    local cats   = {};
    local income = {};
    local spend  = {};
    local stats  = T{ earned = 0, spent = 0, count = 0, moved = 0, cats = cats, oldest = false, since = since };
    for _, entry in ipairs(records.active()) do
        if (entry.time >= since and entry.time < before and entry.amount ~= 0 and transfer(entry)) then
            stats.moved = stats.moved + 1;
        elseif (counted(entry, since, before, period)) then
            local cat = cats[entry.cat];
            if (cat == nil) then
                cat = T{ earned = 0, spent = 0, count = 0 };
                cats[entry.cat] = cat;
            end
            local key  = records.source(entry);
            local side = entry.amount > 0 and income or spend;
            local row  = side[key];
            if (row == nil) then
                row = T{ label = key, cat = entry.cat, total = 0, count = 0 };
                side[key] = row;
            end
            row.total = row.total + math.abs(entry.amount);
            row.count = row.count + 1;
            cat.count = cat.count + 1;
            if (entry.amount > 0) then
                cat.earned   = cat.earned + entry.amount;
                stats.earned = stats.earned + entry.amount;
            else
                cat.spent   = cat.spent - entry.amount;
                stats.spent = stats.spent - entry.amount;
            end
            stats.count = stats.count + 1;
            stats.oldest = stats.oldest or entry.time;
        end
    end
    stats.income = top(income, 'total');
    stats.spend  = top(spend, 'total');
    records.cache[key] = { version = records.version, stamp = math.floor(now / 60), stats = stats };
    return stats;
end

local function tally(row, amount)
    if (amount > 0) then
        row.earned = row.earned + amount;
    else
        row.spent = row.spent - amount;
    end
    row.entries = row.entries + 1;
end

function records.days(period, now, from, to)
    local key   = ('days|%s|%d|%d'):fmt(period, from or 0, to or 0);
    local cache = records.cache[key];
    if (fresh(cache, now)) then
        return cache.list, cache.map;
    end
    local since, before = records.span(period, now, from, to);
    local list    = {};
    local map     = {};
    local entries = records.active();
    for index = #entries, 1, -1 do
        local entry = entries[index];
        if (counted(entry, since, before, period)) then
            local day = day_of(entry);
            local row = map[day];
            if (row == nil) then
                row = { day = day, earned = 0, spent = 0, entries = 0, close = records.balance_of(entry) };
                map[day] = row;
                list[#list + 1] = row;
            end
            tally(row, entry.amount);
        end
    end
    table.sort(list, function (a, b)
        return a.day > b.day;
    end);
    records.cache[key] = { version = records.version, stamp = math.floor(now / 60), list = list, map = map };
    return list, map;
end

function records.day_totals()
    local cache = records.cache.totals;
    if (cache and cache.version == records.version) then
        return cache.map;
    end
    local map = {};
    for _, entry in ipairs(records.active()) do
        if (entry.amount ~= 0 and not transfer(entry)) then
            local day = day_of(entry);
            local row = map[day];
            if (row == nil) then
                row = { earned = 0, spent = 0, entries = 0 };
                map[day] = row;
            end
            tally(row, entry.amount);
        end
    end
    records.cache.totals = { version = records.version, map = map };
    return map;
end

local function matches(entry, query, needle)
    if (query.cat ~= nil and entry.cat ~= query.cat) then
        return false;
    end
    if ((query.side == 'gain' and entry.amount < 0) or (query.side == 'loss' and entry.amount > 0)) then
        return false;
    end
    if (needle == nil) then
        return true;
    end
    if (records.who == 'all' and entry.char and entry.char:lower():find(needle, 1, true)) then
        return true;
    end
    return records.describe(entry):lower():find(needle, 1, true) ~= nil or names.zone(entry.zone):lower():find(needle, 1, true) ~= nil;
end

function records.rows(query, now)
    local key   = ('%s|%s|%d|%d|%s|%s|%s|%s'):fmt(records.who, query.period, query.from or 0, query.to or 0, query.cat or '', query.search or '', query.side or 'all', query.order or 'new');
    local cache = records.cache.rows;
    if (fresh(cache, now) and cache.key == key) then
        return cache.items, cache.total, key;
    end
    local since, before = records.span(query.period, now, query.from, query.to);
    local needle  = (query.search or '') ~= '' and query.search:lower() or nil;
    local matched = {};
    local entries = records.active();
    for index = #entries, 1, -1 do
        local entry = entries[index];
        if (counted(entry, since, before, query.period) and matches(entry, query, needle)) then
            matched[#matched + 1] = entry;
        end
    end

    local items = {};
    if (query.order == 'big') then
        table.sort(matched, function (a, b)
            local x, y = math.abs(a.amount), math.abs(b.amount);
            if (x ~= y) then
                return x > y;
            end
            return a.time > b.time;
        end);
        items = matched;
    else
        local oldest = query.order == 'old';
        local header = nil;
        local first, last, step = 1, #matched, 1;
        if (oldest) then
            first, last, step = #matched, 1, -1;
        end
        for index = first, last, step do
            local entry = matched[index];
            local day   = day_of(entry);
            if (header == nil or header.day ~= day) then
                header = { header = true, day = day, earned = 0, spent = 0, entries = 0 };
                items[#items + 1] = header;
            end
            tally(header, entry.amount);
            if (oldest or header.close == nil) then
                header.close = records.balance_of(entry);
            end
            items[#items + 1] = entry;
        end
    end
    records.cache.rows = { key = key, version = records.version, stamp = math.floor(now / 60), items = items, total = #matched };
    return items, #matched, key;
end

local function csv(value)
    local text = tostring(value or '');
    if (text:find('[",]')) then
        return '"' .. text:gsub('"', '""') .. '"';
    end
    return text;
end

function records.export()
    if (records.owner == nil) then
        return nil;
    end
    local target = path('ledger.csv');
    local file   = io.open(target, 'w');
    if (not file) then
        return nil;
    end
    file:write('Date,Amount,Balance,Category,Zone,Details\n');
    for _, entry in ipairs(records.entries) do
        if (entry.amount ~= 0) then
            file:write(table.concat({
                os.date('%Y-%m-%d %H:%M:%S', entry.time),
                tostring(entry.amount),
                tostring(entry.balance or ''),
                csv(records.LABEL[entry.cat] or entry.cat),
                csv(names.zone(entry.zone)),
                csv(records.describe(entry)),
            }, ','), '\n');
        end
    end
    file:close();
    return target;
end

return records;
