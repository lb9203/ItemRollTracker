if iRollTracker == nil then iRollTracker = {} end
if iRollTracker.ext == nil then iRollTracker.ext = {} end

---------------------
-- Library Imports --
---------------------
local LibDB		= LibStub("LibDataBroker-1.1")
local LibDBIcon	= LibStub("LibDBIcon-1.0")
local LibWindow = LibStub("LibWindow-1.1")

----------------------
-- Member Variables --
----------------------
iRollTracker.wasMainWindowShown = false	-- whether main window should be shown after closing options window
iRollTracker.item = ""	-- this should be a valid itemLink
iRollTracker.rollingItem = ""	-- this should be a valid itemLink
iRollTracker.isOpen = false	-- if an item is currently being rolled for
iRollTracker.entries = {}	-- list of current roll (sorted) entries
iRollTracker.specqueue = {}	-- list of players to query specs
iRollTracker.isInspecting = false	-- whether or not an inspect request has been sent already
iRollTracker.pools = {
	heading		= CreateFramePool("Frame", iRollTrackerFrame_Scroll_Layout,"iRollTracker_Template_Heading"),
	entry		= CreateFramePool("Frame", iRollTrackerFrame_Scroll_Layout,"iRollTracker_Template_Entry"),
}	-- reuse frames to prevent excess created frames
iRollTracker.events = {}	-- syntactic sugar for OnEvent handlers

----------------------
-- Imported Aliases --
----------------------
-- Header `#include`s aren't supported.
-- This is the most concise workaround.

-- consts.lua
local const_text_addonname		= iRollTracker.ext.const_text_addonname
local const_version				= iRollTracker.ext.const_version
local const_namechars			= iRollTracker.ext.const_namechars
local const_time_doubleclick	= iRollTracker.ext.const_time_doubleclick
local const_frame_size_ignore	= iRollTracker.ext.const_frame_size_ignore
local const_path_icon_LDB		= iRollTracker.ext.const_path_icon_LDB
local const_path_icon_unknown	= iRollTracker.ext.const_path_icon_unknown

-- color.lua
local const_colortable	= iRollTracker.ext.const_colortable
local const_classcolor	= iRollTracker.ext.const_classcolor

local UncolorizeText = iRollTracker.ext.UncolorizeText

local Colorize		= iRollTracker.ext.Colorize
local ColorizeName	= iRollTracker.ext.ColorizeName
local ColorizeSpec	= iRollTracker.ext.ColorizeSpec
local ColorizeSpecBW = iRollTracker.ext.ColorizeSpecBW
local ColorizeLayerSpec		= iRollTracker.ext.ColorizeLayerSpec
local ColorizeLayerRarity	= iRollTracker.ext.ColorizeLayerRarity

-- components.lua
local ResetHeading		= iRollTracker.ext.ResetHeading
local ResetEntry		= iRollTracker.ext.ResetEntry

local InitHeading	= iRollTracker.ext.InitHeading
local InitEntry		= iRollTracker.ext.InitEntry

-----------------------
-- Utility Functions --
-----------------------
local const_roleicon = {
	TANK	= CreateAtlasMarkup("roleicon-tiny-tank"),
	HEALER	= CreateAtlasMarkup("roleicon-tiny-healer"),
	DAMAGER	= CreateAtlasMarkup("roleicon-tiny-dps"),
	NONE	= CreateAtlasMarkup("roleicon-tiny-none"),
}
local function RoleIconString(name)
	local role = UnitGroupRolesAssigned(name)
	return const_roleicon[role]
end

local function ParsiRollText(text)
	local regex_find_roll =
		"[%a%-" .. const_namechars .. "]+" ..
		" rolls %d+ %(1%-%d+%)"
	local regex_find_data =
		"([%a%-" .. const_namechars .. "]+)" ..
		" rolls (%d+) %(1%-(%d+)%)"
	if string.find(text, regex_find_roll) == nil then
		return false
	else
		local _,_, name, roll, max =
			string.find(text, regex_find_data)
		return true, name, roll, max
	end
end

