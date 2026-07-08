local success, result = pcall(function()
    local ffi = assert(ffi, "FFI must be enabled")

    ffi.cdef[[
        void* GetModuleHandleA(const char* lpModuleName);
        bool IsBadReadPtr(const void* lp, uintptr_t ucb);
    ]]

    local ref = gui.Reference("World", "Extra")
    local combobox = gui.Combobox(ref, "rc_circle_type", "Crosshair Recoil (FIX)", "Off", "Line", "Fade", "Stroke", "Stroke Animated")
    local rc_color = gui.ColorPicker(combobox, "rc_circle_clr", "Circle Color", 255, 255, 255, 255)
    local rc_speed = gui.Slider(ref, "rc_circle_speed", "Circle Speed", 15, -100, 100)

    local client_base = ffi.cast("uintptr_t", ffi.C.GetModuleHandleA("client.dll"))
    
    local dwEntityList = 38696576
    local m_pCameraServices = 4632
    
    local m_iFOV = 0x290
    local fov_offset_found = false

    local function is_valid_ptr(ptr)
        if not ptr or ptr == ffi.cast("void*", 0) then return false end
        return ffi.C.IsBadReadPtr(ffi.cast("void*", ptr), 8) == false
    end

    local function ReadPtr(base, offset)
        if base == 0 then return 0 end
        local ptr = ffi.cast("uintptr_t*", base + offset)
        if is_valid_ptr(ptr) then return ptr[0] end
        return 0
    end

    local function ReadInt(base, offset)
        if base == 0 then return 0 end
        local ptr = ffi.cast("int*", base + offset)
        if is_valid_ptr(ptr) then return ptr[0] end
        return 0
    end

    local function GetPlayerPtr(entity_list_base, idx)
        if entity_list_base == 0 or idx <= 0 then return 0 end
        local chunk_ptr = ReadPtr(entity_list_base, 8 * bit.rshift(idx, 9) + 16)
        if chunk_ptr == 0 then return 0 end
        return ReadPtr(chunk_ptr, 112 * bit.band(idx, 0x1FF))
    end

    http.Get("https://raw.githubusercontent.com/a2x/cs2-dumper/refs/heads/main/output/offsets.json", function(body)
        if not body or body == "" then return end
        local matchEntityList = string.match(body, '"dwEntityList"%s*:%s*(%d+)')
        if matchEntityList then
            dwEntityList = tonumber(matchEntityList)
            --print("[Spread Circle] dwEntityList parsed from GitHub: 0x" .. string.format("%X", dwEntityList))
        end
    end)

    http.Get("https://raw.githubusercontent.com/a2x/cs2-dumper/refs/heads/main/output/client_dll.json", function(body)
        if not body or body == "" then return end
        local matchCameraServices = string.match(body, '"m_pCameraServices"%s*:%s*(%d+)')
        local matchFov = string.match(body, '"m_iFOV"%s*:%s*(%d+)')
        if matchCameraServices and matchFov then
            m_pCameraServices = tonumber(matchCameraServices)
            m_iFOV = tonumber(matchFov)
            fov_offset_found = true
            --print("[Spread Circle] m_pCameraServices parsed from GitHub: 0x" .. string.format("%X", m_pCameraServices))
            --print("[Spread Circle] FOV Offset parsed from GitHub: 0x" .. string.format("%X", m_iFOV))
        end
    end)

    local function FCR(parent, targetName)
        if not parent or not parent.Children then return nil end
        
        for child in parent:Children() do
            if child:GetName() == targetName then return child end
            local found = FCR(child, targetName)
            if found then return found end
        end
        return nil
    end

    FCR(gui.Reference("World"), "Crosshair Recoil"):SetInvisible(true)

    callbacks.Register("Draw", function()
        local type_val = combobox:GetValue()
        if type_val == 0 then return end

        rc_speed:SetInvisible(type_val ~= 4)

        local lp = entities.GetLocalPlayer()
        if not lp or not lp:IsAlive() then return end

        local w, h = draw.GetScreenSize()
        if not w or w == 0 then return end
        local cx, cy = w / 2, h / 2
        

        local inacc = lp:GetWeaponInaccuracy() or 0
        if inacc <= 0 then return end

        local lp_idx = lp:GetIndex()
        if not lp_idx then return end

        local entity_list = ReadPtr(client_base, dwEntityList)
        if entity_list == 0 then return end

        local player_ptr = GetPlayerPtr(entity_list, lp_idx)
        if player_ptr == 0 then return end

        local camPtr = ReadPtr(player_ptr, m_pCameraServices)
        if camPtr == 0 then return end

        if not fov_offset_found then
            for test_offset = 0x250, 0x2C0, 4 do
                local val_fov        = ReadInt(camPtr, test_offset)
                local val_desired    = ReadInt(camPtr, test_offset + 4)
                
                if val_fov == 40 and val_desired == 90 then
                    m_iFOV = test_offset
                    fov_offset_found = true
                    print("[Spread Circle] Scanner successfully hooked m_iFOV at: 0x" .. string.format("%X", m_iFOV))
                    break
                end
            end
        end

        local fov = ReadInt(camPtr, m_iFOV)
        if not fov or fov <= 0 then fov = 90 end

        local fov_scale = 90 / fov
        local radius = math.floor(inacc * 900 * fov_scale)

        if radius < 2 then radius = 2 end
        if radius > 250 then radius = 250 end
        
        local r, g, b, a = rc_color:GetValue()

        if type_val == 1 then
            draw.Color(r, g, b, a)
            draw.OutlinedCircle(cx, cy, radius)

        elseif type_val == 2 then
            for i = 1, radius do
                local alpha_scale = i / radius

                alpha_scale = alpha_scale * alpha_scale

                draw.Color(r, g, b, math.floor(a * alpha_scale))
                draw.OutlinedCircle(cx, cy, i)
            end

            draw.Color(r, g, b, a)
            draw.OutlinedCircle(cx, cy, radius)
        elseif type_val == 3 or type_val == 4 then
            local rotation_offset = 0
            if type_val == 4 then
                rotation_offset = (globals.RealTime() * rc_speed:GetValue() / 10) % (math.pi * 2)
            end

            local segments = 32
            local step = (math.pi * 2) / segments

            draw.Color(r, g, b, a)

            for i = 0, segments - 1 do
                if i % 2 == 0 then
                    local angle_start = i * step + rotation_offset
                    local angle_end = (i + 1) * step + rotation_offset

                    local x1 = math.floor(cx + math.cos(angle_start) * radius + 0.5)
                    local y1 = math.floor(cy + math.sin(angle_start) * radius + 0.5)

                    local x2 = math.floor(cx + math.cos(angle_end) * radius + 0.5)
                    local y2 = math.floor(cy + math.sin(angle_end) * radius + 0.5)

                    draw.Line(x1, y1, x2, y2)
                end
            end
        end
    end)

    callbacks.Register("Unload", function()
        FCR(gui.Reference("World"), "Crosshair Recoil"):SetInvisible(false)
    end)
end)

if not success then
    print("[Error] Скрипт упал: " .. tostring(result))
end