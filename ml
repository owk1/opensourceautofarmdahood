-- Esperar o servidor carregar completamente
local function waitForGameLoad()
    local maxWaitTime = 30 -- segundos
    local startTime = tick()
    
    -- Esperar pelo workspace carregar
    while not game:IsLoaded() and (tick() - startTime) < maxWaitTime do
        task.wait(1)
    end
    
    -- Esperar por elementos essenciais do jogo
    local essentials = {
        game.Workspace,
        game.Workspace:FindFirstChild("Ignored"),
        game.Workspace:FindFirstChild("Cashiers"),
        game:GetService("Players").LocalPlayer
    }
    
    for _, essential in ipairs(essentials) do
        if not essential then
            task.wait(1)
        end
    end
    
    print("Servidor carregado!")
    return true
end

-- Chamar a função de espera antes de continuar
if not waitForGameLoad() then
    warn("Não foi possível carregar o servidor completamente após 30 segundos")
    return
end

-- Serviços
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local Backpack = LocalPlayer:WaitForChild("Backpack")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local TextChatService = game:GetService("TextChatService")

-- Configurações
local TOOL_NAME = "Combat"
local tool
local running = true
local cashierIndex = 1

-- Parâmetros do Farm
local MOVE_DELAY = 0.5
local ATTACK_REPEATS = 15
local ATTACK_INTERVAL = 0.5

-- Configurações do Hop
local AUTO_HOP = true
local HOP_TIME = 300
local MIN_PLAYERS = 2
local PlaceID = game.PlaceId
local visitedServers = {}
local cursor = ""

-- Configurações do Chat
local AUTO_MSG = true
local MSG_INTERVAL = 30
local messages = {
    "buy da hood cash at letal,gg",
    "get da hood cash at letal,gg",
    "get sorotonin external at letal,gg",
    "get matcha external at letal,gg"
}

-- Variáveis
local startTime = tick()
local moneyCollected = 0
local lastHopTime = tick()

-- Sistema de Hop
local function initHopSystem()
    local success = pcall(function()
        if isfile and isfile("NotSameServers.json") then
            visitedServers = HttpService:JSONDecode(readfile("NotSameServers.json"))
        end
    end)
    
    if not success then
        table.insert(visitedServers, os.date("!*t").hour)
        writefile("NotSameServers.json", HttpService:JSONEncode(visitedServers))
    end
end

initHopSystem()

-- Funções do Chat - THREAD SEPARADA
local function sendChat(msg)
    if not msg or msg == "" then return false end
    
    return pcall(function()
        local channel = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
        if channel then
            channel:SendAsync(msg)
            return true
        end
        return false
    end)
end

-- Sistema de mensagens automáticas em thread separada
local msgIndex = 1
local function startAutoChat()
    if not AUTO_MSG or #messages == 0 then return end
    
    -- Envia primeira mensagem imediatamente
    task.spawn(function()
        local msg = messages[msgIndex]
        sendChat(msg)
        msgIndex = msgIndex + 1
        if msgIndex > #messages then msgIndex = 1 end
    end)
    
    -- Thread para mensagens periódicas
    task.spawn(function()
        while running and AUTO_MSG do
            task.wait(MSG_INTERVAL)
            
            if not running or not AUTO_MSG then break end
            
            local msg = messages[msgIndex]
            sendChat(msg)
            
            msgIndex = msgIndex + 1
            if msgIndex > #messages then
                msgIndex = 1
            end
        end
    end)
end

-- Funções do Hop
local function findServer()
    local url = 'https://games.roblox.com/v1/games/' .. PlaceID .. '/servers/Public?sortOrder=Asc&limit=100'
    if cursor ~= "" then url = url .. '&cursor=' .. cursor end
    
    local success, data = pcall(function()
        return HttpService:JSONDecode(game:HttpGet(url))
    end)
    
    if not success or not data or not data.data then return false end
    
    cursor = data.nextPageCursor or ""
    
    for _, server in pairs(data.data) do
        local id = tostring(server.id)
        local playing = tonumber(server.playing)
        
        if playing and playing <= MIN_PLAYERS and id ~= game.JobId then
            local alreadyVisited = false
            for _, visited in ipairs(visitedServers) do
                if tostring(visited) == id then
                    alreadyVisited = true
                    break
                end
            end
            
            if not alreadyVisited then
                table.insert(visitedServers, id)
                if #visitedServers > 50 then
                    table.remove(visitedServers, 1)
                end
                writefile("NotSameServers.json", HttpService:JSONEncode(visitedServers))
                
                TeleportService:TeleportToPlaceInstance(PlaceID, id, LocalPlayer)
                return true
            end
        end
    end
    
    return false
