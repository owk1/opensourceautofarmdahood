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
local Character = LocalPlayer.Character
local Humanoid = Character and Character:WaitForChild("Humanoid")
local Backpack = LocalPlayer:WaitForChild("Backpack")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local TextChatService = game:GetService("TextChatService")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")

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
local HOP_ON_DEATH = true
local HOP_TIME = 1800
local MIN_PLAYERS = 4
local MAX_PLAYERS_FOR_DEATH_HOP = 6
local PlaceID = game.PlaceId
local visitedServers = {}
local cursor = ""
local deathCount = 0
local deathHopCooldown = 0
local hopInProgress = false

-- Configurações do Chat
local AUTO_MSG = true
local MSG_INTERVAL = 30
local messages = {
    "get da hood cash at letal,gg",
    "get vector at letal,gg",
    "get sorotonin external at letal,gg",
    "get matcha external at letal,gg"
}

-- Variáveis
local startTime = tick()
local moneyCollected = 0
local lastHopTime = tick()
local lastActionTime = tick()
local idleThreshold = 15
local lastPosition = Vector3.new(0, 0, 0)
local isRespawning = false

-- Sistema de Anti-Idle
local function checkIdle()
    local currentTime = tick()
    local hrp = Character and Character:FindFirstChild("HumanoidRootPart")
    
    if hrp then
        local currentPos = hrp.Position
        local distanceMoved = (currentPos - lastPosition).Magnitude
        
        if distanceMoved < 2 and (currentTime - lastActionTime) > idleThreshold then
            print("⚠️ Personagem está idle! Tomando ações corretivas...")
            return true
        end
        
        lastPosition = currentPos
    end
    
    return false
end

local function fixIdle()
    if not Character or not Character.Parent then return end
    
    print("Executando correção de idle...")
    
    local actions = {
        function()
            if Humanoid then
                Humanoid.Jump = true
                task.wait(0.5)
                Humanoid.Jump = false
            end
        end,
        function()
            if Humanoid then
                local hrp = Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    hrp.CFrame = hrp.CFrame * CFrame.new(10, 0, 0)
                end
            end
        end,
        function()
            forceEquipTool()
        end
    }
    
    for _, action in ipairs(actions) do
        pcall(action)
        task.wait(0.5)
    end
    
    lastActionTime = tick()
    print("✅ Correção de idle aplicada")
end

-- Sistema de verificação do Combat
local function checkToolEquipped()
    if not Character or not Character.Parent then return false, false end
    
    -- Verifica se o Combat está equipado no personagem
    tool = Character:FindFirstChild(TOOL_NAME)
    if tool and tool:IsA("Tool") then
        return true, true
    end
    
    -- Verifica se está na mochila
    tool = Backpack:FindFirstChild(TOOL_NAME)
    if tool and tool:IsA("Tool") then
        return false, true
    end
    
    -- Procura por qualquer ferramenta com nome similar
    for _, child in pairs(Backpack:GetChildren()) do
        if child:IsA("Tool") and string.find(child.Name:lower(), "combat") then
            tool = child
            return false, true
        end
    end
    
    for _, child in pairs(Character:GetChildren()) do
        if child:IsA("Tool") and string.find(child.Name:lower(), "combat") then
            tool = child
            return true, true
        end
    end
    
    return false, false
end

local function isAlive()
    return Character and Character.Parent and Humanoid and Humanoid.Health > 0
end

local function forceEquipTool()
    if not isAlive() then 
        return false 
    end
    
    local isEquipped, exists = checkToolEquipped()
    
    if isEquipped then
        return true
    elseif exists and tool then
        Humanoid:EquipTool(tool)
        print("Combat equipado forçadamente")
        lastActionTime = tick()
        return true
    end
    
    print("❌ Combat não encontrado")
    return false
end

-- Sistema de Hop melhorado
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

