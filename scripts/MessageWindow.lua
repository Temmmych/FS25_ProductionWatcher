--[[
-- @Name: Production Watcher
-- @Version: 1.0.0.0
-- @Author: Temmmych
-- @Contacts: https://github.com/Temmmych/FS25_ProductionWatcher
--]]

MessageWindow = {}
local MessageWindow_mt = Class(MessageWindow)
local texturePath = g_currentModDirectory .. "gui/background.dds"
local bgOverlay = createImageOverlay(texturePath)
local infoMessages = {
    "message_matreials_5",
    "message_stock_95",
    "message_matreials_empty",
    "message_stock_full"
}

function MessageWindow.new()
    local self = setmetatable({}, MessageWindow_mt)
    self.messages = {}
    self.maxMessageLenght = 23
    self.startX = 0.186354
    self.startY = 0.953703
    self.uiScale = g_gameSettings:getValue('uiScale')
    self.fontSize = self.uiScale * 0.014
    self.textHeight = getTextHeight(self.fontSize, "Text")
    self.paddingX = self.uiScale * 0.003
    self.paddingY = self.uiScale * 0.0052
    self.spacing = self.uiScale * 0.005
    self.bgWidth = self.uiScale * 0.2
    self.bgHeight = self.textHeight + 0.0065
    self.dragging = false
    self.dragOffsetX = 0
    self.dragOffsetY = 0
    return self
end

function MessageWindow:addOrUpdateMessage(message)
    local l10n = g_i18n:getText(infoMessages[message.messageId])
    local upd = false
    message.text = self:subStr(message.text, self.maxMessageLenght)
    message.text =  utf8ToUpper(message.text  .. ": " .. l10n)
    for i, msg in ipairs(self.messages) do
        if msg.uniqueId == message.uniqueId then
            if msg.type == message.type then
                upd = true
                msg.update = true
                if msg.lastMessageId ~= message.messageId then
                    msg.lastMessageId = message.messageId
                    msg.text = message.text
                    msg.show = true
                end
            end 
            break
        end
    end
    
    if not upd then
        message.lastMessageId = message.messageId
        message.update = true
        message.show = true
        table.insert(self.messages, message)
    end
end

function MessageWindow:deleteMessages()
    for i = #self.messages, 1, -1 do
        if not self.messages[i].update then
            table.remove(self.messages, i)
        else
            self.messages[i].update = false
        end
    end
end

function MessageWindow:draw()
    if not g_currentMission.hud.isVisible then return end
    if next(self.messages) == nil then return end
    local counter = 0
    for i, msg in ipairs(self.messages) do
        if msg.show then
            msg.bgX = self.startX
            msg.bgY = self.startY - counter * (self.bgHeight + self.spacing)
            msg.enterWidth = self.uiScale * 0.016
            msg.enterX = msg.bgX - msg.enterWidth
            msg.closeWidth = self.uiScale * 0.011
            msg.closeX = msg.bgX + self.bgWidth
            local textX = msg.bgX + self.paddingX
            local textY = msg.bgY + self.paddingY
            
            setOverlayColor(bgOverlay, 0, 0, 0, 0.9)
            renderOverlay(bgOverlay, msg.enterX, msg.bgY, msg.enterWidth, self.bgHeight)
            setTextBold(true)
            setTextColor(1, 1, 1, 1)
            renderText(msg.enterX + self.paddingX, textY + 0.0014, self.fontSize, "[+]")

            setOverlayColor(bgOverlay, 0, 0, 0, 0.65)
            renderOverlay(bgOverlay, msg.bgX, msg.bgY, self.bgWidth, self.bgHeight)

            setTextBold(false)
            setTextColor(1, 1, 1, 1)
            renderText(textX, textY, self.fontSize, msg.text)

            
            setOverlayColor(bgOverlay, 0, 0, 0, 0.9)
            renderOverlay(bgOverlay, msg.closeX, msg.bgY, msg.closeWidth, self.bgHeight)
            setTextBold(true)
            setTextColor(1, 1, 1, 1)
            renderText(msg.closeX + self.paddingX, textY, self.fontSize, "X")

            counter = counter + 1
        end
    end
end

function MessageWindow:mouseEvent(posX, posY, isDown, isUp, button)
    if next(self.messages) == nil then return end
    if g_gui.currentGui ~= nil then return end

    if button == 1 then
        if isDown then
            for i, msg in ipairs(self.messages) do
                if posX > msg.bgX and posX < msg.bgX + self.bgWidth 
                   and posY > msg.bgY and posY < msg.bgY + self.bgHeight then
                    self.isDragging = true
                    self.dragOffsetX = posX - self.startX
                    self.dragOffsetY = posY - self.startY
                    return
                end
            end
        elseif isUp then
            if self.isDragging then
                ProductionWatcher:saveSettings(self.startX, self.startY)
            end
            self.isDragging = false
            for i = #self.messages, 1, -1 do
                local msg = self.messages[i]
                if posX > msg.enterX and posX < msg.enterX + msg.enterWidth 
                   and posY > msg.bgY and posY < msg.bgY + self.bgHeight then
                    ProductionWatcher:openProductionPointByUniqueId(self.messages[i].uniqueId)
                    return
                end
                if posX > msg.closeX and posX < msg.closeX + msg.closeWidth 
                   and posY > msg.bgY and posY < msg.bgY + self.bgHeight then
                    self.messages[i].show = false
                    return
                end
            end
        end
    end

    if self.isDragging and not isUp then
        self.startX = posX - self.dragOffsetX
        self.startY = posY - self.dragOffsetY
    end
end

function MessageWindow:subStr(str, length)
    if string.len(str) <= length then return str end
    return utf8Substr(str, 0, length) .. "..."
end