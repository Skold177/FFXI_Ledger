require('common');

local LIMIT = 256;

local icons = T{
    cache   = T{},
    retired = T{},
    count   = 0,
};

local function load(id)
    local item = AshitaCore:GetResourceManager():GetItemById(id);
    if (item == nil or item.Bitmap == nil or (item.ImageSize or 0) == 0) then
        return nil;
    end

    local ffi = require('ffi');
    local d3d = require('d3d8');
    local C   = ffi.C;
    local out = ffi.new('IDirect3DTexture8*[1]');
    if (C.D3DXCreateTextureFromFileInMemoryEx(d3d.get_device(), item.Bitmap, item.ImageSize, 0xFFFFFFFF, 0xFFFFFFFF, 1, 0, C.D3DFMT_A8R8G8B8, C.D3DPOOL_MANAGED, C.D3DX_DEFAULT, C.D3DX_DEFAULT, 0xFF000000, nil, nil, out) ~= C.S_OK) then
        return nil;
    end
    local texture = d3d.gc_safe_release(ffi.cast('IDirect3DTexture8*', out[0]));
    return T{ texture = texture, id = tonumber(ffi.cast('uint32_t', texture)) };
end

function icons.get(id)
    local entry = icons.cache[id];
    if (entry == nil) then
        if (icons.count >= LIMIT) then
            icons.retired = icons.cache;
            icons.cache   = T{};
            icons.count   = 0;
        end
        local ok, loaded = pcall(load, id);
        entry = (ok and loaded) or false;
        icons.cache[id] = entry;
        icons.count     = icons.count + 1;
    end
    return entry and entry.id or nil;
end

return icons;
