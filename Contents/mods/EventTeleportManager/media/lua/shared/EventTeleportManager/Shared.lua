local Logger = require("EventTeleportManager/Logger")
local DateTimeUtility = require("ElyonLib/DateTime/DateTimeUtility")

local EventTeleportManager = {}
EventTeleportManager.VERSION = "1.0.0"
EventTeleportManager.Events = {}
EventTeleportManager.OriginalPositions = {}
EventTeleportManager.Shared = {}
EventTeleportManager.PlayerTeleportHistory = {}

local DEBUG_MODE = true
function EventTeleportManager.Shared.debugLog(message, category)
	if not DEBUG_MODE then
		return
	end

	local player = getPlayer() and getPlayer():getUsername() or "Unknown"
	local prefix = string.format("[%s][%s]", category or "DEBUG", player)

	Logger:debug(prefix .. " " .. message)
end

EventTeleportManager.CONST = {
	EVENT_CHECK_INTERVAL = 60, -- every minute
	DEFAULT_DISPLAY_COOLDOWN = 1000, -- milliseconds
	DATE_FORMAT = "%H:%M %Y-%m-%d",
}

EventTeleportManager.EVENT_STATUS = {
	FUTURE = 1,
	ACTIVE = 2,
	ENDED = 3,
}

EventTeleportManager.ACCESS_LEVEL = {
	None = 1,
	Observer = 2,
	GM = 3,
	Overseer = 4,
	Moderator = 5,
	Admin = 6,
}

function EventTeleportManager.Shared.RequestEvents()
	if isClient() then
		sendClientCommand("EventTeleportManager", "LoadEvents", { toAll = false })
		return EventTeleportManager.Events
	else
		local events = EventTeleportManager.Server.LoadEvents()
		return events
	end
end

function EventTeleportManager.Shared.RequestPositions()
	if isClient() then
		sendClientCommand("EventTeleportManager", "LoadPositions", { toAll = false })
		return EventTeleportManager.OriginalPositions
	else
		local positions = EventTeleportManager.Server.LoadPositions()
		return positions
	end
end

function EventTeleportManager.Shared.CanPlayerSelfRegister(player)
	local allowPlayerRegistration = SandboxVars.EventTeleportManager.AllowPlayerRegistration
	if allowPlayerRegistration == nil then
		allowPlayerRegistration = true
	end

	if not allowPlayerRegistration then
		return EventTeleportManager.Shared.HasPermission(player)
	end

	return true
end

function EventTeleportManager.Shared.GetRegistrationMode()
	local allowPlayerRegistration = SandboxVars.EventTeleportManager.AllowPlayerRegistration
	if allowPlayerRegistration == nil then
		allowPlayerRegistration = false
	end

	return allowPlayerRegistration and "player" or "admin_only"
end

function EventTeleportManager.Shared.HasPermission(player)
	if not player then
		return false
	end

	if not isClient() and not isServer() then
		return true
	end

	local requiredPermission = SandboxVars.EventTeleportManager.EventAdminAccess
		or EventTeleportManager.ACCESS_LEVEL.Admin

	local playerAccessLevel = player:getAccessLevel()
	local playerPermissionValue = EventTeleportManager.ACCESS_LEVEL[playerAccessLevel]
		or EventTeleportManager.ACCESS_LEVEL.None

	return playerPermissionValue >= requiredPermission
end

function EventTeleportManager.Shared.CanManageEvents(player)
	return EventTeleportManager.Shared.HasPermission(player)
end

function EventTeleportManager.Shared.GetEventStatus(event)
	if not event then
		return EventTeleportManager.EVENT_STATUS.ENDED
	end

	local currentTimeUTC = DateTimeUtility.getCurrentUTCDate()

	if event.startTime then
		local eventStartTimeUTC = DateTimeUtility.fromTimestamp(event.startTime, false)

		if eventStartTimeUTC and DateTimeUtility.isDateBefore(currentTimeUTC, eventStartTimeUTC) then
			return EventTeleportManager.EVENT_STATUS.FUTURE
		end
	end

	if event.endTime then
		local eventEndTimeUTC = DateTimeUtility.fromTimestamp(event.endTime, false)

		if eventEndTimeUTC and DateTimeUtility.isDateAfter(currentTimeUTC, eventEndTimeUTC) then
			return EventTeleportManager.EVENT_STATUS.ENDED
		end
	end

	return EventTeleportManager.EVENT_STATUS.ACTIVE
end

function EventTeleportManager.Shared.GetEventStatusFast(event)
	if not event then
		return EventTeleportManager.EVENT_STATUS.ENDED
	end

	local currentTimestamp = DateTimeUtility.toTimestamp(DateTimeUtility.getCurrentUTCDate())

	if event.startTime and DateTimeUtility.isTimestampBefore(currentTimestamp, event.startTime) then
		return EventTeleportManager.EVENT_STATUS.FUTURE
	end

	if event.endTime and DateTimeUtility.isTimestampAfter(currentTimestamp, event.endTime) then
		return EventTeleportManager.EVENT_STATUS.ENDED
	end

	return EventTeleportManager.EVENT_STATUS.ACTIVE
