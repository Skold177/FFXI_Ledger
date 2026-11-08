require('common');

local tracker = require('tracker');
local bags    = require('bags');
local names   = require('names');

local INVENTORY   = 0;
local SAFE        = 1;
local STORAGE     = 2;
local LOCKER      = 4;
local SATCHEL     = 5;
local GIL         = 0xFFFF;
local ANY_SLOT    = 0x52;
local REPLY_WAIT  = 3.0;
local SETTLE      = 0.25;
local EVENT_GRACE = 2.0;
local TALK_HOLD   = 2.0;
local NPC_HOLD    = 3.0;
local SYNTH_MAX   = 45.0;
local SYNTH_GRACE = 1.0;
local SELL_MAX    = 10.0;
local STATUS_LIFE = 6.0;
local QUEUE_MAX   = 80;
local ASK_LIFE    = 10.0;
local MYROOM      = 1;
local ZONE_CHANGE = 2;
local FERETORY    = 285;
local USABLE_SIZE = 0x24;

local mover = {
    ORDER       = { INVENTORY, SATCHEL, SAFE, STORAGE, LOCKER },
    MOVABLE     = { [INVENTORY] = true, [SATCHEL] = true, [SAFE] = true, [STORAGE] = true, [LOCKER] = true },
    HOME        = { [SAFE] = true, [STORAGE] = true },
    locker      = false,
    queue       = {},
    pending     = nil,
    ready_at    = 0,
    hold_until  = 0,
    synth_until = 0,
    sell_until  = 0,
    in_event    = false,
    zoning      = false,
    status      = nil,
    home        = false,
    appraised   = nil,
    zone        = 0,
    asked       = -math.huge,
    walked      = true,
};

local function u8(data, offset)
    return data:byte(offset + 1) or 0;
end

local function u16(data, offset)
    local a, b = data:byte(offset + 1, offset + 2);
    return (a or 0) + (b or 0) * 0x100;
end

local function u32(data, offset)
    return u16(data, offset) + u16(data, offset + 2) * 0x10000;
end

local function hold(until_time)
    mover.hold_until = math.max(mover.hold_until, until_time);
end

function mover.say(text, now)
    mover.status = { text = text, at = now };
end

function mover.clear()
    mover.queue   = {};
    mover.pending = nil;
end

function mover.status_text(now)
    local moving = #mover.queue + (mover.pending and 1 or 0);
    if (moving > 0) then
        return ('Moving %d %s...'):fmt(moving, moving == 1 and 'item' or 'items'), false;
    end
    if (mover.status and now - mover.status.at < STATUS_LIFE) then
        return mover.status.text, true;
    end
    return nil;
end

function mover.blocked(now)
    local memory = AshitaCore:GetMemoryManager();
    if (memory:GetParty():GetMemberIsActive(0) == 0 or mover.zoning or bags.loading or memory:GetPlayer():GetIsZoning() ~= 0) then
        return 'Wait until zoning finishes.';
    end
    if (mover.in_event or now < mover.hold_until) then
        return 'Not while talking to an NPC or in a cutscene.';
    end
    if (tracker.trading(now)) then
        return 'Not during a trade.';
    end
    if (now < mover.synth_until) then
        return 'Not while synthesizing.';
    end
    if (now < mover.sell_until) then
        return 'Not while selling to a shop.';
    end
    return nil;
end

local function shut(bag)
    if (mover.HOME[bag] and not mover.home) then
        return ('%s only opens in your own Mog House.'):fmt(bags.LABEL[bag]);
    end
    if (bag == LOCKER and not mover.locker) then
        return 'Your Mog Locker lease does not reach here.';
    end
    return nil;
end

mover.shut = shut;

function mover.usable(bag)
    return mover.MOVABLE[bag] == true and bags.state[bag].max > 0 and shut(bag) == nil;
end