local function findLowPlayerServer(maxPlayers)
    if hopInProgress then return false end
    hopInProgress = true
    
    local url = 'https://games.roblox.com/v1/games/' .. PlaceID .. '/servers/Public?sortOrder=Asc&limit=100'
    if cursor ~= "" then url = url .. '&cursor=' .. cursor end
    
    local success, data = pcall(function()
        return HttpService:JSONDecode(game:HttpGet(url))
    end)
    
    if not success or not data or not data.data then 
        hopInProgress = false
        return false 
    end
    
    cursor = data.nextPageCursor or ""
    
    local servers = {}
    for _, server in pairs(data.data) do
        local id = tostring(server.id)
        local playing = tonumber(server.playing) or 0
        
        if playing <= maxPlayers and id ~= game.JobId then
            local alreadyVisited = false
            for _, visited in ipairs(visitedServers) do
                if tostring(visited) == id then
                    alreadyVisited = true
                    break
                end
            end
            
            if not alreadyVisited then
                table.insert(servers, {
                    id = id,
                    players = playing
                })
            end
        end
    end
    
    table.sort(servers, function(a, b)
        return a.players < b.players
    end)
    
    for _, server in ipairs(servers) do
        if server.players <= maxPlayers then
            table.insert(visitedServers, server.id)
            if #visitedServers > 50 then
                table.remove(visitedServers, 1)
            end
            
            pcall(function()
                writefile("NotSameServers.json", HttpService:JSONEncode(visitedServers))
            end)
            
            print("🔄 Conectando ao servidor low com " .. server.players .. " jogadores...")
            
            local teleportSuccess = pcall(function()
                TeleportService:TeleportToPlaceInstance(PlaceID, server.id, LocalPlayer)
            end)
            
            hopInProgress = false
            return teleportSuccess
        end
    end
    
    hopInProgress = false
    return false
end

local function hopOnDeath()
    if not HOP_ON_DEATH then return false end
    if hopInProgress then return false end
    if tick() - deathHopCooldown < 60 then return false end
    
    print("💀 Personagem morreu! Procurando servidor low...")
    
    local success = findLowPlayerServer(MAX_PLAYERS_FOR_DEATH_HOP)
    
    if success then
        deathHopCooldown = tick()
        task.wait(5)
    else
        print("❌ Não foi encontrar servidor low disponível")
    end
    
    return success
end

-- Sistema de movimentação com Pathfinding
local function moveToPosition(targetPosition)
    if not isAlive() then return false end
    
    local hrp = Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    
    local distance = (hrp.Position - targetPosition).Magnitude
    
    -- Se estiver muito longe, teleporta
    if distance > 100 then
        hrp.CFrame = CFrame.new(targetPosition + Vector3.new(0, 5, 0))
        task.wait(1)
        return true
    end
    
    -- Usa pathfinding para distâncias médias
    if distance > 10 then
        local path = PathfindingService:CreatePath({
            AgentRadius = 2,
            AgentHeight = 5,
            AgentCanJump = true
        })
        
        path:ComputeAsync(hrp.Position, targetPosition)
        
        if path.Status == Enum.PathStatus.Success then
            local waypoints = path:GetWaypoints()
            
            for _, waypoint in ipairs(waypoints) do
                if not isAlive() then break end
                
                Humanoid:MoveTo(waypoint.Position)
                
                local reached = false
                local startTime = tick()
                
                while not reached and tick() - startTime < 3 do
                    if (hrp.Position - waypoint.Position).Magnitude < 4 then
                        reached = true
                    end
                    task.wait()
                end
                
                if waypoint.Action == Enum.PathWaypointAction.Jump then
                    Humanoid.Jump = true
                end
                
                task.wait(0.1)
            end
            
            return true
        end
    end
    
    -- Movimento direto para distâncias curtas
    Humanoid:MoveTo(targetPosition)
    
    local startTime = tick()
    while (hrp.Position - targetPosition).Magnitude > 4 and tick() - startTime < 3 do
        if not isAlive() then return false end
        task.wait()
    end
    
    lastActionTime = tick()
    return true
end

local function moveTo(cframe)
    if not cframe or not isAlive() then return false end
    return moveToPosition(cframe.Position)
end

-- Sistema de chat melhorado
local function sendChatAsync(msg)
    if not msg or msg == "" then return false end
    
    return pcall(function()
        local channel = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
        if channel then
            channel:SendAsync(msg)
            lastActionTime = tick()
            return true
        end
        return false
    end)
