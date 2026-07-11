
local primary_weapons_ids = {
    "glock",
    "hkp2000",
    "usp_silencer",
    "elite",
    "p250",
    "tec9",
    "fiveseven",
    "cz75a",
    "deagle",
    "revolver"
}

local primary_weapons_ids_t = {
    "None",
    "Glock-18",
    "P2000",
    "USP-S",
    "Dual Berettas",
    "P250",
    "Tec-9",
    "Five-SeveN",
    "CZ75-Auto",
    "Desert Eagle",
    "R8 Revolver"
}

local secondary_weapons_ids = {
    "nova",
    "mag7",
    "sawedoff",
    "xm1014",
    "m249",
    "negev",
    "mp5sd",
    "p90",
    "mp7",
    "mac10",
    "mp9",
    "bizon",
    "ump45",
    "galilar",
    "famas",
    "ak47",
    "m4a1",
    "m4a1_silencer",
    "ssg08",
    "aug",
    "sg556",
    "awp",
    "g3sg1",
    "scar20"
}

local secondary_weapons_ids_t = {
    "None",
    "Nova",
    "MAG-7",
    "Sawed-Off",
    "XM1014",
    "M249",
    "Negev",
    "MP5-SD",
    "P90",
    "MP7",
    "MAC-10",
    "MP9",
    "PP-Bizon",
    "UMP-45",
    "Galil AR",
    "FAMAS",
    "AK-47",
    "M4A4",
    "M4A1-S",
    "SSG 08",
    "AUG",
    "SG 553",
    "AWP",
    "G3SG1",
    "SCAR-20"
}

local RF = gui.Reference

local misc = RF("Miscellaneous")

local group = gui.Groupbox(misc, "Simple Auto Buy", 384, 250, 350, 0)

local primary = gui.Combobox(group, "simpleautobuy_primary", "Primary Weapon", unpack(primary_weapons_ids_t))
local secondary = gui.Combobox(group, "simpleautobuy_secondary", "Secondary Weapon", unpack(secondary_weapons_ids_t))

local other = gui.Multibox(group, "Other")

local armor = gui.Checkbox(other, "simpleautobuy_armor", "Armor", false) -- vesthelm
local defuser = gui.Checkbox(other, "simpleautobuy_defuser", "Defuse Kit", false)
local taser = gui.Checkbox(other, "simpleautobuy_taser", "Taser", false)
local flashbang = gui.Checkbox(other, "simpleautobuy_flashbang", "Flashbang", false)
local smoke = gui.Checkbox(other, "simpleautobuy_smoke", "Smoke", false)
local molotov = gui.Checkbox(other, "simpleautobuy_molotov", "Molotov", false)
local decoy = gui.Checkbox(other, "simpleautobuy_decoy", "Decoy", false)
local HE = gui.Checkbox(other, "simpleautobuy_he", "HE Grenade", false)

local function get_my_controller_index(lp)
    local my_pawn_idx = lp:GetIndex()
    for i = 1, globals.MaxClients() do
        local ent = entities.GetByIndex(i)
        if ent then
            local pawn = ent:GetFieldEntity("m_hPawn")
            if pawn and pawn:GetIndex() == my_pawn_idx then
                return i
            end
        end
    end
    return nil
end

local function on_player_spawn(event)
    if event:GetName() ~= "player_spawn" then return end

    local controller_index = event:GetInt("userid") + 1
    local local_player_idx = get_my_controller_index(entities.GetLocalPlayer())

    if controller_index ~= local_player_idx then return end

    local selected_primary = primary:GetValue()
    local selected_secondary = secondary:GetValue()

    if selected_primary ~= 0 then
        client.Command("buy " .. primary_weapons_ids[selected_primary], true)
    end

    if selected_secondary ~= 0 then
        client.Command("buy " .. secondary_weapons_ids[selected_secondary], true)
    end

    if armor:GetValue() then
        client.Command("buy vesthelm", true)
    end

    if defuser:GetValue() then
        client.Command("buy defuser", true)
    end

    if taser:GetValue() then
        client.Command("buy taser", true)
    end

    if flashbang:GetValue() then
        client.Command("buy flashbang", true)
    end

    if smoke:GetValue() then
        client.Command("buy smokegrenade", true)
    end

    if molotov:GetValue() then
        client.Command("buy molotov", true)
    end

    if decoy:GetValue() then
        client.Command("buy decoy", true)
    end

    if HE:GetValue() then
        client.Command("buy hegrenade", true)
    end
end

callbacks.Register("FireGameEvent", on_player_spawn)
client.AllowListener("player_spawn")