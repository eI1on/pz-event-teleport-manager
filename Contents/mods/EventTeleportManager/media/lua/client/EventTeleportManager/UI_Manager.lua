local DateTimeUtility = require("ElyonLib/DateTime/DateTimeUtility")
local DateTimeModel = require("ElyonLib/DateTime/DateTimeModel")
local DateTimeSelector = require("ElyonLib/UI/Calendar/DateTimeSelector")

local Logger = require("EventTeleportManager/Logger")
local EventTeleportManager = require("EventTeleportManager/Shared")

local CONST = {
	LAYOUT = {
		WINDOW_SIZE = {
			MAIN_PANEL = {
				WIDTH = 650,
				HEIGHT = 550,
			},
			PLAYER_SELECTION_MODAL = {
				WIDTH = 350,
				HEIGHT = 450,
			},
		},
		TAB = {
			HEIGHT = 30,
		},
		BUTTON = {
			WIDTH = 110,
			HEIGHT = 25,
		},
		LABEL = {
			WIDTH = 80,
		},
		ENTRY = {
			WIDTH = 200,
		},
		NUMBER_ENTRY = {
			WIDTH = 50,
		},
		PADDING = 10,
		SPACING = {
			SECTION = 10,
			ITEM = 5,
		},
		ELEMENT_HEIGHT = 25,
	},
	FONT = {
		SMALL = UIFont.Small,
		MEDIUM = UIFont.Medium,
		LARGE = UIFont.Large,
	},
	COLORS = {
		BACKGROUND = {
			NORMAL = { r = 0.1, g = 0.1, b = 0.1, a = 0.8 },
			FIELD = { r = 0.15, g = 0.15, b = 0.15, a = 0.8 },
			PANEL = { r = 0.1, g = 0.1, b = 0.1, a = 0.5 },
		},
		BORDER = {
			NORMAL = { r = 0.4, g = 0.4, b = 0.4, a = 1 },
			DARK = { r = 0.2, g = 0.2, b = 0.2, a = 1 },
			LIGHT = { r = 0.5, g = 0.5, b = 0.5, a = 1 },
		},
		BUTTON = {
			NORMAL = { r = 0.2, g = 0.2, b = 0.2, a = 0.8 },
			HOVER = { r = 0.3, g = 0.3, b = 0.3, a = 0.8 },
			SELECTED = { r = 0.3, g = 0.5, b = 0.7, a = 0.8 },
			CLOSE = { r = 0.8, g = 0.2, b = 0.2, a = 0.8 },
			CLOSE_HOVER = { r = 0.9, g = 0.3, b = 0.3, a = 0.8 },
		},
		TEXT = {
			NORMAL = { r = 1, g = 1, b = 1, a = 1 },
			ERROR = { r = 1, g = 0.2, b = 0.2, a = 1 },
		},
		TAB = {
			ACTIVE = { r = 0.3, g = 0.5, b = 0.7, a = 0.8 },
			INACTIVE = { r = 0.2, g = 0.2, b = 0.2, a = 0.8 },
		},
		LIST = {
			ALT = { r = 0.15, g = 0.15, b = 0.15, a = 0.75 },
			SELECTED = { r = 0.3, g = 0.5, b = 0.7, a = 0.9 },
		},
		EVENT = {
			ACTIVE = { r = 0.2, g = 0.7, b = 0.2, a = 1 },
			INACTIVE = { r = 0.7, g = 0.2, b = 0.2, a = 1 },
			FUTURE = { r = 0.2, g = 0.2, b = 0.7, a = 1 },
		},
	},
}

local function copyColor(color)
	if not color then
		return nil
	end
	return {
		r = color.r,
		g = color.g,
		b = color.b,
		a = color.a,
	}
end

local function getEventStatusColor(status)
	if status == EventTeleportManager.EVENT_STATUS.FUTURE then
		return copyColor(CONST.COLORS.EVENT.FUTURE)
	elseif status == EventTeleportManager.EVENT_STATUS.ACTIVE then
		return copyColor(CONST.COLORS.EVENT.ACTIVE)
	else
		return copyColor(CONST.COLORS.EVENT.INACTIVE)
	end
end

EventTeleportManager.UI_Manager = ISCollapsableWindow:derive("EventTeleportManager_UI")
EventTeleportManager.UI_Manager.instance = nil

function EventTeleportManager.UI_Manager:new(x, y, width, height, playerNum)
	local o = ISCollapsableWindow:new(
		x,
		y,
		width or CONST.LAYOUT.WINDOW_SIZE.MAIN_PANEL.WIDTH,
		height or CONST.LAYOUT.WINDOW_SIZE.MAIN_PANEL.HEIGHT
	)
	setmetatable(o, self)
	self.__index = self

	o.player = getSpecificPlayer(playerNum)
	o.borderColor = copyColor(CONST.COLORS.BORDER.NORMAL)
	o.backgroundColor = copyColor(copyColor(CONST.COLORS.BACKGROUND.NORMAL))
	o.username = o.player:getUsername()
	o.canManageEvents = EventTeleportManager.Shared.CanManageEvents(o.player)
	o.currentView = o.canManageEvents and "admin" or "player"
	o.selectedEvent = nil
	o.selectedPlayer = nil
	o.notificationMessage = ""
	o.notificationTime = 0

	o.minimumWidth = CONST.LAYOUT.WINDOW_SIZE.MAIN_PANEL.WIDTH
	o.minimumHeight = CONST.LAYOUT.WINDOW_SIZE.MAIN_PANEL.HEIGHT

	o.lastDynamicUpdate = 0
	o.dynamicUpdateInterval = 500

	local titleText = o.canManageEvents and getText("IGUI_ETM_Admin_Title") or getText("IGUI_ETM_Player_Title")
	o:setTitle(titleText)
	o:setResizable(true)

	return o
end

function EventTeleportManager.UI_Manager:createChildren()
	ISCollapsableWindow.createChildren(self)

	local currentY = self:titleBarHeight() + CONST.LAYOUT.PADDING

	if self.canManageEvents then
		self:createTabs(currentY)
		currentY = self.adminTab:getBottom() + CONST.LAYOUT.PADDING
	end

	self:createNotificationArea(currentY)
	currentY = self.notificationLabel:getBottom() + CONST.LAYOUT.PADDING

	local rh = self:resizeWidgetHeight()
	local contentHeight = self.height - currentY - CONST.LAYOUT.PADDING - rh

	self.contentPanel =
		ISPanel:new(CONST.LAYOUT.PADDING, currentY, self.width - (CONST.LAYOUT.PADDING * 2), contentHeight)
	self.contentPanel:initialise()
	self.contentPanel.borderColor = { r = 0, g = 0, b = 0, a = 0 }
	self.contentPanel.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
	self.contentPanel.anchorRight = true
	self.contentPanel.anchorBottom = true
	self:addChild(self.contentPanel)

	self:createViewContent()

	self:updateEventList()
	self:updateButtonStates()
end

function EventTeleportManager.UI_Manager:onResize()
	ISCollapsableWindow.onResize(self)

	if not self.contentPanel then
		return
	end

	local th = self:titleBarHeight()
	local rh = self:resizeWidgetHeight()
	local currentY = self.contentPanel:getY()

	self.contentPanel:setWidth(self.width - (CONST.LAYOUT.PADDING * 2))
	self.contentPanel:setHeight(self.height - currentY - CONST.LAYOUT.PADDING - rh)

	if self.eventListPanel and self.eventDetailsPanel then
		local panelHeight = self.contentPanel:getHeight() - CONST.LAYOUT.BUTTON.HEIGHT - CONST.LAYOUT.PADDING * 2
		local leftPanelWidth = math.floor(self.contentPanel:getWidth() * 0.33)
		local rightPanelWidth = self.contentPanel:getWidth() - leftPanelWidth - CONST.LAYOUT.PADDING

		self.eventListPanel:setHeight(panelHeight)
		self.eventListPanel:setWidth(leftPanelWidth)

		self.eventDetailsPanel:setX(leftPanelWidth + CONST.LAYOUT.PADDING)
		self.eventDetailsPanel:setWidth(rightPanelWidth)
		self.eventDetailsPanel:setHeight(panelHeight)

		if self.eventList then
			self.eventList:setWidth(leftPanelWidth - (CONST.LAYOUT.PADDING * 2))

			local listY = self.eventListLabel:getBottom() + CONST.LAYOUT.PADDING
			local listHeight = panelHeight - listY - CONST.LAYOUT.PADDING

			if self.currentView == "admin" then
				listHeight = listHeight - CONST.LAYOUT.BUTTON.HEIGHT - CONST.LAYOUT.PADDING
			end

			self.eventList:setHeight(listHeight)

			if self.currentView == "admin" then
				local buttonY = self.eventList:getBottom() + CONST.LAYOUT.PADDING
				local buttonWidth = (leftPanelWidth - CONST.LAYOUT.PADDING * 3) / 2

				if self.createEventButton then
					self.createEventButton:setY(buttonY)
					self.createEventButton:setWidth(buttonWidth)
				end

				if self.deleteEventButton then
					self.deleteEventButton:setY(buttonY)
					self.deleteEventButton:setX(self.createEventButton:getRight() + CONST.LAYOUT.PADDING)
					self.deleteEventButton:setWidth(buttonWidth)
				end
			end
		end

		if self.currentView == "admin" then
			if self.playerList then
				local playerListY = self.playersLabel:getBottom() + CONST.LAYOUT.SPACING.ITEM
				local playerListWidth = rightPanelWidth
					- CONST.LAYOUT.PADDING * 3
					- CONST.LAYOUT.BUTTON.WIDTH
					- CONST.LAYOUT.SPACING.ITEM
				local playerListHeight = panelHeight
					- playerListY
					- CONST.LAYOUT.PADDING * 2
					- CONST.LAYOUT.BUTTON.HEIGHT

				self.playerList:setWidth(playerListWidth)
				self.playerList:setHeight(playerListHeight)

				if self.addPlayerButton then
					self.addPlayerButton:setX(self.playerList:getRight() + CONST.LAYOUT.SPACING.ITEM)
				end

				if self.removePlayerButton then
					self.removePlayerButton:setX(self.playerList:getRight() + CONST.LAYOUT.SPACING.ITEM)
				end

				if self.saveButton then
					self.saveButton:setX(rightPanelWidth - CONST.LAYOUT.BUTTON.WIDTH - CONST.LAYOUT.PADDING)
					self.saveButton:setY(panelHeight - CONST.LAYOUT.BUTTON.HEIGHT - CONST.LAYOUT.PADDING)
				end
			end
		else
			if self.noEventLabel then
				self.noEventLabel:setX(rightPanelWidth / 2 - 100)
				self.noEventLabel:setY(panelHeight / 2 - 10)
			end
		end

		if self.bottomButtonsPanel then
			self.bottomButtonsPanel:setWidth(self.contentPanel:getWidth())
			self.bottomButtonsPanel:setY(panelHeight + CONST.LAYOUT.PADDING)

			local buttonWidth = (self.contentPanel:getWidth() - (CONST.LAYOUT.PADDING * 4)) / 3

			if self.currentView == "admin" then
				if self.teleportPlayersButton then
					self.teleportPlayersButton:setWidth(buttonWidth)
				end

				if self.returnPlayersButton then
					self.returnPlayersButton:setX(self.teleportPlayersButton:getRight() + CONST.LAYOUT.PADDING)
					self.returnPlayersButton:setWidth(buttonWidth)
				end

				if self.closeButton2 then
					self.closeButton2:setX(self.returnPlayersButton:getRight() + CONST.LAYOUT.PADDING)
					self.closeButton2:setWidth(buttonWidth)
				end
			else
				if self.registerButton then
					self.registerButton:setWidth(buttonWidth)
				end

				if self.teleportButton then
					self.teleportButton:setX(self.registerButton:getRight() + CONST.LAYOUT.PADDING)
					self.teleportButton:setWidth(buttonWidth)
				end

				if self.returnButton then
					self.returnButton:setX(self.teleportButton:getRight() + CONST.LAYOUT.PADDING)
					self.returnButton:setWidth(buttonWidth)
				end
			end
		end
	end
end

function EventTeleportManager.UI_Manager:resizePlayerDetailsDisplay(width, height) end

function EventTeleportManager.UI_Manager:resizeBottomButtons()
	if not self.bottomButtonsPanel then
		return
	end

	self.bottomButtonsPanel:setWidth(self.contentPanel:getWidth())
	self.bottomButtonsPanel:setY(self.contentPanel:getHeight() - CONST.LAYOUT.BUTTON.HEIGHT)

	local buttonWidth = (self.bottomButtonsPanel:getWidth() - (CONST.LAYOUT.PADDING * 4)) / 3

	if self.currentView == "admin" then
		if self.teleportPlayersButton then
			self.teleportPlayersButton:setWidth(buttonWidth)
		end

		if self.returnPlayersButton then
			self.returnPlayersButton:setX(self.teleportPlayersButton:getRight() + CONST.LAYOUT.PADDING)
			self.returnPlayersButton:setWidth(buttonWidth)
		end

		if self.closeButton2 then
			self.closeButton2:setX(self.returnPlayersButton:getRight() + CONST.LAYOUT.PADDING)
			self.closeButton2:setWidth(buttonWidth)
		end
	else
		if self.registerButton then
			self.registerButton:setWidth(buttonWidth)
		end

		if self.teleportButton then
			self.teleportButton:setX(self.registerButton:getRight() + CONST.LAYOUT.PADDING)
			self.teleportButton:setWidth(buttonWidth)
		end

		if self.returnButton then
			self.returnButton:setX(self.teleportButton:getRight() + CONST.LAYOUT.PADDING)
			self.returnButton:setWidth(buttonWidth)
		end
	end
end

function EventTeleportManager.UI_Manager:createNotificationArea(y)
	self.notificationLabel = ISLabel:new(
		0,
		y,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		"",
		CONST.COLORS.TEXT.NORMAL.r,
		CONST.COLORS.TEXT.NORMAL.g,
		CONST.COLORS.TEXT.NORMAL.b,
		CONST.COLORS.TEXT.NORMAL.a,
		CONST.FONT.SMALL,
		true
	)
	self:addChild(self.notificationLabel)
	self:centerNotificationText()
end

function EventTeleportManager.UI_Manager:centerNotificationText()
	if self.notificationLabel and self.notificationLabel:getWidth() > 0 then
		self.notificationLabel:setX((self:getWidth() - self.notificationLabel:getWidth()) / 2)
	else
		self.notificationLabel:setX(self:getWidth() / 2)
	end
end

function EventTeleportManager.UI_Manager:showNotification(message, duration)
	self.notificationMessage = message
	self.notificationTime = getTimestampMs() + (duration or 3000)
	self.notificationLabel:setName(message)
	self:centerNotificationText()
end

