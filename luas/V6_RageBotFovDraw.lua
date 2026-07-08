local FOV_SLIDER_PATH = "rbot.fov" 

-- Переменная для хранения сглаженного радиуса
local smoothed_radius = 0

local function DrawFOVCircle()
    if gui.GetValue("esp.master") == false then return end

    local pLocal = entities.GetLocalPlayer()
    if not pLocal or not pLocal:IsAlive() then 
        smoothed_radius = 0 
        return 
    end

    local screen_width, screen_height = draw.GetScreenSize()
    if not screen_width or screen_height == 0 then return end

    local center_x = screen_width / 2
    local center_y = screen_height / 2

    local fov_value = gui.GetValue(FOV_SLIDER_PATH)
    if not fov_value or fov_value <= 0 then return end

    local origin = pLocal:GetAbsOrigin()
    if not origin then return end

    -- Безопасное получение позиции глаз
    local eye_pos = pLocal.GetEyePosition and pLocal:GetEyePosition() or (origin + Vector3(0, 0, 64))

    local view_angles = engine.GetViewAngles()
    local forward = view_angles:Forward()
    local right = view_angles:Right()
    
    if not forward or not right then return end

    local fov_rad = math.rad(fov_value)
    
    -- Точка, куда мы смотрим ПРЯМО (наш динамический центр)
    local forward_pos = eye_pos + (forward * 1000)
    -- Точка на границе FOV рейджбота
    local edge_pos = eye_pos + (forward * math.cos(fov_rad) + right * math.sin(fov_rad)) * 1000
    
    -- Проецируем ОБЕ точки через один и тот же кадр рендера
    local fx, fy = client.WorldToScreen(forward_pos)
    local ex, ey = client.WorldToScreen(edge_pos)
    
    if fx and fy and ex and ey then
        -- ФИКС: Считаем дельту между проекцией взгляда и проекцией края.
        -- При повороте камеры они двигаются вместе, сохраняя идеальную дистанцию.
        local dx = ex - fx
        local dy = ey - fy
        local raw_radius = math.sqrt(dx * dx + dy * dy)
        
        -- Ограничиваем от неадекватных значений
        raw_radius = math.max(1, math.min(3000, raw_radius))
        
        -- Плавное изменение радиуса (при переключении зума на скауте/авп)
        local lerp_factor = math.min(1, globals.FrameTime() * 15)
        if smoothed_radius == 0 then
            smoothed_radius = raw_radius
        else
            smoothed_radius = smoothed_radius + (raw_radius - smoothed_radius) * lerp_factor
        end
    end
    
    -- Отрисовка стабильного 2D круга СТРОГО по центру экрана
    if smoothed_radius > 0 then
        local final_radius = math.floor(smoothed_radius + 0.5)
        draw.Color(255, 255, 255, 150) 
        draw.OutlinedCircle(center_x, center_y, final_radius)
    end
end

callbacks.Register("Draw", DrawFOVCircle)