end

function EventTeleportManager.Shared.GetEventStatusText(status)
	if status == EventTeleportManager.EVENT_STATUS.FUTURE then
		return getText("IGUI_ETM_Status_Future")
	elseif status == EventTeleportManager.EVENT_STATUS.ACTIVE then
		return getText("IGUI_ETM_Status_Active")
	else
		return getText("IGUI_ETM_Status_Ended")
	end
end

function EventTeleportManager.Shared.IsPlayerRegistered(username, eventId)
	if not EventTeleportManager.Events[eventId] then
		return false
	end

	for i = 1, #EventTeleportManager.Events[eventId].players do
		if EventTeleportManager.Events[eventId].players[i] == username then
			return true
		end
	end

	return false
end

local rand = newrandom()
local chars = "0123456789aAbBcCdDeEfFgGhHiIjJkKlLmMnNoOpPqQrRsStTuUvVwWxXyYzZ"

-- Generate a short UUID-like ID (6 characters)
---@param prefix string|nil Optional prefix for the ID
---@return string id The generated ID
function EventTeleportManager.Shared.GenerateEventId(prefix)
	prefix = prefix or "event_"
	local idStr = ""

	for _ = 1, 6 do
		local index = math.floor(rand:random(#chars)) + 1
		idStr = idStr .. chars:sub(index, index)
	end

	return prefix .. idStr
end

function EventTeleportManager.Shared.GetEventById(eventId)
	return EventTeleportManager.Events[eventId]
end

function EventTeleportManager.Shared.GetEventIndex(eventId)
	local index = 1
	for id, _ in pairs(EventTeleportManager.Events) do
		if id == eventId then
			return index
		end
		index = index + 1
	end
	return nil
end

function EventTeleportManager.Shared.GetPlayerSafehouse(player)
	local safehouses = EventTeleportManager.Shared.GetPlayerSafehouses(player)
	return safehouses[1] -- first/primary safehouse
end

---@param player IsoPlayer
---@return boolean
function EventTeleportManager.Shared.HasZombiesThreat(player)
	if not player then
		return false
	end

	local enableZombieCheck = SandboxVars.EventTeleportManager.ZombieCheck
	if not enableZombieCheck then
		return false
	end

	local threshold = SandboxVars.EventTeleportManager.ZombieThreshold or 5
	local stats = player:getStats()

	local visibleZombies = stats:getNumVisibleZombies()
	local chasingZombies = stats:getNumChasingZombies()
	local closeZombies = stats:getNumVeryCloseZombies()

	-- if any zombies are chasing or very close, always block
	if chasingZombies > 0 or closeZombies > 0 then
		return true
	end

	-- check if visible zombies exceed threshold
	return visibleZombies > threshold
end

function EventTeleportManager.Shared.IsPlayerOnCooldown(player)
	if not player then
		return false
	end

	local username = player:getUsername()
	local cooldownSetting = SandboxVars.EventTeleportManager.TeleportCooldown or 300

	if cooldownSetting <= 0 then
		return false
	end

	local lastTeleport = EventTeleportManager.PlayerTeleportHistory[username]
	if not lastTeleport then
		return false
	end

	local currentTime = getTimestampMs()
	local timeSinceLastTeleport = currentTime - lastTeleport

	return timeSinceLastTeleport < (cooldownSetting * 1000)
end

function EventTeleportManager.Shared.RecordPlayerTeleport(player)
	if not player then
		return
	end

	local username = player:getUsername()
	EventTeleportManager.PlayerTeleportHistory[username] = getTimestampMs()
end

function EventTeleportManager.Shared.GetRemainingCooldown(player)
	if not player then
		return 0
	end

	local username = player:getUsername()
	local cooldownSetting = SandboxVars.EventTeleportManager.TeleportCooldown or 300
	local lastTeleport = EventTeleportManager.PlayerTeleportHistory[username]

	if not lastTeleport or cooldownSetting <= 0 then
		return 0
	end

	local currentTime = getTimestampMs()
	local timeSinceLastTeleport = currentTime - lastTeleport
	local remainingMs = (cooldownSetting * 1000) - timeSinceLastTeleport

	return math.max(0, math.ceil(remainingMs / 1000))
end

function EventTeleportManager.Shared.ShouldProtectPosition(player, eventId)
	if not player then
		return false
	end

	local enableProtection = SandboxVars.EventTeleportManager.TeleportPositionProtection
	if not enableProtection then
		return false
	end

	local username = player:getUsername()
	local currentPos = { x = player:getX(), y = player:getY(), z = player:getZ() }

	local existingPos = EventTeleportManager.OriginalPositions[username]
	if existingPos then
		local timeSinceSaved = getTimestampMs() - (existingPos.timestamp or 0)

		if timeSinceSaved < 30000 then
			if EventTeleportManager.Shared.IsNearEventLocation(currentPos) then
				return true
			end
		end

		local distance = EventTeleportManager.Shared.CalculateDistance(currentPos, existingPos)
		if distance < 50 then
			return true
		end
	end

	return false
end
function EventTeleportManager.Shared.IsNearEventLocation(position, threshold)
	threshold = threshold or 100

	if not EventTeleportManager.Events then
		return false
	end

	for eventId, event in pairs(EventTeleportManager.Events) do
		if event.location then
			local distance = EventTeleportManager.Shared.CalculateDistance(position, event.location)
			if distance < threshold then
				return true, eventId, distance
			end
		end
	end

	return false
end

function EventTeleportManager.Shared.CalculateDistance(pos1, pos2)
	if not pos1 or not pos2 then
		return math.huge
	end

	local dx = pos1.x - pos2.x
	local dy = pos1.y - pos2.y
	local dz = (pos1.z or 0) - (pos2.z or 0)

	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function EventTeleportManager.Shared.GetPlayerActiveEvents(username)
	local activeEvents = {}

	if not EventTeleportManager.Events then
		return activeEvents
	end

	for eventId, event in pairs(EventTeleportManager.Events) do
		local status = EventTeleportManager.Shared.GetEventStatus(event)
		if status == EventTeleportManager.EVENT_STATUS.ACTIVE then
			if EventTeleportManager.Shared.IsPlayerRegistered(username, eventId) then
				table.insert(activeEvents, {
					id = eventId,
					name = event.name,
					event = event,
				})
			end
		end
	end

	return activeEvents
end

function EventTeleportManager.Shared.GetReturnTeleportMode()
	local mode = SandboxVars.EventTeleportManager.TeleportReturnMode or 3

	if mode == 1 then
		return "original_only"
	elseif mode == 2 then
		return "safehouse_choice"
	else -- mode == 3
		return "player_choice"
	end
end

function EventTeleportManager.Shared.GetPlayerSafehouses(player)
	if not player then
		return {}
	end

	local safehouses = {}
	local allSafehouses = SafeHouse.getSafehouseList()

	for i = 0, allSafehouses:size() - 1 do
		local safehouse = allSafehouses:get(i)

		if safehouse:isOwner(player) or safehouse:playerAllowed(player) then
			local safehouseData = {
				x = safehouse:getX() + safehouse:getW() / 2,
				y = safehouse:getY() + safehouse:getH() / 2,
				z = 0,
				title = safehouse:getTitle() or ("Safehouse " .. (i + 1)),
				isOwner = safehouse:isOwner(player),
				id = tostring(safehouse:getX()) .. "_" .. tostring(safehouse:getY()),
			}
			table.insert(safehouses, safehouseData)
		end
	end

	table.sort(safehouses, function(a, b)
		if a.isOwner ~= b.isOwner then
			return a.isOwner
		end
		return a.title < b.title
	end)

	return safehouses
end

function EventTeleportManager.Shared.ValidateReturnTeleport(player, returnType, safehouseId)
	if not player then
		return false, "IGUI_ETM_PlayerNotFound"
	end

	local username = player:getUsername()

	if not EventTeleportManager.OriginalPositions[username] then
		return false, "IGUI_ETM_NoSavedPosition"
	end

	if EventTeleportManager.Shared.IsPlayerOnCooldown(player) then
		local remaining = EventTeleportManager.Shared.GetRemainingCooldown(player)
		return false, "IGUI_ETM_ReturnCooldown", { time = remaining }
	end

	if EventTeleportManager.Shared.HasZombiesThreat(player) then
		return false, "IGUI_ETM_ZombiesThreat"
	end

	local allowedMode = EventTeleportManager.Shared.GetReturnTeleportMode()

	if returnType == "original" then
		if allowedMode == "safehouse_choice" then
			return false, "IGUI_ETM_OriginalNotAllowed"
		end
	elseif returnType == "safehouse" then
		if allowedMode == "original_only" then
			return false, "IGUI_ETM_SafehouseNotAllowed"
		end

		local safehouses = EventTeleportManager.Shared.GetPlayerSafehouses(player)
		if #safehouses == 0 then
			return false, "IGUI_ETM_NoSafehouse"
		end

		if safehouseId then
			local found = false
			for _, safehouse in ipairs(safehouses) do
				if safehouse.id == safehouseId then
					found = true
					break
				end
			end
			if not found then
				return false, "IGUI_ETM_SafehouseNotFound"
			end
		end
	else
		return false, "IGUI_ETM_InvalidReturnType"
	end

	return true
end

return EventTeleportManager
