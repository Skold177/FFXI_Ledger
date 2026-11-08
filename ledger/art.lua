require('common');

local chat = require('chat');

local art = T{
    styles   = T{},
    tried    = T{},
    textures = T{},
};

local CLASSIC_FILE = 19;
local IMAGE_CHUNK  = 0x20;
local LAYOUT_CHUNK = 0x31;
local DXT1_IMAGE   = 0xA1;
local DXT1_DATA    = 69;
local PART_COUNT   = 0x51;
local PART_START   = 0x53;
local PART_SIZE    = 62;

local function u32(data, offset)
    local a, b, c, d = data:byte(offset + 1, offset + 4);
    return a + b * 0x100 + c * 0x10000 + d * 0x1000000;
end

local function s16(data, offset)
    local a, b = data:byte(offset + 1, offset + 2);
    local value = a + b * 0x100;
    if (value >= 0x8000) then
        value = value - 0x10000;
    end
    return value;
end

local function le(value)
    return string.char(value % 0x100, math.floor(value / 0x100) % 0x100, math.floor(value / 0x10000) % 0x100, math.floor(value / 0x1000000) % 0x100);
end

local function chunk(data, wanted, name)
    local pos = 0;
    while (pos + 16 <= #data) do
        local packed = u32(data, pos + 4);
        local size   = math.floor(packed / 128) * 16;
        if (size == 0) then
            return nil;
        end
        if (packed % 128 == wanted and (not name or data:sub(pos + 1, pos + 4) == name)) then
            return pos + 16, size - 16;
        end
        pos = pos + size;
    end
    return nil;
end

function art.dds(data, name)
    local body = chunk(data, IMAGE_CHUNK, name or 'newt');
    if (not body) then
        return nil;
    end
    local width  = u32(data, body + 21);
    local height = u32(data, body + 25);
    local bytes  = width * height / 2;
    if (data:byte(body + 1) ~= DXT1_IMAGE or data:sub(body + 58, body + 61) ~= '1TXD' or width < 4 or width > 1024 or height < 4 or height > 1024 or body + DXT1_DATA + bytes > #data) then
        return nil;
    end
    local header = 'DDS ' .. le(124) .. le(0x81007) .. le(height) .. le(width) .. le(bytes) .. le(0) .. le(1) .. string.rep(le(0), 11)
        .. le(32) .. le(4) .. 'DXT1' .. string.rep(le(0), 5)
        .. le(0x1000) .. string.rep(le(0), 4);
    return header .. data:sub(body + DXT1_DATA + 1, body + DXT1_DATA + bytes);
end

function art.layout(data)
    local body = chunk(data, LAYOUT_CHUNK);
    if (not body) then
        return nil;
    end
    local parts = T{};
    for index = 0, (data:byte(body + PART_COUNT + 1) or 0) - 1 do
        local at = body + PART_START + PART_SIZE * index;
        if (at + PART_SIZE > #data) then
            break;
        end
        local colors = T{};
        for corner = 0, 3 do
            local r, g, b, a = data:byte(at + 27 + corner * 4, at + 30 + corner * 4);
            colors:append(T{ r / 128, g / 128, b / 128, a / 128 });
        end
        parts:append(T{
            name   = data:sub(at + 47, at + 62):match('(%S+)%s*$'),
            width  = s16(data, at + 17),
            height = s16(data, at + 19),
            right  = data:byte(at + 22) > 1,
            bottom = data:byte(at + 24) > 1,
            colors = colors,
        });
    end
    return parts;
end

local function texture(dds)
    local ffi = require('ffi');
    local d3d = require('d3d8');
    local C   = ffi.C;
    local out = ffi.new('IDirect3DTexture8*[1]');
    if (C.D3DXCreateTextureFromFileInMemoryEx(d3d.get_device(), dds, #dds, 0xFFFFFFFF, 0xFFFFFFFF, 1, 0, C.D3DFMT_A8R8G8B8, C.D3DPOOL_MANAGED, C.D3DX_DEFAULT, C.D3DX_DEFAULT, 0, nil, nil, out) ~= C.S_OK) then
        return nil;
    end
    local held = d3d.gc_safe_release(ffi.cast('IDirect3DTexture8*', out[0]));
    art.textures:append(held);
    return tonumber(ffi.cast('uint32_t', held));
end

local function load(file)
    local name = ('ROM/0/%d.DAT'):fmt(file);
    local path = AshitaCore:GetResourceManager():GetFilePath(file);
    local handle = path and io.open(path, 'rb');
    if (not handle) then
        return nil, ('could not open %s'):fmt(name);
    end
    local data = handle:read('*a');
    handle:close();

    local style = T{ parts = art.layout(data) };
    for _, piece in ipairs({ { 'background', 'newt' }, { 'corner', 'corn' }, { 'edge', 'hfr1' }, { 'side', 'vfr1' } }) do
        local dds = art.dds(data, piece[2]);
        if (not dds) then
            return nil, ('%s has no %s texture'):fmt(name, piece[2]);
        end
        style[piece[1]] = texture(dds);
        if (not style[piece[1]]) then
            return nil, ('Direct3D could not load the textures in %s'):fmt(name);
        end
    end
    if (not style.parts) then
        return nil, ('%s has no window layout'):fmt(name);
    end
    return style;
end

function art.style(file)
    if (art.tried[file]) then
        return art.styles[file];
    end
    art.tried[file] = true;

    local ok, style, reason = pcall(load, file);
    if (ok and style) then
        art.styles[file] = style;
    else
        print(chat.header(addon.name):append(chat.warning(('Theme art: %s, using a plain background.'):fmt(ok and reason or tostring(style)))));
    end
    return art.styles[file];
end

function art.window()
    local style = art.style(CLASSIC_FILE);
    return style and style.background;
end

return art;
