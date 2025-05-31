local FileUtils = require("ElyonLib/FileUtils/FileUtils")
local Logger = require("EventTeleportManager/Logger")
local EventTeleportManager = require("EventTeleportManager/Shared")

EventTeleportManager.Server = {}
EventTeleportManager.Server.ServerCommands = {}

local DATA_DIR = "EventTeleportManager"
local EVENTS_FILE = DATA_DIR .. "/events.json"
local POSITIONS_FILE = DATA_DIR .. "/positions.json"

--------------------------------------------------
-- UTILITY FUNCTIONS
--------------------------------------------------

local function navigateOrCreateTable(tbl, path)
	local current = tbl
	for key in string.gmatch(path or "", "([^%.]+)") do
		if not current[key] then
			current[key] = {}
		end
		current = current[key]
	end
	return current
end

local function formatEventInfo(event)
	local info = string.format(
		"[Name: %s] [ID: %s] [Status: %s]",
		event.name or "N/A",
		event.id or "N/A",
		event.lastStatus or "N/A"
	)

	if event.location then
		info = info
			.. string.format(
				" [Location: (%.1f, %.1f, %.1f)]",
				event.location.x or 0,
				event.location.y or 0,
				event.location.z or 0
			)
	end

	if event.players then
		info = info .. string.format(" [Players: %d]", #event.players)
	end

	return info
end

local function writeServerLog(logText)
	writeLog("admin", logText)
end

--------------------------------------------------
-- DATA MANAGEMENT
--------------------------------------------------

function EventTeleportManager.Server.SaveEvents(events)
	EventTeleportManager.Events = events
end

function EventTeleportManager.Server.SavePositions(positions)
	EventTeleportManager.OriginalPositions = positions
end

function EventTeleportManager.Server.LoadEvents()
	EventTeleportManager.Events = ModData.getOrCreate("EventTeleportManager_Events")
	return EventTeleportManager.Events
end

function EventTeleportManager.Server.LoadPositions()
	EventTeleportManager.OriginalPositions = ModData.getOrCreate("EventTeleportManager_OriginalPositions")
	return EventTeleportManager.OriginalPositions
end

--------------------------------------------------
-- PUSHING UPDATES TO CLIENTS
--------------------------------------------------

function EventTeleportManager.Server.PushEventsToAll(events)
	if isServer() then
		sendServerCommand("EventTeleportManager", "LoadEvents", events)
	else
		EventTeleportManager.Events = events
		EventTeleportManager.Client.Commands.LoadEvents(events)
	end
end

function EventTeleportManager.Server.PushEventsToPlayer(player, events)
	if isServer() then
		sendServerCommand(player, "EventTeleportManager", "LoadEvents", events)
	else
		EventTeleportManager.Events = events
		EventTeleportManager.Client.Commands.LoadEvents(events)
	end
end

function EventTeleportManager.Server.PushPositionsToAll(positions)
	if isServer() then
		sendServerCommand("EventTeleportManager", "LoadPositions", positions)
	else
		EventTeleportManager.OriginalPositions = positions
		EventTeleportManager.Client.Commands.LoadPositions(positions)
	end
end

function EventTeleportManager.Server.PushPositionsToPlayer(player, positions)
	if isServer() then
		sendServerCommand(player, "EventTeleportManager", "LoadPositions", positions)
	else
		EventTeleportManager.OriginalPositions = positions
		EventTeleportManager.Client.Commands.LoadPositions(positions)
	end
end

--------------------------------------------------
-- SERVER COMMAND HANDLERS
--------------------------------------------------

function EventTeleportManager.Server.ServerCommands.LoadEvents(player, args)
	local events = EventTeleportManager.Server.LoadEvents()
	if args and args.toAll then
		EventTeleportManager.Server.PushEventsToAll(events)
	else
		EventTeleportManager.Server.PushEventsToPlayer(player, events)
	end
end

function EventTeleportManager.Server.ServerCommands.LoadPositions(player, args)
	local positions = EventTeleportManager.Server.LoadPositions()
	if args and args.toAll then
		EventTeleportManager.Server.PushPositionsToAll(positions)
	else
		EventTeleportManager.Server.PushPositionsToPlayer(player, positions)
	end
end

function EventTeleportManager.Server.ServerCommands.AddEvent(player, args)
	local events = EventTeleportManager.Shared.RequestEvents()

	if not EventTeleportManager.Shared.HasPermission(player) then
		sendServerCommand(player, "EventTeleportManager", "CommandResponse", {
			success = false,
			messageKey = "IGUI_ETM_AccessDenied",
		})
		return
	end

	local newEvent = args.newEvent
	if not newEvent or not newEvent.name or newEvent.name == "" then
		sendServerCommand(player, "EventTeleportManager", "CommandResponse", {
			success = false,
			messageKey = "IGUI_ETM_EventNameEmpty",
		})
		return
	end

	if not newEvent.id then
		newEvent.id = EventTeleportManager.Shared.GenerateEventId()
	end

	newEvent.players = newEvent.players or {}
	newEvent.lastStatus = EventTeleportManager.Shared.GetEventStatus(newEvent)

	events[newEvent.id] = newEvent
	EventTeleportManager.Server.SaveEvents(events)
	EventTeleportManager.Server.PushEventsToAll(events)

	sendServerCommand(player, "EventTeleportManager", "CommandResponse", {
		success = true,
		messageKey = "IGUI_ETM_EventCreated",
		messageArgs = { eventName = newEvent.name },
		eventId = newEvent.id,
	})

	local logText = string.format(
		"[Admin: %s] [SteamID: %s] [Role: %s] Added Event: %s",
		tostring(player:getUsername() or "Unknown"),
		tostring(player:getSteamID() or "0"),
		tostring(player:getAccessLevel() or "None"),
		tostring(formatEventInfo(newEvent))
	)
	writeServerLog(logText)
end

function EventTeleportManager.Server.ServerCommands.RemoveEvent(player, args)
	local events = EventTeleportManager.Shared.RequestEvents()
	local positions = EventTeleportManager.Shared.RequestPositions()

	if not EventTeleportManager.Shared.HasPermission(player) then
		sendServerCommand(player, "EventTeleportManager", "CommandResponse", {
			success = false,
			messageKey = "IGUI_ETM_AccessDenied",
		})
		return
	end

	local eventId = args.eventId
	local event = events[eventId]

	if not event then
		sendServerCommand(player, "EventTeleportManager", "CommandResponse", {
			success = false,
			messageKey = "IGUI_ETM_EventNotFound",
		})
		return
	end

	local eventName = event.name
	events[eventId] = nil

	for username, posInfo in pairs(positions) do
		if posInfo.eventId == eventId then
			positions[username] = nil
		end
	end

	EventTeleportManager.Server.SaveEvents(events)
	EventTeleportManager.Server.SavePositions(positions)
	EventTeleportManager.Server.PushEventsToAll(events)
	EventTeleportManager.Server.PushPositionsToAll(positions)

	sendServerCommand(player, "EventTeleportManager", "CommandResponse", {
		success = true,
		messageKey = "IGUI_ETM_EventDeleted",
		messageArgs = { eventName = eventName },
	})

	local logText = string.format(
		"[Admin: %s] [SteamID: %s] [Role: %s] Removed Event: %s",
		tostring(player:getUsername() or "Unknown"),
		tostring(player:getSteamID() or "0"),
		tostring(player:getAccessLevel() or "None"),
		tostring(formatEventInfo(event))
	)
	writeServerLog(logText)
end

function EventTeleportManager.Server.ServerCommands.EditEventData(player, args)
	local events = EventTeleportManager.Shared.RequestEvents()

	if not EventTeleportManager.Shared.HasPermission(player) then
		sendServerCommand(player, "EventTeleportManager", "CommandResponse", {
			success = false,
			messageKey = "IGUI_ETM_AccessDenied",
		})
		return
	end

	local eventId = args.eventId
	local newKey = args.newKey
	local newValue = args.newValue

	local event = events[eventId]
	if not event then
		sendServerCommand(player, "EventTeleportManager", "CommandResponse", {
			success = false,
			messageKey = "IGUI_ETM_EventNotFound",
		})
		return
	end

	local parentTablePath, finalKey = string.match(newKey, "^(.*)%.([^%.]+)$")
	local modifying = parentTablePath and navigateOrCreateTable(event, parentTablePath) or event
	local modifyingKey = finalKey or newKey
	local oldValue = modifying[modifyingKey]

	if newValue == nil then
		if modifying[modifyingKey] ~= nil then
			modifying[modifyingKey] = nil
		end
	else
		modifying[modifyingKey] = tonumber(newValue) or newValue
	end

	if newKey == "startTime" or newKey == "endTime" then
		event.lastStatus = EventTeleportManager.Shared.GetEventStatus(event)
	end

	EventTeleportManager.Server.SaveEvents(events)
	EventTeleportManager.Server.PushEventsToAll(events)

	sendServerCommand(player, "EventTeleportManager", "CommandResponse", {
		success = true,
		messageKey = "IGUI_ETM_EventUpdated",
		messageArgs = { eventName = event.name },
	})
end

function EventTeleportManager.Server.ServerCommands.ModifyEventPlayers(player, args)
	local events = EventTeleportManager.Shared.RequestEvents()

	local eventId = args.eventId
	local action = args.action
	local username = args.username or player:getUsername()
	local usernames = args.usernames or { username }

	local event = events[eventId]
	if not event then
		sendServerCommand(player, "EventTeleportManager", "CommandResponse", {
			success = false,
			messageKey = "IGUI_ETM_EventNotFound",
		})
		return
	end

	if not event.players then
		event.players = {}
	end

	if action == "add" then
		if not EventTeleportManager.Shared.HasPermission(player) then
			sendServerCommand(player, "EventTeleportManager", "CommandResponse", {
				success = false,
				messageKey = "IGUI_ETM_AccessDenied",
			})
			return
		end

		local addedCount = 0
		for _, targetUsername in ipairs(usernames) do
			local isRegistered = EventTeleportManager.Shared.IsPlayerRegistered(targetUsername, eventId)
			if not isRegistered then
				table.insert(event.players, targetUsername)
				addedCount = addedCount + 1
			end
		end

		sendServerCommand(player, "EventTeleportManager", "CommandResponse", {
			success = true,
			messageKey = "IGUI_ETM_PlayersAdded",
			messageArgs = { count = addedCount },
		})
	elseif action == "remove" then
		if not EventTeleportManager.Shared.HasPermission(player) then
			sendServerCommand(player, "EventTeleportManager", "CommandResponse", {
				success = false,
				messageKey = "IGUI_ETM_AccessDenied",
			})
			return
		end

		local removedCount = 0
		for _, targetUsername in ipairs(usernames) do
			for i = #event.players, 1, -1 do
				if event.players[i] == targetUsername then
					table.remove(event.players, i)
					removedCount = removedCount + 1
					break
				end
			end
		end

		sendServerCommand(player, "EventTeleportManager", "CommandResponse", {
			success = true,
			messageKey = "IGUI_ETM_PlayersRemoved",
			messageArgs = { count = removedCount },
		})
	elseif action == "register" then
		if not EventTeleportManager.Shared.CanPlayerSelfRegister(player) then
			sendServerCommand(player, "EventTeleportManager", "CommandResponse", {
				success = false,
				messageKey = "IGUI_ETM_SelfRegistrationDisabled",
			})
			return
		end

		local isRegistered = EventTeleportManager.Shared.IsPlayerRegistered(username, eventId)
		if isRegistered then
			sendServerCommand(player, "EventTeleportManager", "CommandResponse", {
				success = false,
				messageKey = "IGUI_ETM_AlreadyRegistered",
			})
			return
		end

		table.insert(event.players, username)
		sendServerCommand(player, "EventTeleportManager", "CommandResponse", {
			success = true,
			messageKey = "IGUI_ETM_RegistrationSuccess",
			messageArgs = { eventName = event.name },
		})
	elseif action == "unregister" then
		if not EventTeleportManager.Shared.CanPlayerSelfRegister(player) then
			sendServerCommand(player, "EventTeleportManager", "CommandResponse", {
				success = false,
				messageKey = "IGUI_ETM_SelfRegistrationDisabled",
			})
			return
		end

		local isRegistered = EventTeleportManager.Shared.IsPlayerRegistered(username, eventId)
		if not isRegistered then
			sendServerCommand(player, "EventTeleportManager", "CommandResponse", {
				success = false,
				messageKey = "IGUI_ETM_UnregistrationFailed",
			})
			return
		end

		for i = 1, #event.players do
			if event.players[i] == username then
				table.remove(event.players, i)
				break
			end
		end

		sendServerCommand(player, "EventTeleportManager", "CommandResponse", {
			success = true,
			messageKey = "IGUI_ETM_UnregistrationSuccess",
			messageArgs = { eventName = event.name },
		})
	end

	EventTeleportManager.Server.SaveEvents(events)
	EventTeleportManager.Server.PushEventsToAll(events)
end

function EventTeleportManager.Server.ServerCommands.TeleportPlayer(player, args)
	local events = EventTeleportManager.Shared.RequestEvents()
	local positions = EventTeleportManager.Shared.RequestPositions()

	local eventId = args.eventId
	local targetUsername = args.username or player:getUsername()
	local byAdmin = args.byAdmin or false

	if byAdmin and targetUsername ~= player:getUsername() and not EventTeleportManager.Shared.HasPermission(player) then
		sendServerCommand(player, "EventTeleportManager", "CommandResponse", {
			success = false,
			messageKey = "IGUI_ETM_AccessDenied",
		})
		return
	end

	local event = events[eventId]
	if not event then
		sendServerCommand(player, "EventTeleportManager", "CommandResponse", {
			success = false,
			messageKey = "IGUI_ETM_EventNotFound",
		})
		return
	end

	if not byAdmin then
		if not EventTeleportManager.Shared.IsPlayerRegistered(targetUsername, eventId) then
			sendServerCommand(player, "EventTeleportManager", "CommandResponse", {
				success = false,
				messageKey = "IGUI_ETM_TeleportFailed",
			})
			return
		end

		local status = EventTeleportManager.Shared.GetEventStatus(event)
		if status ~= EventTeleportManager.EVENT_STATUS.ACTIVE then
			local messageKey = status == EventTeleportManager.EVENT_STATUS.FUTURE and "IGUI_ETM_EventWindowNotOpen"
				or "IGUI_ETM_EventWindowClosed"
			sendServerCommand(player, "EventTeleportManager", "CommandResponse", {
				success = false,
				messageKey = messageKey,
			})
			return
		end
	end

	local targetPlayer = EventTeleportManager.Server.GetPlayerByUsername(targetUsername)
	if not targetPlayer then
		sendServerCommand(player, "EventTeleportManager", "CommandResponse", {
			success = false,
			messageKey = "IGUI_ETM_PlayerNotFound",
		})
		return
	end

	local teleportData = {
		eventId = eventId,
		eventName = event.name,
		location = event.location,
		savePosition = not positions[targetUsername],
	}

	sendServerCommand(targetPlayer, "EventTeleportManager", "ClientTeleportToEvent", teleportData)

	sendServerCommand(player, "EventTeleportManager", "CommandResponse", {
		success = true,
		messageKey = "IGUI_ETM_TeleportSuccess",
		messageArgs = { eventName = event.name },
	})

	if byAdmin and targetUsername ~= player:getUsername() then
		sendServerCommand(targetPlayer, "EventTeleportManager", "CommandResponse", {
			success = true,
			messageKey = "IGUI_ETM_TeleportSuccess",
			messageArgs = { eventName = event.name },
		})
	end
end

function EventTeleportManager.Server.ServerCommands.ReturnPlayer(player, args)
	local positions = EventTeleportManager.Shared.RequestPositions()
	local targetUsername = args.username or player:getUsername()
	local byAdmin = args.byAdmin or false
	local returnType = args.returnType or "original"
	local safehouseId = args.safehouseId

	if byAdmin and targetUsername ~= player:getUsername() and not EventTeleportManager.Shared.HasPermission(player) then
		sendServerCommand(player, "EventTeleportManager", "CommandResponse", {
			success = false,
			messageKey = "IGUI_ETM_AccessDenied",
		})
		return
	end

	local targetPlayer = EventTeleportManager.Server.GetPlayerByUsername(targetUsername)
	if not targetPlayer then
		sendServerCommand(player, "EventTeleportManager", "CommandResponse", {
			success = false,
			messageKey = "IGUI_ETM_PlayerNotFound",
		})
		return
	end

	local posInfo = positions[targetUsername]
	if not posInfo then
		sendServerCommand(player, "EventTeleportManager", "CommandResponse", {
			success = false,
			messageKey = "IGUI_ETM_NoSavedPosition",
		})
		return
	end

	if not byAdmin then
		local isValid, messageKey, messageArgs =
			EventTeleportManager.Shared.ValidateReturnTeleport(targetPlayer, returnType, safehouseId)
		if not isValid then
			sendServerCommand(player, "EventTeleportManager", "CommandResponse", {
				success = false,
				messageKey = messageKey,
				messageArgs = messageArgs,
			})
			return
		end
	end

	local returnData = {
		returnType = returnType,
	}

	if returnType == "safehouse" then
		local safehouse

		if safehouseId then
			local safehouses = EventTeleportManager.Shared.GetPlayerSafehouses(targetPlayer)
			for _, sh in ipairs(safehouses) do
				if sh.id == safehouseId then
					safehouse = sh
					break
				end
			end
		else
			safehouse = EventTeleportManager.Shared.GetPlayerSafehouse(targetPlayer)
		end

		if not safehouse then
			sendServerCommand(player, "EventTeleportManager", "CommandResponse", {
				success = false,
				messageKey = "IGUI_ETM_NoSafehouse",
			})
			return
		end

		returnData.position = {
			x = safehouse.x,
			y = safehouse.y,
			z = safehouse.z,
		}
		returnData.safehouseName = safehouse.title
	else -- "original"
		returnData.position = {
			x = posInfo.x,
			y = posInfo.y,
			z = posInfo.z,
		}
		returnData.eventId = posInfo.eventId
	end

	positions[targetUsername] = nil
	EventTeleportManager.Server.SavePositions(positions)
	EventTeleportManager.Server.PushPositionsToAll(positions)

	sendServerCommand(targetPlayer, "EventTeleportManager", "ClientReturnToPosition", returnData)

	local messageKey = returnType == "safehouse" and "IGUI_ETM_ReturnToSafehouseSuccess" or "IGUI_ETM_ReturnSuccess"
	sendServerCommand(player, "EventTeleportManager", "CommandResponse", {
		success = true,
		messageKey = messageKey,
	})

	if byAdmin and targetUsername ~= player:getUsername() then
		sendServerCommand(targetPlayer, "EventTeleportManager", "CommandResponse", {
			success = true,
			messageKey = messageKey,
		})
	end
end

function EventTeleportManager.Server.ServerCommands.SavePlayerPosition(player, args)
	local positions = EventTeleportManager.Shared.RequestPositions()
	local username = player:getUsername()

	if EventTeleportManager.Shared.ShouldProtectPosition(player, args.eventId) then
		return
	end

	positions[username] = {
		x = args.x,
		y = args.y,
		z = args.z,
		eventId = args.eventId,
		timestamp = args.timestamp or getTimestampMs(),
	}

	EventTeleportManager.Server.SavePositions(positions)
	EventTeleportManager.Server.PushPositionsToAll(positions)
end

--------------------------------------------------
-- UTILITY FUNCTIONS
--------------------------------------------------

function EventTeleportManager.Server.GetPlayerByUsername(username)
	local players = getOnlinePlayers()
	if not players then
		return nil
	end
	for i = 0, players:size() - 1 do
		local player = players:get(i)
		if player and player:getUsername() == username then
			return player
		end
	end
	return nil
end

function EventTeleportManager.Server.checkEvents()
	local events = EventTeleportManager.Shared.RequestEvents()
	for eventId, event in pairs(events) do
		local status = EventTeleportManager.Shared.GetEventStatus(event)
		if event.lastStatus ~= status then
			event.lastStatus = status
			if status == EventTeleportManager.EVENT_STATUS.ACTIVE then
				EventTeleportManager.Server.NotifyEvent(eventId, "started")
			elseif status == EventTeleportManager.EVENT_STATUS.ENDED then
				EventTeleportManager.Server.NotifyEvent(eventId, "ended")
			end
		end
	end
	EventTeleportManager.Server.SaveEvents(events)
end

function EventTeleportManager.Server.NotifyEvent(eventId, status)
	local events = EventTeleportManager.Shared.RequestEvents()
	local event = events[eventId]
	if not event then
		return
	end

	local args = {
		eventId = eventId,
		status = status,
		eventName = event.name,
	}

	-- notify registered players
	for i = 1, #event.players do
		local player = EventTeleportManager.Server.GetPlayerByUsername(event.players[i])
		if player then
			sendServerCommand(player, "EventTeleportManager", "EventNotification", args)
		end
	end

	-- notify admins
	local players = getOnlinePlayers()
	if players then
		for i = 0, players:size() - 1 do
			local player = players:get(i)
			if player and EventTeleportManager.Shared.HasPermission(player) then
				sendServerCommand(player, "EventTeleportManager", "EventNotification", args)
			end
		end
	end
end

--------------------------------------------------
-- INITIALIZATION
--------------------------------------------------

function EventTeleportManager.Server.init()
	local events = EventTeleportManager.Server.LoadEvents()
	local positions = EventTeleportManager.Server.LoadPositions()
end

function EventTeleportManager.Server.onClientCommand(module, command, player, args)
	if module ~= "EventTeleportManager" then
		return
	end

	if EventTeleportManager.Server.ServerCommands[command] then
		EventTeleportManager.Server.ServerCommands[command](player, args)
	end
end

if isServer() then
	Events.EveryOneMinute.Remove(EventTeleportManager.Server.checkEvents)
	Events.EveryOneMinute.Add(EventTeleportManager.Server.checkEvents)
end

Events.OnInitGlobalModData.Remove(EventTeleportManager.Server.init)
Events.OnInitGlobalModData.Add(EventTeleportManager.Server.init)

Events.OnClientCommand.Remove(EventTeleportManager.Server.onClientCommand)
Events.OnClientCommand.Add(EventTeleportManager.Server.onClientCommand)

return EventTeleportManager.Server
