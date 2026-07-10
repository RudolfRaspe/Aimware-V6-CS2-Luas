ffi.cdef[[
    void* GetModuleHandleA(const char* lpModuleName);
]]

local NULL = 0x0
local ENGINE2_DLL_NAME = "engine2.dll"

local cVTable_Address_VEngineCvar007_offset     = NULL
local cResolveConVar_offset                     = NULL
local cVTable_FindConVar_offset                 = 0xB
local cConVarFlags                              = 0x30

local FCVAR_DEVELOPMENTONLY                        = 0x2
local FCVAR_USERINFO                            = 0x200

local function getOffsetFromPattern(cDllName, cPattern, cPatternOffset, cInstrSize)
    local cPatternLocation = mem.FindPattern(cDllName, cPattern)
    if not cPatternLocation then return NULL end
    local cRelativeAddress = ffi.cast("int32_t*", cPatternLocation + cPatternOffset)[0x0]
    return tonumber(cPatternLocation + cRelativeAddress + cInstrSize) - tonumber(ffi.cast("uintptr_t", ffi.C.GetModuleHandleA(cDllName)))
end

cVTable_Address_VEngineCvar007_offset   = getOffsetFromPattern(ENGINE2_DLL_NAME, "48 8B 0D ?? ?? ?? ?? 48 8B 16 48 89 7C 24 ?? 4C 89 4C 24 ??", 3, 7)
cResolveConVar_offset                   = getOffsetFromPattern(ENGINE2_DLL_NAME, "48 8B D3 E8 ?? ?? ?? ?? 48 8B 44 24", 4, 8)

local function patchConVar(cConVarName)
    local engine2_base_address = tonumber(ffi.cast("uintptr_t", ffi.C.GetModuleHandleA(ENGINE2_DLL_NAME)))

    if engine2_base_address == nil or engine2_base_address == NULL then
        return
    end

    local vTable_engine_address = tonumber(ffi.cast("uintptr_t*", engine2_base_address + cVTable_Address_VEngineCvar007_offset)[0x0])
    local vTable_engine_table = tonumber(ffi.cast("uintptr_t*", vTable_engine_address)[0x0])

    local pFindConVarFunction_address = ffi.cast("uintptr_t*", vTable_engine_table)[cVTable_FindConVar_offset]
    local pFindConVarFunction = ffi.cast("void* (*)(void*, void*, const char*, int)", pFindConVarFunction_address)

    local pFindConVarOutput = ffi.new("void*[1]")
    local pFindConVarName = ffi.new("char[?]", cConVarName:len() + 0x1, cConVarName)

    pFindConVarFunction(ffi.cast("void*", vTable_engine_address), pFindConVarOutput, pFindConVarName, 0x0)

    local pResolveConVarFunction = ffi.cast("void* (*)(int64_t*, int32_t, int16_t)", tonumber(ffi.cast("uintptr_t", engine2_base_address + cResolveConVar_offset)))
    local pResolveConVarOutput = ffi.new("int64_t[0x2]")

    pResolveConVarFunction(pResolveConVarOutput, ffi.cast("int32_t", pFindConVarOutput[0x0]), 0x0)
    
    local pCurrentConVarStruct_address = tonumber(pResolveConVarOutput[0x1])
    if pCurrentConVarStruct_address == 0 then return end
    
    local pCurrentConVarFlags = ffi.cast("uintptr_t*", pCurrentConVarStruct_address + cConVarFlags)

    pCurrentConVarFlags[0x0] = bit.band(pCurrentConVarFlags[0x0], bit.bnot(FCVAR_DEVELOPMENTONLY))
    pCurrentConVarFlags[0x0] = bit.bor(pCurrentConVarFlags[0x0], FCVAR_USERINFO)
end

local function SafeUTF8Sub(str, current_len)
    local result = ""
    local count = 0
    for char in str:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        count = count + 1
        if count > current_len then break end
        result = result .. char
    end
    return result
