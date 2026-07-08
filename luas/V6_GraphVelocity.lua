local unpack = unpack or table.unpack

local ref = gui.Reference("Visuals", "Local")
local group = gui.Groupbox(ref, "Velocity Graph Settings", 15, 0, 350, 0)

local ui_enable = gui.Checkbox(group, "graph_enable", "Enable Velocity Graph", true)
local ui_pos_x = gui.Slider(group, "graph_pos_x", "Position X", 20, 0, 2560)
local ui_pos_y = gui.Slider(group, "graph_pos_y", "Position Y", 600, 0, 1440)
local ui_width = gui.Slider(group, "graph_width", "Width", 250, 100, 600)
local ui_height = gui.Slider(group, "graph_height", "Height", 80, 30, 300)
local ui_max_points = gui.Slider(group, "graph_max_points", "Graph History (Points)", 100, 20, 300)
local ui_max_speed = gui.Slider(group, "graph_max_speed", "Max Speed Scale", 350, 250, 1000)

local ui_color_line = gui.ColorPicker(group, "graph_color_line", "Line Color", 0, 255, 255, 220)
local ui_color_bg = gui.ColorPicker(group, "graph_color_bg", "Background Color", 20, 20, 20, 150)
local ui_color_border = gui.ColorPicker(group, "graph_color_border", "Border Color", 255, 255, 255, 50)

local font = draw.CreateFont("Tahoma", 16, 700)

local last_origin = nil
local current_speed = 0

local MAX_BUFFER = 300
local speed_history = {}
local history_head = 1
local history_count = 0

local function push_speed(val)
    speed_history[history_head] = val
    history_head = (history_head % MAX_BUFFER) + 1
    if history_count < MAX_BUFFER then
        history_count = history_count + 1
    end
end

local last_ui = {}
local function get_ui()
    last_ui.x = ui_pos_x:GetValue()
    last_ui.y = ui_pos_y:GetValue()
    last_ui.w = ui_width:GetValue()
    last_ui.h = ui_height:GetValue()
    last_ui.max_p = ui_max_points:GetValue()
    last_ui.max_s = ui_max_speed:GetValue()
    last_ui.bg_r, last_ui.bg_g, last_ui.bg_b, last_ui.bg_a = ui_color_bg:GetValue()
    last_ui.bd_r, last_ui.bd_g, last_ui.bd_b, last_ui.bd_a = ui_color_border:GetValue()
    last_ui.ln_r, last_ui.ln_g, last_ui.ln_b, last_ui.ln_a = ui_color_line:GetValue()
end

callbacks.Register("Draw", function()
    if not ui_enable:GetValue() or not gui.GetValue("esp.master") then
        last_origin = nil
        current_speed = 0
        history_head = 1
        history_count = 0
        return
    end

    local pLocal = entities.GetLocalPlayer()
    if not pLocal or not pLocal:IsAlive() then
        last_origin = nil
        current_speed = 0
        history_head = 1
        history_count = 0
        return
    end

    local current_origin = pLocal:GetAbsOrigin()
    if not current_origin then return end

    if last_origin ~= nil then
        local dx = current_origin.x - last_origin.x
        local dy = current_origin.y - last_origin.y
        local frame_time = globals.FrameTime()

        if frame_time > 0 then
            local distance = math.sqrt(dx * dx + dy * dy)
            local calculated_speed = distance / frame_time
            
            if calculated_speed < 2000 then
                current_speed = current_speed + (calculated_speed - current_speed) * 0.3
            end
        end
    end
    last_origin = current_origin

    push_speed(current_speed)

    get_ui()
    
    local draw_x = last_ui.x
    local draw_y = last_ui.y
    local w = last_ui.w
    local h = last_ui.h
    local max_points = last_ui.max_p
    local max_speed_on_graph = last_ui.max_s

    draw.Color(last_ui.bg_r, last_ui.bg_g, last_ui.bg_b, last_ui.bg_a)
    draw.FilledRect(draw_x, draw_y, draw_x + w, draw_y + h)
    
    draw.Color(last_ui.bd_r, last_ui.bd_g, last_ui.bd_b, last_ui.bd_a)
    draw.OutlinedRect(draw_x, draw_y, draw_x + w, draw_y + h)

    if history_count > 1 then
        draw.Color(last_ui.ln_r, last_ui.ln_g, last_ui.ln_b, last_ui.ln_a)
        
        local step_x = w / (max_points - 1)
        local prev_draw_point_x = nil
        local prev_draw_point_y = nil
        
        local points_to_draw = math.min(history_count, max_points)
        local read_pos = (history_head - points_to_draw - 1 + MAX_BUFFER) % MAX_BUFFER + 1

        for i = 1, points_to_draw do
            local speed_val = speed_history[read_pos]
            read_pos = (read_pos % MAX_BUFFER) + 1
            
            local point_x = draw_x + w - (points_to_draw - i) * step_x
            
            local factor = speed_val / max_speed_on_graph
            if factor > 1 then factor = 1 end
            if factor < 0 then factor = 0 end
            
            local point_y = draw_y + h - (factor * h)

            if prev_draw_point_x ~= nil then
                draw.Line(prev_draw_point_x, prev_draw_point_y, point_x, point_y)
            end
            
            prev_draw_point_x = point_x
            prev_draw_point_y = point_y
        end
    end

    draw.SetFont(font)
    draw.Color(255, 255, 255, 255)
    local display_speed = math.floor(current_speed + 0.5)
    draw.Text(draw_x + 5, draw_y + 5, "V: " .. tostring(display_speed))
    
    draw.Color(255, 255, 255, 50)
    draw.Text(draw_x + w - 30, draw_y + 5, tostring(max_speed_on_graph))
end)