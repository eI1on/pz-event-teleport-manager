local EventTeleportManager = require("EventTeleportManager/Shared")
local MenuDock = require("ElyonLib/UI/MenuDock/MenuDock")

MenuDock.registerButton({
	id = "event_teleport_manager",
	title = getText("IGUI_ETM_Title"),
	icon = "media/ui/ui_icon_event_teleport_manager.png",
	minimumAccessLevel = "None",
	allowSinglePlayer = true,
	onClick = function(playerNum, entry)
		EventTeleportManager.UI_Manager.toggle(playerNum)
	end,
})
