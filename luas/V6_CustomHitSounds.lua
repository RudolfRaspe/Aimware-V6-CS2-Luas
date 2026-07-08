local ffi = assert(ffi, "ffi not enabled — turn on Allow Insecure in script settings and reload.")

-- ---------- helpers ----------
local function notify(title, msg)
    print(string.format("[%s] %s", title, msg))
end

-- ---------- FFI: Win32 (Strictly for file enumeration & directory) ----------
ffi.cdef[[
    typedef struct {
        uint32_t dwFileAttributes;
        uint32_t ftCreationTimeLow,  ftCreationTimeHigh;
        uint32_t ftLastAccessTimeLow, ftLastAccessTimeHigh;
        uint32_t ftLastWriteTimeLow, ftLastWriteTimeHigh;
        uint32_t nFileSizeHigh, nFileSizeLow;
        uint32_t dwReserved0, dwReserved1;
        char     cFileName[260];
        char     cAlternateFileName[14];
    } WIN32_FIND_DATAA;

    void* FindFirstFileA(const char* lpFileName, WIN32_FIND_DATAA* lpFindFileData);
    bool  FindNextFileA (void* hFindFile, WIN32_FIND_DATAA* lpFindFileData);
    bool  FindClose     (void* hFindFile);
    unsigned int GetCurrentDirectoryA(unsigned int nBufferLength, char* lpBuffer);
    int   ShellExecuteA (int hwnd, const char* lpOperation, const char* lpFile,
                         const char* lpParameters, const char* lpDirectory, int nShowCmd);
]]

local k32, sh32
do
    local ok
    ok, k32  = pcall(ffi.load, "kernel32"); if not ok then k32  = ffi.C end
    ok, sh32 = pcall(ffi.load, "shell32");  if not ok then sh32 = ffi.C end
end
local INVALID_HANDLE_VALUE = ffi.cast("void*", -1)

-- ---------- resolve sounds folder ----------
local PATH_BUF = 260
local cwd_buf  = ffi.new("char[?]", PATH_BUF)
k32.GetCurrentDirectoryA(PATH_BUF, cwd_buf)
local sounds_path = ffi.string(cwd_buf):gsub("bin\\win64", "csgo\\sounds")

-- ---------- audio file detection ----------
local function get_ext(name)
    return (name:lower():match("%.([^.]+)$"))
end

local function is_audio_file(name)
    return get_ext(name) == "vsnd_c"
end

-- ---------- sound list ----------
local sound_files = { [0] = "None" }

local function enumerate_sounds()
    local data   = ffi.new("WIN32_FIND_DATAA")
    local handle = k32.FindFirstFileA(sounds_path .. "\\*", data)

    if handle == nil or handle == INVALID_HANDLE_VALUE then
        notify("Sounds", "Couldn't open " .. sounds_path)
        return
    end

    sound_files = { [0] = "None" }
    local i = 1

    repeat
        local name = ffi.string(data.cFileName)
        if name ~= "." and name ~= ".." and is_audio_file(name) then
            sound_files[i] = name
            i = i + 1
        end
    until not k32.FindNextFileA(handle, data)

    k32.FindClose(handle)
end

local function build_options()
    local out = {}
    for k = 0, #sound_files do
        out[#out + 1] = sound_files[k]
    end
    return out
end

enumerate_sounds()

-- ---------- GUI ----------
local window = gui.Window("custom_sounds_win", "Custom Hit Sounds", 200, 200, 360, 500)

-- Follow main menu visibility
local ref_menu = gui.Reference("Menu")
callbacks.Register("Draw", function()
    window:SetActive(ref_menu:IsActive())
end)

local opts = build_options()

-- Playback dispatcher
local function play_sound(filename)
    if not filename or filename == "None" then return end
    client.Command("play \\sounds\\" .. filename, true)
end

local function selected(combo)
    return sound_files[combo:GetValue()]
end

-- Layout components with inline "Test" buttons
local cb_hit      = gui.Combobox(window, "cs_hit",      "Hit Sound", unpack(opts))
gui.Button(window, "Test Hit Sound", function() play_sound(selected(cb_hit)) end)

local cb_kill     = gui.Combobox(window, "cs_kill",     "Kill Sound", unpack(opts))
gui.Button(window, "Test Kill Sound", function() play_sound(selected(cb_kill)) end)

local cb_hithead  = gui.Combobox(window, "cs_hithead",  "Headshot Sound", unpack(opts))
gui.Button(window, "Test Headshot Sound", function() play_sound(selected(cb_hithead)) end)

local cb_killhead = gui.Combobox(window, "cs_killhead", "Headshot Kill Sound", unpack(opts))
gui.Button(window, "Test Headshot Kill Sound", function() play_sound(selected(cb_killhead)) end)

local sl_volume   = gui.Slider  (window, "cs_volume",   "Volume Scale", 50, 0, 100, 1)

gui.Button(window, "Open Folder", function()
    sh32.ShellExecuteA(0, "open", sounds_path, nil, nil, 1)
end)

gui.Button(window, "Reload Sounds", function()
    enumerate_sounds()
    local fresh = build_options()
    cb_hit     :SetOptions(unpack(fresh))
    cb_kill    :SetOptions(unpack(fresh))
    cb_hithead :SetOptions(unpack(fresh))
    cb_killhead:SetOptions(unpack(fresh))
    cb_hit:SetValue(0); cb_kill:SetValue(0); cb_hithead:SetValue(0); cb_killhead:SetValue(0)
    notify("Sounds", string.format("Reloaded! Total files found: %d", #fresh - 1))
end)

-- ---------- volume polling (engine: snd_toolvolume) ----------
local last_volume = -1
callbacks.Register("Draw", function()
    local v = sl_volume:GetValue()
    if v ~= last_volume then
        last_volume = v
        client.Command(string.format("snd_toolvolume %.2f", v / 100), true)
    end
end)

local function on_hit(headshot_branch, body_enabled)
    if headshot_branch then
        play_sound(selected(cb_hithead))
    elseif body_enabled then
        play_sound(selected(cb_hit))
    end
end

local function on_kill(headshot_branch, body_enabled)
    if headshot_branch then
        play_sound(selected(cb_killhead))
    elseif body_enabled then
        play_sound(selected(cb_kill))
    end
end

-- ---------- local player resolver ----------
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

-- ---------- event ----------
client.AllowListener("player_hurt")

callbacks.Register("FireGameEvent", function(event)
    if event:GetName() ~= "player_hurt" then return end

    local hit_on      = cb_hit      :GetValue() > 0
    local hithead_on  = cb_hithead  :GetValue() > 0
    local kill_on     = cb_kill     :GetValue() > 0
    local killhead_on = cb_killhead :GetValue() > 0
    if not (hit_on or hithead_on or kill_on or killhead_on) then return end

    local lp = entities.GetLocalPlayer()
    if not lp then return end

    local my_ctrl_idx = get_my_controller_index(lp)
    if not my_ctrl_idx then return end

    local attackerID = event:GetInt("attacker")
    local victimID   = event:GetInt("userid")
    if (attackerID + 1) ~= my_ctrl_idx then return end
    if attackerID == victimID then return end

    local headshot = event:GetInt("hitgroup") == 1
    local health   = event:GetInt("health")

    if not kill_on and not killhead_on then
        on_hit(headshot and hithead_on, hit_on)
    elseif health > 0 then
        on_hit(headshot and hithead_on, hit_on)
    else
        on_kill(headshot and killhead_on, kill_on)
    end
end)

notify("Custom Sounds", "Loaded")