-- RainbowLoop.lua
-- 基于 WindUI 框架的彩色循环效果组件
-- 依赖：需在 main.lua 加载 WindUI 后引入

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

-- 等待 WindUI 加载完成（确保 main.lua 已先执行）
local WindUI
repeat
    task.wait(0.05)
    WindUI = _G.WindUI or getfenv(1).WindUI -- 适配不同执行环境
until WindUI and WindUI.Creator and WindUI.CreateWindow

-- 1. 核心：创建彩虹色渐变序列（可自定义颜色）
local function createRainbowGradient()
    local colorKeypoints = {
        ColorSequenceKeypoint.new(0.0, Color3.fromHex("#ff0000")),   -- 红色
        ColorSequenceKeypoint.new(0.2, Color3.fromHex("#ff9500")),   -- 橙色
        ColorSequenceKeypoint.new(0.4, Color3.fromHex("#ffff00")),   -- 黄色
        ColorSequenceKeypoint.new(0.6, Color3.fromHex("#34c759")),   -- 绿色
        ColorSequenceKeypoint.new(0.8, Color3.fromHex("#007aff")),   -- 蓝色
        ColorSequenceKeypoint.new(1.0, Color3.fromHex("#af52de"))    -- 紫色
    }
    return ColorSequence.new(colorKeypoints)
end

-- 2. 核心：生成偏移后的颜色序列（实现循环流动）
local function getOffsetGradient(offset)
    offset = offset or 0
    local baseGradient = createRainbowGradient()
    local newKeypoints = {}
    
    for _, keypoint in ipairs(baseGradient.Keypoints) do
        local newTime = (keypoint.Time + offset) % 1
        table.insert(newKeypoints, ColorSequenceKeypoint.new(newTime, keypoint.Value))
    end
    
    table.sort(newKeypoints, function(a, b) return a.Time < b.Time end)
    return ColorSequence.new(newKeypoints)
end

-- 3. 对外接口：给UI元素添加彩色循环效果
-- 参数：
-- targetUI: 目标UI元素（Frame/ImageLabel/TextLabel/UIStroke等）
-- duration: 循环周期（秒，默认2.5秒）
-- rotation: 渐变旋转角度（0=纵向，90=横向，默认90）
function WindUI.AddRainbowLoop(targetUI, duration, rotation)
    -- 参数校验
    if not targetUI or not targetUI:IsA("GuiObject") then
        warn("[RainbowLoop] 目标必须是GuiObject（如Frame/TextLabel）")
        return nil
    end
    
    duration = duration or 2.5
    rotation = rotation or 90

    -- 创建/复用UIGradient
    local gradient = targetUI:FindFirstChildOfClass("UIGradient")
    if not gradient then
        gradient = WindUI.Creator.New("UIGradient", {
            Rotation = rotation,
            Color = createRainbowGradient()
        }, {Parent = targetUI})
    else
        gradient.Rotation = rotation
        gradient.Color = createRainbowGradient()
    end

    -- 动画控制变量
    local isRunning = true
    local startTime = tick()

    -- 用RenderStepped实现流畅循环（避免Tween颜色序列卡顿）
    local connection = RunService.RenderStepped:Connect(function()
        if not isRunning or not targetUI.Parent then
            connection:Disconnect()
            return
        end
        
        -- 计算当前偏移量（随时间线性变化）
        local elapsed = tick() - startTime
        local offset = (elapsed / duration) % 1
        gradient.Color = getOffsetGradient(offset)
    end)

    -- 返回控制器（暂停/继续/停止）
    return {
        IsRunning = function() return isRunning end,
        Pause = function() isRunning = false end,
        Resume = function() 
            isRunning = true 
            startTime = tick() - (tick() - startTime) % duration -- 续接上次进度
        end,
        Stop = function() 
            isRunning = false 
            connection:Disconnect()
            gradient:Destroy() -- 可选：停止后移除渐变
        end
    }
end

-- 4. 示例：创建带彩色循环的WindUI窗口
function WindUI.CreateRainbowDemoWindow()
    -- 创建基础窗口
    local demoWindow = WindUI.CreateWindow({
        Title = "WindUI 彩色循环示例",
        Size = UDim2.new(0, 550, 0, 380),
        Folder = "RainbowDemo",
        Icon = "rbxassetid://12187365364", -- 示例图标
        Resizable = true
    })

    -- 1. 给窗口标题添加彩色循环
    local titleLabel = demoWindow.UIElements.Main.Main.Topbar.Left.Title.Title
    local titleRainbow = WindUI.AddRainbowLoop(titleLabel, 2, 0) -- 纵向环绕，2秒一圈

    -- 2. 给窗口边框添加彩色循环
    local windowBorder = WindUI.Creator.New("UIStroke", {
        Thickness = 3,
        ApplyStrokeMode = "Border"
    }, {Parent = demoWindow.UIElements.Main.Background})
    local borderRainbow = WindUI.AddRainbowLoop(windowBorder, 3, 0) -- 3秒一圈

    -- 3. 创建示例按钮并添加彩色循环
    local demoButton = WindUI.Creator.New("TextButton", {
        Size = UDim2.new(0, 200, 0, 50),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Text = "彩色循环按钮",
        TextSize = 18,
        FontFace = Font.new(WindUI.Creator.Font, Enum.FontWeight.SemiBold)
    }, {Parent = demoWindow.UIElements.MainBar})

    -- 给按钮背景和文字分别加循环
    local buttonBgRainbow = WindUI.AddRainbowLoop(demoButton, 2.2, 90) -- 横向环绕
    local buttonTextRainbow = WindUI.AddRainbowLoop(demoButton, 1.8, 90)

    -- 按钮点击事件（控制循环暂停/继续）
    WindUI.Creator.AddSignal(demoButton.MouseButton1Click, function()
        local isRunning = buttonBgRainbow.IsRunning()
        if isRunning then
            buttonBgRainbow.Pause()
            buttonTextRainbow.Pause()
            demoButton.Text = "继续彩色循环"
        else
            buttonBgRainbow.Resume()
            buttonTextRainbow.Resume()
            demoButton.Text = "暂停彩色循环"
        end
    end)

    -- 窗口关闭时停止所有循环
    demoWindow:OnClose(function()
        titleRainbow.Stop()
        borderRainbow.Stop()
        buttonBgRainbow.Stop()
        buttonTextRainbow.Stop()
    end)

    return demoWindow
end

-- 自动启动示例（若作为独立文件运行）
if script and script.Parent then
    task.spawn(function()
        task.wait(1) -- 等待WindUI完全初始化
        WindUI.CreateRainbowDemoWindow()
    end)
end

-- 导出到全局（方便其他脚本调用）
_G.WindUI = WindUI
print("[RainbowLoop] 彩色循环组件加载完成，可调用 WindUI.AddRainbowLoop()")