end

local function GetUTF8Len(str)
    local len = 0
    for _ in str:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        len = len + 1
    end
    return len
end

-------------------/\-------------------
local Aimware_Misc_Features_ref = gui.Reference("Miscellaneous", "Features")
local NameChanger_Combobox_ref = gui.Combobox(Aimware_Misc_Features_ref, "var_NameChanger_Listbox", "Clan-tag/Name-tag", "Disabled", "Fake name", "Static", "Static | Radar", "Minecraft enchantment | Radar", "Radar Exploit", "Tag Spammer", "Name Stealer", "Nearest Stealer")

local NameChanger_Clantag_Editbox_ref = gui.Editbox(Aimware_Misc_Features_ref, "var_NameChanger_Clantag_Editbox", "Custom Text / Tag")

local Spammer_Speed_Slider_ref = gui.Slider(Aimware_Misc_Features_ref, "var_Spammer_Speed_Slider", "Tag Spammer Delay", 100, 1, 1000)
local Stealer_Speed_Slider_ref = gui.Slider(Aimware_Misc_Features_ref, "var_Stealer_Speed_Slider", "Name Stealer Delay", 100, 1, 1000)
-------------------\/-------------------

local function GetMagicSymbols(iCount)
    local magicSymbols = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz "
    local result = ""
    for i = 1, iCount do
        local magicIndex = math.random(1, magicSymbols:len() - 1)
        result = result .. magicSymbols:sub(magicIndex, magicIndex)
    end
    return result
end

local cOldRealName = " "
local function SaveRealPlayerName(cRealPlayerName)
    if cRealPlayerName and cRealPlayerName ~= "" then
        cOldRealName = cRealPlayerName
    end
end

local function SetUserNameAndClantag(cClantagWithName)
    if not cClantagWithName or cClantagWithName == "" then return end
    client.Command("name " .. cClantagWithName, false)
    client.Command("setinfo name " .. '"' .. cClantagWithName .. '"', false)
end

local function DisabledClantagHendler()
    SetUserNameAndClantag(cOldRealName)
end

local function StaticClantagHendler()
    if NameChanger_Clantag_Editbox_ref:GetString() == "" then
        SetUserNameAndClantag(cOldRealName)
    else
        SetUserNameAndClantag(NameChanger_Clantag_Editbox_ref:GetString() .. " | " .. cOldRealName)
    end
end

local function FakeNameHendler()
    if NameChanger_Clantag_Editbox_ref:GetString() == "" then
        SetUserNameAndClantag(cOldRealName)
    else
        SetUserNameAndClantag(NameChanger_Clantag_Editbox_ref:GetString())
    end
end

local fakeChanged = false
local function StaticRadarClantagHendler()
    local text = NameChanger_Clantag_Editbox_ref:GetString()
    if text == "" then
        SetUserNameAndClantag(fakeChanged and cOldRealName or cOldRealName .. "") --⠀
    else
        SetUserNameAndClantag(text .. " | " .. cOldRealName .. (fakeChanged and "" or ""))
    end
    fakeChanged = not fakeChanged
end

local function MinecraftEnchantmentClantagHendler()
    SetUserNameAndClantag(GetMagicSymbols(math.random(10, 16)))
end

local function RadarExploitClantagHendler()
    SetUserNameAndClantag(fakeChanged and cOldRealName or cOldRealName .. "")
    fakeChanged = not fakeChanged
end

local spammer_last_update = 0
local spammer_current_length = 0
local spammer_building = true 
local build_style = 1 
local erase_style = 1

local function ResetSpammerState()
    spammer_current_length = 0
    spammer_building = true
    build_style = 1
    erase_style = 1
    spammer_last_update = 0
end