function mover.targets(from)
    local list = {};
    for _, bag in ipairs(mover.ORDER) do
        if (bag ~= from and mover.usable(bag)) then
            list[#list + 1] = bag;
        end
    end
    return list;
end

function mover.group()
    local list = {};
    for _, bag in ipairs(mover.ORDER) do
        if (bags.state[bag].max > 0) then
            list[#list + 1] = bag;
        end
    end
    return list;
end

function mover.check(from, slot, to, id)
    if (from == to or not mover.MOVABLE[from] or not mover.MOVABLE[to]) then
        return 'Items only move between Inventory, Mog Satchel, Mog Safe, Storage and Mog Locker.';
    end
    local reason = shut(from) or shut(to);
    if (reason) then
        return reason;
    end
    local inventory = AshitaCore:GetMemoryManager():GetInventory();
    local from_max  = inventory:GetContainerCountMax(from) or 0;
    local to_max    = inventory:GetContainerCountMax(to) or 0;
    if (from_max == 0 or to_max == 0) then
        return ('%s is not available.'):fmt(bags.LABEL[to_max == 0 and to or from]);
    end
    local item = slot >= 1 and slot <= from_max and inventory:GetContainerItem(from, slot) or nil;
    if (item == nil or item.Id == 0 or item.Id == GIL or (item.Count or 0) == 0 or (id ~= nil and item.Id ~= id)) then
        return 'That item is no longer there.';
    end
    if ((item.Flags or 0) ~= 0) then
        return 'Equipped or locked items stay put.';
    end
    if ((item.Price or 0) ~= 0) then
        return 'Items for sale in your bazaar stay put.';
    end
    if (from == INVENTORY and slot == mover.appraised) then
        return 'That item is waiting to be sold to the shop. Sell it or zone first.';
    end
    local free = 0;
    for index = 1, to_max do
        local other = inventory:GetContainerItem(to, index);
        if (other == nil or other.Id == 0) then
            free = free + 1;
        end
    end
    if (free == 0) then
        return ('%s is full.'):fmt(bags.LABEL[to]);
    end
    return nil, item;
end

function mover.reason(from, slot, to, id, now)
    return mover.blocked(now) or (mover.check(from, slot, to, id));
end

function mover.request(from, slot, to, id, now)
    local reason = mover.reason(from, slot, to, id, now);
    if (reason) then
        mover.say(reason, now);
        return false;
    end
    if (mover.pending and mover.pending.from == from and mover.pending.slot == slot) then
        return false;
    end
    for _, move in ipairs(mover.queue) do
        if (move.from == from and move.slot == slot) then
            return false;
        end
    end
    if (#mover.queue >= QUEUE_MAX) then
        return false;
    end
    mover.queue[#mover.queue + 1] = { from = from, slot = slot, to = to, id = id };
    return true;
end

function mover.tick(now)
    local pending = mover.pending;
    if (pending) then
        local item = AshitaCore:GetMemoryManager():GetInventory():GetContainerItem(pending.from, pending.slot);
        if (item == nil or item.Id ~= pending.id or item.Count ~= pending.count) then
            mover.pending  = nil;
            mover.ready_at = now + SETTLE;
        elseif (now - pending.at > REPLY_WAIT) then
            mover.clear();
            mover.say(('%s did not move, so Ledger stopped moving items.'):fmt(names.item(pending.id)), now);
        end
        return;
    end
    if (#mover.queue == 0 or now < mover.ready_at) then
        return;
    end
    local blocked = mover.blocked(now);
    if (blocked) then
        mover.clear();
        mover.say(blocked, now);
        return;
    end
    local move = table.remove(mover.queue, 1);
    local reason, item = mover.check(move.from, move.slot, move.to, move.id);
    if (reason) then
        mover.say(reason, now);
        return;
    end
    local count = item.Count;
    AshitaCore:GetPacketManager():AddOutgoingPacket(0x29, {
        0x29, 0x06, 0x00, 0x00,
        count % 0x100, math.floor(count / 0x100) % 0x100, math.floor(count / 0x10000) % 0x100, math.floor(count / 0x1000000) % 0x100,
        move.from, move.to, move.slot, ANY_SLOT,
    });
    mover.pending = { from = move.from, slot = move.slot, id = item.Id, count = count, at = now };
end

function mover.packet_in(id, data, now)
    if (id == 0x00A) then
        local zone   = u16(data, 0x30);
        local inside = u32(data, 0x80) == MYROOM and zone ~= FERETORY;
        mover.home      = inside and (mover.walked or (mover.home and zone == mover.zone));
        mover.zone      = zone;
        mover.zoning    = false;
        mover.in_event  = u16(data, 0x62) ~= 0;
        mover.appraised = nil;
        mover.clear();
    elseif (id == 0x00B) then
        mover.walked    = u8(data, 0x04) ~= ZONE_CHANGE or now - mover.asked <= ASK_LIFE;
        mover.zoning    = true;
        mover.appraised = nil;
        mover.clear();
    elseif (id == 0x01C) then
        mover.locker = u16(data, USABLE_SIZE + LOCKER * 2) > 0;
    elseif (id == 0x032 or id == 0x033 or id == 0x034) then
        mover.in_event = true;
    elseif (id == 0x06F and now < mover.synth_until) then
        mover.synth_until = now + SYNTH_GRACE;
    end
end

function mover.packet_out(id, data, now)
    if ((id == 0x05B and u16(data, 0x0E) == 0) or (id == 0x05C and u8(data, 0x1E) == 0)) then
        mover.in_event = false;
        hold(now + EVENT_GRACE);
    elseif (id == 0x01A and u16(data, 0x0A) == 0) then
        hold(now + TALK_HOLD);
    elseif (id == 0x036) then
        hold(now + NPC_HOLD);
    elseif (id == 0x096) then
        mover.synth_until = now + SYNTH_MAX;
    elseif (id == 0x084) then
        mover.sell_until = now + SELL_MAX;
        mover.appraised  = u8(data, 0x0A);
    elseif (id == 0x085) then
        mover.sell_until = math.min(mover.sell_until, now + SETTLE);
        mover.appraised  = nil;
    elseif (id == 0x05E) then
        mover.asked = now;
    end
end

return mover;