end

local msgIndex = 1
local function startAutoChat()
    if not AUTO_MSG or #messages == 0 then return end
    
    task.spawn(function()
        while running and AUTO_MSG do
            if isAlive() then
                local msg = messages[msgIndex]
                sendChatAsync(msg)
                
                msgIndex = msgIndex + 1
                if msgIndex > #messages then
                    msgIndex = 1
                end
            end
            
            task.wait(MSG_INTERVAL)
        end
    end)
end

-- Funções do Farm
local function equipTool()
    if not isAlive() then return false end
    return forceEquipTool()
end

local function collectMoney()
    if not isAlive() then return 0 end
    
    local drops = game.Workspace:FindFirstChild("Ignored")
    drops = drops and drops:FindFirstChild("Drop")
    if not drops then return 0 end
    
    local collected = 0
    local hrp = Character:FindFirstChild("HumanoidRootPart")
    
    if not hrp then return 0 end
    
    for _, money in ipairs(drops:GetChildren()) do
        if money.Name == "MoneyDrop" and money:FindFirstChild("ClickDetector") then
            if (money.Position - hrp.Position).Magnitude <= 20 then
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
    if not isAlive() or not atm or not atm.Parent then return false end
    
    local openPart = atm:FindFirstChild("Open")
    if not openPart then return false end
    
    -- Primeiro equipa a ferramenta
    if not equipTool() then 
        print("❌ Não foi possível equipar o Combat, abortando ataque")
        return false
    end
    
    -- Move até o ATM
    if not moveTo(openPart.CFrame * CFrame.new(1, 0, 2)) then
        print("❌ Não foi possível chegar ao ATM")
        return false
    end
    
    task.wait(0.5) -- Pequena pausa antes de atacar
    
    -- Verifica novamente se está vivo e com a ferramenta
    if not isAlive() then return false end
    
    local isEquipped, _ = checkToolEquipped()
    if not isEquipped then
        print("❌ Ferramenta não está equipada, reequipando...")
        equipTool()
    end
    
    -- Ataca o ATM
    for i = 1, ATTACK_REPEATS do
        if not isAlive() then break end
        
        -- Verifica a cada 3 ataques se a ferramenta ainda está equipada
        if i % 3 == 0 then
            local isEquipped, _ = checkToolEquipped()
            if not isEquipped and not equipTool() then
                print("❌ Perdeu a ferramenta durante o ataque")
                break
            end
        end
        
        if tool and tool.Parent == Character then
            tool:Activate()
            lastActionTime = tick()
        end
        
        task.wait(ATTACK_INTERVAL)
    end
    
    return true
end

-- Sistema de monitoramento
local function startToolMonitor()
    task.spawn(function()
        while running do
            task.wait(3)
            
            if not running then break end
            if not isAlive() then 
                task.wait(2)
                continue 
            end
            
            local isEquipped, exists = checkToolEquipped()
            
            if exists and not isEquipped then
                print("🔧 Combat na mochila mas não equipado. Equipando...")
                forceEquipTool()
            elseif not exists then
                print("⚠️ Combat não encontrado")
            end
        end
    end)
end

local function startAntiIdle()
    task.spawn(function()
        while running do
            task.wait(3)
            
            if not running then break end
            if not isAlive() or isRespawning then 
                task.wait(2)
                continue 
            end
            
            if checkIdle() then
                fixIdle()
            end
        end
    end)
end

