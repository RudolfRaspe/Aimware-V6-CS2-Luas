local ref = gui.Reference("Visuals", "Local")
local group = gui.Groupbox(ref, "Advanced Motion Trail", 383, 235, 350, 0)

local enable = gui.Checkbox(group, "enable_motion_trail", "Enable Motion Trail", true)
local trail_length = gui.Slider(group, "trail_length", "Trail Length", 128, 32, 512)
local trail_width = gui.Slider(group, "trail_width", "Trail Width", 2, 1, 10)

-- Обновил комбобокс, добавил 4 новых эффекта
local trail_type = gui.Combobox(group, "trail_type", "Trail Color Mode", "Rainbow", "Static", "Gradient")
local rainbow_speed = gui.Slider(group, "rainbow_speed", "Rainbow Speed", 2, 1, 16)
local color_one = gui.ColorPicker(group, "color_one", "Primary Color", 0, 190, 255, 255)
local color_two = gui.ColorPicker(group, "color_two", "Gradient End Color", 255, 0, 128, 255)

-- 0: None, 1: Sparks, 2: Distortion, 3: Neon, 4: Pulse, 5: Dashed, 
-- 6: Comet, 7: Glitch, 8: ZigZag, 9: Ghost Orbs
local effect_type = gui.Combobox(group, "effect_type", "Extra Effects", "None", "Electric Sparks", "Lightning Distortion", "Neon Glow", "Pulse Wave", "Dashed Line", "Comet Tail", "Glitch", "ZigZag", "Ghost Orbs")

local DataItems = {}
local LastTickCount = -1

local function GetRainbowRGB(Factor, Speed)
    local cur_time = globals.CurTime() * Speed
    local r = math.floor(math.sin(Factor + cur_time) * 127 + 128)
    local g = math.floor(math.sin(Factor + cur_time + 2) * 127 + 128)
    local b = math.floor(math.sin(Factor + cur_time + 4) * 127 + 128)
    return r, g, b
end

local function LerpColor(factor, r1, g1, b1, a1, r2, g2, b2, a2)
    local r = math.floor(r1 + (r2 - r1) * factor)
    local g = math.floor(g1 + (g2 - g1) * factor)
    local b = math.floor(b1 + (b2 - b1) * factor)
    local a = math.floor(a1 + (a2 - a1) * factor)
    return r, g, b, a
end

-- Округление 2D координат для предотвращения пиксельного дрожания
local function SmoothW2S(vec3d)
    local x, y = client.WorldToScreen(vec3d)
    if not x or not y then return nil, nil end
    return math.floor(x + 0.5), math.floor(y + 0.5)
end

local function DrawThickLine(x1, y1, x2, y2, width)
    if width <= 1 then
        draw.Line(x1, y1, x2, y2)
        return
    end
    local dx = x2 - x1
    local dy = y2 - y1
    local len = math.sqrt(dx * dx + dy * dy)
    if len == 0 then return end
    
    local nx = -dy / len * (width / 2)
    local ny = dx / len * (width / 2)

    draw.Triangle(x1 + nx, y1 + ny, x1 - nx, y1 - ny, x2 + nx, y2 + ny)
    draw.Triangle(x2 + nx, y2 + ny, x1 - nx, y1 - ny, x2 - nx, y2 - ny)
end

