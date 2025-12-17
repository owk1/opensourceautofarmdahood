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
local RunService = game:GetService("RunService")

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
local HOP_TIME = 1800
local MIN_PLAYERS = 4
local PlaceID = game.PlaceId
local visitedServers = {}
local cursor = ""

-- Configurações do Chat
local AUTO_MSG = true
local MSG_INTERVAL = 30
local messages = {
    "buy da hood cash at letal,gg",
    "get da hood cash accs at letal,gg",
    "get sorotonin external at letal,gg",
    "get matcha external at letal,gg"
}

-- Variáveis
local startTime = tick()
local moneyCollected = 0
local lastHopTime = tick()
local isDead = false
local lastActionTime = tick()
local idleThreshold = 15 -- segundos sem ação
local lastPosition = Vector3.new(0, 0, 0)

-- Sistema de Anti-Idle
local function checkIdle()
    local currentTime = tick()
    local hrp = Character and Character:FindFirstChild("HumanoidRootPart")
    
    if hrp then
        local currentPos = hrp.Position
        local distanceMoved = (currentPos - lastPosition).Magnitude
        
        -- Se não se moveu pelo menos 2 unidades em idleThreshold segundos
        if distanceMoved < 2 and (currentTime - lastActionTime) > idleThreshold then
            print("⚠️ Personagem está idle! Tomando ações corretivas...")
            return true
        end
        
        lastPosition = currentPos
    end
    
    return false
end

local function fixIdle()
    print("Executando correção de idle...")
    
    -- Tenta diferentes ações para sair do estado idle
    local actions = {
        function()
            -- Pular
            if Humanoid then
                Humanoid.Jump = true
                task.wait(0.5)
                Humanoid.Jump = false
            end
        end,
        function()
            -- Movimento lateral
            if Humanoid then
                Humanoid:Move(Vector3.new(5, 0, 0))
                task.wait(1)
                Humanoid:Move(Vector3.new(0, 0, 0))
            end
        end,
        function()
            -- Teleportar para posição segura
            local hrp = Character and Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.CFrame = CFrame.new(0, 10, 0)
            end
        end,
        function()
            -- Reequipar tool
            forceEquipTool()
        end
    }
    
    -- Executa ações aleatórias para desbloquear
    for _, action in ipairs(actions) do
        pcall(action)
        task.wait(0.5)
    end
    
    lastActionTime = tick()
    print("✅ Correção de idle aplicada")
end

-- Sistema de verificação do Combat
local function checkToolEquipped()
    if not Character or not Character.Parent then return false end
    
    -- Verifica se o Combat está equipado no personagem
    tool = Character:FindFirstChild(TOOL_NAME)
    if tool and tool:IsA("Tool") then
        return true
    end
    
    -- Verifica se está na mochila
    tool = Backpack:FindFirstChild(TOOL_NAME)
    if tool and tool:IsA("Tool") then
        return false, true -- Não está equipado, mas existe na mochila
    end
    
    return false, false -- Não existe
end

local function forceEquipTool()
    if not Character or not Character.Parent or not Humanoid then 
        return false 
    end
    
    -- Verifica se o personagem está morto
    if Humanoid.Health <= 0 then
        isDead = true
        return false
    else
        isDead = false
    end
    
    -- Procura pelo Combat
    tool = Backpack:FindFirstChild(TOOL_NAME) or Character:FindFirstChild(TOOL_NAME)
    
    if tool and tool:IsA("Tool") then
        -- Se o tool está na mochila, equipa
        if tool.Parent == Backpack then
            Humanoid:EquipTool(tool)
            print("Combat equipado forçadamente")
            lastActionTime = tick()
            return true
        -- Se já está equipado
        elseif tool.Parent == Character then
            return true
        end
    end
    
    return false
end

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

-- Sistema de chat melhorado (não bloqueante)
local msgQueue = {}
local isSendingMsg = false

local function sendChatAsync(msg)
    if not msg or msg == "" then return false end
    
    return pcall(function()
        local channel = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
        if channel then
            channel:SendAsync(msg)
            lastActionTime = tick() -- Atualiza tempo da última ação
            return true
        end
        return false
    end)
end

