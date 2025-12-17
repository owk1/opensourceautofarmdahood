repeat wait() until game:IsLoaded()
wait(2)

-- CONFIGURAÇÕES DO AUTO FARM (EDITÁVEIS)
local ENABLE_AUTO_FARM = true

-- CONFIGURAÇÕES DO AUTO MESSAGE (EDITÁVEIS)
local AUTO_MSG = true  -- true para ligar, false para desligar
local MSG_INTERVAL = 30  -- intervalo em segundos entre mensagens
local messages = {
    "get cheap da hood cash at letal,gg",
    "get serotonin at letal,gg", 
    "get vector at letal,gg"
}

-- CONFIGURAÇÕES DO AUTO SERVER HOP (EDITÁVEIS)
local AUTO_HOP = true
local HOP_TIME = 300  -- Tempo em segundos antes de fazer hop (5 minutos por padrão)

-- Sistema de Auto Message
if AUTO_MSG and #messages > 0 then
    task.spawn(function()
        local TextChatService = game:GetService("TextChatService")
        local msgIndex = 1
        local isSendingMsg = false
        
        local function sendChatAsync(msg)
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

        while true do
            if not isSendingMsg then
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
            
            wait(MSG_INTERVAL)
        end
    end)
end

-- Sistema de Auto Farm
if ENABLE_AUTO_FARM then
    local humanoid = game.Players.LocalPlayer.Character.Humanoid
    local tool = game.Players.LocalPlayer.Backpack.Combat

    local function getMoneyAroundMe() 
        wait(0.5)
        for i, money in ipairs(game.Workspace.Ignored.Drop:GetChildren()) do
            if money.Name == "MoneyDrop" and (money.Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude <= 20 then
                game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = money.CFrame
                fireclickdetector(money.ClickDetector)
                wait(0.5)
            end  
        end
    end

    local function startAutoFarm() 
        humanoid:EquipTool(tool)

        for i, v in ipairs(game.Workspace.Cashiers:GetChildren()) do
            game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = v.Open.CFrame * CFrame.new(0, 0, 2)

            for i = 0, 15 do
                wait(0.5)
                tool:Activate()
            end

            getMoneyAroundMe()
        end
        wait(0.5)
    end

    startAutoFarm()
end

-- Sistema de Auto Server Hop
if AUTO_HOP then
    -- Espera o tempo configurado antes de fazer hop
    if HOP_TIME > 0 then
        wait(HOP_TIME)
    end
    
    local PlaceID = game.PlaceId
    local AllIDs = {}
    local foundAnything = ""
    local actualHour = os.date("!*t").hour
    local Deleted = false

    local last

    local File = pcall(function()
       AllIDs = game:GetService('HttpService'):JSONDecode(readfile("NotSameServers.json"))
    end)
    if not File then
       table.insert(AllIDs, actualHour)
       writefile("NotSameServers.json", game:GetService('HttpService'):JSONEncode(AllIDs))
    end

    function TPReturner()
       local Site;
       if foundAnything == "" then
           Site = game.HttpService:JSONDecode(game:HttpGet('https://games.roblox.com/v1/games/' .. PlaceID .. '/servers/Public?sortOrder=Asc&limit=100'))
       else
           Site = game.HttpService:JSONDecode(game:HttpGet('https://games.roblox.com/v1/games/' .. PlaceID .. '/servers/Public?sortOrder=Asc&limit=100&cursor=' .. foundAnything))
       end
       local ID = ""
       if Site.nextPageCursor and Site.nextPageCursor ~= "null" and Site.nextPageCursor ~= nil then
           foundAnything = Site.nextPageCursor
       end
       local num = 0;
       local extranum = 0
       for i,v in pairs(Site.data) do
           extranum += 1
           local Possible = true
           ID = tostring(v.id)
           if tonumber(v.maxPlayers) > tonumber(v.playing) then
               if extranum ~= 1 and tonumber(v.playing) < last or extranum == 1 then
                   last = tonumber(v.playing)
               elseif extranum ~= 1 then
                   continue
               end
               for _,Existing in pairs(AllIDs) do
                   if num ~= 0 then
                       if ID == tostring(Existing) then
                           Possible = false
                       end
                   else
                       if tonumber(actualHour) ~= tonumber(Existing) then
                           local delFile = pcall(function()
                               delfile("NotSameServers.json")
                               AllIDs = {}
                               table.insert(AllIDs, actualHour)
                           end)
                       end
                   end
                   num = num + 1
               end
               if Possible == true then
                   table.insert(AllIDs, ID)
                   wait()
                   pcall(function()
                       writefile("NotSameServers.json", game:GetService('HttpService'):JSONEncode(AllIDs))
                       wait()
                       game:GetService("TeleportService"):TeleportToPlaceInstance(PlaceID, ID, game.Players.LocalPlayer)
                   end)
                   wait(4)
               end
           end
       end
    end

    function Teleport()
       while wait() do
           pcall(function()
               TPReturner()
               if foundAnything ~= "" then
                   TPReturner()
               end
           end)
       end
    end

    Teleport()
end