local const_spectable = {
	[1455] = "new",	-- Death Knight
	[ 250] = "BDK", [ 251] = "FRS", [ 252] = "UNH",
	[1456] = "new",	-- Demon Hunter
	[ 577] = "HAV", [ 581] = "VDH",
	[1447] = "new",	-- Druid
	[ 102] = "OWL", [ 103] = "CAT", [ 104] = "BR" , [ 105] = "RST",
	[1448] = "new",	-- Hunter
	[ 253] = "BM" , [ 254] = "MM" , [ 255] = "SV" ,
	[1449] = "new",	-- Mage
	[  62] = "ARC", [  63] = "HOT", [  64] = "FRS",
	[1450] = "new",	-- Monk
	[ 268] = "BRM", [ 270] = "MW" , [ 269] = "WW" ,
	[1451] = "new",	-- Paladin
	[  65] = "HLY", [  66] = "PT" , [  70] = "RET",
	[1452] = "new",	-- Priest
	[ 256] = "DSC", [ 257] = "HLY", [ 258] = "SHA",
	[1453] = "new",	-- Rogue
	[ 259] = "SIN", [ 260] = "OUT", [ 261] = "SUB",
	[1444] = "new",	-- Shaman
	[ 262] = "ELE", [ 263] = "ENH", [ 264] = "RST",
	[1454] = "new",	-- Warlock
	[ 265] = "AFF", [ 266] = "DMN", [ 267] = "DST",
	[1446] = "new",	-- Warrior
	[  71] = "ARM", [  72] = "FY" , [  73] = "PT" ,
}
local function GetSpec(player, entry)
	local GUID = UnitGUID(player)
	if iRollTracker.specqueue[GUID] == nil then
		iRollTracker.specqueue[GUID] = {
			["name"] = player,
			["entry"] = { entry },
		}
	else
		table.insert(iRollTracker.specqueue[GUID].entry, entry)
	end
	if iRollTracker.isInspecting == false then
		NotifyInspect(player)
		iRollTracker.isInspecting = true
		local function reinspect()
			if iRollTracker.isInspecting then
				NotifyInspect(player)
				C_Timer.After(2.000, reinspect)
			end
		end
		C_Timer.After(2.000, reinspect)
	end
	return ""
end

local function getItemLink(itemtext)
	local regex_find_itemlink = "(|c[fF][fF]%x%x%x%x%x%x|Hitem:[:%d]-|h.-|h|r)"
	local _,_, itemlink = string.find(itemtext, regex_find_itemlink)
	if itemlink == nil then
		return ""
	else
		return itemlink
	end
end

local function ResetAddonData(isAcceptCallback)
	if isAcceptCallback == nil then
		StaticPopup_Show("ItemRollTRACKER_RESET")
		return
	elseif isAcceptCallback == true then
		iRollTracker_ClearAll()
	
		ItemRollTrackerDB = {
			options = {
				maxRollThreshold = 100,
			},
			unmaximize = { width = 250, height = 320 },
			libwindow = {},
			ldbicon = { hide = false },
		}
	
		iRollTrackerFrame:ClearAllPoints()
		iRollTrackerFrame:SetPoint("CENTER")
		iRollTrackerFrame:SetSize(250, 320)
	
		LibWindow.RegisterConfig(iRollTrackerFrame, ItemRollTrackerDB.libwindow)
		LibWindow.SavePosition(iRollTrackerFrame)
	
		iRollTrackerFrame:Hide()
	end
end

local function PrintHelpText()
	local function ColorCommand(cmd)
		return Colorize(cmd, const_colortable["Erythro"])
	end

	print(
		const_text_addonname ..
		" (" .. const_version .. ")" ..
		" commands:"
	)

	print(ColorCommand("  /rt:") .. " toggles the main window")
	print(ColorCommand("  /rt help:")	.. " lists available commands")
	print(ColorCommand("  /rt config:")	.. " opens the addon settings")
	print(ColorCommand("  /rt close:")	.. " closes the current roll")
	print(ColorCommand("  /rt clear:")	.. " clears the main window")
	print(ColorCommand("  /rt reset:")	.. " reset all data/settings")
