local EventTeleportManager = require("EventTeleportManager/Shared")

local ISDebugMenu_setupButtons = ISDebugMenu.setupButtons
---@diagnostic disable-next-line: duplicate-set-field
function ISDebugMenu:setupButtons()
	self:addButtonInfo(getText("IGUI_ETM_Title"), function()
		EventTeleportManager.UI_Manager.toggle(getPlayer():getPlayerNum())
	end, "MAIN")
	ISDebugMenu_setupButtons(self)
end

local ISAdminPanelUI_create = ISAdminPanelUI.create
---@diagnostic disable-next-line: duplicate-set-field
function ISAdminPanelUI:create()
	ISAdminPanelUI_create(self)
	local fontHeight = getTextManager():getFontHeight(UIFont.Small)
	local btnWid = 150
	local btnHgt = math.max(25, fontHeight + 3 * 2)
	local btnGapY = 5

	local lastButton = self.children[self.IDMax - 1]
	lastButton = lastButton.internal == "CANCEL" and self.children[self.IDMax - 2] or lastButton

	self.showEventTeleportManager = ISButton:new(
		lastButton.x,
		lastButton.y + btnHgt + btnGapY,
		btnWid,
		btnHgt,
		getText("IGUI_ETM_Title"),
		self,
		function()
			EventTeleportManager.UI_Manager.toggle(getPlayer():getPlayerNum())
		end
	)
	self.showEventTeleportManager.internal = ""
	self.showEventTeleportManager:initialise()
	self.showEventTeleportManager:instantiate()
	self.showEventTeleportManager.borderColor = self.buttonBorderColor
	self:addChild(self.showEventTeleportManager)
end

local ISUserPanelUI_create = ISUserPanelUI.create
---@diagnostic disable-next-line: duplicate-set-field
function ISUserPanelUI:create()
	ISUserPanelUI_create(self)
	local fontHeight = getTextManager():getFontHeight(UIFont.Small)
	local btnWid = 150
	local btnHgt = math.max(25, fontHeight + 3 * 2)
	local btnGapY = 5

	self.showEventTeleportManager = ISButton:new(
		self.serverOptionBtn.x,
		self.serverOptionBtn.y + btnHgt + btnGapY,
		btnWid,
		btnHgt,
		getText("IGUI_ETM_Title"),
		self,
		function()
			EventTeleportManager.UI_Manager.toggle(getPlayer():getPlayerNum())
		end
	)
	self.showEventTeleportManager.internal = ""
	self.showEventTeleportManager:initialise()
	self.showEventTeleportManager:instantiate()
	self.showEventTeleportManager.borderColor = self.buttonBorderColor
	self:addChild(self.showEventTeleportManager)
end