function MotionTrajectory()
    if not enable:GetValue() or gui.GetValue("esp.master") == false then
        DataItems = {}
        LastTickCount = -1
        return
    end

    local localPlayer = entities.GetLocalPlayer()
    if not localPlayer or not localPlayer:IsAlive() then
        DataItems = {}
        LastTickCount = -1
        return
    end

    local vecOrigin = localPlayer:GetAbsOrigin()
    if not vecOrigin then return end

    local tick = globals.TickCount()
    local max_length = trail_length:GetValue()
    
    if tick ~= LastTickCount then
        table.insert(DataItems, 1, Vector3(vecOrigin.x, vecOrigin.y, vecOrigin.z))
        if #DataItems > max_length then
            table.remove(DataItems)
        end
        LastTickCount = tick
    end

    local total_items = #DataItems
    if total_items < 2 then return end
    
    local mode = trail_type:GetValue()
    local effect = effect_type:GetValue()
    local width = trail_width:GetValue()
    local r_speed = rainbow_speed:GetValue()

    local r1, g1, b1, a1 = color_one:GetValue()
    local r2, g2, b2, a2 = color_two:GetValue()

    local last_cx, last_cy = nil, nil
    local last_valid = false

    for i = 1, total_items do
        local cur = DataItems[i]
        local cx, cy = SmoothW2S(cur)

        if i > 1 and last_valid and cx and cy then
            local prev = DataItems[i - 1]
            local dx = cur.x - prev.x
            local dy = cur.y - prev.y
            local dz = cur.z - prev.z
            local dist = math.sqrt(dx * dx + dy * dy + dz * dz)

            -- Защита от рывков линии через весь экран при повороте камеры
            local screen_dist = math.sqrt((last_cx - cx)^2 + (last_cy - cy)^2)
            
            if dist < 300 and screen_dist < 400 then
                local r, g, b, a = 255, 255, 255, 255
                local factor = i / total_items

                if mode == 0 then
                    r, g, b = GetRainbowRGB(i * 0.15, r_speed)
                    a = a1
                elseif mode == 1 then
                    r, g, b, a = r1, g1, b1, a1
                elseif mode == 2 then
                    r, g, b, a = LerpColor(factor, r1, g1, b1, a1, r2, g2, b2, a2)
                end

                -- Отрисовка эффектов
                if effect == 1 then -- Electric Sparks
                    draw.Color(r, g, b, a)
                    DrawThickLine(last_cx, last_cy, cx, cy, width)
                    if math.random(1, 100) > 94 then
                        local spark_size = math.random(2, 4)
                        draw.Color(255, 255, 255, a)
                        draw.FilledRect(last_cx + math.random(-12, 12), last_cy + math.random(-12, 12), last_cx + spark_size, last_cy + spark_size)
                    end
                elseif effect == 2 then -- Lightning Distortion
                    draw.Color(r, g, b, a)
                    if i % 3 == 0 then
                        DrawThickLine(last_cx, last_cy, cx + math.random(-5, 5), cy + math.random(-5, 5), width)
                    else
                        DrawThickLine(last_cx, last_cy, cx, cy, width)
                    end
                elseif effect == 3 then -- Neon Glow
                    draw.Color(r, g, b, math.floor(a * 0.25))
                    DrawThickLine(last_cx, last_cy, cx, cy, width * 3.5)
                    draw.Color(r, g, b, a)
                    DrawThickLine(last_cx, last_cy, cx, cy, width)
                elseif effect == 4 then -- Pulse Wave
                    draw.Color(r, g, b, a)
                    local pulse = math.sin(globals.CurTime() * 8 + i * 0.25) * (width * 0.5)
                    local current_width = math.max(1, width + pulse)
                    DrawThickLine(last_cx, last_cy, cx, cy, current_width)
                elseif effect == 5 then -- Dashed Line
                    if i % 2 == 0 then
                        draw.Color(r, g, b, a)
                        DrawThickLine(last_cx, last_cy, cx, cy, width)
                    end
                -- === НОВЫЕ ЭФФЕКТЫ НИЖЕ ===
                elseif effect == 6 then -- Comet Tail (Хвост кометы)
                    -- Линия сужается к концу
                    local comet_w = math.max(1, math.floor(width * (1 - factor)))
                    draw.Color(r, g, b, a)
                    DrawThickLine(last_cx, last_cy, cx, cy, comet_w)
                    -- Яркая точка на самом кончике
                    if i == total_items then
                        draw.Color(255, 255, 255, a)
                        draw.FilledCircle(cx, cy, width + 1)
                    end
                elseif effect == 7 then -- Glitch (Глитч)
                    -- Смещение линии и смена цветов
                    local glitch_x = math.random(-4, 4)
                    local glitch_y = math.random(-4, 4)
                    if math.random(1, 100) > 90 then
                        draw.Color(255, 0, 0, a) -- Красный канал
                        DrawThickLine(last_cx + glitch_x, last_cy, cx + glitch_x, cy, width)
                        draw.Color(0, 255, 255, a) -- Синий канал
                        DrawThickLine(last_cx - glitch_x, last_cy, cx - glitch_x, cy, width)
                    else
                        draw.Color(r, g, b, a)
                        DrawThickLine(last_cx, last_cy + glitch_y, cx, cy + glitch_y, width)
                    end
                elseif effect == 8 then -- ZigZag (Молния)
                    draw.Color(r, g, b, a)
                    -- Каждую вторую точку смещаем в сторону
                    if i % 2 == 0 then
                        DrawThickLine(last_cx, last_cy, cx + 4, cy, width)
                        DrawThickLine(cx + 4, cy, cx, cy, width)
                    else
                        DrawThickLine(last_cx, last_cy, cx - 4, cy, width)
                        DrawThickLine(cx - 4, cy, cx, cy, width)
                    end
                elseif effect == 9 then -- Ghost Orbs (Призрачные сферы)
                    -- Вместо линии рисуем круги, которые растворяются
                    local orb_radius = math.max(1, math.floor(width * (1 - factor)))
                    local orb_alpha = math.floor(a * (1 - factor))
                    draw.Color(r, g, b, orb_alpha)
                    draw.FilledCircle(cx, cy, orb_radius)
                else
                    draw.Color(r, g, b, a)
                    DrawThickLine(last_cx, last_cy, cx, cy, width)
                end
                last_valid = true
            else
                last_valid = false
            end
        else
            last_valid = (cx ~= nil and cy ~= nil)
        end

        last_cx, last_cy = cx, cy
    end
end

callbacks.Register("Draw", MotionTrajectory)