end

local function ToggleVisible()
	if (iRollTrackerFrame:IsShown()) then
		iRollTrackerFrame:Hide()
	else
		iRollTrackerFrame:Show()
		LibWindow.RestorePosition(iRollTrackerFrame)
	end
end

-- View display update functions for the current roll item.
local function UpdateItemIcon()
	local itemLink = iRollTracker.item
	if itemLink then
		local _,_, itemRarity, _,_,_,_,_,_, itemIcon =
			GetItemInfo(itemLink)
		if itemRarity ~= nil then
			ColorizeLayerRarity(iRollTrackerFrame_Item.border, itemRarity)
		else
			iRollTrackerFrame_Item.border:SetVertexColor(0.85, 0.85, 0.85)
		end

		if itemLink == "" then
			iRollTrackerFrame_Item_Icon.icon:SetTexture(nil)	-- hides texture
		elseif itemIcon == nil then
			iRollTrackerFrame_Item_Icon.icon:SetTexture(const_path_icon_unknown)
		else
			iRollTrackerFrame_Item_Icon.icon:SetTexture(itemIcon)
		end
	end
end

local function ClearItem()
	iRollTracker.item = ""
	UpdateItemIcon()
end

local function GetReplaceIndex(player)
	for i, widget in ipairs(iRollTracker.entries) do
		if widget.name then
			compareName = UncolorizeText(widget.name:GetText())
			if player == compareName then
				return i
			end
		end
	end
	return nil
end

local function GetInsertIndex(roll, max)
	for i, widget in ipairs(iRollTracker.entries) do
		if widget.roll then
			local roll_compare =
				tonumber(UncolorizeText(widget.roll:GetText()))
			local max_compare = tonumber(UncolorizeText(widget.max:GetText()))

			if (max > max_compare) then
				return i
			end

			if (max == max_compare and roll > roll_compare) then
				return i
			end
		end
	end
	return #(iRollTracker.entries) + 1
end

-- Inserts frame as the new frame at index.
-- The current frame at index is pushed down by 1.
local function ScrollInsert(frame, index)
	local frame_prev = nil
	if index == 1 then
		frame_prev = iRollTrackerFrame_Scroll_Layout_PadTop
	else
		frame_prev = iRollTracker.entries[index-1]
	end
	frame:SetPoint("TOP", frame_prev, "BOTTOM")

	local frame_next = nil
	if index == #(iRollTracker.entries)+1 then
		frame_next = iRollTrackerFrame_Scroll_Layout_PadBottom
	else
		frame_next = iRollTracker.entries[index]
	end
	frame_next:SetPoint("TOP", frame, "BOTTOM")

	table.insert(iRollTracker.entries, index, frame)
	
	iRollTrackerFrame_Scroll_Layout:AddLayoutChildren(frame)
	iRollTrackerFrame_Scroll_Layout:Layout()
end

local function ScrollReplace(frame, index)
	currFrame = iRollTracker.entries[index]
	currFrame.roll:SetText(frame.roll:GetText()) 
end

