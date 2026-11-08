require('common');

local chat = require('chat');

local icon = {
    tried   = false,
    id      = nil,
    texture = nil,
};

local function load()
    local ffi  = require('ffi');
    local d3d  = require('d3d8');
    local C    = ffi.C;
    local path = ('%s\\assets\\gil.png'):fmt(addon.path);
    local out  = ffi.new('IDirect3DTexture8*[1]');
    if (C.D3DXCreateTextureFromFileA(d3d.get_device(), path, out) ~= C.S_OK) then
        return nil, 'could not load assets\\gil.png';
    end
    icon.texture = d3d.gc_safe_release(ffi.cast('IDirect3DTexture8*', out[0]));
    return tonumber(ffi.cast('uint32_t', icon.texture));
end

function icon.gil()
    if (icon.tried) then
        return icon.id;
    end
    icon.tried = true;

    local ok, id, reason = pcall(load);
    if (ok and id) then
        icon.id = id;
    else
        print(chat.header(addon.name):append(chat.warning(('Gil icon: %s, drawing a plain coin.'):fmt(ok and reason or tostring(id)))));
    end
    return icon.id;
end

return icon;
