--[[
-- @Name: Production Watcher
-- @Version: 1.0.0.0
-- @Author: Temmmych
-- @Contacts: https://github.com/Temmmych/FS25_ProductionWatcher
--]]

ProductionWatcher = {}
ProductionWatcher.showMouseCursor = false
ProductionWatcher.camera_pitch, ProductionWatcher.camera_yaw, ProductionWatcher.camera_roll = nil, nil, nil

local modName = g_currentModName
local modDirectory = g_currentModDirectory
local version = g_modManager:getModByName(modName).version
local ProductionWatcher_mt = Class(ProductionWatcher)

function ProductionWatcher.new()
    local self = setmetatable({}, ProductionWatcher_mt)
    self.messageWindow = MessageWindow.new()
    self.messageVisibility = true
    self.lastVehicle = nil
    self.prductionNextCheck = 0
    self.productionCheckInterval = 3
    addModEventListener(self)
    return self
end

function ProductionWatcher:check()
    if g_currentMission.productionChainManager ~= nil then
        local productionPoints = g_currentMission.productionChainManager.productionPoints
        for _, productionPoint in pairs(productionPoints) do
            if productionPoint.owningPlaceable.typeName == "productionPoint" or productionPoint.owningPlaceable.typeName == "greenhouse" then -- TODO лишнее
                local ownerFarmId = productionPoint.ownerFarmId
                if ownerFarmId ~= 0 and ownerFarmId == g_currentMission:getFarmId() then
                    local name = productionPoint.owningPlaceable:getName()
                    local uniqueId = productionPoint.owningPlaceable.uniqueId
                    local messageInputId = 0
                    local messageOutputId = 0

                    for _, production in productionPoint.productions do
                        if production.status > 0 then
                            for i, input in ipairs(production.inputs) do
                                local fillLevel = productionPoint.storage:getFillLevel(input.type)
                                local capacity = productionPoint.storage:getCapacity(input.type)
                                local fillLveleToCapacity = (fillLevel / capacity) * 100
                                if production.status == 2 or  fillLevel < input.amount then
                                    messageInputId = 3
                                elseif fillLveleToCapacity < 5 and messageInputId < 1 then
                                    messageInputId = 1
                                end
                            end

                            for i, output in ipairs(production.outputs) do
                                local fillLevel = productionPoint.storage:getFillLevel(output.type)
                                local capacity = productionPoint.storage:getCapacity(output.type)
                                local fillLveleToCapacity = (fillLevel / capacity) * 100
								local distributionMode = 0
								if productionPoint.getOutputDistributionMode ~= nil then
									distributionMode = productionPoint:getOutputDistributionMode(output.type)
								end
                                local distributionMode = productionPoint:getOutputDistributionMode(output.type)
                                if distributionMode ~= 1 and distributionMode ~= 2 then -- ProductionStorageControl has 3 for keep and 0 for spawn
                                    if production.status == 3 or fillLveleToCapacity > 99.5 then
                                        messageOutputId = 4
                                    elseif fillLveleToCapacity > 95 and messageOutputId < 2 then
                                        messageOutputId = 2
                                    end
                                end
                            end

                        end
                    end

                    if messageInputId > 0 then
                        self.messageWindow:addOrUpdateMessage({text = name, uniqueId = uniqueId, type = "input", messageId = messageInputId})
                    end

                    if messageOutputId > 0 then
                        self.messageWindow:addOrUpdateMessage({text = name, uniqueId = uniqueId, type = "output", messageId = messageOutputId})
                    end
                end
            end
        end
        self.messageWindow:deleteMessages()
    end
end

function ProductionWatcher:openProductionPointByUniqueId(uniqueId)
    for _, productionPoint in pairs(g_currentMission.productionChainManager.productionPoints) do
        if productionPoint.owningPlaceable.uniqueId == uniqueId then
            productionPoint:openMenu()
            return
        end
    end
end

function ProductionWatcher:loadMap(name)
    self.messageWindow.startX, self.messageWindow.startY = self:loadSettings()
end


function ProductionWatcher:toggleCursor()
    self:SetMouseCursor(not ProductionWatcher.showMouseCursor)
end

function ProductionWatcher:mouseEvent(posX, posY, isDown, isUp, button)
    if g_gui.currentGui ~= nil then return end

    if ProductionWatcher.showMouseCursor or g_inputBinding:getShowMouseCursor() then -- g_inputBinding:getShowMouseCursor() from other mods
        self.messageWindow:mouseEvent(posX, posY, isDown, isUp, button)
    end
