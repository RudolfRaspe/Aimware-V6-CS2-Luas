local rbotAA_ref = gui.Reference("Ragebot", "Anti-Aim")

local customYawAngle = gui.Slider(rbotAA_ref, "customYawAngle", "Custom Yaw Angle", 0, -180, 180)

local key_left    = gui.Keybox(rbotAA_ref, "manual_left",    "Manual Left",    0)
local key_right   = gui.Keybox(rbotAA_ref, "manual_right",   "Manual Right",   0)
local key_forward = gui.Keybox(rbotAA_ref, "manual_forward", "Manual Forward", 0)
local manual_override = 0  -- 0=关闭, 1=左, 2=右, 3=向前/向后

local spin_enable = gui.Checkbox(rbotAA_ref, "m_spin_en", "Enable Spinbot", false)
local indicators_enable = gui.Checkbox(rbotAA_ref, "m_indcs_en", "Enable Indicators", true)
local spin_speed  = gui.Slider(rbotAA_ref, "m_spin_speed", "Spin Speed", 20, 1, 100)
local current_yaw = 0

local function check_manual_keys()
    if key_left:GetValue() ~= 0 and input.IsButtonPressed(key_left:GetValue()) then
        manual_override = (manual_override == 1) and 0 or 1
    elseif key_right:GetValue() ~= 0 and input.IsButtonPressed(key_right:GetValue()) then
        manual_override = (manual_override == 2) and 0 or 2
    elseif key_forward:GetValue() ~= 0 and input.IsButtonPressed(key_forward:GetValue()) then
        manual_override = (manual_override == 3) and 0 or 3
    end
end
callbacks.Register("PreMove", function(cmd)
    if not gui.GetValue("rbot.master") then return end
    if not gui.GetValue("rbot.antiaim.enabled") then return end

    local va = cmd:GetViewAngles()
    local yaw_modified = false

    if customYawAngle:GetValue() ~= 0 then
        va.y = va.y + customYawAngle:GetValue()
        yaw_modified = true
    end

    if manual_override ~= 0 then
        if manual_override == 1 then
            va.y = va.y - 90   -- 左
        elseif manual_override == 2 then
            va.y = va.y + 90   -- 右
        elseif manual_override == 3 then
            va.y = va.y + 180  -- 前/后
        end
        yaw_modified = true

    elseif spin_enable:GetValue() then
        local speed = spin_speed:GetValue() * 0.5
        current_yaw = (current_yaw + speed) % 360
        
        local final_yaw = current_yaw
        if final_yaw > 180 then 
            final_yaw = final_yaw - 360 
        end
        
        va.y = final_yaw
        yaw_modified = true
    end

    if yaw_modified then
        cmd:SetViewAngles(va)
    end
end)

local function draw_arrow(points, active)
    if active then
        draw.Color(0, 255, 220, 220)
    else
        draw.Color(0, 0, 0, 80)
    end

    draw.Triangle(points[1][1], points[1][2], points[2][1], points[2][2], points[3][1], points[3][2])
    draw.Triangle(points[1][1], points[1][2], points[3][1], points[3][2], points[4][1], points[4][2])
end

local function draw_manual_indicators()
    if not gui.GetValue("rbot.master") or not indicators_enable:GetValue() then return end

    local sw, sh = draw.GetScreenSize()
    local cx, cy = sw / 2, sh / 2
    local DIST = 45 -- 距离中心点的距离
    local LEN  = 35 -- 箭头长度
    local W    = 15 -- 箭头半宽
    local IN   = -10 -- 凹进程度

    draw_arrow({
        {cx - (DIST + LEN), cy}, 
        {cx - DIST, cy - W}, 
        {cx - (DIST - IN), cy}, 
        {cx - DIST, cy + W}
    }, manual_override == 1)

    draw_arrow({
        {cx + (DIST + LEN), cy}, 
        {cx + DIST, cy - W}, 
        {cx + (DIST - IN), cy}, 
        {cx + DIST, cy + W}
    }, manual_override == 2)

    draw_arrow({
        {cx, cy - (DIST + LEN)}, 
        {cx + W, cy - DIST}, 
        {cx, cy - (DIST - IN)}, 
        {cx - W, cy - DIST}
    }, manual_override == 3)
end

local function draw_spinbot_indicator()
    if not spin_enable:GetValue() then return end
    
    local sw, sh = draw.GetScreenSize()
    if sw then
        draw.Color(0, 255, 200, 255)
        draw.Text(sw/2 - 40, sh/2 + 80, "SPINBOT")
    end
end

callbacks.Register("Draw", function()
    check_manual_keys()      -- 检测手动控制按键
    draw_manual_indicators() -- 绘制手动控制指示器
    draw_spinbot_indicator() -- 绘制Spinbot状态
end)

callbacks.Register("Unload", function()
    manual_override = 0
    current_yaw = 0
end)

print("Manual AA loaded")
