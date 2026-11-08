require('common');

local names = require('names');

local GIL         = 0xFFFF;
local HINT_LIFE   = 3.0;
local WAIT        = 1.5;
local KILL_LIFE   = 15.0;
local REGIME_LIFE = 5.0;
local NPC_LIFE    = 15.0;
local WINDOW_LIFE = 60.0;
local NPC_TRADE   = 10.0;
local EVENT_GRACE = 5.0;
local TRADE_GRACE = 3.0;
local EVENT_MAX   = 600.0;

local TRADE_START       = 0;
local TRADE_CONFIRMED   = 2;
local TRADE_UNCONFIRMED = 3;
local TRADE_END         = 9;

local DEFEATS     = T{ [6] = true, [20] = true };
local REGIME_DONE = 559;
local GIL_FOUND   = 565;

local tracker = T{
    balance     = nil,
    zone        = 0,
    my_id       = 0,
    hints       = T{},
    pending     = T{},
    contexts    = T{},
    shop        = T{},
    sell        = nil,
    bazaar      = T{ seller = nil, items = T{} },
    parcels     = T{},
    partner     = nil,
    npc         = nil,
    kill        = nil,
    regime      = nil,
    on_baseline = nil,
    on_change   = nil,
    on_entry    = nil,
};

local function u8(data, offset)
    return data:byte(offset + 1) or 0;
end

local function u16(data, offset)
    local a, b = data:byte(offset + 1, offset + 2);
    return (a or 0) + (b or 0) * 0x100;
end

local function u32(data, offset)
    local a, b, c, d = data:byte(offset + 1, offset + 4);
    return (a or 0) + (b or 0) * 0x100 + (c or 0) * 0x10000 + (d or 0) * 0x1000000;
end

local function text(data, offset, length)
    return names.optional(data:sub(offset + 1, offset + length));
end

local function my_id()
    if (tracker.my_id == 0) then
        tracker.my_id = AshitaCore:GetMemoryManager():GetParty():GetMemberServerId(0);
    end
    return tracker.my_id;
end

local function recent_npc(now)
    local npc = tracker.npc;
    if (npc and now - npc.at <= NPC_LIFE) then
        return npc.name;
    end
    return nil;
end

local function open_context(kind, cat, who, verb, now, life)
    tracker.contexts[kind] = T{ cat = cat, who = who, verb = verb, opened = now, expires = life and (now + life) or nil };
end

local function touch_context(kind, cat, who, now)
    local context = tracker.contexts[kind];
    if (context and context.cat == cat and context.expires and now <= context.expires) then
        context.expires = now + WINDOW_LIFE;
        context.who     = context.who or who;
        return;
    end
    open_context(kind, cat, who, nil, now, WINDOW_LIFE);
end

local function close_context(kind, now, grace)
    local context = tracker.contexts[kind];
    if (context) then
        context.expires = math.min(context.expires or math.huge, now + grace);
    end
end

local function context_who(kind, cat)
    local context = tracker.contexts[kind];
    if (context and context.cat == cat) then
        return context.who;
    end
    return nil;
end

local function current_context(now)
    local best = nil;
    for kind, context in pairs(tracker.contexts) do
        local alive = now - context.opened <= EVENT_MAX;
        if (context.expires) then
            alive = now <= context.expires;
        end
        if (not alive) then
            tracker.contexts[kind] = nil;
        elseif (best == nil or context.opened > best.opened) then
            best = context;
        end
    end
    return best;
end

local function score(source, delta)
    if (source.sign ~= 0 and (delta > 0) ~= (source.sign > 0)) then
        return 0;
    end
    if (source.amount == nil) then
        return 1;
    end
    if (source.amount == math.abs(delta)) then
        return 3;
    end
    return source.loose and 1 or 0;
end

local function best_match(list, value, rate)
    local found, index, top = nil, nil, 0;
    for i, item in ipairs(list) do
        local points = rate(item, value);
        if (points > top) then
            found, index, top = item, i, points;
        end
    end
    return found, index;
end

local function record(change, source)
    source = source or T{ cat = 'other' };
    tracker.on_entry(T{
        time    = change.time,
        amount  = change.delta,
        balance = change.balance,
        zone    = change.zone,
        cat     = source.cat,
        verb    = source.verb,
        who     = source.who,
        item    = source.item,
        qty     = source.qty,
    });
end

local function hint(source, now)
    source.sign = source.sign or 0;
    source.at   = now;
    local change, index = best_match(tracker.pending, source, function (pending, wanted)
        return score(wanted, pending.delta);
    end);
    if (change) then
        table.remove(tracker.pending, index);
        record(change, source);
        return;
    end
    tracker.hints:append(source);
end