local function TagSpammerHandler()
    local now = common.Time()
    if now < spammer_last_update then spammer_last_update = 0 end

    local current_delay = Spammer_Speed_Slider_ref:GetValue() / 100
    if now - spammer_last_update < current_delay then return end
    spammer_last_update = now

    local input_text = NameChanger_Clantag_Editbox_ref:GetString()
    if input_text == "" then SetUserNameAndClantag(cOldRealName) return end

    local max_len = GetUTF8Len(input_text)
    if spammer_current_length > max_len then spammer_current_length = max_len end

    if spammer_building then
        spammer_current_length = spammer_current_length + 1
        if spammer_current_length > max_len then
            spammer_current_length = max_len
            spammer_building = false 
            erase_style = math.random(1, 2)
        end
    else
        spammer_current_length = spammer_current_length - 1
        if spammer_current_length < 0 then
            spammer_current_length = 0
            spammer_building = true 
            build_style = math.random(1, 2)
        end
    end

    if spammer_current_length == 0 then SetUserNameAndClantag(cOldRealName) return end

    local animated_tag = ""
    if spammer_building then
        if build_style == 1 then
            animated_tag = SafeUTF8Sub(input_text, spammer_current_length)
        else
            animated_tag = SafeUTF8Sub(input_text, max_len):sub(math.max(1, input_text:len() - spammer_current_length * 2))
        end
    else
        if erase_style == 1 then
            animated_tag = SafeUTF8Sub(input_text, spammer_current_length)
        else
            animated_tag = SafeUTF8Sub(input_text, max_len):sub(math.max(1, input_text:len() - spammer_current_length * 2))
        end
    end

    if animated_tag == "" then 
        SetUserNameAndClantag(cOldRealName) 
    else 
        SetUserNameAndClantag(animated_tag .. " | " .. cOldRealName) 
    end
end

local stealer_last_update = 0