function EventTeleportManager.UI_Manager:createTabs(y)
	local tabHeight = CONST.LAYOUT.BUTTON.HEIGHT

	self.adminTab =
		ISButton:new(CONST.LAYOUT.PADDING, y, 0, tabHeight, getText("IGUI_ETM_AdminView"), self, self.onTabSelected)
	self.adminTab:initialise()
	self.adminTab:instantiate()
	self.adminTab:setWidthToTitle(0)
	self.adminTab.internal = "admin"
	self.adminTab.borderColor = copyColor(CONST.COLORS.BORDER.NORMAL)
	self.adminTab.backgroundColor = self.currentView == "admin" and copyColor(CONST.COLORS.BUTTON.SELECTED)
		or copyColor(CONST.COLORS.BORDER.NORMAL)
	self.adminTab.backgroundColorMouseOver = copyColor(CONST.COLORS.BUTTON.HOVER)
	self:addChild(self.adminTab)

	self.playerTab = ISButton:new(
		self.adminTab:getRight() + CONST.LAYOUT.PADDING,
		y,
		0,
		tabHeight,
		getText("IGUI_ETM_PlayerView"),
		self,
		self.onTabSelected
	)
	self.playerTab:initialise()
	self.playerTab:instantiate()
	self.playerTab:setWidthToTitle(0)
	self.playerTab.internal = "player"
	self.playerTab.borderColor = copyColor(CONST.COLORS.BORDER.NORMAL)
	self.playerTab.backgroundColor = self.currentView == "player" and copyColor(CONST.COLORS.TAB.ACTIVE)
		or copyColor(CONST.COLORS.BORDER.NORMAL)
	self.playerTab.backgroundColorMouseOver = copyColor(CONST.COLORS.BUTTON.HOVER)
	self:addChild(self.playerTab)
end

function EventTeleportManager.UI_Manager:createViewContent()
	if self.eventListPanel then
		self.contentPanel:removeChild(self.eventListPanel)
		self.eventListPanel = nil
	end

	if self.eventDetailsPanel then
		self.contentPanel:removeChild(self.eventDetailsPanel)
		self.eventDetailsPanel = nil
	end

	if self.bottomButtonsPanel then
		self.contentPanel:removeChild(self.bottomButtonsPanel)
		self.bottomButtonsPanel = nil
	end

	local panelHeight = self.contentPanel:getHeight() - CONST.LAYOUT.BUTTON.HEIGHT - CONST.LAYOUT.PADDING * 2
	local leftPanelWidth = math.floor(self.contentPanel:getWidth() * 0.33)
	local rightPanelWidth = self.contentPanel:getWidth() - leftPanelWidth - CONST.LAYOUT.PADDING

	self:createEventList(0, 0, leftPanelWidth, panelHeight)
	self:createEventDetails(leftPanelWidth + CONST.LAYOUT.PADDING, 0, rightPanelWidth, panelHeight)
	self:createBottomButtons(0, panelHeight + CONST.LAYOUT.PADDING)

	local titleText = self.currentView == "admin" and getText("IGUI_ETM_Admin_Title")
		or getText("IGUI_ETM_Player_Title")
	self:setTitle(titleText)
	self:updateTabColors()
end

function EventTeleportManager.UI_Manager:createEventList(x, y, width, height)
	self.eventListPanel = ISPanel:new(x, y, width, height)
	self.eventListPanel:initialise()
	self.eventListPanel.borderColor = copyColor(CONST.COLORS.BORDER.NORMAL)
	self.eventListPanel.backgroundColor = copyColor(copyColor(CONST.COLORS.BACKGROUND.NORMAL))
	self.eventListPanel.anchorRight = false
	self.eventListPanel.anchorBottom = true
	self.contentPanel:addChild(self.eventListPanel)

	local title = self.currentView == "admin" and getText("IGUI_ETM_EventList") or getText("IGUI_ETM_AvailableEvents")
	self.eventListLabel = ISLabel:new(
		CONST.LAYOUT.PADDING,
		CONST.LAYOUT.PADDING,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		title,
		CONST.COLORS.TEXT.NORMAL.r,
		CONST.COLORS.TEXT.NORMAL.g,
		CONST.COLORS.TEXT.NORMAL.b,
		CONST.COLORS.TEXT.NORMAL.a,
		CONST.FONT.MEDIUM,
		true
	)
	self.eventListPanel:addChild(self.eventListLabel)

	local listY = self.eventListLabel:getBottom() + CONST.LAYOUT.PADDING
	local listHeight = height - listY - CONST.LAYOUT.PADDING

	if self.currentView == "admin" then
		listHeight = listHeight - CONST.LAYOUT.BUTTON.HEIGHT - CONST.LAYOUT.PADDING
	end

	self.eventList = ISScrollingListBox:new(CONST.LAYOUT.PADDING, listY, width - (CONST.LAYOUT.PADDING * 2), listHeight)
	self.eventList:initialise()
	self.eventList:instantiate()
	self.eventList.itemheight = 2 * getTextManager():MeasureStringY(CONST.FONT.SMALL, "A") + 1.5 * CONST.LAYOUT.PADDING
	self.eventList.selected = 0
	self.eventList.joypadParent = self
	self.eventList.font = CONST.FONT.SMALL
	self.eventList.drawBorder = true
	self.eventList.borderColor = copyColor(CONST.COLORS.BORDER.DARK)
	self.eventList.backgroundColor = copyColor(copyColor(CONST.COLORS.BACKGROUND.NORMAL))
	self.eventList.doDrawItem = self.drawEventListItem
	self.eventList.onMouseDown = self.onEventListMouseDown
	self.eventList.target = self
	self.eventList.anchorRight = true
	self.eventList.anchorBottom = true
	self.eventListPanel:addChild(self.eventList)

	if self.currentView == "admin" then
		local buttonY = self.eventList:getBottom() + CONST.LAYOUT.PADDING
		local buttonWidth = (width - CONST.LAYOUT.PADDING * 3) / 2

		self.createEventButton = ISButton:new(
			CONST.LAYOUT.PADDING,
			buttonY,
			buttonWidth,
			CONST.LAYOUT.BUTTON.HEIGHT,
			getText("IGUI_ETM_Create"),
			self,
			self.onCreateEvent
		)
		self.createEventButton:initialise()
		self.createEventButton:instantiate()
		self.createEventButton.borderColor = copyColor(CONST.COLORS.BORDER.NORMAL)
		self.createEventButton.backgroundColor = copyColor(CONST.COLORS.BUTTON.NORMAL)
		self.createEventButton.backgroundColorMouseOver = copyColor(CONST.COLORS.BUTTON.HOVER)
		self.createEventButton.anchorTop = false
		self.createEventButton.anchorBottom = true
		self.createEventButton.anchorRight = false
		self.eventListPanel:addChild(self.createEventButton)

		self.deleteEventButton = ISButton:new(
			self.createEventButton:getRight() + CONST.LAYOUT.PADDING,
			buttonY,
			buttonWidth,
			CONST.LAYOUT.BUTTON.HEIGHT,
			getText("IGUI_ETM_DeleteEvent"),
			self,
			self.onDeleteEvent
		)
		self.deleteEventButton:initialise()
		self.deleteEventButton:instantiate()
		self.deleteEventButton.borderColor = copyColor(CONST.COLORS.BORDER.NORMAL)
		self.deleteEventButton.backgroundColor = copyColor(CONST.COLORS.BUTTON.CLOSE)
		self.deleteEventButton.backgroundColorMouseOver = copyColor(CONST.COLORS.BUTTON.CLOSE_HOVER)
		self.deleteEventButton:setEnable(false)
		self.deleteEventButton.anchorLeft = false
		self.deleteEventButton.anchorTop = false
		self.deleteEventButton.anchorRight = true
		self.deleteEventButton.anchorBottom = true
		self.eventListPanel:addChild(self.deleteEventButton)
	end
end

function EventTeleportManager.UI_Manager:createEventDetails(x, y, width, height)
	self.eventDetailsPanel = ISPanel:new(x, y, width, height)
	self.eventDetailsPanel:initialise()
	self.eventDetailsPanel.borderColor = copyColor(CONST.COLORS.BORDER.NORMAL)
	self.eventDetailsPanel.backgroundColor = copyColor(copyColor(CONST.COLORS.BACKGROUND.NORMAL))
	self.eventDetailsPanel.anchorLeft = false
	self.eventDetailsPanel.anchorRight = true
	self.eventDetailsPanel.anchorBottom = true
	self.contentPanel:addChild(self.eventDetailsPanel)

	self.detailsTitle = ISLabel:new(
		CONST.LAYOUT.PADDING,
		CONST.LAYOUT.PADDING,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		getText("IGUI_ETM_EventDetails"),
		CONST.COLORS.TEXT.NORMAL.r,
		CONST.COLORS.TEXT.NORMAL.g,
		CONST.COLORS.TEXT.NORMAL.b,
		CONST.COLORS.TEXT.NORMAL.a,
		CONST.FONT.MEDIUM,
		true
	)
	self.eventDetailsPanel:addChild(self.detailsTitle)

	self.noEventLabel = ISLabel:new(
		width / 2 - 100,
		height / 2 - 10,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		getText("IGUI_ETM_NoEvents"),
		CONST.COLORS.TEXT.NORMAL.r,
		CONST.COLORS.TEXT.NORMAL.g,
		CONST.COLORS.TEXT.NORMAL.b,
		CONST.COLORS.TEXT.NORMAL.a,
		CONST.FONT.MEDIUM,
		true
	)
	self.noEventLabel.anchorLeft = true
	self.noEventLabel.anchorRight = true
	self.noEventLabel.anchorTop = true
	self.noEventLabel.anchorBottom = true
	self.eventDetailsPanel:addChild(self.noEventLabel)

	if self.currentView == "admin" then
		self:createAdminDetailsForm(width, height)
	else
		self:createPlayerDetailsDisplay(width, height)
	end

	return self.eventDetailsPanel
end

---@param targetField any Target field to receive the selected date (DateDisplay or label)
---@param fieldName string Field identifier ("startTime" or "endTime")
function EventTeleportManager.UI_Manager:openDatePicker(targetField, fieldName, useGameTime)
	local timestamp

	if self.selectedEvent then
		if fieldName == "startTime" then
			timestamp = self.selectedEvent.startTime
		elseif fieldName == "endTime" then
			timestamp = self.selectedEvent.endTime
		end
	end

	local screenWidth = getCore():getScreenWidth()
	local screenHeight = getCore():getScreenHeight()
	local datePicker = DateTimeSelector:new(screenWidth / 2, screenHeight / 2, 0, 0, false)

	if timestamp then
		local dateModel = DateTimeModel:new({
			useGameTime = false,
			date = DateTimeUtility.fromTimestamp(timestamp),
		})

		datePicker:setDateModel(dateModel)
	end

	datePicker:setShowTime(true)
	datePicker:setShowSeconds(false)
	datePicker:setUse24HourFormat(true)
	datePicker:setShowTimezoneInfo(true)

	datePicker:setOnDateTimeSelected(self, function(parent, selectedDate, wasCancelled)
		if wasCancelled or not selectedDate then
			return
		end

		local formattedDate = DateTimeUtility.formatDate(selectedDate, DateTimeUtility.FORMAT.EU)
		targetField:setName(formattedDate)

		if self.selectedEvent then
			local utcTimestamp = DateTimeUtility.toTimestamp(
				DateTimeUtility.toUTC(selectedDate, DateTimeUtility.getLocalTimezoneOffset())
			)

			if fieldName == "startTime" then
				self.selectedEvent.startTime = utcTimestamp
			elseif fieldName == "endTime" then
				self.selectedEvent.endTime = utcTimestamp
			end

			if self.selectedEvent.id then
				EventTeleportManager.Client.EditEventData(self.selectedEvent.id, fieldName, utcTimestamp)
				self:showNotification(getText("IGUI_ETM_DateUpdated"), 2000)
			end
		end
	end)

	datePicker:initialise()
	datePicker:addToUIManager()
	datePicker:bringToTop()

	return datePicker
end