end

function ProductionWatcher:SetMouseCursor(newSet)
    ProductionWatcher.showMouseCursor = newSet
    g_inputBinding:setShowMouseCursor(newSet)
    local vehicle = g_localPlayer:getCurrentVehicle()

    if vehicle ~= nil and vehicle.spec_enterable ~= nil and vehicle.spec_enterable.cameras ~= nil then
        for _, camera in pairs(vehicle.spec_enterable.cameras) do
            camera.isRotatable = not newSet
        end
    end
    
    if newSet or g_inputBinding:getShowMouseCursor() then -- g_inputBinding:getShowMouseCursor() from other mods
        if g_localPlayer.camera ~= nil then
            ProductionWatcher.camera_pitch, ProductionWatcher.camera_yaw, ProductionWatcher.camera_roll = g_localPlayer.camera:getRotation()
        end
    else
        ProductionWatcher.camera_pitch, ProductionWatcher.camera_yaw, ProductionWatcher.camera_roll = nil, nil, nil
    end
end

function ProductionWatcher:toggleMessageVisibility()
	self.messageVisibility = not self.messageWindow:issetVisibility()
    self.messageWindow:toggleVisibility(self.messageVisibility)
end

function ProductionWatcher:update(dt)
    if g_gui ~= nil and g_gui.currentGui ~= nil then return end
    
    if g_currentMission.time > self.prductionNextCheck then
        self:check()
        self.prductionNextCheck = g_currentMission.time + self.productionCheckInterval * 1000
    end

    local currentVehicle = g_localPlayer:getCurrentVehicle()

    if currentVehicle ~= self.lastVehicle then
        self:SetMouseCursor(false)
        self.lastVehicle = currentVehicle
    end

    if ProductionWatcher.camera_pitch ~= nil and g_localPlayer.camera ~= nil then
        g_localPlayer.camera:setRotation(ProductionWatcher.camera_pitch, ProductionWatcher.camera_yaw, ProductionWatcher.camera_roll)    
    end

    local _, actionEventId = g_inputBinding:registerActionEvent('PRODUCTIONWATCHER_CURSOR_ACTION_KEY', self, ProductionWatcher.toggleCursor, false, true, false, true)
    g_inputBinding:setActionEventText(actionEventId, g_i18n:getText("PRODUCTIONWATCHER_CURSOR_ACTION_KEY")) --
	g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_VERY_LOW) -- 
    g_inputBinding:setActionEventTextVisibility(actionEventId, false)

    local _, actionEventId = g_inputBinding:registerActionEvent('PRODUCTIONWATCHER_INPUT_ACTION_KEY', self, ProductionWatcher.toggleMessageVisibility, false, true, false, true)
    g_inputBinding:setActionEventText(actionEventId, g_i18n:getText("PRODUCTIONWATCHER_INPUT_ACTION_KEY")) --
	g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_VERY_LOW) -- 
    g_inputBinding:setActionEventTextVisibility(actionEventId, false)
end

function ProductionWatcher:draw()
    self.messageWindow:draw()
end

function ProductionWatcher:getSettingsFilePath()
    local saveGameDirectory = g_currentMission.missionInfo.savegameDirectory
    local fileSettingsName = "ProductionWatcherSettings_"
    return getUserProfileAppPath() .. "modSettings" .. "/" .. fileSettingsName .. ".xml"
end

function ProductionWatcher:saveSettings(posX, posY)
    local path = self:getSettingsFilePath()
    local xmlFile = createXMLFile("settings", path, "Settings")
    setXMLFloat(xmlFile, "Settings#posX", posX or 0.186354)
    setXMLFloat(xmlFile, "Settings#posY", posY or 0.953703)
    saveXMLFile(xmlFile)
    delete(xmlFile)
end

function ProductionWatcher:loadSettings()
    local path = self:getSettingsFilePath()
    local posX, posY =  0.186354, 0.953703
    if fileExists(path) then
        local xmlFile = loadXMLFile("settings", path)
        posX = getXMLFloat(xmlFile, "Settings#posX") or posX
        posY = getXMLFloat(xmlFile, "Settings#posY") or posY
        delete(xmlFile)
    end
    return posX, posY
end

ProductionWatcher.new()