local function NameStealerHandler()
    local now = common.Time()
    if now < stealer_last_update then stealer_last_update = 0 end

    local current_delay = Stealer_Speed_Slider_ref:GetValue() / 100
    if now - stealer_last_update < current_delay then return end
    stealer_last_update = now

    local pool = {}
    local pLocalPlayer = entities.GetLocalPlayer()
    local local_idx = pLocalPlayer and pLocalPlayer:GetIndex() or -1

    local pawns = entities.FindByClass("CCSPlayerController")
    if pawns then
        for _, pawn in pairs(pawns) do
            if pawn then
                local idx = pawn:GetIndex()
                if idx and idx ~= local_idx then
                    local name = pawn:GetFieldString("m_iszPlayerName")
                    if name and name ~= "" and name ~= "nil" and name ~= cOldRealName and not name:find("GOTV") then
                        table.insert(pool, name)
                    end
                end
            end
        end
    end

    if #pool == 0 then return end
    SetUserNameAndClantag(pool[math.random(1, #pool)] .. "")
end

local function NearestNameStealerHandler()
    local now = common.Time()
    if now < stealer_last_update then stealer_last_update = 0 end

    local current_delay = Stealer_Speed_Slider_ref:GetValue() / 100
    if now - stealer_last_update < current_delay then return end
    stealer_last_update = now

    local pLocalPlayer = entities.GetLocalPlayer()
    if not pLocalPlayer then return end

    local localOrigin = pLocalPlayer:GetAbsOrigin()
    if not localOrigin then return end

    local shortestDistance = math.huge
    local targetName = nil

    local pawns = entities.FindByClass("C_CSPlayerPawn")
    if pawns then
        for _, pawn in pairs(pawns) do
            if pawn then
                local idx = pawn:GetIndex()
                if idx and idx ~= pLocalPlayer:GetIndex() then
                    local pawnOrigin = pawn:GetAbsOrigin()
                    if pawnOrigin and pawnOrigin.x and pawnOrigin.y and pawnOrigin.z then
                        local dx, dy, dz = localOrigin.x - pawnOrigin.x, localOrigin.y - pawnOrigin.y, localOrigin.z - pawnOrigin.z
                        local distance = math.sqrt(dx*dx + dy*dy + dz*dz)

                        if distance < shortestDistance then
                            local name = client.GetPlayerNameByIndex(idx)
                            if name and name ~= "" and name ~= "nil" and name ~= cOldRealName and not name:find("GOTV") then
                                shortestDistance = distance
                                targetName = name
                            end
                        end
                    end
                end
            end
        end
    end

    if targetName then SetUserNameAndClantag(targetName .. "") end
end

local cInitTime = common.Time()
local bForceExit = false
local bNameWasSaved = false
local bNameWasChanged = false
local cLastTimeChanged_logic = -1

local function NameChangerLogicHandler()
    if bForceExit then return end
    if common.Time() < cLastTimeChanged_logic then cLastTimeChanged_logic = common.Time() end

    if engine.GetServerIP() == nil or engine.GetMapName() == nil or engine.GetMapName() == "" then
        cInitTime = common.Time()
        bNameWasSaved = false
        ResetSpammerState()
        return
    end

    local pLocalPLayerEnt = entities.GetLocalPlayer()
    if pLocalPLayerEnt == nil then
        cInitTime = common.Time()
        bNameWasSaved = false
        ResetSpammerState()
        return
    end

    if (common.Time() - cInitTime) < 0.3 then bNameWasSaved = false return end
    
    if bNameWasSaved == false then
        if pLocalPLayerEnt:IsPlayer() == false then return end
        SaveRealPlayerName(pLocalPLayerEnt:GetName())
        bNameWasSaved = true
        ResetSpammerState()
        pcall(patchConVar, "name")
    end

    if (common.Time() - cLastTimeChanged_logic) > 0.01 then
        cLastTimeChanged_logic = common.Time()
        local ComboboxValue = NameChanger_Combobox_ref:GetValue()

        if ComboboxValue == 0 and bNameWasChanged == true then DisabledClantagHendler() bNameWasChanged = false end
        if ComboboxValue == 1 then FakeNameHendler() bNameWasChanged = true end
        if ComboboxValue == 2 then StaticClantagHendler() bNameWasChanged = true end
        if ComboboxValue == 3 then StaticRadarClantagHendler() bNameWasChanged = true end
        if ComboboxValue == 4 then MinecraftEnchantmentClantagHendler() bNameWasChanged = true end
        if ComboboxValue == 5 then RadarExploitClantagHendler() bNameWasChanged = true end
        if ComboboxValue == 6 then TagSpammerHandler() bNameWasChanged = true end
        if ComboboxValue == 7 then NameStealerHandler() bNameWasChanged = true end
        if ComboboxValue == 8 then NearestNameStealerHandler() bNameWasChanged = true end
    end
end

local cLastTimeChanged_menu = -1
local function NameChangerMenuHandler()
    if bForceExit then return end
    if common.Time() < cLastTimeChanged_menu then cLastTimeChanged_menu = common.Time() end

    if (common.Time() - cLastTimeChanged_menu) > 0.01 then
        cLastTimeChanged_menu = common.Time()
        local ComboboxValue = NameChanger_Combobox_ref:GetValue()

        NameChanger_Clantag_Editbox_ref:SetInvisible(not (ComboboxValue == 1 or ComboboxValue == 2 or ComboboxValue == 3 or ComboboxValue == 6))
        Spammer_Speed_Slider_ref:SetInvisible(ComboboxValue ~= 6)
        Stealer_Speed_Slider_ref:SetInvisible(ComboboxValue ~= 7 and ComboboxValue ~= 8)
    end
end

print("[Name Changer] initialized");

callbacks.Register("Draw", NameChangerLogicHandler)
callbacks.Register("Draw", NameChangerMenuHandler)
callbacks.Register("Unload", function()
    bForceExit = true
    if bNameWasSaved and NameChanger_Combobox_ref:GetValue() ~= 0 then
        local pLocalPLayerEnt = entities.GetLocalPlayer()
        if pLocalPLayerEnt == nil then return end
        DisabledClantagHendler()
    end
end)