function tracker.set_balance(value, now)
    if (tracker.balance == nil) then
        tracker.balance = value;
        tracker.on_baseline(value);
        return;
    end
    local delta = value - tracker.balance;
    if (delta == 0) then
        return;
    end
    tracker.balance = value;
    tracker.on_change(value);

    local change = T{ at = now, time = os.time(), delta = delta, balance = value, zone = tracker.zone, context = current_context(now) };
    local source, index = best_match(tracker.hints, delta, score);
    if (source) then
        table.remove(tracker.hints, index);
        record(change, source);
        return;
    end
    tracker.pending:append(change);
end

function tracker.tick(now)
    while (#tracker.hints > 0 and now - tracker.hints[1].at > HINT_LIFE) do
        table.remove(tracker.hints, 1);
    end
    while (#tracker.pending > 0 and now - tracker.pending[1].at >= WAIT) do
        local change = table.remove(tracker.pending, 1);
        record(change, change.context);
    end
end

function tracker.trading(now)
    local context = tracker.contexts.trade;
    return context ~= nil and (context.expires == nil or now <= context.expires);
end

function tracker.flush()
    while (#tracker.pending > 0) do
        local change = table.remove(tracker.pending, 1);
        record(change, change.context);
    end
end

function tracker.reset()
    tracker.balance  = nil;
    tracker.pending  = T{};
    tracker.hints    = T{};
    tracker.contexts = T{};
    tracker.npc      = nil;
    tracker.kill     = nil;
    tracker.regime   = nil;
end

local function open_event(index, now)
    open_context('event', 'npc', names.entity(index), nil, now, nil);
end

function tracker.zone_in(data)
    tracker.my_id    = u32(data, 0x04);
    tracker.zone     = u16(data, 0x30);
    tracker.hints    = T{};
    tracker.shop     = T{};
    tracker.sell     = nil;
    tracker.bazaar   = T{ seller = nil, items = T{} };
    tracker.parcels  = T{};
    tracker.partner  = nil;
    tracker.contexts = T{};
    return text(data, 0x84, 16), tracker.my_id;
end

function tracker.packet_in(id, data, now)
    if (id == 0x01E) then
        if (u8(data, 0x08) == 0 and u8(data, 0x09) == 0) then
            tracker.set_balance(u32(data, 0x04), now);
        end
    elseif (id == 0x01F) then
        if (u8(data, 0x0A) == 0 and u8(data, 0x0B) == 0 and u16(data, 0x08) == GIL) then
            tracker.set_balance(u32(data, 0x04), now);
        end
    elseif (id == 0x020) then
        if (u8(data, 0x0E) == 0 and u8(data, 0x0F) == 0 and u16(data, 0x0C) == GIL) then
            tracker.set_balance(u32(data, 0x04), now);
        end
    elseif (id == 0x029) then
        local message = u16(data, 0x18);
        if (DEFEATS[message]) then
            local name = names.entity(u16(data, 0x16));
            if (name) then
                tracker.kill = T{ name = name, at = now };
            end
        elseif (message == REGIME_DONE) then
            tracker.regime = now;
        elseif (message == GIL_FOUND and u32(data, 0x08) == my_id()) then
            local regime = tracker.regime ~= nil and now - tracker.regime <= REGIME_LIFE;
            local kill   = tracker.kill ~= nil and now - tracker.kill.at <= KILL_LIFE;
            hint(T{ cat = regime and 'regime' or 'mob', sign = 1, amount = u32(data, 0x0C), who = kill and tracker.kill.name or nil }, now);
        end
    elseif (id == 0x032) then
        open_event(u16(data, 0x08), now);
    elseif (id == 0x034) then
        open_event(u16(data, 0x28), now);
    elseif (id == 0x03C) then
        if (u16(data, 0x04) == 0) then
            tracker.shop = T{};
        end
        for base = 0x08, #data - 12, 12 do
            local item = u16(data, base + 4);
            if (item ~= 0) then
                tracker.shop[u8(data, base + 6)] = T{ item = item, price = u32(data, base) };
            end
        end
        touch_context('window', 'shop', recent_npc(now), now);
    elseif (id == 0x03E) then
        touch_context('window', 'shop', recent_npc(now), now);
    elseif (id == 0x03D) then
        if (tracker.sell) then
            tracker.sell.price = u32(data, 0x04);
        end
    elseif (id == 0x086) then
        touch_context('window', 'guild', recent_npc(now), now);
    elseif (id == 0x082 or id == 0x084) then
        local count = u8(data, 0x06);
        if (count > 0) then
            local buy = id == 0x082;
            touch_context('window', 'guild', recent_npc(now), now);
            hint(T{ cat = 'guild', sign = buy and -1 or 1, verb = buy and 'Bought' or 'Sold', item = u16(data, 0x04), qty = count, who = context_who('window', 'guild') }, now);
        end
    elseif (id == 0x021) then
        tracker.partner = names.entity(u16(data, 0x08));
    elseif (id == 0x022) then
        local kind = u32(data, 0x08);
        if (kind == TRADE_START) then
            open_context('trade', 'trade', names.entity(u16(data, 0x0C)) or tracker.partner, nil, now, nil);
        elseif (kind == TRADE_END) then
            close_context('trade', now, TRADE_GRACE);
        elseif (kind ~= TRADE_CONFIRMED and kind ~= TRADE_UNCONFIRMED) then
            close_context('trade', now, 0);
        end
    elseif (id == 0x04B) then
        if (u8(data, 0x05) == 1 and #data >= 0x3C and u16(data, 0x30) == GIL) then
            tracker.parcels[u8(data, 0x06)] = T{ from = text(data, 0x14, 16), amount = u32(data, 0x38) };
        end
    elseif (id == 0x105) then
        tracker.bazaar.items[u8(data, 0x10)] = T{ item = u16(data, 0x0E), price = u32(data, 0x04) };
    elseif (id == 0x10A) then
        hint(T{ cat = 'bazaar', sign = 1, verb = 'Sold', qty = u32(data, 0x04), item = u16(data, 0x08), who = text(data, 0x0A, 16) }, now);
    end
end

function tracker.packet_out(id, data, now)
    if (id == 0x01A) then
        if (u16(data, 0x0A) == 0) then
            local name = names.entity(u16(data, 0x08));
            if (name) then
                tracker.npc = T{ name = name, at = now };
            end
        end
    elseif (id == 0x032) then
        tracker.partner = names.entity(u16(data, 0x08));
    elseif (id == 0x036) then
        open_context('npc_trade', 'npc', names.entity(u16(data, 0x3A)), 'Trade', now, NPC_TRADE);
    elseif (id == 0x05B) then
        if (u16(data, 0x0E) == 0) then
            close_context('event', now, EVENT_GRACE);
        end
    elseif (id == 0x083) then
        local entry = tracker.shop[u16(data, 0x0A)];
        local qty   = u32(data, 0x04);
        touch_context('window', 'shop', recent_npc(now), now);
        hint(T{ cat = 'shop', sign = -1, verb = 'Bought', item = entry and entry.item, qty = qty, amount = entry and entry.price * qty, loose = true, who = context_who('window', 'shop') }, now);
    elseif (id == 0x084) then
        tracker.sell = T{ qty = u32(data, 0x04), item = u16(data, 0x08) };
    elseif (id == 0x085) then
        local sell = tracker.sell;
        if (sell and u16(data, 0x04) == 1) then
            tracker.sell = nil;
            touch_context('window', 'shop', recent_npc(now), now);
            hint(T{ cat = 'shop', sign = 1, verb = 'Sold', item = sell.item, qty = sell.qty, amount = sell.price and sell.price * sell.qty, loose = true, who = context_who('window', 'shop') }, now);
        end
    elseif (id == 0x04D) then
        local command, box, slot = u8(data, 0x04), u8(data, 0x05), u8(data, 0x06);
        touch_context('window', 'delivery', nil, now);
        if (command == 0x0A and box == 1 and tracker.parcels[slot]) then
            local parcel = tracker.parcels[slot];
            local ah     = parcel.from ~= nil and parcel.from:sub(1, 2) == 'AH';
            tracker.parcels[slot] = nil;
            hint(T{ cat = ah and 'ah' or 'delivery', sign = 1, amount = parcel.amount, loose = true, verb = ah and 'Sold' or 'Received', who = parcel.from }, now);
        elseif (command == 0x02 and box == 2 and u8(data, 0x07) == 0) then
            hint(T{ cat = 'delivery', sign = -1, amount = u32(data, 0x08), loose = true, verb = 'Sent', who = text(data, 0x10, 16) }, now);
        end
    elseif (id == 0x04E) then
        local command = u8(data, 0x04);
        touch_context('window', 'ah', nil, now);
        if (command == 0x0E) then
            local item = u16(data, 0x0C);
            hint(T{ cat = 'ah', sign = -1, verb = 'Bought', item = item, qty = u32(data, 0x10) == 0 and names.stack(item) or 1, amount = u32(data, 0x08) }, now);
        elseif (command == 0x0B) then
            local listed = AshitaCore:GetMemoryManager():GetInventory():GetContainerItem(0, u16(data, 0x0C));
            local item   = listed and listed.Id ~= 0 and listed.Id or nil;
            hint(T{ cat = 'ah', sign = -1, verb = 'Listing fee', item = item, qty = u32(data, 0x10) == 0 and names.stack(item) or 1 }, now);
        end
    elseif (id == 0x105) then
        tracker.bazaar = T{ seller = names.entity(u16(data, 0x08)), items = T{} };
        open_context('window', 'bazaar', tracker.bazaar.seller, nil, now, WINDOW_LIFE);
    elseif (id == 0x106) then
        local entry = tracker.bazaar.items[u8(data, 0x04)];
        touch_context('window', 'bazaar', tracker.bazaar.seller, now);
        hint(T{ cat = 'bazaar', sign = -1, verb = 'Bought', item = entry and entry.item, qty = u32(data, 0x08), who = tracker.bazaar.seller }, now);
    end
end

return tracker;