end

local function shouldHop()
    if not AUTO_HOP then return false end
    if tick() - startTime < HOP_TIME then return false end
    if #Players:GetPlayers() <= MIN_PLAYERS then return false end
    if tick() - lastHopTime < 300 then return false end
    
    return true
end

-- Funções do Farm
local function equipTool()
    tool = Backpack:FindFirstChild(TOOL_NAME) or Character:FindFirstChild(TOOL_NAME)
    if tool and tool:IsA("Tool") and tool.Parent ~= Character then
        Humanoid:EquipTool(tool)
    end
    return tool ~= nil
end

local function validateChar()
    if not Character or not Character.Parent then
        Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        Humanoid = Character:WaitForChild("Humanoid")
        return false
    end
    return true
end

local function avoidChair()
    if Humanoid.Sit then
        Humanoid.Sit = false
        local hrp = Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = hrp.CFrame * CFrame.new(5, 0, 0)
        end
        task.wait(0.5)
    end
end

local function moveTo(pos)
    if not pos or not validateChar() then return false end
    
    local hrp = Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.CFrame = pos
        task.wait(MOVE_DELAY)
        return true
    end
    return false
end

local function collectMoney()
    if not validateChar() then return 0 end
    
    local drops = game.Workspace:FindFirstChild("Ignored")
    drops = drops and drops:FindFirstChild("Drop")
    if not drops then return 0 end
    
    local collected = 0
    
    for _, money in ipairs(drops:GetChildren()) do
        if money.Name == "MoneyDrop" and money:FindFirstChild("ClickDetector") then
            local hrp = Character:FindFirstChild("HumanoidRootPart")
            if hrp and (money.Position - hrp.Position).Magnitude <= 20 then
                if moveTo(money.CFrame) then
                    fireclickdetector(money.ClickDetector)
                    collected = collected + 1
                    moneyCollected = moneyCollected + 1
                    task.wait(0.1)
                end
            end
        end
    end
    
    return collected
end

local function attackATM(atm)
    if not validateChar() or not atm or not atm.Parent then return false end
    
    local openPart = atm:FindFirstChild("Open")
    if not openPart then return false end
    
    avoidChair()
    
    if not moveTo(openPart.CFrame * CFrame.new(1, 0, 2)) then
        return false
    end
    
    avoidChair()
    
    if not equipTool() then return false end
    
    for i = 1, ATTACK_REPEATS do
        if not validateChar() then break end
        
        if tool and tool.Parent == Character then
            tool:Activate()
        end
        
        task.wait(ATTACK_INTERVAL)
    end
    
    return true
end

-- Loop Principal
local function mainLoop()
    print("Script iniciado")
    
    equipTool()
    
    -- Inicia o sistema de mensagens automáticas
    startAutoChat()
    
    while running do
        if shouldHop() then
            lastHopTime = tick()
            
            if findServer() then
                task.wait(10)
                return
            else
                startTime = tick() - 1200
            end
        end
        
        if not validateChar() then
            task.wait(3)
            continue
        end
        
        equipTool()
        
        local atms = game.Workspace:FindFirstChild("Cashiers")
        if not atms then
            task.wait(5)
            continue
        end
        
        local atmList = atms:GetChildren()
        if #atmList == 0 then
            task.wait(2)
            continue
        end
        
        for i = cashierIndex, #atmList do
            if not running then break end
            if not validateChar() then break end
            
            local atm = atmList[i]
            
            if attackATM(atm) then
                collectMoney()
                task.wait(0.5)
            end
            
            cashierIndex = i + 1
            if cashierIndex > #atmList then
                cashierIndex = 1
            end
        end
        
        task.wait(1)
    end
end

-- Eventos
LocalPlayer.CharacterAdded:Connect(function(newChar)
    Character = newChar
    Humanoid = newChar:WaitForChild("Humanoid")
    task.wait(2)
    equipTool()
end)

-- Comandos
LocalPlayer.Chatted:Connect(function(msg)
    local cmd = msg:lower()
    
    if cmd == "/stop" then
        running = false
        print("Script parado")
    elseif cmd == "/hop" then
        findServer()
    elseif cmd == "/stats" then
        local elapsed = math.floor((tick() - startTime) / 60)
        print("Tempo: " .. elapsed .. "m | Dinheiro: " .. moneyCollected)
    elseif cmd == "/msg on" then
        AUTO_MSG = true
        startAutoChat()
        print("Mensagens ON")
    elseif cmd == "/msg off" then
        AUTO_MSG = false
        print("Mensagens OFF")
    elseif cmd:sub(1, 5) == "/msg " then
        sendChat(msg:sub(6))
    end
end)

-- Inicialização
mainLoop()