---@param width number Form width
---@param height number Form height
function EventTeleportManager.UI_Manager:createAdminDetailsForm(width, height)
	local labelTexts = {
		getText("IGUI_ETM_EventName") .. ":",
		getText("IGUI_ETM_TeleportFrom") .. ":",
		getText("IGUI_ETM_TeleportUntil") .. ":",
		getText("IGUI_ETM_Location") .. ":",
		getText("IGUI_ETM_Players"),
	}

	local maxLabelWidth = 0
	for i = 1, #labelTexts do
		local textWidth = getTextManager():MeasureStringX(CONST.FONT.SMALL, labelTexts[i])
		maxLabelWidth = math.max(maxLabelWidth, textWidth)
	end

	local labelWidth = maxLabelWidth + 2 * CONST.LAYOUT.PADDING
	local entryWidth = CONST.LAYOUT.ENTRY.WIDTH
	local entryX = CONST.LAYOUT.PADDING + labelWidth + CONST.LAYOUT.PADDING
	local dateDisplayWidth = getTextManager():MeasureStringX(CONST.FONT.SMALL, string.format("00:00 00/00/0000"))
		+ CONST.LAYOUT.PADDING

	local inputY = self.detailsTitle:getBottom() + CONST.LAYOUT.SPACING.SECTION

	self.nameLabel = ISLabel:new(
		CONST.LAYOUT.PADDING,
		inputY,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		labelTexts[1],
		CONST.COLORS.TEXT.NORMAL.r,
		CONST.COLORS.TEXT.NORMAL.g,
		CONST.COLORS.TEXT.NORMAL.b,
		CONST.COLORS.TEXT.NORMAL.a,
		CONST.FONT.SMALL,
		true
	)
	self.eventDetailsPanel:addChild(self.nameLabel)

	self.nameEntry = ISTextEntryBox:new("", entryX, inputY, entryWidth, CONST.LAYOUT.ELEMENT_HEIGHT)
	self.nameEntry:initialise()
	self.nameEntry:instantiate()
	self.nameEntry.borderColor = copyColor(CONST.COLORS.BORDER.NORMAL)
	self.nameEntry.backgroundColor = copyColor(CONST.COLORS.BACKGROUND.FIELD)
	self.eventDetailsPanel:addChild(self.nameEntry)

	inputY = self.nameEntry:getBottom() + CONST.LAYOUT.SPACING.SECTION

	self.startTimeLabel = ISLabel:new(
		CONST.LAYOUT.PADDING,
		inputY,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		labelTexts[2],
		CONST.COLORS.TEXT.NORMAL.r,
		CONST.COLORS.TEXT.NORMAL.g,
		CONST.COLORS.TEXT.NORMAL.b,
		CONST.COLORS.TEXT.NORMAL.a,
		CONST.FONT.SMALL,
		true
	)
	self.eventDetailsPanel:addChild(self.startTimeLabel)

	self.startTimeDisplay = ISLabel:new(
		entryX,
		inputY,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		getText("IGUI_ETM_SetStartTime"),
		CONST.COLORS.TEXT.NORMAL.r,
		CONST.COLORS.TEXT.NORMAL.g,
		CONST.COLORS.TEXT.NORMAL.b,
		CONST.COLORS.TEXT.NORMAL.a,
		CONST.FONT.SMALL,
		true
	)
	self.startTimeDisplay.tooltip = getText("Tooltip_ETM_TeleportFrom")
	self.eventDetailsPanel:addChild(self.startTimeDisplay)

	self.startTimeButton = ISButton:new(
		entryX + dateDisplayWidth + CONST.LAYOUT.PADDING,
		inputY,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		"",
		self,
		function()
			self:openDatePicker(self.startTimeDisplay, "startTime")
		end
	)
	self.startTimeButton:initialise()
	self.startTimeButton:instantiate()
	local calendarIcon = getTexture("media/ui/ElyonLib/ui_button_calendar.png")
	self.startTimeButton:setImage(calendarIcon)
	self.startTimeButton.borderColor = copyColor(CONST.COLORS.BORDER.NORMAL)
	self.startTimeButton.backgroundColor = copyColor(CONST.COLORS.BUTTON.NORMAL)
	self.startTimeButton.backgroundColorMouseOver = copyColor(CONST.COLORS.BUTTON.HOVER)
	self.eventDetailsPanel:addChild(self.startTimeButton)

	inputY = self.startTimeDisplay:getBottom() + CONST.LAYOUT.SPACING.SECTION

	self.endTimeLabel = ISLabel:new(
		CONST.LAYOUT.PADDING,
		inputY,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		labelTexts[3],
		CONST.COLORS.TEXT.NORMAL.r,
		CONST.COLORS.TEXT.NORMAL.g,
		CONST.COLORS.TEXT.NORMAL.b,
		CONST.COLORS.TEXT.NORMAL.a,
		CONST.FONT.SMALL,
		true
	)
	self.eventDetailsPanel:addChild(self.endTimeLabel)

	self.endTimeDisplay = ISLabel:new(
		entryX,
		inputY,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		getText("IGUI_ETM_SetEndTime"),
		CONST.COLORS.TEXT.NORMAL.r,
		CONST.COLORS.TEXT.NORMAL.g,
		CONST.COLORS.TEXT.NORMAL.b,
		CONST.COLORS.TEXT.NORMAL.a,
		CONST.FONT.SMALL,
		true
	)
	self.endTimeDisplay.tooltip = getText("Tooltip_ETM_TeleportUntil")
	self.eventDetailsPanel:addChild(self.endTimeDisplay)

	self.endTimeButton = ISButton:new(
		entryX + dateDisplayWidth + CONST.LAYOUT.PADDING,
		inputY,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		"",
		self,
		function()
			self:openDatePicker(self.endTimeDisplay, "endTime")
		end
	)
	self.endTimeButton:initialise()
	self.endTimeButton:instantiate()
	self.endTimeButton:setImage(calendarIcon)
	self.endTimeButton.borderColor = copyColor(CONST.COLORS.BORDER.NORMAL)
	self.endTimeButton.backgroundColor = copyColor(CONST.COLORS.BUTTON.NORMAL)
	self.endTimeButton.backgroundColorMouseOver = copyColor(CONST.COLORS.BUTTON.HOVER)
	self.eventDetailsPanel:addChild(self.endTimeButton)

	inputY = self.endTimeLabel:getBottom() + CONST.LAYOUT.SPACING.SECTION
	self.locationLabel = ISLabel:new(
		CONST.LAYOUT.PADDING,
		inputY,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		labelTexts[4],
		CONST.COLORS.TEXT.NORMAL.r,
		CONST.COLORS.TEXT.NORMAL.g,
		CONST.COLORS.TEXT.NORMAL.b,
		CONST.COLORS.TEXT.NORMAL.a,
		CONST.FONT.SMALL,
		true
	)
	self.eventDetailsPanel:addChild(self.locationLabel)

	self.locationXLabel = ISLabel:new(
		entryX,
		inputY,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		"X:",
		CONST.COLORS.TEXT.NORMAL.r,
		CONST.COLORS.TEXT.NORMAL.g,
		CONST.COLORS.TEXT.NORMAL.b,
		CONST.COLORS.TEXT.NORMAL.a,
		CONST.FONT.SMALL,
		true
	)
	self.eventDetailsPanel:addChild(self.locationXLabel)

	self.locationXEntry = ISTextEntryBox:new(
		"0",
		self.locationXLabel:getRight() + CONST.LAYOUT.SPACING.ITEM,
		inputY,
		CONST.LAYOUT.NUMBER_ENTRY.WIDTH,
		CONST.LAYOUT.ELEMENT_HEIGHT
	)
	self.locationXEntry:initialise()
	self.locationXEntry:instantiate()
	self.locationXEntry.borderColor = copyColor(CONST.COLORS.BORDER.DARK)
	self.locationXEntry.backgroundColor = copyColor(CONST.COLORS.BACKGROUND.FIELD)
	self.eventDetailsPanel:addChild(self.locationXEntry)

	self.locationYLabel = ISLabel:new(
		self.locationXEntry:getRight() + CONST.LAYOUT.SPACING.ITEM,
		inputY,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		"Y:",
		CONST.COLORS.TEXT.NORMAL.r,
		CONST.COLORS.TEXT.NORMAL.g,
		CONST.COLORS.TEXT.NORMAL.b,
		CONST.COLORS.TEXT.NORMAL.a,
		CONST.FONT.SMALL,
		true
	)
	self.eventDetailsPanel:addChild(self.locationYLabel)

	self.locationYEntry = ISTextEntryBox:new(
		"0",
		self.locationYLabel:getRight() + CONST.LAYOUT.SPACING.ITEM,
		inputY,
		CONST.LAYOUT.NUMBER_ENTRY.WIDTH,
		CONST.LAYOUT.ELEMENT_HEIGHT
	)
	self.locationYEntry:initialise()
	self.locationYEntry:instantiate()
	self.locationYEntry.borderColor = copyColor(CONST.COLORS.BORDER.DARK)
	self.locationYEntry.backgroundColor = copyColor(CONST.COLORS.BACKGROUND.FIELD)
	self.eventDetailsPanel:addChild(self.locationYEntry)

	self.locationZLabel = ISLabel:new(
		self.locationYEntry:getRight() + CONST.LAYOUT.SPACING.ITEM,
		inputY,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		"Z:",
		CONST.COLORS.TEXT.NORMAL.r,
		CONST.COLORS.TEXT.NORMAL.g,
		CONST.COLORS.TEXT.NORMAL.b,
		CONST.COLORS.TEXT.NORMAL.a,
		CONST.FONT.SMALL,
		true
	)
	self.eventDetailsPanel:addChild(self.locationZLabel)

	self.locationZEntry = ISTextEntryBox:new(
		"0",
		self.locationZLabel:getRight() + CONST.LAYOUT.SPACING.ITEM,
		inputY,
		CONST.LAYOUT.NUMBER_ENTRY.WIDTH,
		CONST.LAYOUT.ELEMENT_HEIGHT
	)
	self.locationZEntry:initialise()
	self.locationZEntry:instantiate()
	self.locationZEntry.borderColor = copyColor(CONST.COLORS.BORDER.DARK)
	self.locationZEntry.backgroundColor = copyColor(CONST.COLORS.BACKGROUND.FIELD)
	self.eventDetailsPanel:addChild(self.locationZEntry)

	self.setLocationButton = ISButton:new(
		self.locationZEntry:getRight() + CONST.LAYOUT.SPACING.ITEM * 2,
		inputY,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		"",
		self,
		self.onSetLocation
	)
	self.setLocationButton:initialise()
	self.setLocationButton:instantiate()
	self.setLocationButton.borderColor = copyColor(CONST.COLORS.BORDER.NORMAL)
	self.setLocationButton.backgroundColor = copyColor(CONST.COLORS.BUTTON.NORMAL)
	self.setLocationButton.backgroundColorMouseOver = copyColor(CONST.COLORS.BUTTON.HOVER)

	local locationIcon = getTexture("media/ui/ElyonLib/ui_pick_current_location.png")
	self.setLocationButton:setImage(locationIcon)
	self.eventDetailsPanel:addChild(self.setLocationButton)

	inputY = self.setLocationButton:getBottom() + CONST.LAYOUT.SPACING.SECTION * 2
	self.playersLabel = ISLabel:new(
		CONST.LAYOUT.PADDING,
		inputY,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		labelTexts[5],
		CONST.COLORS.TEXT.NORMAL.r,
		CONST.COLORS.TEXT.NORMAL.g,
		CONST.COLORS.TEXT.NORMAL.b,
		CONST.COLORS.TEXT.NORMAL.a,
		CONST.FONT.SMALL,
		true
	)
	self.eventDetailsPanel:addChild(self.playersLabel)

	local playerListY = self.playersLabel:getBottom() + CONST.LAYOUT.SPACING.ITEM
	local playerListWidth = width - CONST.LAYOUT.PADDING * 3 - CONST.LAYOUT.BUTTON.WIDTH - CONST.LAYOUT.SPACING.ITEM
	local playerListHeight = height - playerListY - CONST.LAYOUT.PADDING * 2 - CONST.LAYOUT.BUTTON.HEIGHT

	self.playerList = ISScrollingListBox:new(CONST.LAYOUT.PADDING, playerListY, playerListWidth, playerListHeight)
	self.playerList:initialise()
	self.playerList:instantiate()
	self.playerList.itemheight = CONST.LAYOUT.ELEMENT_HEIGHT
	self.playerList.selected = 0
	self.playerList.joypadParent = self
	self.playerList.font = CONST.FONT.SMALL
	self.playerList.drawBorder = true
	self.playerList.borderColor = copyColor(CONST.COLORS.BORDER.DARK)
	self.playerList.backgroundColor = copyColor(copyColor(CONST.COLORS.BACKGROUND.NORMAL))
	self.playerList.doDrawItem = self.drawPlayerListItem
	self.playerList.onMouseDown = self.onPlayerListMouseDown
	self.playerList.target = self
	self.playerList.anchorRight = true
	self.playerList.anchorBottom = true
	self.eventDetailsPanel:addChild(self.playerList)

	self.addPlayerButton = ISButton:new(
		self.playerList:getRight() + CONST.LAYOUT.SPACING.ITEM,
		playerListY,
		CONST.LAYOUT.BUTTON.WIDTH,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		getText("IGUI_ETM_AddPlayer"),
		self,
		self.onAddPlayer
	)
	self.addPlayerButton:initialise()
	self.addPlayerButton:instantiate()
	self.addPlayerButton.borderColor = copyColor(CONST.COLORS.BORDER.NORMAL)
	self.addPlayerButton.backgroundColor = copyColor(CONST.COLORS.BUTTON.NORMAL)
	self.addPlayerButton.backgroundColorMouseOver = copyColor(CONST.COLORS.BUTTON.HOVER)
	self.addPlayerButton.anchorLeft = false
	self.addPlayerButton.anchorRight = true
	self.eventDetailsPanel:addChild(self.addPlayerButton)

	self.removePlayerButton = ISButton:new(
		self.playerList:getRight() + CONST.LAYOUT.SPACING.ITEM,
		self.addPlayerButton:getBottom() + CONST.LAYOUT.SPACING.ITEM,
		CONST.LAYOUT.BUTTON.WIDTH,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		getText("IGUI_ETM_RemovePlayer"),
		self,
		self.onRemovePlayer
	)
	self.removePlayerButton:initialise()
	self.removePlayerButton:instantiate()
	self.removePlayerButton.borderColor = copyColor(CONST.COLORS.BORDER.NORMAL)
	self.removePlayerButton.backgroundColor = copyColor(CONST.COLORS.BUTTON.CLOSE)
	self.removePlayerButton.backgroundColorMouseOver = copyColor(CONST.COLORS.BUTTON.CLOSE_HOVER)
	self.removePlayerButton:setEnable(false)
	self.removePlayerButton.anchorLeft = false
	self.removePlayerButton.anchorRight = true
	self.eventDetailsPanel:addChild(self.removePlayerButton)

	self.saveButton = ISButton:new(
		width - CONST.LAYOUT.BUTTON.WIDTH - CONST.LAYOUT.PADDING,
		height - CONST.LAYOUT.BUTTON.HEIGHT - CONST.LAYOUT.PADDING,
		CONST.LAYOUT.BUTTON.WIDTH,
		CONST.LAYOUT.BUTTON.HEIGHT,
		getText("IGUI_ETM_Save"),
		self,
		self.onSaveEvent
	)
	self.saveButton:initialise()
	self.saveButton:instantiate()
	self.saveButton.borderColor = copyColor(CONST.COLORS.BORDER.NORMAL)
	self.saveButton.backgroundColor = copyColor(CONST.COLORS.BUTTON.NORMAL)
	self.saveButton.backgroundColorMouseOver = copyColor(CONST.COLORS.BUTTON.HOVER)
	self.saveButton.anchorLeft = false
	self.saveButton.anchorTop = false
	self.saveButton.anchorRight = true
	self.saveButton.anchorBottom = true
	self.eventDetailsPanel:addChild(self.saveButton)

	self:hideEventDetailsAdmin(true)
end

---@param width number Form width
---@param height number Form height
function EventTeleportManager.UI_Manager:createPlayerDetailsDisplay(width, height)
	local labelTexts = {
		getText("IGUI_ETM_EventName") .. ":",
		getText("IGUI_ETM_Status") .. ":",
		getText("IGUI_ETM_TeleportFrom") .. ":",
		getText("IGUI_ETM_TeleportUntil") .. ":",
		getText("IGUI_ETM_RegistrationStatus") .. ":",
	}

	local maxLabelWidth = 0
	for i = 1, #labelTexts do
		local textWidth = getTextManager():MeasureStringX(CONST.FONT.SMALL, labelTexts[i])
		maxLabelWidth = math.max(maxLabelWidth, textWidth)
	end

	local labelWidth = CONST.LAYOUT.PADDING + maxLabelWidth + CONST.LAYOUT.PADDING
	local valueX = CONST.LAYOUT.PADDING + labelWidth + CONST.LAYOUT.PADDING

	local detailsY = self.detailsTitle:getBottom() + CONST.LAYOUT.SPACING.SECTION

	self.nameLabel = ISLabel:new(
		CONST.LAYOUT.PADDING,
		detailsY,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		labelTexts[1],
		CONST.COLORS.TEXT.NORMAL.r,
		CONST.COLORS.TEXT.NORMAL.g,
		CONST.COLORS.TEXT.NORMAL.b,
		CONST.COLORS.TEXT.NORMAL.a,
		CONST.FONT.SMALL,
		true
	)
	self.eventDetailsPanel:addChild(self.nameLabel)

	self.nameValue = ISLabel:new(
		valueX,
		detailsY,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		"",
		CONST.COLORS.TEXT.NORMAL.r,
		CONST.COLORS.TEXT.NORMAL.g,
		CONST.COLORS.TEXT.NORMAL.b,
		CONST.COLORS.TEXT.NORMAL.a,
		CONST.FONT.SMALL,
		true
	)
	self.eventDetailsPanel:addChild(self.nameValue)

	detailsY = self.nameLabel:getBottom() + CONST.LAYOUT.PADDING
	self.statusLabel = ISLabel:new(
		CONST.LAYOUT.PADDING,
		detailsY,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		labelTexts[2],
		CONST.COLORS.TEXT.NORMAL.r,
		CONST.COLORS.TEXT.NORMAL.g,
		CONST.COLORS.TEXT.NORMAL.b,
		CONST.COLORS.TEXT.NORMAL.a,
		CONST.FONT.SMALL,
		true
	)
	self.eventDetailsPanel:addChild(self.statusLabel)

	self.statusValue = ISLabel:new(
		valueX,
		detailsY,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		"",
		CONST.COLORS.TEXT.NORMAL.r,
		CONST.COLORS.TEXT.NORMAL.g,
		CONST.COLORS.TEXT.NORMAL.b,
		CONST.COLORS.TEXT.NORMAL.a,
		CONST.FONT.SMALL,
		true
	)
	self.eventDetailsPanel:addChild(self.statusValue)

	detailsY = self.statusLabel:getBottom() + CONST.LAYOUT.PADDING
	self.startTimeLabel = ISLabel:new(
		CONST.LAYOUT.PADDING,
		detailsY,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		labelTexts[3],
		CONST.COLORS.TEXT.NORMAL.r,
		CONST.COLORS.TEXT.NORMAL.g,
		CONST.COLORS.TEXT.NORMAL.b,
		CONST.COLORS.TEXT.NORMAL.a,
		CONST.FONT.SMALL,
		true
	)
	self.eventDetailsPanel:addChild(self.startTimeLabel)

	self.startTimeDisplay = ISLabel:new(
		valueX,
		detailsY,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		getText("IGUI_ETM_SetStartTime"),
		CONST.COLORS.TEXT.NORMAL.r,
		CONST.COLORS.TEXT.NORMAL.g,
		CONST.COLORS.TEXT.NORMAL.b,
		CONST.COLORS.TEXT.NORMAL.a,
		CONST.FONT.SMALL,
		true
	)
	self.startTimeDisplay.tooltip = getText("Tooltip_ETM_TeleportFrom")
	self.startTimeDisplay:initialise()
	self.eventDetailsPanel:addChild(self.startTimeDisplay)

	detailsY = self.startTimeLabel:getBottom() + CONST.LAYOUT.PADDING
	self.endTimeLabel = ISLabel:new(
		CONST.LAYOUT.PADDING,
		detailsY,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		labelTexts[4],
		CONST.COLORS.TEXT.NORMAL.r,
		CONST.COLORS.TEXT.NORMAL.g,
		CONST.COLORS.TEXT.NORMAL.b,
		CONST.COLORS.TEXT.NORMAL.a,
		CONST.FONT.SMALL,
		true
	)
	self.eventDetailsPanel:addChild(self.endTimeLabel)

	self.endTimeDisplay = ISLabel:new(
		valueX,
		detailsY,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		getText("IGUI_ETM_SetEndTime"),
		CONST.COLORS.TEXT.NORMAL.r,
		CONST.COLORS.TEXT.NORMAL.g,
		CONST.COLORS.TEXT.NORMAL.b,
		CONST.COLORS.TEXT.NORMAL.a,
		CONST.FONT.SMALL,
		true
	)
	self.endTimeDisplay:initialise()
	self.eventDetailsPanel:addChild(self.endTimeDisplay)

	detailsY = self.endTimeLabel:getBottom() + CONST.LAYOUT.PADDING
	self.registrationLabel = ISLabel:new(
		CONST.LAYOUT.PADDING,
		detailsY,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		labelTexts[5],
		CONST.COLORS.TEXT.NORMAL.r,
		CONST.COLORS.TEXT.NORMAL.g,
		CONST.COLORS.TEXT.NORMAL.b,
		CONST.COLORS.TEXT.NORMAL.a,
		CONST.FONT.SMALL,
		true
	)
	self.eventDetailsPanel:addChild(self.registrationLabel)

	self.registrationValue = ISLabel:new(
		valueX,
		detailsY,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		"",
		CONST.COLORS.TEXT.NORMAL.r,
		CONST.COLORS.TEXT.NORMAL.g,
		CONST.COLORS.TEXT.NORMAL.b,
		CONST.COLORS.TEXT.NORMAL.a,
		CONST.FONT.SMALL,
		true
	)
	self.eventDetailsPanel:addChild(self.registrationValue)

	self:hideEventDetailsPlayer(true)