-- Loop Principal Corrigido
local function mainLoop()
    print("✅ Script iniciado com sucesso!")
    print("⚙️ Configurações: Hop=" .. tostring(AUTO_HOP) .. ", DeathHop=" .. tostring(HOP_ON_DEATH))
    
    -- Aguarda personagem inicial
    if not Character then
        Character = LocalPlayer.CharacterAdded:Wait()
        task.wait(1)
    end
    
    if not Humanoid then
        Humanoid = Character:WaitForChild("Humanoid")
    end
    
    -- Inicializa sistemas
    startToolMonitor()
    startAntiIdle()
    startAutoChat()
    
    -- Loop principal
    while running do
        -- Verifica se está vivo
        if not isAlive() then
            task.wait(1)
            continue
        end
        
        -- Atualiza posição
        local hrp = Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            lastPosition = hrp.Position
        end
        
        -- Verifica hop automático
        if AUTO_HOP and tick() - startTime > HOP_TIME and tick() - lastHopTime > 300 then
            lastHopTime = tick()
            if findLowPlayerServer(MIN_PLAYERS) then
                task.wait(10)
                return
            end
        end
        
        -- Equipa ferramenta antes de qualquer ação
        if not equipTool() then
            print("❌ Sem ferramenta, aguardando...")
            task.wait(2)
            continue
        end
        
        -- Procura caixas eletrônicos
        local atms = game.Workspace:FindFirstChild("Cashiers")
        if not atms then
            print("⏳ Caixas não encontrados, aguardando...")
            task.wait(3)
            continue
        end
        
        local atmList = atms:GetChildren()
        if #atmList == 0 then
            print("⏳ Nenhum caixa disponível, aguardando...")
            task.wait(2)
            continue
        end
        
        -- Processa caixas eletrônicos
        local attacked = false
        
        for i = cashierIndex, #atmList do
            if not running or not isAlive() then break end
            
            local atm = atmList[i]
            
            print("🎯 Atacando caixa " .. i .. " de " .. #atmList)
            
            if attackATM(atm) then
                collectMoney()
                attacked = true
                task.wait(0.5)
            else
                print("❌ Falha ao atacar caixa, tentando próximo...")
                task.wait(0.2)
            end
            
            cashierIndex = i + 1
            if cashierIndex > #atmList then
                cashierIndex = 1
            end
            
            task.wait(0.3)
        end
        
        -- Pausa entre ciclos
        if attacked then
            task.wait(1)
        else
            print("🔁 Nenhum caixa atacado, reiniciando ciclo...")
            task.wait(2)
        end
    end
end

-- Eventos Corrigidos
local function setupCharacterEvents()
    LocalPlayer.CharacterAdded:Connect(function(newChar)
        print("🔄 Personagem respawnando...")
        isRespawning = true
        
        Character = newChar
        task.wait(1) -- Aguarda carregamento
        
        Humanoid = newChar:WaitForChild("Humanoid")
        lastActionTime = tick()
        
        -- Aguarda ferramenta aparecer
        local maxWait = 10
        local waited = 0
        
        while waited < maxWait do
            if Backpack:FindFirstChild(TOOL_NAME) then
                break
            end
            
            -- Também verifica por ferramentas similares
            local found = false
            for _, child in pairs(Backpack:GetChildren()) do
                if child:IsA("Tool") and string.find(child.Name:lower(), "combat") then
                    found = true
                    break
                end
            end
            
            if found then break end
            
            task.wait(0.5)
            waited = waited + 0.5
        end
        
        forceEquipTool()
        isRespawning = false
        print("✅ Personagem respawnado e preparado")
    end)
end

-- Inicialização Segura
setupCharacterEvents()

-- Se já temos personagem, força equipamento inicial
if Character and Humanoid then
    task.wait(1)
    forceEquipTool()
end

-- Comandos
LocalPlayer.Chatted:Connect(function(msg)
    local cmd = msg:lower()
    
    if cmd == "/stop" then
        running = false
        print("🛑 Script parado")
    elseif cmd == "/hop" then
        findLowPlayerServer(MIN_PLAYERS)
    elseif cmd == "/stats" then
        local elapsed = math.floor((tick() - startTime) / 60)
        print("📊 Tempo: " .. elapsed .. "m | Dinheiro: " .. moneyCollected)
        print("💀 Mortes: " .. deathCount)
    elseif cmd == "/fixidle" then
        fixIdle()
    elseif cmd == "/checktool" then
        local isEquipped, exists = checkToolEquipped()
        if isEquipped then
            print("✅ Combat equipado")
        elseif exists then
            print("⚠️ Combat na mochila (não equipado)")
            forceEquipTool()
        else
            print("❌ Combat não encontrado")
        end
    end
end)

-- Inicia o loop principal
mainLoop()