-- Sistema de mensagens automáticas melhorado
local msgIndex = 1
local function startAutoChat()
    if not AUTO_MSG or #messages == 0 then return end
    
    task.spawn(function()
        while running and AUTO_MSG do
            -- Envia mensagem se não estiver enviando e houver mensagens na fila
            if not isSendingMsg and #msgQueue == 0 then
                local msg = messages[msgIndex]
                isSendingMsg = true
                
                task.spawn(function()
                    sendChatAsync(msg)
                    isSendingMsg = false
                end)
                
                msgIndex = msgIndex + 1
                if msgIndex > #messages then
                    msgIndex = 1
                end
            end
            
            task.wait(MSG_INTERVAL)
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
    local isEquipped, existsInBackpack = checkToolEquipped()
    
    if isEquipped then
        return true
    elseif existsInBackpack then
        return forceEquipTool()
    end
    
    return false
end

local function validateChar()
    if not Character or not Character.Parent then
        Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        Humanoid = Character:WaitForChild("Humanoid")
        isDead = false
        lastActionTime = tick()
        return false
    end
    
    -- Verifica se o personagem está morto
    if Humanoid.Health <= 0 then
        if not isDead then
            print("Personagem morreu, aguardando respawn...")
            isDead = true
        end
        return false
    end
    
    isDead = false
    return true
end

local function avoidChair()
    if Humanoid and Humanoid.Sit then
        Humanoid.Sit = false
        local hrp = Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = hrp.CFrame * CFrame.new(5, 0, 0)
        end
        task.wait(0.5)
        lastActionTime = tick()
    end
end

local function moveTo(pos)
    if not pos or not validateChar() then return false end
    
    local hrp = Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.CFrame = pos
        lastActionTime = tick()
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
                    lastActionTime = tick()
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
    
    if not equipTool() then 
        print("Não foi possível equipar o Combat")
        return false
    end
    
    for i = 1, ATTACK_REPEATS do
        if not validateChar() then break end
        
        -- Verifica se o combat ainda está equipado durante o ataque
        if i % 5 == 0 then -- Verifica a cada 5 ataques
            equipTool()
        end
        
        if tool and tool.Parent == Character then
            tool:Activate()
            lastActionTime = tick()
        end
        
        task.wait(ATTACK_INTERVAL)
    end
    
    return true
end

-- Sistema de monitoramento contínuo do Combat
local function startToolMonitor()
    task.spawn(function()
        while running do
            task.wait(5) -- Verifica a cada 5 segundos
            
            if not running then break end
            
            if validateChar() then
                local isEquipped, existsInBackpack = checkToolEquipped()
                
                if existsInBackpack and not isEquipped then
                    print("Combat detectado na mochila mas não equipado. Equipando...")
                    forceEquipTool()
                elseif not existsInBackpack then
                    print("Combat não encontrado na mochila ou no personagem")
                end
            end
        end
    end)
end

-- Sistema Anti-Idle
local function startAntiIdle()
    task.spawn(function()
        while running do
            task.wait(3) -- Verifica a cada 3 segundos
            
            if not running then break end
            
            if validateChar() then
                if checkIdle() then
                    fixIdle()
                end
            end
        end
    end)
end

-- Loop Principal
local function mainLoop()
    print("Script iniciado")
    
    -- Inicializa última posição
    local hrp = Character and Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        lastPosition = hrp.Position
    end
    
    lastActionTime = tick()
    
    -- Inicia o monitor do Combat
    startToolMonitor()
    
    -- Inicia o sistema anti-idle
    startAntiIdle()
    
    -- Inicia o sistema de mensagens automáticas
    startAutoChat()
    
    -- Loop principal otimizado
    while running do
        -- Verifica necessidade de hop
        if shouldHop() then
            lastHopTime = tick()
            
            if findServer() then
                task.wait(10)
                return
            else
                startTime = tick() - 1200
            end
        end
        
        -- Verifica se personagem é válido
        if not validateChar() then
            task.wait(1)
            continue
        end
        
        -- Atualiza posição para cálculo de idle
        hrp = Character and Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            lastPosition = hrp.Position
        end
        
        -- Força o equipamento do Combat
        equipTool()
        
        -- Busca caixas eletrônicos
        local atms = game.Workspace:FindFirstChild("Cashiers")
        if not atms then
            print("Caixas eletrônicos não encontrados, aguardando...")
            task.wait(3)
            continue
        end
        
        local atmList = atms:GetChildren()
        if #atmList == 0 then
            print("Nenhum caixa eletrônico disponível, aguardando...")
            task.wait(2)
            continue
        end
        
        -- Processa caixas eletrônicos
        local attacked = false
        
        for i = cashierIndex, #atmList do
            if not running then break end
            if not validateChar() then break end
            
            local atm = atmList[i]
            
            if attackATM(atm) then
                collectMoney()
                attacked = true
                lastActionTime = tick()
                task.wait(0.5)
            else
                task.wait(0.1)
            end
            
            cashierIndex = i + 1
            if cashierIndex > #atmList then
                cashierIndex = 1
            end
            
            -- Pequena pausa entre caixas
            task.wait(0.2)
        end
        
        -- Se não atacou nenhum caixa, espera menos tempo
        if not attacked then
            task.wait(0.5)
        else
            task.wait(1)
        end
    end
end

-- Eventos
LocalPlayer.CharacterAdded:Connect(function(newChar)
    Character = newChar
    Humanoid = newChar:WaitForChild("Humanoid")
    isDead = false
    lastActionTime = tick()
    
    task.wait(1.5) -- Espera reduzida para o personagem carregar
    
    -- Espera pelo Combat aparecer na mochila
    local maxWait = 8
    local waited = 0
    
    while waited < maxWait do
        if Backpack:FindFirstChild(TOOL_NAME) then
            break
        end
        task.wait(0.5)
        waited = waited + 1
    end
    
    forceEquipTool()
    print("Personagem respawnou, Combat reequipado")
end)

-- Monitora quando o personagem morre
if Humanoid then
    Humanoid.Died:Connect(function()
        isDead = true
        print("Personagem morreu")
    end)
end

-- Monitora movimento para atualizar idle
RunService.Heartbeat:Connect(function()
    if Character and Character.Parent then
        local hrp = Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            local velocity = hrp.AssemblyLinearVelocity
            if velocity.Magnitude > 2 then
                lastActionTime = tick()
            end
        end
    end
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
        sendChatAsync(msg:sub(6))
    elseif cmd == "/checktool" then
        local isEquipped, existsInBackpack = checkToolEquipped()
        if isEquipped then
            print("✓ Combat equipado")
        elseif existsInBackpack then
            print("✓ Combat na mochila (não equipado)")
            forceEquipTool()
        else
            print("✗ Combat não encontrado")
        end
    elseif cmd == "/fixidle" then
        fixIdle()
    elseif cmd == "/reset" then
        lastActionTime = tick()
        print("Tempo de ação resetado")
    end
end)

-- Inicialização
mainLoop()