end

function EventTeleportManager.UI_Manager:createBottomButtons(x, y)
	self.bottomButtonsPanel = ISPanel:new(x, y, self.contentPanel:getWidth(), CONST.LAYOUT.BUTTON.HEIGHT)
	self.bottomButtonsPanel:initialise()
	self.bottomButtonsPanel.borderColor = { r = 0, g = 0, b = 0, a = 0 }
	self.bottomButtonsPanel.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
	self.bottomButtonsPanel.anchorRight = true
	self.bottomButtonsPanel.anchorBottom = true
	self.contentPanel:addChild(self.bottomButtonsPanel)

	local buttonWidth = (self.bottomButtonsPanel:getWidth() - (CONST.LAYOUT.PADDING * 4)) / 3

	if self.currentView == "admin" then
		self.teleportPlayersButton = ISButton:new(
			CONST.LAYOUT.PADDING,
			0,
			buttonWidth,
			CONST.LAYOUT.BUTTON.HEIGHT,
			getText("IGUI_ETM_TeleportPlayers"),
			self,
			self.onTeleportPlayers
		)
		self.teleportPlayersButton:initialise()
		self.teleportPlayersButton:instantiate()
		self.teleportPlayersButton.borderColor = copyColor(CONST.COLORS.BORDER.NORMAL)
		self.teleportPlayersButton.backgroundColor = copyColor(CONST.COLORS.BUTTON.NORMAL)
		self.teleportPlayersButton.backgroundColorMouseOver = copyColor(CONST.COLORS.BUTTON.HOVER)
		self.teleportPlayersButton:setEnable(false)
		self.teleportPlayersButton.anchorRight = false
		self.bottomButtonsPanel:addChild(self.teleportPlayersButton)

		self.returnPlayersButton = ISButton:new(
			self.teleportPlayersButton:getRight() + CONST.LAYOUT.PADDING,
			0,
			buttonWidth,
			CONST.LAYOUT.BUTTON.HEIGHT,
			getText("IGUI_ETM_ReturnPlayers"),
			self,
			self.onReturnPlayers
		)
		self.returnPlayersButton:initialise()
		self.returnPlayersButton:instantiate()
		self.returnPlayersButton.borderColor = copyColor(CONST.COLORS.BORDER.NORMAL)
		self.returnPlayersButton.backgroundColor = copyColor(CONST.COLORS.BUTTON.NORMAL)
		self.returnPlayersButton.backgroundColorMouseOver = copyColor(CONST.COLORS.BUTTON.HOVER)
		self.returnPlayersButton:setEnable(false)
		self.returnPlayersButton.anchorLeft = false
		self.returnPlayersButton.anchorRight = false
		self.bottomButtonsPanel:addChild(self.returnPlayersButton)

		self.closeButton2 = ISButton:new(
			self.returnPlayersButton:getRight() + CONST.LAYOUT.PADDING,
			0,
			buttonWidth,
			CONST.LAYOUT.BUTTON.HEIGHT,
			getText("IGUI_ETM_Close"),
			self,
			self.close
		)
		self.closeButton2:initialise()
		self.closeButton2:instantiate()
		self.closeButton2.borderColor = copyColor(CONST.COLORS.BORDER.NORMAL)
		self.closeButton2.backgroundColor = copyColor(CONST.COLORS.BUTTON.CLOSE)
		self.closeButton2.backgroundColorMouseOver = copyColor(CONST.COLORS.BUTTON.CLOSE_HOVER)
		self.closeButton2.anchorLeft = false
		self.closeButton2.anchorRight = true
		self.bottomButtonsPanel:addChild(self.closeButton2)
	else
		self.registerButton = ISButton:new(
			CONST.LAYOUT.PADDING,
			0,
			buttonWidth,
			CONST.LAYOUT.BUTTON.HEIGHT,
			getText("IGUI_ETM_Register"),
			self,
			self.onRegister
		)
		self.registerButton:initialise()
		self.registerButton:instantiate()
		self.registerButton.borderColor = copyColor(CONST.COLORS.BORDER.NORMAL)
		self.registerButton.backgroundColor = copyColor(CONST.COLORS.BUTTON.NORMAL)
		self.registerButton.backgroundColorMouseOver = copyColor(CONST.COLORS.BUTTON.HOVER)
		self.registerButton:setEnable(false)
		self.registerButton.anchorRight = false
		self.bottomButtonsPanel:addChild(self.registerButton)

		self.teleportButton = ISButton:new(
			self.registerButton:getRight() + CONST.LAYOUT.PADDING,
			0,
			buttonWidth,
			CONST.LAYOUT.BUTTON.HEIGHT,
			getText("IGUI_ETM_TeleportToEvent"),
			self,
			self.onTeleport
		)
		self.teleportButton:initialise()
		self.teleportButton:instantiate()
		self.teleportButton.borderColor = copyColor(CONST.COLORS.BORDER.NORMAL)
		self.teleportButton.backgroundColor = copyColor(CONST.COLORS.BUTTON.NORMAL)
		self.teleportButton.backgroundColorMouseOver = copyColor(CONST.COLORS.BUTTON.HOVER)
		self.teleportButton:setEnable(false)
		self.teleportButton.anchorLeft = false
		self.teleportButton.anchorRight = false
		self.bottomButtonsPanel:addChild(self.teleportButton)

		self.returnButton = ISButton:new(
			self.teleportButton:getRight() + CONST.LAYOUT.PADDING,
			0,
			buttonWidth,
			CONST.LAYOUT.BUTTON.HEIGHT,
			getText("IGUI_ETM_ReturnToPosition"),
			self,
			self.onReturn
		)
		self.returnButton:initialise()
		self.returnButton:instantiate()
		self.returnButton.borderColor = copyColor(CONST.COLORS.BORDER.NORMAL)
		self.returnButton.backgroundColor = copyColor(CONST.COLORS.BUTTON.NORMAL)
		self.returnButton.backgroundColorMouseOver = copyColor(CONST.COLORS.BUTTON.HOVER)
		self.returnButton:setEnable(false)
		self.returnButton.anchorLeft = false
		self.returnButton.anchorRight = true
		self.bottomButtonsPanel:addChild(self.returnButton)
	end
end

function EventTeleportManager.UI_Manager:hideEventDetailsAdmin(hide)
	if not self.nameEntry then
		return
	end

	if self.noEventLabel then
		self.noEventLabel:setVisible(hide)
	end

	local elements = {
		self.nameLabel,
		self.nameEntry,
		self.startTimeLabel,
		self.startTimeDisplay,
		self.startTimeButton,
		self.endTimeLabel,
		self.endTimeDisplay,
		self.endTimeButton,
		self.locationLabel,
		self.locationXLabel,
		self.locationXEntry,
		self.locationYLabel,
		self.locationYEntry,
		self.locationZLabel,
		self.locationZEntry,
		self.setLocationButton,
		self.playersLabel,
		self.playerList,
		self.addPlayerButton,
		self.removePlayerButton,
		self.saveButton,
	}

	for i = 1, #elements do
		if elements[i] then
			elements[i]:setVisible(not hide)
		end
	end
end

function EventTeleportManager.UI_Manager:hideEventDetailsPlayer(hide)
	if not self.nameValue then
		return
	end

	if self.noEventLabel then
		self.noEventLabel:setVisible(hide)
	end

	local elements = {
		self.nameLabel,
		self.nameValue,
		self.statusLabel,
		self.statusValue,
		self.startTimeLabel,
		self.startTimeDisplay,
		self.endTimeLabel,
		self.endTimeDisplay,
		self.registrationLabel,
		self.registrationValue,
	}

	for i = 1, #elements do
		if elements[i] then
			elements[i]:setVisible(not hide)
		end
	end
end

function EventTeleportManager.UI_Manager:drawEventListItem(y, item, alt)
	local event = item.item
	if not event then
		return y
	end

	local status = EventTeleportManager.Shared.GetEventStatus(event)
	local statusColor = getEventStatusColor(status) --[[@as table]]
	local statusText = EventTeleportManager.Shared.GetEventStatusText(status)

	local isRegistered = EventTeleportManager.Shared.IsPlayerRegistered(self.target.username, event.id)

	local isSelected = self.selected == item.index
	local bgColor = isSelected and copyColor(CONST.COLORS.LIST.SELECTED)
		or (alt and CONST.COLORS.LIST_ALT or self.backgroundColor)

	self:drawRect(0, y, self:getWidth(), self.itemheight - 1, bgColor.a, bgColor.r, bgColor.g, bgColor.b)

	local textHeight = getTextManager():MeasureStringY(self.font, event.name)
	self:drawText(
		event.name,
		CONST.LAYOUT.PADDING,
		y + self.itemheight / 2 - textHeight / 2,
		CONST.COLORS.TEXT.NORMAL.r,
		CONST.COLORS.TEXT.NORMAL.g,
		CONST.COLORS.TEXT.NORMAL.b,
		CONST.COLORS.TEXT.NORMAL.a,
		self.font
	)

	local textWidth = getTextManager():MeasureStringX(self.font, statusText)
	textHeight = getTextManager():MeasureStringY(self.font, statusText)
	self:drawText(
		statusText,
		self:getWidth() - textWidth - CONST.LAYOUT.PADDING,
		y + CONST.LAYOUT.PADDING / 2,
		statusColor.r,
		statusColor.g,
		statusColor.b,
		statusColor.a,
		self.font
	)

	if isRegistered then
		statusText = getText("IGUI_ETM_Registered")
		statusColor = copyColor(CONST.COLORS.EVENT.ACTIVE) --[[@as table]]
	else
		statusText = getText("IGUI_ETM_NotRegistered")
		statusColor = copyColor(CONST.COLORS.EVENT.INACTIVE) --[[@as table]]
	end

	textWidth = getTextManager():MeasureStringX(self.font, statusText)
	self:drawText(
		statusText,
		self:getWidth() - textWidth - CONST.LAYOUT.PADDING,
		y + CONST.LAYOUT.PADDING + textHeight,
		statusColor.r,
		statusColor.g,
		statusColor.b,
		statusColor.a,
		self.font
	)

	return y + self.itemheight
end

function EventTeleportManager.UI_Manager:drawPlayerListItem(y, item, alt)
	local username = item.text

	local isSelected = self.selected == item.index
	local bgColor = isSelected and copyColor(CONST.COLORS.LIST.SELECTED)
		or (alt and CONST.COLORS.LIST_ALT or self.backgroundColor)

	self:drawRect(0, y, self:getWidth(), self.itemheight - 1, bgColor.a, bgColor.r, bgColor.g, bgColor.b)

	self:drawText(
		username,
		CONST.LAYOUT.PADDING,
		y + (self.itemheight - getTextManager():MeasureStringY(self.font, username)) / 2,
		CONST.COLORS.TEXT.NORMAL.r,
		CONST.COLORS.TEXT.NORMAL.g,
		CONST.COLORS.TEXT.NORMAL.b,
		CONST.COLORS.TEXT.NORMAL.a,
		self.font
	)

	return y + self.itemheight
end

function EventTeleportManager.UI_Manager:updateEventList()
	self.eventList:clear()

	if not EventTeleportManager.Events then
		if self.currentView == "admin" then
			self:hideEventDetailsAdmin(true)
			if self.deleteEventButton then
				self.deleteEventButton:setEnable(false)
			end
			if self.teleportPlayersButton then
				self.teleportPlayersButton:setEnable(false)
			end
			if self.returnPlayersButton then
				self.returnPlayersButton:setEnable(false)
			end

			self:showNotification(getText("IGUI_ETM_NoEvents"))
		else
			self:hideEventDetailsPlayer(true)
			if self.registerButton then
				self.registerButton:setEnable(false)
			end
			if self.teleportButton then
				self.teleportButton:setEnable(false)
			end
			if self.returnButton then
				self.returnButton:setEnable(false)
			end

			self:showNotification(getText("IGUI_ETM_NoEvents"))
		end
		return
	end

	local eventsSorted = {}
	for id, event in pairs(EventTeleportManager.Events) do
		local eventCopy = copyTable(event)
		eventCopy.status = EventTeleportManager.Shared.GetEventStatus(event)
		eventCopy.isRegistered = EventTeleportManager.Shared.IsPlayerRegistered(self.username, id)
		table.insert(eventsSorted, eventCopy)
	end

	if self.currentView == "admin" then
		table.sort(eventsSorted, function(a, b)
			if a.status ~= b.status then
				return a.status < b.status
			end
			return a.name < b.name
		end)
	else
		table.sort(eventsSorted, function(a, b)
			if a.isRegistered ~= b.isRegistered then
				return a.isRegistered
			end
			if a.status ~= b.status then
				return a.status < b.status
			end
			return a.name < b.name
		end)
	end

	for _, event in ipairs(eventsSorted) do
		self.eventList:addItem(event.name, event)
	end

	if self.currentView == "player" and self.returnButton then
		local hasOriginalPosition = EventTeleportManager.OriginalPositions
			and EventTeleportManager.OriginalPositions[self.username] ~= nil
		self.returnButton:setEnable(hasOriginalPosition)
	end

	if self.selectedEvent then
		local stillExists = false
		for i = 1, #self.eventList.items do
			if self.eventList.items[i].item.id == self.selectedEvent.id then
				self.eventList.selected = i
				stillExists = true
				break
			end
		end

		if not stillExists then
			self.selectedEvent = nil
		end
	end

	self:onEventSelected()
	self:updateButtonStates()