local function ScrollAppend(frame)
	ScrollInsert(frame, #(iRollTracker.entries)+1)
	local max_scroll = iRollTrackerFrame_Scroll:GetVerticalScrollRange()
	iRollTrackerFrame_Scroll:SetVerticalScroll(max_scroll)
end

----------------------
-- Global Functions --
----------------------
-- These are easily accessible from XML.

-- A prettified title string, including the AddOn version string.
function iRollTracker_OnLoad(self)
	str_title = const_text_addonname
	
	self.title:SetText(str_title)
	self.clickprev = GetTime();
	
	self:RegisterForDrag("LeftButton")
	table.insert(UISpecialFrames, "iRollTrackerFrame")

	local addon_registered = C_ChatInfo.RegisterAddonMessagePrefix("iRollTrack")
	if addon_registered == false then
		StaticPopup_Show("ItemRollTRACKER_CHATPREFIXFULL")
	else
		self:RegisterEvent("CHAT_MSG_ADDON")
	end

	self:RegisterEvent("ADDON_LOADED")
	self:RegisterEvent("RAID_ROSTER_UPDATE")
	self:RegisterEvent("GROUP_ROSTER_UPDATE")
	self:RegisterEvent("CHAT_MSG_SYSTEM")
	self:RegisterEvent("INSPECT_READY")
end

-- Toggle maximizing the window. Saves previous size to SavedVariables.
function iRollTracker_ToggleMaximize()
	local width, height = iRollTrackerFrame:GetSize()
	local _, _, width_max, height_max = iRollTrackerFrame:GetResizeBounds()

	local function IsEqual(x, y)
		return math.abs(x - y) < const_frame_size_ignore
	end

	if IsEqual(width, width_max) and IsEqual(height, height_max) then
		local width, height = 250, 320
		if ItemRollTrackerDB.unmaximize ~= nil then
			width = ItemRollTrackerDB.unmaximize["width"]
			height = ItemRollTrackerDB.unmaximize["height"]
		end
		iRollTrackerFrame:SetSize(width, height)
	else
		ItemRollTrackerDB.unmaximize = {
			["width"] = width,
			["height"] = height
		}
		iRollTrackerFrame:SetSize(width_max, height_max)
	end
end

-- Detect double clicks on window titlebar.
function iRollTracker_OnMouseDown(self, button)
	if iRollTrackerFrame_TitleHitbox:IsMouseOver() then
		local click = GetTime()
		-- 500ms is Windows' default interval
		if click - self.clickprev < const_time_doubleclick then
			iRollTracker_ToggleMaximize()
			-- clear double click buffer by setting threshold back in time
			self.clickprev = GetTime() - const_time_doubleclick
		else
			self.clickprev = GetTime()
		end
	end
end

-- Use LibWindow to save the position in a resolution-independent way.
function iRollTracker_StopPositioning()
	iRollTrackerFrame:StopMovingOrSizing()
	LibWindow.SavePosition(iRollTrackerFrame)
end

-- Open the Interface settings menu to the panel for this AddOn.
function iRollTracker_ShowOptions()
	iRollTracker.wasMainWindowShown = iRollTrackerFrame:IsShown()
	iRollTrackerFrame:Hide()
	iRollTrackerFrame_Options:HookScript("OnHide", function()
		if iRollTracker.wasMainWindowShown then
			iRollTrackerFrame:Show()
		end
	end)
	iRollTrackerFrame:HookScript("OnShow", function()
		if iRollTrackerFrame_Options:IsShown() then
			iRollTracker.wasMainWindowShown = true
			iRollTrackerFrame:Hide()
		end
	end)

	if iRollTrackerFrame_Options:IsShown() == false then
		iRollTrackerFrame_Options:Show()
	end
end


-- Use the item data on the cursor to update internal variables.
function iRollTracker_AcceptCursor()
	local type, itemID, itemLink = GetCursorInfo();
	if type=="item" and itemLink then
		iRollTracker.item = itemLink
		iRollTracker.itemId = itemID
		ClearCursor()
		UpdateItemIcon()
		if MouseIsOver(iRollTrackerFrame_Item) then
			iRollTracker_ShowTooltip()
		end
	end
end

function iRollTracker_AcceptText()
	local itemtext = iRollTrackerFrame_EditItem:GetText()
	itemtext = getItemLink(itemtext)
	iRollTrackerFrame_EditItem:SetText(itemtext)
	iRollTracker.item = itemtext
	UpdateItemIcon()
end

function iRollTracker_SendCursor()
	local type, itemID, itemLink = GetCursorInfo()
	if type=="item" and itemLink then
		iRollTracker.item = itemLink
		ClearCursor()
		UpdateItemIcon()
		iRollTracker_ShowTooltip()
	end
	-- some code repetition is necessary here;
	-- otherwise we end up in a loop of calling Accept/Send.
end

function iRollTracker_SendCursorPlayer(self)
	player = UncolorizeText(self.name:GetText())

	DropItemOnUnit(player);
end

-- Tooltip display handling for the main Item.
function iRollTracker_ShowTooltip()
	local _, itemLink = GetItemInfo(iRollTracker.item)
	if itemLink ~= nil then
		GameTooltip:ClearLines()
		GameTooltip:SetOwner(iRollTrackerFrame_Item, "ANCHOR_NONE")
		GameTooltip:SetPoint("TOPLEFT", iRollTrackerFrame_Item, "BOTTOMLEFT", 0, -4)
		GameTooltip:SetHyperlink(itemLink)
		GameTooltip:Show()
	end
end
function iRollTracker_HideTooltip()
	GameTooltip:Hide()
	GameTooltip:ClearLines()
	GameTooltip:ClearAllPoints()
end

----------------------------
-- Global State Functions --
----------------------------
-- These functions also handle state transitions for the addon,
-- setting properties based on whether a roll is currently open.

function iRollTracker_OpenRoll()
	local itemstring = iRollTracker.item
	local _, itemLink = GetItemInfo(iRollTracker.item)
	if itemLink == nil then
		return
	end

	iRollTracker.isOpen = true

	local message = "Roll for " .. itemstring
	local channel = ""
	if IsInRaid() then
		channel = "RAID_WARNING"
	elseif IsInGroup() then
		channel = "PARTY"
	else
		channel = "SAY"
	end
	SendChatMessage(message, channel)
	
	ChatThrottleLib:SendAddonMessage("ALERT", "iRollTrack", "<v1>H:" .. iRollTracker.item, "RAID")

	local heading = iRollTracker.pools.heading:Acquire()
	ResetHeading(heading)
	InitHeading(heading, iRollTracker.item)
	heading:Show()
	ScrollAppend(heading)
	iRollTracker.entries = { heading }
end

function iRollTracker_CloseRoll()
	if (not iRollTracker.isOpen) then
		return
	end

	iRollTracker.isOpen = false
	
	local itemstring = iRollTracker.item
	local _, itemLink = GetItemInfo(iRollTracker.item)
	if itemLink ~= nil then
		itemstring = itemLink
	end
	local message = "Closed roll for " .. itemstring
	local channel = ""
	if IsInRaid() then
		channel = "RAID_WARNING"
	elseif IsInGroup() then
		channel = "PARTY"
	else
		channel = "SAY"
	end
	SendChatMessage(message, channel)

	ChatThrottleLib:SendAddonMessage("ALERT", "iRollTrack", "<v1>S:", "RAID")

	ClearItem()
end

function iRollTracker_ClearAll()
	if iRollTracker.isOpen then
		iRollTracker_CloseRoll()
	else
		ClearItem()
	end

	iRollTrackerFrame_Scroll_Layout_PadBottom:SetPoint("TOP", iRollTrackerFrame_Scroll_Layout_PadTop, "BOTTOM")

	iRollTracker.pools.heading:ReleaseAll()
	iRollTracker.pools.entry:ReleaseAll()

	iRollTracker.entries = {}
	iRollTrackerFrame_Scroll_Layout:Layout()
end

--------------------
-- Event Handlers --
--------------------

-- Dispatcher for arbitrary event types.
function iRollTrackerFrame_OnEvent(self, event, ...)
	iRollTracker.events[event](self, ...)
end

-- Event: RAID_/GROUP_ROSTER_UPDATE
-- Updates the button status
-- (whether or not a client can broadcast roll alerts).
function iRollTracker.events:RAID_ROSTER_UPDATE()
	-- print("raid roster update")
end
function iRollTracker.events:GROUP_ROSTER_UPDATE()
	-- print("group roster update")
end

-- Event: CHAT_MSG_ADDON
function iRollTracker.events:CHAT_MSG_ADDON(...)
	local prefix, text, channel, sender, target, zoneChannelID, localID, name, instanceID = ...
	local self_name, self_realm = UnitFullName("player")
	local self_str = self_name .. "-" .. self_realm
	local isSelf = (sender == self_str)
	local isAssist = false
	if UnitIsSameServer(sender) then
		local regex_find_name = "([^%-]+)%-.+"
		local _,_, name = string.find(sender, regex_find_name)
		sender = name
	end
	if IsInRaid() then
		isAssist = (UnitIsGroupAssistant(sender) or UnitIsGroupLeader(sender))
	elseif IsInGroup() then
		isAssist = UnitIsGroupLeader(sender)
	else
		isAssist = true
	end
	if (prefix == "iRollTrack") and (not isSelf) and isAssist then
		local regex_find_comm = "^<v(%d+)>([HS]):(.*)"
		local _,_, version, type, data =
			string.find(text, regex_find_comm)
		if version == "1" then
			if type == "S" then
				iRollTracker.isOpen = false
			
				ClearItem()
			elseif type == "H" then
				iRollTracker.isOpen = true
				iRollTracker.item = data

				local heading = iRollTracker.pools.heading:Acquire()
				ResetHeading(heading)
				InitHeading(heading, iRollTracker.item)
				heading:Show()
				ScrollAppend(heading)
				iRollTracker.entries = { heading }
			end
		end
	end
end

-- Event: INSPECT_READY
-- Updates any spec info that still needs to be filled in.
function iRollTracker.events:INSPECT_READY(...)
	local inspecteeGUID = ...
	local frame_inspectee = iRollTracker.specqueue[inspecteeGUID]
	if frame_inspectee ~= nil then
		local spec = ""
		local player = iRollTracker.specqueue[inspecteeGUID].name
		local specID = GetInspectSpecialization(player)
		spec = const_spectable[specID]
		spec = ColorizeSpecBW(spec, specID)

		for _, entry in pairs(iRollTracker.specqueue[inspecteeGUID].entry) do
			entry.spec:SetText(spec)
			ColorizeLayerSpec(entry.specBackground, specID)
		end
		
		iRollTracker.specqueue[inspecteeGUID] = nil
		ClearInspectPlayer()
		if #(iRollTracker.specqueue) > 0 then
			for k,v in pairs(iRollTracker.specqueue) do
				NotifyInspect(v.name)
				iRollTracker.isInspecting = true
				local function reinspect()
					if iRollTracker.isInspecting then
						NotifyInspect(player)
						C_Timer.After(2.000, reinspect)
					end
				end
				C_Timer.After(2.000, reinspect)
				break
			end
		else
			iRollTracker.isInspecting = false
		end
	end
end

-- Event: CHAT_MSG_SYSTEM
-- If found, insert a new roll entry into the list.
function iRollTracker.events:CHAT_MSG_SYSTEM(...)
	local text = ...
	local isRoll, player, roll, max = ParsiRollText(text)
	if (isRoll and iRollTracker.isOpen) then
		local role = RoleIconString(player)
		local name = ColorizeName(player)
		local rollnum = tonumber(roll)
		local maxnum = tonumber(max)
		local threshold = ItemRollTrackerDB.options.maxRollThreshold
		if maxnum == threshold then
			max = Colorize(max, const_colortable["green"])
		elseif maxnum > threshold then
			max = Colorize(max, const_colortable["red"])
		elseif maxnum < threshold then
			max = Colorize(max, const_colortable["gray"])
		end

		local replaceIndex = GetReplaceIndex(player)

		if replaceIndex then
			-- Recolour name to blue to indicate player has rolled more than once.
			roll = Colorize(UncolorizeText(roll), const_colortable["blue"])
			iRollTracker.entries[replaceIndex].name:SetText(name)
			iRollTracker.entries[replaceIndex].roll:SetText(roll)
			iRollTracker.entries[replaceIndex].max:SetText(max)
		else
			local entry = iRollTracker.pools.entry:Acquire()
			ResetEntry(entry)
			local spec = GetSpec(player, entry)

			InitEntry(entry, role, spec, name, roll, max)
			entry:Show()
			local index = GetInsertIndex(rollnum, maxnum)
			ScrollInsert(entry, index)
		end
	end
end

-- Event: ADDON_LOADED
-- Handle anything dependent on loading SavedVariables.
function iRollTracker.events:ADDON_LOADED(...)
	local addonName = ...
	if addonName == "ItemRollTracker" then
		if ItemRollTrackerDB == nil then
			ItemRollTrackerDB = {}
		end

		-- Default options
		if ItemRollTrackerDB.options == nil then
			ItemRollTrackerDB.options = {}
		end
		if ItemRollTrackerDB.options.maxRollThreshold == nil then
			ItemRollTrackerDB.options.maxRollThreshold = 100
		end

		-- LibWindow: resolution-independent positioning
		-- Registration needs to happen after addon loads,
		-- otherwise XML frames aren't defined yet.
		if ItemRollTrackerDB.libwindow == nil then
			ItemRollTrackerDB.libwindow = {}
		end
		LibWindow.RegisterConfig(iRollTrackerFrame, ItemRollTrackerDB.libwindow)
		LibWindow.RestorePosition(iRollTrackerFrame)

		-- LDBIcon: minimap button
		local name_LDB_icon = "Item Roll Tracker Icon"

		local function MinimapTooltip(tooltip)
			tooltip:ClearLines()
			local version = Colorize(const_version, const_colortable["gray"])
			tooltip:AddDoubleLine(const_text_addonname, version)
			local l_click = Colorize(" toggle showing the addon window.", const_colortable["white"])
			local r_click = Colorize(" open the configuration window.", const_colortable["white"])
			tooltip:AddLine("Left-Click:" .. l_click)
			tooltip:AddLine("Right-Click:" .. r_click)
		end

		-- First create a Data Broker to bind the minimap button to.
		local LDB_icon = LibDB:NewDataObject(name_LDB_icon, {
			type = "launcher",
			icon = const_path_icon_LDB,
			tocname = "ItemRollTracker",
			label = "Item Roll Tracker",
			OnTooltipShow = MinimapTooltip,
			OnClick = function(frame, button)
				if button == "LeftButton" then
					ToggleVisible()
				elseif button == "RightButton" then
					iRollTracker_ShowOptions()
				end
			end
		})

		if ItemRollTrackerDB.ldbicon == nil then
			-- default value: *do* show minimap
			ItemRollTrackerDB.ldbicon = { hide = false }
		end
		LibDBIcon:Register(name_LDB_icon, LDB_icon, ItemRollTrackerDB.ldbicon)
	end
end

--------------------
-- Slash Commands --
--------------------
SLASH_ItemRollTRACKER1, SLASH_ItemRollTRACKER2, SLASH_ItemRollTRACKER3 =
	"/iRollTracker", "/rolltrack", "/rt"
function SlashCmdList.ItemRollTRACKER(msg, editBox)
	local cmd = string.lower(msg)
	if cmd == "help" or cmd == "h" or cmd == "?" then
		PrintHelpText()
	elseif cmd == "config" or cmd == "opt" or cmd == "options" then
		iRollTracker_ShowOptions()
	elseif cmd == "close" then
		iRollTrackerFrame_ButtonsRoll_CloseRoll:Click()
	elseif cmd == "clear" then
		iRollTrackerFrame_ButtonClear:Click()
	elseif cmd == "reset" then
		ResetAddonData()
	else
		ToggleVisible()
	end
end

-------------------
-- Popup Dialogs --
-------------------
local const_text_confirmReset =
	"This will reset all Item Roll Tracker data.".. "|n" ..
	"Are you sure?"
StaticPopupDialogs["ItemRollTRACKER_RESET"] = {
	showAlert = true,
	text = const_text_confirmReset,
	button1 = "Yes",
	button2 = "Cancel",
	OnAccept = function()
		ResetAddonData(true)
	end,
	whileDead = true,
	hideOnEscape = true,
	timeout = 300,
}

local const_text_chatPrefixFull =
	"All chat prefix slots have been registered." .. "|n" ..
	"Item Roll Tracker can no longer sync your display" .. "|n" ..
	"with the rest of the raid."
StaticPopupDialogs["ItemRollTRACKER_CHATPREFIXFULL"] = {
	showAlert = true,
	text = const_text_chatPrefixFull,
	button1 = "Okay",
	whileDead = true,
	hideOnEscape = true,
	timeout = 300,
}