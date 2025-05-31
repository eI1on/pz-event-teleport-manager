local EventTeleportManager = require("EventTeleportManager/Shared")

EventTeleportManager.Client = {}
EventTeleportManager.Client.Commands = {}

function EventTeleportManager.Client.ShowNotification(message)
	if
		EventTeleportManager.UI_Manager
		and EventTeleportManager.UI_Manager.instance
		and EventTeleportManager.UI_Manager.instance:isVisible()
	then
		EventTeleportManager.UI_Manager.instance:showNotification(message)
	end
end

function EventTeleportManager.Client.Commands.LoadEvents(args)
	if type(args) ~= "table" then
		args = {}
	end

	EventTeleportManager.Events = args

	if EventTeleportManager.UI_Manager.instance and EventTeleportManager.UI_Manager.instance:isVisible() then
		EventTeleportManager.UI_Manager.instance:updateEventList()
	end
end

function EventTeleportManager.Client.Commands.LoadPositions(args)
	if type(args) ~= "table" then
		args = {}
	end

	EventTeleportManager.OriginalPositions = args
end

function EventTeleportManager.Client.Commands.EventNotification(args)
	if not args or not args.eventId or not args.status or not args.eventName then
		return
	end

	local message = ""

	if args.status == "started" then
		message = "Event has started: " .. args.eventName
	elseif args.status == "ended" then
		message = "Event has ended: " .. args.eventName
	end

	if message ~= "" then
		EventTeleportManager.Client.ShowNotification(message)
	end

	if
		EventTeleportManager.UI_Manager
		and EventTeleportManager.UI_Manager.instance
		and EventTeleportManager.UI_Manager.instance:isVisible()
	then
		EventTeleportManager.UI_Manager.instance:updateEventList()
	end
end

function EventTeleportManager.Client.Commands.CommandResponse(args)
	if not args then
		return
	end

	if args.messageKey then
		local message = ""

		if args.messageArgs then
			if
				args.messageKey == "IGUI_ETM_EventCreated"
				or args.messageKey == "IGUI_ETM_EventUpdated"
				or args.messageKey == "IGUI_ETM_EventDeleted"
			then
				message = getText(args.messageKey, args.messageArgs.eventName)
			elseif
				args.messageKey == "IGUI_ETM_RegistrationSuccess"
				or args.messageKey == "IGUI_ETM_UnregistrationSuccess"
				or args.messageKey == "IGUI_ETM_TeleportSuccess"
			then
				message = getText(args.messageKey, args.messageArgs.eventName)
			elseif
				args.messageKey == "IGUI_ETM_PlayersAdded"
				or args.messageKey == "IGUI_ETM_PlayersRemoved"
				or args.messageKey == "IGUI_ETM_TeleportPlayersSuccess"
				or args.messageKey == "IGUI_ETM_ReturnPlayersSuccess"
			then
				message = getText(args.messageKey, args.messageArgs.count)
			elseif
				args.messageKey == "IGUI_ETM_InvalidAction" or args.messageKey == "IGUI_ETM_InvalidTeleportAction"
			then
				message = getText(args.messageKey, args.messageArgs.action)
			else
				message = getText(args.messageKey)
			end
		else
			message = getText(args.messageKey)
		end

		EventTeleportManager.Client.ShowNotification(message)
	end
	if
		EventTeleportManager.UI_Manager
		and EventTeleportManager.UI_Manager.instance
		and EventTeleportManager.UI_Manager.instance:isVisible()
	then
		EventTeleportManager.UI_Manager.instance:updateEventList()
	end
end

function EventTeleportManager.Client.OnServerCommand(module, command, args)
	if module ~= "EventTeleportManager" then
		return
	end

	if EventTeleportManager.Client.Commands[command] then
		EventTeleportManager.Client.Commands[command](args)
	end
end

Events.OnServerCommand.Add(EventTeleportManager.Client.OnServerCommand)

function EventTeleportManager.Client.EditEventData(eventId, key, value)
	sendClientCommand("EventTeleportManager", "EditEventData", {
		eventId = eventId,
		newKey = key,
		newValue = value,
	})
end

function EventTeleportManager.Client.AddEvent(eventData)
	sendClientCommand("EventTeleportManager", "AddEvent", {
		newEvent = eventData,
	})
end

function EventTeleportManager.Client.RemoveEvent(eventId)
	sendClientCommand("EventTeleportManager", "RemoveEvent", {
		eventId = eventId,
	})
end

function EventTeleportManager.Client.ModifyEventPlayers(eventId, action, usernames)
	sendClientCommand("EventTeleportManager", "ModifyEventPlayers", {
		eventId = eventId,
		action = action,
		usernames = usernames,
	})
end

function EventTeleportManager.Client.TeleportPlayer(eventId, username, byAdmin)
	sendClientCommand("EventTeleportManager", "TeleportPlayer", {
		eventId = eventId,
		username = username,
		byAdmin = byAdmin or false,
	})
end

function EventTeleportManager.Client.ReturnPlayer(username, byAdmin, returnType, safehouseId)
	sendClientCommand("EventTeleportManager", "ReturnPlayer", {
		username = username,
		byAdmin = byAdmin or false,
		returnType = returnType or "original",
		safehouseId = safehouseId, -- will be nil for non-safehouse returns
	})
end

function EventTeleportManager.Client.Commands.ClientTeleportToEvent(args)
	if not args or not args.location then
		return
	end

	local player = getPlayer()
	if not player then
		return
	end

	if args.savePosition then
		if not EventTeleportManager.Shared.ShouldProtectPosition(player, args.eventId) then
			local currentPos = {
				x = player:getX(),
				y = player:getY(),
				z = player:getZ(),
				eventId = args.eventId,
				timestamp = getTimestampMs(),
			}

			sendClientCommand("EventTeleportManager", "SavePlayerPosition", currentPos)
		end
	end

	player:setX(args.location.x)
	player:setY(args.location.y)
	player:setZ(args.location.z)
	player:setLx(args.location.x)
	player:setLy(args.location.y)
	player:setLz(args.location.z)

	if args.eventName then
		EventTeleportManager.Client.ShowNotification(getText("IGUI_ETM_TeleportedToEvent", args.eventName))
	end
end

function EventTeleportManager.Client.Commands.ClientReturnToPosition(args)
	if not args or not args.position then
		return
	end

	local player = getPlayer()
	if not player then
		return
	end

	local returnType = args.returnType or "original"
	local destination = args.position

	player:setX(destination.x)
	player:setY(destination.y)
	player:setZ(destination.z)
	player:setLx(destination.x)
	player:setLy(destination.y)
	player:setLz(destination.z)

	EventTeleportManager.Shared.RecordPlayerTeleport(player)

	if returnType == "safehouse" then
		local safehouseName = args.safehouseName or "safehouse"
		EventTeleportManager.Client.ShowNotification(getText("IGUI_ETM_ReturnedToSafehouse", safehouseName))
	else
		EventTeleportManager.Client.ShowNotification(getText("IGUI_ETM_ReturnedToOriginal"))
	end
end

local doCommand = false
local function sendCommand()
	if doCommand then
		EventTeleportManager.Events = EventTeleportManager.Shared.RequestEvents()
		EventTeleportManager.OriginalPositions = EventTeleportManager.Shared.RequestPositions()
		Events.OnTick.Remove(sendCommand)
	end
	doCommand = true
end
Events.OnTick.Add(sendCommand)

return EventTeleportManager.Client