end

function EventTeleportManager.UI_Manager:updateEventDetails()
	if not self.selectedEvent then
		if self.currentView == "admin" then
			self:hideEventDetailsAdmin(true)
			if self.deleteEventButton then
				self.deleteEventButton:setEnable(false)
			end
			if self.teleportPlayersButton then
				self.teleportPlayersButton:setEnable(false)
			end
			if self.returnPlayersButton then
				self.returnPlayersButton:setEnable(false)
			end
		else
			self:hideEventDetailsPlayer(true)
			if self.registerButton then
				self.registerButton:setEnable(false)
			end
			if self.teleportButton then
				self.teleportButton:setEnable(false)
			end
		end
		return
	end

	if self.currentView == "admin" then
		self:updateAdminEventDetails()
	else
		self:updatePlayerEventDetails()
	end
end

function EventTeleportManager.UI_Manager:updateAdminEventDetails()
	self:hideEventDetailsAdmin(false)

	self.nameEntry:setText(self.selectedEvent.name or "")

	if self.selectedEvent.startTime then
		local dateModel = DateTimeModel:new({
			date = DateTimeUtility.fromTimestamp(self.selectedEvent.startTime),
		})
		local localDate = dateModel:getLocalDate()

		local formattedDate = DateTimeUtility.formatDate(localDate, DateTimeUtility.FORMAT["EU"])
		self.startTimeDisplay:setName(formattedDate)
	else
		self.startTimeDisplay:setName(getText("IGUI_ETM_SetStartTime"))
	end

	if self.selectedEvent.endTime then
		local dateModel = DateTimeModel:new({
			date = DateTimeUtility.fromTimestamp(self.selectedEvent.endTime),
		})
		local localDate = dateModel:getLocalDate()

		local formattedDate = DateTimeUtility.formatDate(localDate, DateTimeUtility.FORMAT["EU"])
		self.endTimeDisplay:setName(formattedDate)
	else
		self.endTimeDisplay:setName(getText("IGUI_ETM_SetEndTime"))
	end

	local loc = self.selectedEvent.location or { x = 0, y = 0, z = 0 }
	self.locationXEntry:setText(tostring(math.floor(loc.x)))
	self.locationYEntry:setText(tostring(math.floor(loc.y)))
	self.locationZEntry:setText(tostring(math.floor(loc.z)))

	self.playerList:clear()
	if self.selectedEvent.players and #self.selectedEvent.players > 0 then
		for _, username in ipairs(self.selectedEvent.players) do
			self.playerList:addItem(username, username)
		end
	end

	self:updateButtonStates()
end

