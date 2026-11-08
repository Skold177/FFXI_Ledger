require('common');

local WIDE = T{
    [0x8140] = ' ',
    [0x8145] = '- ',
    [0x8146] = ':',
    [0x8148] = '?',
    [0x8149] = '!',
    [0x815E] = '/',
    [0x8160] = '~',
    [0x8169] = '(',
    [0x816A] = ')',
    [0x817B] = '+',
    [0x817C] = '-',
    [0x8181] = '=',
};

local names = T{
    items     = T{},
    zones     = T{},
    lookups   = {},
    key_items = {},
};

function names.clean(text)
    if (type(text) ~= 'string') then
        return '';
    end
    local out = T{};
    local pos = 1;
    while (pos <= #text) do
        local byte = text:byte(pos);
        if (byte == 0) then
            break;
        end
        if ((byte >= 0x81 and byte <= 0x9F) or (byte >= 0xE0 and byte <= 0xFC)) then
            out:append(WIDE[byte * 0x100 + (text:byte(pos + 1) or 0)] or '');
            pos = pos + 2;
        else
            if (byte >= 0x20 and byte < 0x7F) then
                out:append(string.char(byte));
            end
            pos = pos + 1;
        end
    end
    return table.concat(out);
end

function names.optional(text)
    local cleaned = names.clean(text);
    if (cleaned == '') then
        return nil;
    end
    return cleaned;
end

function names.item(id)
    if (id == nil or id == 0) then
        return nil;
    end
    local cached = names.items[id];
    if (cached) then
        return cached;
    end
    local item = AshitaCore:GetResourceManager():GetItemById(id);
    local name = item and names.optional(item.Name and item.Name[1]) or ('Item %d'):fmt(id);
    names.items[id] = name;
    return name;
end

function names.terms(id)
    local cached = names.lookups[id];
    if (cached) then
        return cached;
    end
    local item  = AshitaCore:GetResourceManager():GetItemById(id);
    local short = names.item(id):lower();
    local full  = item and names.optional(item.LogNameSingular and item.LogNameSingular[1]);
    local list  = { short };
    if (full and full:lower() ~= short) then
        list[2] = full:lower();
    end
    names.lookups[id] = list;
    return list;
end

function names.key_item(id)
    local cached = names.key_items[id];
    if (cached) then
        return cached;
    end
    local name = names.optional(AshitaCore:GetResourceManager():GetString('keyitems.names', id)) or ('Key Item %d'):fmt(id);
    names.key_items[id] = name;
    return name;
end

function names.stack(id)
    local item = id and AshitaCore:GetResourceManager():GetItemById(id);
    return item and item.StackSize or 1;
end

function names.zone(id)
    if (id == nil or id == 0) then
        return '';
    end
    local cached = names.zones[id];
    if (cached) then
        return cached;
    end
    local name = names.optional(AshitaCore:GetResourceManager():GetString('zones.names', id)) or ('Zone %d'):fmt(id);
    names.zones[id] = name;
    return name;
end

function names.entity(index)
    if (index == nil or index == 0 or index >= 0x900) then
        return nil;
    end
    local memory = AshitaCore:GetMemoryManager();
    if (index == memory:GetParty():GetMemberTargetIndex(0)) then
        return nil;
    end
    return names.optional(memory:GetEntity():GetName(index));
end

return names;