function EventTeleportManager.UI_Manager:updatePlayerEventDetails()
	self:hideEventDetailsPlayer(false)

	self.nameValue:setName(self.selectedEvent.name or "")

	local status = EventTeleportManager.Shared.GetEventStatus(self.selectedEvent)
	local statusText = EventTeleportManager.Shared.GetEventStatusText(status)
	local statusColor = getEventStatusColor(status)

	self.statusValue:setName(statusText)
	self.statusValue:setColor(statusColor.r, statusColor.g, statusColor.b)

	if self.selectedEvent.startTime then
		local dateModel = DateTimeModel:new({
			date = DateTimeUtility.fromTimestamp(self.selectedEvent.startTime),
		})
		local localDate = dateModel:getLocalDate()
		local formattedDate = DateTimeUtility.formatDate(localDate, DateTimeUtility.FORMAT["EU"])
		self.startTimeDisplay:setName(formattedDate)
	else
		self.startTimeDisplay:setName(getText("IGUI_ETM_SetStartTime"))
	end

	if self.selectedEvent.endTime then
		local dateModel = DateTimeModel:new({
			date = DateTimeUtility.fromTimestamp(self.selectedEvent.endTime),
		})
		local localDate = dateModel:getLocalDate()
		local formattedDate = DateTimeUtility.formatDate(localDate, DateTimeUtility.FORMAT["EU"])
		self.endTimeDisplay:setName(formattedDate)
	else
		self.endTimeDisplay:setName(getText("IGUI_ETM_SetEndTime"))
	end

	local isRegistered = EventTeleportManager.Shared.IsPlayerRegistered(self.username, self.selectedEvent.id)
	local canSelfRegister = EventTeleportManager.Shared.CanPlayerSelfRegister(self.player)
	local registrationMode = EventTeleportManager.Shared.GetRegistrationMode()

	local activeEvents = EventTeleportManager.Shared.GetPlayerActiveEvents(self.username)
	local hasMultipleActiveEvents = #activeEvents > 1

	if isRegistered then
		local regText = getText("IGUI_ETM_Registered")
		if hasMultipleActiveEvents then
			regText = regText .. " (" .. getText("IGUI_ETM_MultipleActiveEventsShort", #activeEvents) .. ")"
		end
		self.registrationValue:setName(regText)

		if self.registerButton then
			if canSelfRegister then
				self.registerButton:setTitle(getText("IGUI_ETM_Unregister"))
				self.registerButton:setEnable(true)
			else
				self.registerButton:setTitle(getText("IGUI_ETM_ContactAdmin"))
				self.registerButton:setEnable(false)
			end
		end
	else
		self.registrationValue:setName(getText("IGUI_ETM_NotRegistered"))
		if self.registerButton then
			if canSelfRegister then
				self.registerButton:setTitle(getText("IGUI_ETM_Register"))
				self.registerButton:setEnable(true)
			else
				self.registerButton:setTitle(getText("IGUI_ETM_ContactAdmin"))
				self.registerButton:setEnable(false)
			end
		end
	end

	if hasMultipleActiveEvents and not self.multipleEventsWarning then
		self:showNotification(getText("IGUI_ETM_MultipleActiveEvents"), 5000)
	end

	if registrationMode == "admin_only" and not EventTeleportManager.Shared.HasPermission(self.player) then
		self:showNotification(getText("IGUI_ETM_AdminOnlyRegistration"), 5000)
	end
end

function EventTeleportManager.UI_Manager:onEventSelected()
	local selected = self.eventList.selected

	if selected <= 0 or not self.eventList.items[selected] then
		self.selectedEvent = nil
		self.selectedPlayer = nil
	else
		self.selectedEvent = self.eventList.items[selected].item
		self.selectedPlayer = nil
	end

	self:updateEventDetails()
	self:updateButtonStates()
end

function EventTeleportManager.UI_Manager:updateButtonStates()
	local hasSelection = self.selectedEvent ~= nil
	local isNewEvent = hasSelection and not self.selectedEvent.id

	if self.currentView == "admin" then
		if self.deleteEventButton then
			self.deleteEventButton:setEnable(hasSelection and not isNewEvent)
		end

		local hasPlayers = hasSelection and self.selectedEvent.players and #self.selectedEvent.players > 0
		local isExistingEvent = hasSelection and not isNewEvent

		if self.teleportPlayersButton then
			self.teleportPlayersButton:setEnable(isExistingEvent and hasPlayers)
		end

		if self.returnPlayersButton then
			self.returnPlayersButton:setEnable(isExistingEvent and hasPlayers)
		end

		if self.removePlayerButton then
			self.removePlayerButton:setEnable(self.selectedPlayer ~= nil)
		end

		if self.saveButton then
			self.saveButton:setEnable(hasSelection)
		end
	else
		local canSelfRegister = EventTeleportManager.Shared.CanPlayerSelfRegister(self.player)

		if self.registerButton then
			if hasSelection and canSelfRegister then
				self.registerButton:setEnable(true)
				self.registerButton:setTooltip(nil)
			else
				self.registerButton:setEnable(false)
				if hasSelection and not canSelfRegister then
					self.registerButton:setTitle(getText("IGUI_ETM_ContactAdmin"))
					self.registerButton:setTooltip(getText("IGUI_ETM_AdminOnlyRegistration"))
				end
			end
		end

		if self.teleportButton and hasSelection then
		else
			if self.teleportButton then
				self.teleportButton:setEnable(false)
				self.teleportButton:setTooltip(hasSelection and getText("IGUI_ETM_NotRegisteredForEvent") or nil)
			end
		end

		if self.returnButton then
		end
	end
end

function EventTeleportManager.UI_Manager:onEventListMouseDown(x, y)
	if self.items and #self.items == 0 then
		return
	end
	local row = self:rowAt(x, y)

	if row > #self.items then
		row = #self.items
	end
	if row < 1 then
		row = 1
	end

	local item = self.items[row].item

	getSoundManager():playUISound("UISelectListItem")
	self.selected = row
	if self.onmousedown then
		self.onmousedown(self.target, item)
	end

	self.parent.parent.parent:onEventSelected()
end

function EventTeleportManager.UI_Manager:onPlayerListMouseDown(x, y)
	ISScrollingListBox.onMouseDown(self, x, y)

	local selected = self.selected
	if selected > 0 and self.items[selected] then
		self.parent.parent.parent.selectedPlayer = self.items[selected].text
		if self.parent.parent.parent.removePlayerButton then
			self.parent.parent.parent.removePlayerButton:setEnable(true)
		end
	else
		self.parent.parent.parent.selectedPlayer = nil
		if self.parent.parent.parent.removePlayerButton then
			self.parent.parent.parent.removePlayerButton:setEnable(false)
		end
	end
end

function EventTeleportManager.UI_Manager:onTabSelected(button)
	local view = button.internal
	if view == self.currentView then
		return
	end

	self.currentView = view
	self:updateTabColors()
	self:createViewContent()
	self:updateEventList()

	local message = view == "admin" and getText("IGUI_ETM_SwitchedToAdmin") or getText("IGUI_ETM_SwitchedToPlayer")
	self:showNotification(message)
end

function EventTeleportManager.UI_Manager:updateTabColors()
	if not self.adminTab then
		return
	end

	self.adminTab.backgroundColor = self.currentView == "admin" and copyColor(CONST.COLORS.TAB.ACTIVE)
		or copyColor(CONST.COLORS.TAB.INACTIVE)
	self.playerTab.backgroundColor = self.currentView == "player" and copyColor(CONST.COLORS.TAB.ACTIVE)
		or copyColor(CONST.COLORS.TAB.INACTIVE)
end

function EventTeleportManager.UI_Manager:onCreateEvent()
	if self.currentView ~= "admin" then
		return
	end

	self.selectedEvent = {
		id = nil,
		name = "New Event",
		startTime = nil,
		endTime = nil,
		location = {
			x = math.floor(self.player:getX()),
			y = math.floor(self.player:getY()),
			z = math.floor(self.player:getZ()),
		},
		players = {},
	}

	self:updateEventDetails()
	self:updateButtonStates()
	self:showNotification(getText("IGUI_ETM_CreatingNewEvent"))
end

function EventTeleportManager.UI_Manager:onDeleteEvent()
	if self.currentView ~= "admin" or not self.selectedEvent then
		return
	end

	local modal = ISModalDialog:new(
		0,
		0,
		350,
		150,
		string.format("Are you sure you want to delete event '%s'?", self.selectedEvent.name),
		true,
		self,
		self.onDeleteEventConfirm
	)
	modal:initialise()
	modal:addToUIManager()
	modal:setX((getCore():getScreenWidth() / 2) - (modal:getWidth() / 2))
	modal:setY((getCore():getScreenHeight() / 2) - (modal:getHeight() / 2))
end

function EventTeleportManager.UI_Manager:onDeleteEventConfirm(button)
	if button.internal ~= "YES" then
		return
	end

	if not self.selectedEvent then
		return
	end

	EventTeleportManager.Client.RemoveEvent(self.selectedEvent.id)

	self.selectedEvent = nil
	self:updateEventDetails()
end

function EventTeleportManager.UI_Manager:onSaveEvent()
	local eventName = self.nameEntry:getText()
	if not eventName or eventName:trim() == "" then
		self:showNotification(getText("IGUI_ETM_EnterEventName"), 2000)
		return
	end

	local isNewEvent = not self.selectedEvent.id

	if isNewEvent then
		local newEvent = {
			name = eventName,
			startTime = self.selectedEvent.startTime,
			endTime = self.selectedEvent.endTime,
			location = {
				x = math.floor(tonumber(self.locationXEntry:getText()) or 0),
				y = math.floor(tonumber(self.locationYEntry:getText()) or 0),
				z = math.floor(tonumber(self.locationZEntry:getText()) or 0),
			},
			players = {},
		}

		if newEvent.startTime and newEvent.endTime and newEvent.startTime >= newEvent.endTime then
			self:showNotification(getText("IGUI_ETM_StartBeforeEnd"), 3000)
			return
		end

		EventTeleportManager.Client.AddEvent(newEvent)
	else
		EventTeleportManager.Client.EditEventData(self.selectedEvent.id, "name", eventName)

		if self.selectedEvent.startTime then
			EventTeleportManager.Client.EditEventData(self.selectedEvent.id, "startTime", self.selectedEvent.startTime)
		end

		if self.selectedEvent.endTime then
			EventTeleportManager.Client.EditEventData(self.selectedEvent.id, "endTime", self.selectedEvent.endTime)
		end

		EventTeleportManager.Client.EditEventData(
			self.selectedEvent.id,
			"location.x",
			tonumber(self.locationXEntry:getText()) or 0
		)
		EventTeleportManager.Client.EditEventData(
			self.selectedEvent.id,
			"location.y",
			tonumber(self.locationYEntry:getText()) or 0
		)
		EventTeleportManager.Client.EditEventData(
			self.selectedEvent.id,
			"location.z",
			tonumber(self.locationZEntry:getText()) or 0
		)
	end

	local message = isNewEvent and getText("IGUI_ETM_EventCreated", eventName)
		or getText("IGUI_ETM_EventUpdated", eventName)

	self:showNotification(message)
end

function EventTeleportManager.UI_Manager:onSetLocation()
	if self.currentView ~= "admin" or not self.selectedEvent then
		return
	end

	local updatedLocation = {
		x = math.floor(self.player:getX()),
		y = math.floor(self.player:getY()),
		z = math.floor(self.player:getZ()),
	}

	self.selectedEvent.location = updatedLocation
	self.locationXEntry:setText(tostring(updatedLocation.x))
	self.locationYEntry:setText(tostring(updatedLocation.y))
	self.locationZEntry:setText(tostring(updatedLocation.z))

	if self.selectedEvent.id then
		EventTeleportManager.Client.EditEventData(self.selectedEvent.id, "location.x", updatedLocation.x)
		EventTeleportManager.Client.EditEventData(self.selectedEvent.id, "location.y", updatedLocation.y)
		EventTeleportManager.Client.EditEventData(self.selectedEvent.id, "location.z", updatedLocation.z)
		self:showNotification(getText("IGUI_ETM_LocationSet"))
	end
end

function EventTeleportManager.UI_Manager:onAddPlayer()
	if self.currentView ~= "admin" then
		return
	end

	if not self.selectedEvent or not self.selectedEvent.id then
		self:showNotification("Save the event first")
		return
	end

	self.playerSelectionModal = EventTeleportManager.UI_Manager.PlayerSelectionModal:new(
		self,
		(getCore():getScreenWidth() / 2) - (CONST.LAYOUT.WINDOW_SIZE.PLAYER_SELECTION_MODAL.WIDTH / 2),
		(getCore():getScreenHeight() / 2) - (CONST.LAYOUT.WINDOW_SIZE.PLAYER_SELECTION_MODAL.HEIGHT / 2),
		CONST.LAYOUT.WINDOW_SIZE.PLAYER_SELECTION_MODAL.WIDTH,
		CONST.LAYOUT.WINDOW_SIZE.PLAYER_SELECTION_MODAL.HEIGHT
	)
	self.playerSelectionModal:initialise()
	self.playerSelectionModal:addToUIManager()
	self.playerSelectionModal:bringToTop()
end

function EventTeleportManager.UI_Manager:onRemovePlayer()
	if self.currentView ~= "admin" or not self.selectedEvent or not self.selectedPlayer then
		return
	end

	EventTeleportManager.Client.ModifyEventPlayers(self.selectedEvent.id, "remove", { self.selectedPlayer })

	self.selectedPlayer = nil
	self.removePlayerButton:setEnable(false)

	if self.selectedEvent.players and #self.selectedEvent.players <= 1 then
		if self.teleportPlayersButton then
			self.teleportPlayersButton:setEnable(false)
		end
		if self.returnPlayersButton then
			self.returnPlayersButton:setEnable(false)
		end
	end
end

function EventTeleportManager.UI_Manager:onTeleportPlayers()
	if self.currentView ~= "admin" or not self.selectedEvent then
		return
	end

	if not self.selectedEvent.players or #self.selectedEvent.players == 0 then
		self:showNotification(getText("IGUI_ETM_NoPlayersToTeleport"), 3000)
		return
	end

	local teleportedCount = 0
	for _, username in ipairs(self.selectedEvent.players) do
		EventTeleportManager.Client.TeleportPlayer(self.selectedEvent.id, username, true)
		teleportedCount = teleportedCount + 1
	end

	self:showNotification(getText("IGUI_ETM_TeleportingPlayersCount", teleportedCount), 3000)
end

function EventTeleportManager.UI_Manager:onReturnPlayers()
	if self.currentView ~= "admin" or not self.selectedEvent then
		return
	end

	if not EventTeleportManager.OriginalPositions then
		self:showNotification(getText("IGUI_ETM_NoPlayersToReturn"), 3000)
		return
	end

	local playersToReturn = {}
	for username, posInfo in pairs(EventTeleportManager.OriginalPositions) do
		if posInfo.eventId == self.selectedEvent.id then
			table.insert(playersToReturn, username)
		end
	end

	if #playersToReturn == 0 then
		self:showNotification(getText("IGUI_ETM_NoPlayersToReturn"), 3000)
		return
	end

	for _, username in ipairs(playersToReturn) do
		EventTeleportManager.Client.ReturnPlayer(username, true)
	end

	self:showNotification(getText("IGUI_ETM_ReturningPlayersCount", #playersToReturn), 3000)
end

function EventTeleportManager.UI_Manager:onRegister()
	if self.currentView ~= "player" or not self.selectedEvent then
		return
	end

	if not EventTeleportManager.Shared.CanPlayerSelfRegister(self.player) then
		self:showNotification(getText("IGUI_ETM_SelfRegistrationDisabled"), 3000)
		return
	end

	local isRegistered = EventTeleportManager.Shared.IsPlayerRegistered(self.username, self.selectedEvent.id)
	local action = isRegistered and "unregister" or "register"

	EventTeleportManager.Client.ModifyEventPlayers(self.selectedEvent.id, action, { self.username })

	local message = isRegistered and getText("IGUI_ETM_UnregistrationSuccess", self.selectedEvent.name)
		or getText("IGUI_ETM_RegistrationSuccess", self.selectedEvent.name)

	self:showNotification(message)
end

function EventTeleportManager.UI_Manager:onTeleport()
	if self.currentView ~= "player" or not self.selectedEvent then
		return
	end

	local activeEvents = EventTeleportManager.Shared.GetPlayerActiveEvents(self.username)
	if #activeEvents > 1 then
		local eventNames = {}
		for _, eventInfo in ipairs(activeEvents) do
			table.insert(eventNames, eventInfo.name)
		end
		local message = getText("IGUI_ETM_MultipleActiveEventsWarning", table.concat(eventNames, ", "))
		self:showNotification(message, 5000)
	end

	local status = EventTeleportManager.Shared.GetEventStatus(self.selectedEvent)
	if status ~= EventTeleportManager.EVENT_STATUS.ACTIVE then
		local messageKey = status == EventTeleportManager.EVENT_STATUS.FUTURE and "IGUI_ETM_EventNotStarted"
			or "IGUI_ETM_EventEnded"
		self:showNotification(getText(messageKey), 3000)
		return
	end

	local isRegistered = EventTeleportManager.Shared.IsPlayerRegistered(self.username, self.selectedEvent.id)
	if not isRegistered then
		self:showNotification(getText("IGUI_ETM_NotRegisteredForEvent"), 3000)
		return
	end

	if EventTeleportManager.Shared.HasZombiesThreat(self.player) then
		self:showNotification(getText("IGUI_ETM_ZombiesThreat"), 3000)
		return
	end

	if EventTeleportManager.Shared.IsPlayerOnCooldown(self.player) then
		local remaining = EventTeleportManager.Shared.GetRemainingCooldown(self.player)
		self:showNotification(getText("IGUI_ETM_ReturnCooldown", remaining), 3000)
		return
	end

	EventTeleportManager.Client.TeleportPlayer(self.selectedEvent.id, self.username, false)
	self:showNotification(getText("IGUI_ETM_TeleportingToEvent", self.selectedEvent.name))
end

function EventTeleportManager.UI_Manager:updateNotification()
	local currentTime = getTimestampMs()

	if self.notificationTime > 0 and currentTime > self.notificationTime then
		self.notificationMessage = ""
		self.notificationTime = 0
		self.notificationLabel:setName("")
	end
end

function EventTeleportManager.UI_Manager:prerender()
	ISCollapsableWindow.prerender(self)

	self:updateNotification()
	self:updateButtonStates()

	self:updateDynamicButtons()
end

function EventTeleportManager.UI_Manager:updateDynamicButtons()
	if self.currentView ~= "player" then
		return
	end

	if self.teleportButton and self.selectedEvent then
		local isRegistered = EventTeleportManager.Shared.IsPlayerRegistered(self.username, self.selectedEvent.id)
		local status = EventTeleportManager.Shared.GetEventStatus(self.selectedEvent)
		local canTeleport = isRegistered and status == EventTeleportManager.EVENT_STATUS.ACTIVE

		if canTeleport then
			if EventTeleportManager.Shared.HasZombiesThreat(self.player) then
				canTeleport = false
				self.teleportButton:setTooltip(getText("IGUI_ETM_ZombiesThreat"))
			elseif EventTeleportManager.Shared.IsPlayerOnCooldown(self.player) then
				local remaining = EventTeleportManager.Shared.GetRemainingCooldown(self.player)
				canTeleport = false
				self.teleportButton:setTooltip(getText("IGUI_ETM_ReturnCooldown", remaining))
			else
				self.teleportButton:setTooltip(nil)
			end
		end

		self.teleportButton:setEnable(canTeleport and self.selectedEvent.id and true or false)
	end

	if self.returnButton then
		local hasOriginalPosition = EventTeleportManager.OriginalPositions
			and EventTeleportManager.OriginalPositions[self.username] ~= nil

		if not hasOriginalPosition then
			self.returnButton:setEnable(false)
			self.returnButton:setTooltip(getText("IGUI_ETM_NoSavedPosition"))
			return
		end

		local safehouses = EventTeleportManager.Shared.GetPlayerSafehouses(self.player)
		local hasSafehouses = #safehouses > 0
		local returnMode = EventTeleportManager.Shared.GetReturnTeleportMode()

		local canReturn = false
		local tooltipText = nil

		if returnMode == "original_only" then
			canReturn = true
		elseif returnMode == "safehouse_choice" then
			canReturn = hasSafehouses
			if not canReturn then
				tooltipText = getText("IGUI_ETM_NoSafehouse")
			end
		else -- player_choice
			canReturn = true
		end

		if canReturn then
			if EventTeleportManager.Shared.HasZombiesThreat(self.player) then
				canReturn = false
				tooltipText = getText("IGUI_ETM_ZombiesThreat")
			elseif EventTeleportManager.Shared.IsPlayerOnCooldown(self.player) then
				local remaining = EventTeleportManager.Shared.GetRemainingCooldown(self.player)
				canReturn = false
				tooltipText = getText("IGUI_ETM_ReturnCooldown", remaining)
			end
		end

		self.returnButton:setEnable(canReturn)
		self.returnButton:setTooltip(tooltipText)
	end
end

function EventTeleportManager.UI_Manager:close()
	if self.playerSelectionModal then
		self.playerSelectionModal:close()
		self.playerSelectionModal = nil
	end

	if self.returnTeleportModal then
		self.returnTeleportModal:close()
		self.returnTeleportModal = nil
	end

	if self.safehouseSelectionModal then
		self.safehouseSelectionModal:close()
		self.safehouseSelectionModal = nil
	end

	ISCollapsableWindow.close(self)
	self:removeFromUIManager()
	EventTeleportManager.UI_Manager.instance = nil
end

function EventTeleportManager.UI_Manager.toggle(playerNum)
	if EventTeleportManager.UI_Manager.instance then
		EventTeleportManager.UI_Manager.instance:close()
		return
	end

	local x = (getCore():getScreenWidth() / 2) - (CONST.LAYOUT.WINDOW_SIZE.MAIN_PANEL.WIDTH / 2)
	local y = (getCore():getScreenHeight() / 2) - (CONST.LAYOUT.WINDOW_SIZE.MAIN_PANEL.HEIGHT / 2)

	local panel = EventTeleportManager.UI_Manager:new(
		x,
		y,
		CONST.LAYOUT.WINDOW_SIZE.MAIN_PANEL.WIDTH,
		CONST.LAYOUT.WINDOW_SIZE.MAIN_PANEL.HEIGHT,
		playerNum
	)
	panel:initialise()
	panel:addToUIManager()
	EventTeleportManager.UI_Manager.instance = panel
end

EventTeleportManager.UI_Manager.PlayerSelectionModal = ISPanelJoypad:derive("EventTeleportManager_PlayerSelectionModal")

EventTeleportManager.UI_Manager.PlayerSelectionModal.scoreboard = nil

function EventTeleportManager.UI_Manager.PlayerSelectionModal:new(parent, x, y, window, height)
	local o = ISPanelJoypad:new(
		x,
		y,
		window or CONST.LAYOUT.WINDOW_SIZE.PLAYER_SELECTION_MODAL.WIDTH,
		height or CONST.LAYOUT.WINDOW_SIZE.PLAYER_SELECTION_MODAL.HEIGHT
	)
	setmetatable(o, self)
	self.__index = self

	o.parent = parent
	o.player = parent.player
	o.selectedUsernames = {}
	o.backgroundColor = copyColor(copyColor(CONST.COLORS.BACKGROUND.NORMAL))
	o.borderColor = copyColor(CONST.COLORS.BORDER.NORMAL)
	o.moveWithMouse = true
	o.anchorLeft = true
	o.anchorRight = true
	o.anchorTop = true
	o.anchorBottom = true

	o.currentTab = "online" -- "online" or "manual"
	o.contentStartY = 0

	return o
end

function EventTeleportManager.UI_Manager.PlayerSelectionModal:initialise()
	ISPanelJoypad.initialise(self)
	if isClient() then
		scoreboardUpdate()
	end
end

function EventTeleportManager.UI_Manager.PlayerSelectionModal:createChildren()
	self.titleLabel = ISLabel:new(
		CONST.LAYOUT.PADDING,
		CONST.LAYOUT.PADDING,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		getText("IGUI_ETM_AddPlayers"),
		CONST.COLORS.TEXT.NORMAL.r,
		CONST.COLORS.TEXT.NORMAL.g,
		CONST.COLORS.TEXT.NORMAL.b,
		CONST.COLORS.TEXT.NORMAL.a,
		CONST.FONT.MEDIUM,
		true
	)
	self:addChild(self.titleLabel)

	local currentY = self.titleLabel:getBottom() + CONST.LAYOUT.PADDING

	self:createTabs(currentY)
	self.contentStartY = self.onlineTab:getBottom() + CONST.LAYOUT.PADDING

	self:createTabContent()

	local buttonY = self.height - CONST.LAYOUT.BUTTON.HEIGHT - CONST.LAYOUT.PADDING

	self.cancelButton = ISButton:new(
		self.width - CONST.LAYOUT.BUTTON.WIDTH - CONST.LAYOUT.PADDING,
		buttonY,
		CONST.LAYOUT.BUTTON.WIDTH,
		CONST.LAYOUT.BUTTON.HEIGHT,
		getText("IGUI_ETM_Cancel"),
		self,
		self.onCancel
	)
	self.cancelButton:initialise()
	self.cancelButton:instantiate()
	self.cancelButton.borderColor = copyColor(CONST.COLORS.BORDER.NORMAL)
	self.cancelButton.backgroundColor = copyColor(CONST.COLORS.BUTTON.NORMAL)
	self.cancelButton.backgroundColorMouseOver = copyColor(CONST.COLORS.BUTTON.HOVER)
	self:addChild(self.cancelButton)

	self.addButton = ISButton:new(
		self.cancelButton:getX() - CONST.LAYOUT.BUTTON.WIDTH - CONST.LAYOUT.PADDING,
		buttonY,
		CONST.LAYOUT.BUTTON.WIDTH,
		CONST.LAYOUT.BUTTON.HEIGHT,
		getText("IGUI_ETM_Add"),
		self,
		self.onAdd
	)
	self.addButton:initialise()
	self.addButton:instantiate()
	self.addButton.borderColor = copyColor(CONST.COLORS.BORDER.NORMAL)
	self.addButton.backgroundColor = copyColor(CONST.COLORS.BUTTON.NORMAL)
	self.addButton.backgroundColorMouseOver = copyColor(CONST.COLORS.BUTTON.HOVER)
	self.addButton:setEnable(false)
	self:addChild(self.addButton)

	self.errorLabel = ISLabel:new(
		CONST.LAYOUT.PADDING,
		buttonY,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		"",
		CONST.COLORS.TEXT.ERROR.r,
		CONST.COLORS.TEXT.ERROR.g,
		CONST.COLORS.TEXT.ERROR.b,
		CONST.COLORS.TEXT.ERROR.a,
		CONST.FONT.SMALL,
		true
	)
	self.errorLabel:setVisible(false)
	self:addChild(self.errorLabel)
end

function EventTeleportManager.UI_Manager.PlayerSelectionModal:createTabs(y)
	local tabWidth = 120

	self.onlineTab = ISButton:new(
		CONST.LAYOUT.PADDING,
		y,
		tabWidth,
		CONST.LAYOUT.TAB.HEIGHT,
		getText("IGUI_ETM_OnlinePlayers"),
		self,
		self.onTabSelected
	)
	self.onlineTab:initialise()
	self.onlineTab:instantiate()
	self.onlineTab.internal = "online"
	self.onlineTab.borderColor = copyColor(CONST.COLORS.BORDER.NORMAL)
	self.onlineTab.backgroundColor = copyColor(CONST.COLORS.TAB.ACTIVE)
	self.onlineTab.backgroundColorMouseOver = copyColor(CONST.COLORS.BUTTON.HOVER)
	self:addChild(self.onlineTab)

	self.manualTab = ISButton:new(
		self.onlineTab:getRight() + CONST.LAYOUT.PADDING,
		y,
		tabWidth,
		CONST.LAYOUT.TAB.HEIGHT,
		getText("IGUI_ETM_ManualInput"),
		self,
		self.onTabSelected
	)
	self.manualTab:initialise()
	self.manualTab:instantiate()
	self.manualTab.internal = "manual"
	self.manualTab.borderColor = copyColor(CONST.COLORS.BORDER.NORMAL)
	self.manualTab.backgroundColor = copyColor(CONST.COLORS.TAB.INACTIVE)
	self.manualTab.backgroundColorMouseOver = copyColor(CONST.COLORS.BUTTON.HOVER)
	self:addChild(self.manualTab)
end

function EventTeleportManager.UI_Manager.PlayerSelectionModal:createTabContent()
	if self.descLabel then
		self:removeChild(self.descLabel)
	end
	if self.playerList then
		self:removeChild(self.playerList)
	end
	if self.instructLabel then
		self:removeChild(self.instructLabel)
	end
	if self.usernameEntry then
		self:removeChild(self.usernameEntry)
	end
	if self.previewLabel then
		self:removeChild(self.previewLabel)
	end
	if self.previewList then
		self:removeChild(self.previewList)
	end

	if self.currentTab == "online" then
		self:createOnlineContent()
	else
		self:createManualContent()
	end
end

function EventTeleportManager.UI_Manager.PlayerSelectionModal:createOnlineContent()
	self.descLabel = ISLabel:new(
		CONST.LAYOUT.PADDING,
		self.contentStartY,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		getText("IGUI_ETM_SelectPlayersDesc"),
		CONST.COLORS.TEXT.NORMAL.r,
		CONST.COLORS.TEXT.NORMAL.g,
		CONST.COLORS.TEXT.NORMAL.b,
		CONST.COLORS.TEXT.NORMAL.a,
		CONST.FONT.SMALL,
		true
	)
	self:addChild(self.descLabel)

	local listY = self.descLabel:getBottom() + CONST.LAYOUT.PADDING
	local listHeight = self.height - listY - CONST.LAYOUT.BUTTON.HEIGHT - CONST.LAYOUT.PADDING * 3

	self.playerList =
		ISScrollingListBox:new(CONST.LAYOUT.PADDING, listY, self.width - CONST.LAYOUT.PADDING * 2, listHeight)
	self.playerList:initialise()
	self.playerList:instantiate()
	self.playerList.itemheight = CONST.LAYOUT.ELEMENT_HEIGHT
	self.playerList.font = CONST.FONT.SMALL
	self.playerList.drawBorder = true
	self.playerList.borderColor = copyColor(CONST.COLORS.BORDER.NORMAL)
	self.playerList.backgroundColor = copyColor(copyColor(CONST.COLORS.BACKGROUND.NORMAL))
	self.playerList.doDrawItem = self.drawPlayerListItem
	self.playerList.onMouseDown = self.onPlayerListMouseDown
	self.playerList.target = self
	self:addChild(self.playerList)

	self:populatePlayerList()
end

function EventTeleportManager.UI_Manager.PlayerSelectionModal:createManualContent()
	self.descLabel = ISLabel:new(
		CONST.LAYOUT.PADDING,
		self.contentStartY,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		getText("IGUI_ETM_ManualInputDesc"),
		CONST.COLORS.TEXT.NORMAL.r,
		CONST.COLORS.TEXT.NORMAL.g,
		CONST.COLORS.TEXT.NORMAL.b,
		CONST.COLORS.TEXT.NORMAL.a,
		CONST.FONT.SMALL,
		true
	)
	self:addChild(self.descLabel)

	self.instructLabel = ISLabel:new(
		CONST.LAYOUT.PADDING,
		self.descLabel:getBottom() + CONST.LAYOUT.PADDING / 2,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		getText("IGUI_ETM_ManualInputInstruct"),
		0.7,
		0.7,
		0.7,
		1,
		CONST.FONT.SMALL,
		true
	)
	self:addChild(self.instructLabel)

	self.usernameEntry = ISTextEntryBox:new(
		"",
		CONST.LAYOUT.PADDING,
		self.instructLabel:getBottom() + CONST.LAYOUT.PADDING,
		self.width - CONST.LAYOUT.PADDING * 2,
		100
	)
	self.usernameEntry:initialise()
	self.usernameEntry:instantiate()
	self.usernameEntry.borderColor = copyColor(CONST.COLORS.BORDER.NORMAL)
	self.usernameEntry.backgroundColor = { r = 0.1, g = 0.1, b = 0.1, a = 0.8 }
	self.usernameEntry:setMultipleLine(true)
	self.usernameEntry:setMaxLines(10)
	self.usernameEntry.onTextChange = function()
		self:updateAddButton()
	end
	self:addChild(self.usernameEntry)

	self.previewLabel = ISLabel:new(
		CONST.LAYOUT.PADDING,
		self.usernameEntry:getBottom() + CONST.LAYOUT.PADDING,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		getText("IGUI_ETM_PreviewUsernames"),
		CONST.COLORS.TEXT.NORMAL.r,
		CONST.COLORS.TEXT.NORMAL.g,
		CONST.COLORS.TEXT.NORMAL.b,
		CONST.COLORS.TEXT.NORMAL.a,
		CONST.FONT.SMALL,
		true
	)
	self:addChild(self.previewLabel)

	local previewListY = self.previewLabel:getBottom() + CONST.LAYOUT.PADDING / 2
	local previewListHeight = self.height - previewListY - CONST.LAYOUT.BUTTON.HEIGHT - CONST.LAYOUT.PADDING * 3

	self.previewList = ISScrollingListBox:new(
		CONST.LAYOUT.PADDING,
		previewListY,
		self.width - CONST.LAYOUT.PADDING * 2,
		previewListHeight
	)
	self.previewList:initialise()
	self.previewList:instantiate()
	self.previewList.itemheight = CONST.LAYOUT.ELEMENT_HEIGHT
	self.previewList.font = CONST.FONT.SMALL
	self.previewList.drawBorder = true
	self.previewList.borderColor = copyColor(CONST.COLORS.BORDER.NORMAL)
	self.previewList.backgroundColor = copyColor(copyColor(CONST.COLORS.BACKGROUND.NORMAL))
	self:addChild(self.previewList)
end

function EventTeleportManager.UI_Manager.PlayerSelectionModal:populatePlayerList()
	self.playerList:clear()

	local players = {}

	if not isClient() and not isServer() then
		local username = self.player:getUsername()
		local displayName = self.player:getDisplayName()

		local alreadyAdded = false
		if self.parent.selectedEvent and self.parent.selectedEvent.players then
			for _, existingName in ipairs(self.parent.selectedEvent.players) do
				if existingName == username then
					alreadyAdded = true
					break
				end
			end
		end

		if not alreadyAdded then
			table.insert(players, {
				username = username,
				displayName = displayName,
				selected = false,
			})
		end
	elseif isClient() then
		local scoreboard = EventTeleportManager.UI_Manager.PlayerSelectionModal.scoreboard
		if not scoreboard then
			return
		end

		for i = 0, scoreboard.usernames:size() - 1 do
			local username = scoreboard.usernames:get(i)
			local displayName = scoreboard.displayNames:get(i)

			local alreadyAdded = false
			if self.parent.selectedEvent and self.parent.selectedEvent.players then
				for _, existingName in ipairs(self.parent.selectedEvent.players) do
					if existingName == username then
						alreadyAdded = true
						break
					end
				end
			end

			if not alreadyAdded then
				table.insert(players, {
					username = username,
					displayName = displayName,
					selected = false,
				})
			end
		end
	end

	table.sort(players, function(a, b)
		return (a.displayName or a.username):lower() < (b.displayName or b.username):lower()
	end)

	for _, playerData in ipairs(players) do
		local item = self.playerList:addItem(playerData.displayName or playerData.username, playerData)
		if playerData.username ~= playerData.displayName then
			item.tooltip = playerData.username
		end
	end
end

function EventTeleportManager.UI_Manager.PlayerSelectionModal:drawPlayerListItem(y, item, alt)
	local playerData = item.item

	if alt then
		self:drawRect(0, y, self:getWidth(), self.itemheight - 1, 0.3, 0.15, 0.15, 0.15)
	end

	local checkboxSize = 16
	local checkboxX = 10
	local checkboxY = y + (self.itemheight - checkboxSize) / 2

	self:drawRectBorder(checkboxX, checkboxY, checkboxSize, checkboxSize, 1, 0.4, 0.4, 0.4)

	if playerData.selected then
		self:drawRect(checkboxX + 3, checkboxY + 3, checkboxSize - 6, checkboxSize - 6, 1, 0.2, 0.8, 0.2)
	end

	local displayText = playerData.displayName or playerData.username
	local textHeight = getTextManager():MeasureStringY(self.font, displayText)
	self:drawText(
		displayText,
		checkboxX + checkboxSize + 10,
		y + (self.itemheight - textHeight) / 2,
		1,
		1,
		1,
		1,
		self.font
	)

	return y + self.itemheight
end

function EventTeleportManager.UI_Manager.PlayerSelectionModal:onPlayerListMouseDown(x, y)
	local row = self:rowAt(x, y)

	if row > 0 and row <= #self.items then
		local item = self.items[row].item
		item.selected = not item.selected

		self.parent:updateSelectedUsernames()
		self.parent:updateAddButton()
	end
end

function EventTeleportManager.UI_Manager.PlayerSelectionModal:updateSelectedUsernames()
	self.selectedUsernames = {}

	if self.currentTab == "online" then
		if self.playerList then
			for i = 1, #self.playerList.items do
				local item = self.playerList.items[i].item
				if item.selected then
					table.insert(self.selectedUsernames, item.username)
				end
			end
		end
	else
		if self.usernameEntry then
			local text = self.usernameEntry:getText()
			self.selectedUsernames = self:parseUsernames(text)

			if self.previewList then
				self.previewList:clear()
				for i = 1, #self.selectedUsernames do
					self.previewList:addItem(self.selectedUsernames[i], self.selectedUsernames[i])
				end
			end
		end
	end
end

function EventTeleportManager.UI_Manager.PlayerSelectionModal:parseUsernames(text)
	local usernames = {}

	if not text or text:trim() == "" then
		return usernames
	end

	local parts = text:split(";")

	for i = 1, #parts do
		local username = parts[i]:trim()
		if username ~= "" then
			local isDuplicate = false
			for j = 1, #usernames do
				if usernames[j] == username then
					isDuplicate = true
					break
				end
			end

			if not isDuplicate then
				table.insert(usernames, username)
			end
		end
	end

	return usernames
end

function EventTeleportManager.UI_Manager.PlayerSelectionModal:updateAddButton()
	self:updateSelectedUsernames()

	local hasSelection = #self.selectedUsernames > 0
	self.addButton:setEnable(hasSelection)

	self.errorLabel:setVisible(false)
end

function EventTeleportManager.UI_Manager.PlayerSelectionModal:onTabSelected(button)
	if button.internal == self.currentTab then
		return
	end

	self.currentTab = button.internal

	self.onlineTab.backgroundColor = self.currentTab == "online" and copyColor(CONST.COLORS.TAB.ACTIVE)
		or copyColor(CONST.COLORS.TAB.INACTIVE)
	self.manualTab.backgroundColor = self.currentTab == "manual" and copyColor(CONST.COLORS.TAB.ACTIVE)
		or copyColor(CONST.COLORS.TAB.INACTIVE)

	self.selectedUsernames = {}

	self:createTabContent()

	if self.currentTab == "online" and isClient() then
		scoreboardUpdate()
	end

	self:updateAddButton()
end

function EventTeleportManager.UI_Manager.PlayerSelectionModal:onAdd()
	if not self.parent.selectedEvent or #self.selectedUsernames == 0 then
		return
	end

	EventTeleportManager.Client.ModifyEventPlayers(self.parent.selectedEvent.id, "add", self.selectedUsernames)
	self:close()
end

function EventTeleportManager.UI_Manager.PlayerSelectionModal:onCancel()
	self:close()
end

function EventTeleportManager.UI_Manager.PlayerSelectionModal:close()
	if self.parent and self.parent.playerSelectionModal == self then
		self.parent.playerSelectionModal = nil
	end

	self:setVisible(false)
	self:removeFromUIManager()
end

function EventTeleportManager.UI_Manager.PlayerSelectionModal.onScoreboardUpdate(usernames, displayNames, steamIDs)
	EventTeleportManager.UI_Manager.PlayerSelectionModal.scoreboard = {
		usernames = usernames,
		displayNames = displayNames,
		steamIDs = steamIDs,
	}

	local ui = EventTeleportManager.UI_Manager.instance
	if ui and ui.playerSelectionModal and ui.playerSelectionModal:isVisible() then
		ui.playerSelectionModal:populatePlayerList()
	end
end

function EventTeleportManager.UI_Manager.PlayerSelectionModal.OnMiniScoreboardUpdate()
	if ISMiniScoreboardUI.instance then
		scoreboardUpdate()
	end
end

Events.OnScoreboardUpdate.Add(EventTeleportManager.UI_Manager.PlayerSelectionModal.onScoreboardUpdate)
Events.OnMiniScoreboardUpdate.Add(EventTeleportManager.UI_Manager.PlayerSelectionModal.OnMiniScoreboardUpdate)

EventTeleportManager.UI_Manager.ReturnTeleportModal = ISPanelJoypad:derive("EventTeleportManager_ReturnTeleportModal")

function EventTeleportManager.UI_Manager.ReturnTeleportModal:new(
	parent,
	x,
	y,
	width,
	height,
	hasOriginalPosition,
	safehouses
)
	local o = ISPanelJoypad:new(x, y, width or 400, height or 300)
	setmetatable(o, self)
	self.__index = self

	o.parent = parent
	o.player = parent.player
	o.username = parent.username
	o.hasOriginalPosition = hasOriginalPosition
	o.safehouses = safehouses or {}
	o.backgroundColor = copyColor(CONST.COLORS.BACKGROUND.NORMAL)
	o.borderColor = copyColor(CONST.COLORS.BORDER.NORMAL)
	o.moveWithMouse = true

	return o
end

function EventTeleportManager.UI_Manager.ReturnTeleportModal:initialise()
	ISPanelJoypad.initialise(self)
end

function EventTeleportManager.UI_Manager.ReturnTeleportModal:createChildren()
	self.titleLabel = ISLabel:new(
		CONST.LAYOUT.PADDING,
		CONST.LAYOUT.PADDING,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		getText("IGUI_ETM_ReturnTeleportTitle"),
		CONST.COLORS.TEXT.NORMAL.r,
		CONST.COLORS.TEXT.NORMAL.g,
		CONST.COLORS.TEXT.NORMAL.b,
		CONST.COLORS.TEXT.NORMAL.a,
		CONST.FONT.MEDIUM,
		true
	)
	self:addChild(self.titleLabel)

	local currentY = self.titleLabel:getBottom() + CONST.LAYOUT.PADDING

	self.descLabel = ISLabel:new(
		CONST.LAYOUT.PADDING,
		currentY,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		getText("IGUI_ETM_ReturnTeleportDesc"),
		CONST.COLORS.TEXT.NORMAL.r,
		CONST.COLORS.TEXT.NORMAL.g,
		CONST.COLORS.TEXT.NORMAL.b,
		CONST.COLORS.TEXT.NORMAL.a,
		CONST.FONT.SMALL,
		true
	)
	self:addChild(self.descLabel)

	currentY = self.descLabel:getBottom() + CONST.LAYOUT.PADDING * 2

	if self.hasOriginalPosition then
		self.originalPositionButton = ISButton:new(
			CONST.LAYOUT.PADDING,
			currentY,
			self.width - CONST.LAYOUT.PADDING * 2,
			CONST.LAYOUT.BUTTON.HEIGHT * 2,
			getText("IGUI_ETM_ReturnToOriginal"),
			self,
			self.onReturnToOriginalPosition
		)
		self.originalPositionButton:initialise()
		self.originalPositionButton:instantiate()
		self.originalPositionButton.borderColor = copyColor(CONST.COLORS.BORDER.NORMAL)
		self.originalPositionButton.backgroundColor = copyColor(CONST.COLORS.BUTTON.SELECTED) -- Highlighted as preferred
		self.originalPositionButton.backgroundColorMouseOver = copyColor(CONST.COLORS.BUTTON.HOVER)

		local pos = EventTeleportManager.OriginalPositions[self.username]
		self.originalPositionButton:setTooltip(
			getText("IGUI_ETM_OriginalPositionTooltip", math.floor(pos.x), math.floor(pos.y), math.floor(pos.z))
		)

		self:addChild(self.originalPositionButton)
		currentY = self.originalPositionButton:getBottom() + CONST.LAYOUT.PADDING
	end

	if #self.safehouses > 0 then
		local buttonText = #self.safehouses == 1 and getText("IGUI_ETM_ReturnToSafehouse")
			or getText("IGUI_ETM_ChooseSafehouse")

		self.safehouseButton = ISButton:new(
			CONST.LAYOUT.PADDING,
			currentY,
			self.width - CONST.LAYOUT.PADDING * 2,
			CONST.LAYOUT.BUTTON.HEIGHT * 2,
			buttonText,
			self,
			self.onReturnToSafehouse
		)
		self.safehouseButton:initialise()
		self.safehouseButton:instantiate()
		self.safehouseButton.borderColor = copyColor(CONST.COLORS.BORDER.NORMAL)
		self.safehouseButton.backgroundColor = copyColor(CONST.COLORS.BUTTON.NORMAL)
		self.safehouseButton.backgroundColorMouseOver = copyColor(CONST.COLORS.BUTTON.HOVER)

		if #self.safehouses == 1 then
			local safehouse = self.safehouses[1]
			self.safehouseButton:setTooltip(
				getText("IGUI_ETM_SafehouseTooltip", safehouse.title, math.floor(safehouse.x), math.floor(safehouse.y))
			)
		else
			self.safehouseButton:setTooltip(getText("IGUI_ETM_MultipleSafehousesTooltip", #self.safehouses))
		end

		self:addChild(self.safehouseButton)
		currentY = self.safehouseButton:getBottom() + CONST.LAYOUT.PADDING
	end

	currentY = currentY + CONST.LAYOUT.PADDING

	if EventTeleportManager.Shared.HasZombiesThreat(self.player) then
		self.zombieWarning = ISLabel:new(
			CONST.LAYOUT.PADDING,
			currentY,
			CONST.LAYOUT.ELEMENT_HEIGHT,
			getText("IGUI_ETM_ZombieWarning"),
			CONST.COLORS.TEXT.ERROR.r,
			CONST.COLORS.TEXT.ERROR.g,
			CONST.COLORS.TEXT.ERROR.b,
			CONST.COLORS.TEXT.ERROR.a,
			CONST.FONT.SMALL,
			true
		)
		self:addChild(self.zombieWarning)
		currentY = self.zombieWarning:getBottom() + CONST.LAYOUT.PADDING

		if self.originalPositionButton then
			self.originalPositionButton:setEnable(false)
		end
		if self.safehouseButton then
			self.safehouseButton:setEnable(false)
		end
	end

	if EventTeleportManager.Shared.IsPlayerOnCooldown(self.player) then
		local remaining = EventTeleportManager.Shared.GetRemainingCooldown(self.player)
		self.cooldownWarning = ISLabel:new(
			CONST.LAYOUT.PADDING,
			currentY,
			CONST.LAYOUT.ELEMENT_HEIGHT,
			getText("IGUI_ETM_CooldownWarning", remaining),
			CONST.COLORS.TEXT.ERROR.r,
			CONST.COLORS.TEXT.ERROR.g,
			CONST.COLORS.TEXT.ERROR.b,
			CONST.COLORS.TEXT.ERROR.a,
			CONST.FONT.SMALL,
			true
		)
		self:addChild(self.cooldownWarning)
		currentY = self.cooldownWarning:getBottom() + CONST.LAYOUT.PADDING

		if self.originalPositionButton then
			self.originalPositionButton:setEnable(false)
		end
		if self.safehouseButton then
			self.safehouseButton:setEnable(false)
		end
	end

	self.closeButton = ISButton:new(
		self.width - CONST.LAYOUT.BUTTON.WIDTH - CONST.LAYOUT.PADDING,
		self.height - CONST.LAYOUT.BUTTON.HEIGHT - CONST.LAYOUT.PADDING,
		CONST.LAYOUT.BUTTON.WIDTH,
		CONST.LAYOUT.BUTTON.HEIGHT,
		getText("IGUI_ETM_Close"),
		self,
		self.onClose
	)
	self.closeButton:initialise()
	self.closeButton:instantiate()
	self.closeButton.borderColor = copyColor(CONST.COLORS.BORDER.NORMAL)
	self.closeButton.backgroundColor = copyColor(CONST.COLORS.BUTTON.CLOSE)
	self.closeButton.backgroundColorMouseOver = copyColor(CONST.COLORS.BUTTON.CLOSE_HOVER)
	self:addChild(self.closeButton)
end

function EventTeleportManager.UI_Manager.ReturnTeleportModal:onReturnToOriginalPosition()
	local isValid, messageKey, messageArgs = EventTeleportManager.Shared.ValidateReturnTeleport(self.player, "original")
	if not isValid then
		self.parent:showNotification(getText(messageKey, messageArgs), 3000)
		self:close()
		return
	end

	EventTeleportManager.Client.ReturnPlayer(self.username, false, "original")
	self.parent:showNotification(getText("IGUI_ETM_ReturningToOriginal"))
	self:close()
end

function EventTeleportManager.UI_Manager.ReturnTeleportModal:onReturnToSafehouse()
	if #self.safehouses == 1 then
		local safehouse = self.safehouses[1]

		local isValid, messageKey, messageArgs =
			EventTeleportManager.Shared.ValidateReturnTeleport(self.player, "safehouse", safehouse.id)

		if not isValid then
			self.parent:showNotification(getText(messageKey, messageArgs), 3000)
			self:close()
			return
		end

		EventTeleportManager.Client.ReturnPlayer(self.username, false, "safehouse", safehouse.id)
		self.parent:showNotification(getText("IGUI_ETM_ReturningToSafehouse", safehouse.title))
		self:close()
	else
		self:close()
		self.parent:showSafehouseSelectionModal(self.safehouses)
	end
end

function EventTeleportManager.UI_Manager.ReturnTeleportModal:onClose()
	self:close()
end

function EventTeleportManager.UI_Manager.ReturnTeleportModal:close()
	if self.parent and self.parent.returnTeleportModal == self then
		self.parent.returnTeleportModal = nil
	end
	self:setVisible(false)
	self:removeFromUIManager()
end

EventTeleportManager.UI_Manager.SafehouseSelectionModal =
	ISPanelJoypad:derive("EventTeleportManager_SafehouseSelectionModal")

function EventTeleportManager.UI_Manager.SafehouseSelectionModal:new(parent, x, y, width, height, safehouses)
	local o = ISPanelJoypad:new(x, y, width or 400, height or 400)
	setmetatable(o, self)
	self.__index = self

	o.parent = parent
	o.player = parent.player
	o.username = parent.username
	o.safehouses = safehouses or {}
	o.backgroundColor = copyColor(CONST.COLORS.BACKGROUND.NORMAL)
	o.borderColor = copyColor(CONST.COLORS.BORDER.NORMAL)
	o.moveWithMouse = true

	return o
end

function EventTeleportManager.UI_Manager.SafehouseSelectionModal:initialise()
	ISPanelJoypad.initialise(self)
end

function EventTeleportManager.UI_Manager.SafehouseSelectionModal:createChildren()
	self.titleLabel = ISLabel:new(
		CONST.LAYOUT.PADDING,
		CONST.LAYOUT.PADDING,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		getText("IGUI_ETM_ChooseSafehouse"),
		CONST.COLORS.TEXT.NORMAL.r,
		CONST.COLORS.TEXT.NORMAL.g,
		CONST.COLORS.TEXT.NORMAL.b,
		CONST.COLORS.TEXT.NORMAL.a,
		CONST.FONT.MEDIUM,
		true
	)
	self:addChild(self.titleLabel)

	local currentY = self.titleLabel:getBottom() + CONST.LAYOUT.PADDING

	self.descLabel = ISLabel:new(
		CONST.LAYOUT.PADDING,
		currentY,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		getText("IGUI_ETM_SafehouseSelectionDesc"),
		CONST.COLORS.TEXT.NORMAL.r,
		CONST.COLORS.TEXT.NORMAL.g,
		CONST.COLORS.TEXT.NORMAL.b,
		CONST.COLORS.TEXT.NORMAL.a,
		CONST.FONT.SMALL,
		true
	)
	self:addChild(self.descLabel)

	currentY = self.descLabel:getBottom() + CONST.LAYOUT.PADDING

	for i, safehouse in ipairs(self.safehouses) do
		local buttonText = safehouse.title
		if safehouse.isOwner then
			buttonText = buttonText .. " " .. getText("IGUI_ETM_SafehouseOwner")
		end

		local button = ISButton:new(
			CONST.LAYOUT.PADDING,
			currentY,
			self.width - CONST.LAYOUT.PADDING * 2,
			CONST.LAYOUT.BUTTON.HEIGHT * 2,
			buttonText,
			self,
			function()
				self:onSafehouseSelected(safehouse)
			end
		)
		button:initialise()
		button:instantiate()
		button.borderColor = copyColor(CONST.COLORS.BORDER.NORMAL)

		if safehouse.isOwner then
			button.backgroundColor = copyColor(CONST.COLORS.BUTTON.SELECTED)
		else
			button.backgroundColor = copyColor(CONST.COLORS.BUTTON.NORMAL)
		end
		button.backgroundColorMouseOver = copyColor(CONST.COLORS.BUTTON.HOVER)

		button:setTooltip(
			getText("IGUI_ETM_SafehouseLocationTooltip", math.floor(safehouse.x), math.floor(safehouse.y))
		)

		self:addChild(button)
		currentY = button:getBottom() + CONST.LAYOUT.SPACING.ITEM
	end

	self.closeButton = ISButton:new(
		self.width - CONST.LAYOUT.BUTTON.WIDTH - CONST.LAYOUT.PADDING,
		self.height - CONST.LAYOUT.BUTTON.HEIGHT - CONST.LAYOUT.PADDING,
		CONST.LAYOUT.BUTTON.WIDTH,
		CONST.LAYOUT.BUTTON.HEIGHT,
		getText("IGUI_ETM_Close"),
		self,
		self.onClose
	)
	self.closeButton:initialise()
	self.closeButton:instantiate()
	self.closeButton.borderColor = copyColor(CONST.COLORS.BORDER.NORMAL)
	self.closeButton.backgroundColor = copyColor(CONST.COLORS.BUTTON.CLOSE)
	self.closeButton.backgroundColorMouseOver = copyColor(CONST.COLORS.BUTTON.CLOSE_HOVER)
	self:addChild(self.closeButton)
end

function EventTeleportManager.UI_Manager.SafehouseSelectionModal:onSafehouseSelected(safehouse)
	local isValid, messageKey, messageArgs =
		EventTeleportManager.Shared.ValidateReturnTeleport(self.player, "safehouse", safehouse.id)
	if not isValid then
		self.parent:showNotification(getText(messageKey, messageArgs), 3000)
		self:close()
		return
	end

	EventTeleportManager.Client.ReturnPlayer(self.username, false, "safehouse", safehouse.id)
	self.parent:showNotification(getText("IGUI_ETM_ReturningToSafehouse", safehouse.title))
	self:close()
end

function EventTeleportManager.UI_Manager.SafehouseSelectionModal:onClose()
	self:close()
end

function EventTeleportManager.UI_Manager.SafehouseSelectionModal:close()
	if self.parent and self.parent.safehouseSelectionModal == self then
		self.parent.safehouseSelectionModal = nil
	end
	self:setVisible(false)
	self:removeFromUIManager()
end

function EventTeleportManager.UI_Manager:onReturn()
	if self.currentView ~= "player" then
		return
	end

	local hasOriginalPosition = EventTeleportManager.OriginalPositions
		and EventTeleportManager.OriginalPositions[self.username] ~= nil

	if not hasOriginalPosition then
		self:showNotification(getText("IGUI_ETM_NoSavedPosition"), 3000)
		return
	end

	local safehouses = EventTeleportManager.Shared.GetPlayerSafehouses(self.player)
	local hasSafehouses = #safehouses > 0
	local returnMode = EventTeleportManager.Shared.GetReturnTeleportMode()

	if returnMode == "original_only" then
		local isValid, messageKey, messageArgs =
			EventTeleportManager.Shared.ValidateReturnTeleport(self.player, "original")
		if isValid then
			EventTeleportManager.Client.ReturnPlayer(self.username, false, "original")
			self:showNotification(getText("IGUI_ETM_ReturningToOriginal"))
		else
			self:showNotification(getText(messageKey, messageArgs), 3000)
		end
	elseif returnMode == "safehouse_choice" then
		if hasSafehouses then
			if #safehouses == 1 then
				local safehouse = safehouses[1]
				local isValid, messageKey, messageArgs =
					EventTeleportManager.Shared.ValidateReturnTeleport(self.player, "safehouse", safehouse.id)
				if isValid then
					EventTeleportManager.Client.ReturnPlayer(self.username, false, "safehouse", safehouse.id)
					self:showNotification(getText("IGUI_ETM_ReturningToSafehouse", safehouse.title))
				else
					self:showNotification(getText(messageKey, messageArgs), 3000)
				end
			else
				self:showSafehouseSelectionModal(safehouses)
			end
		else
			self:showNotification(getText("IGUI_ETM_NoSafehouse"), 3000)
		end
	else -- player_choice
		if not hasSafehouses then
			local isValid, messageKey, messageArgs =
				EventTeleportManager.Shared.ValidateReturnTeleport(self.player, "original")
			if isValid then
				EventTeleportManager.Client.ReturnPlayer(self.username, false, "original")
				self:showNotification(getText("IGUI_ETM_ReturningToOriginal"))
			else
				self:showNotification(getText(messageKey, messageArgs), 3000)
			end
		else
			self:showReturnOptionsModal(hasOriginalPosition, safehouses)
		end
	end
end

function EventTeleportManager.UI_Manager:showReturnOptionsModal(hasOriginalPosition, safehouses)
	self.returnTeleportModal = EventTeleportManager.UI_Manager.ReturnTeleportModal:new(
		self,
		(getCore():getScreenWidth() / 2) - 200,
		(getCore():getScreenHeight() / 2) - 150,
		400,
		300,
		hasOriginalPosition,
		safehouses
	)
	self.returnTeleportModal:initialise()
	self.returnTeleportModal:addToUIManager()
	self.returnTeleportModal:bringToTop()
end

function EventTeleportManager.UI_Manager:showSafehouseSelectionModal(safehouses)
	self.safehouseSelectionModal = EventTeleportManager.UI_Manager.SafehouseSelectionModal:new(
		self,
		(getCore():getScreenWidth() / 2) - 200,
		(getCore():getScreenHeight() / 2) - 150,
		400,
		math.min(500, 200 + (#safehouses * 40)),
		safehouses
	)
	self.safehouseSelectionModal:initialise()
	self.safehouseSelectionModal:addToUIManager()
	self.safehouseSelectionModal:bringToTop()
end

return EventTeleportManager.UI_Manager
