if eRollTracker == nil then eRollTracker = {} end

---------------------
-- Library Imports --
---------------------
local LibDB		= LibStub("LibDataBroker-1.1")
local LibDBIcon	= LibStub("LibDBIcon-1.0")
local LibWindow = LibStub("LibWindow-1.1")

----------------------
-- Member Variables --
----------------------
eRollTracker.item = ""		-- this should be a valid itemLink
eRollTracker.isOpen = false	-- if an item is currently being rolled for
eRollTracker.entries = {}	-- list of current roll (sorted) entries
eRollTracker.pools = {
	heading		= CreateFramePool("Frame", eRollTrackerFrame_Scroll_Layout,"eRollTracker_Template_Heading"),
	entry		= CreateFramePool("Frame", eRollTrackerFrame_Scroll_Layout,"eRollTracker_Template_Entry"),
	separator	= CreateFramePool("Frame", eRollTrackerFrame_Scroll_Layout,"eRollTracker_Template_Separator"),
}	-- reuse frames to prevent excess created frames
eRollTracker.events = {}	-- syntactic sugar for OnEvent handlers

----------------------
-- Imported Aliases --
----------------------
-- Header `#include`s aren't supported.
-- This is the most concise workaround.

-- textcolor.lua
local const_colortable	= eRollTracker.ext.const_colortable
local const_classcolor	= eRollTracker.ext.const_classcolor
local const_raritycolor	= eRollTracker.ext.const_raritycolor

local UncolorizeText = eRollTracker.ext.UncolorizeText

local Colorize		= eRollTracker.ext.Colorize
local ColorizeName	= eRollTracker.ext.ColorizeName
local ColorizeLayer	= eRollTracker.ext.ColorizeLayer

-- components.lua
local ResetEntry = eRollTracker.ext.ResetEntry

local InitHeading	= eRollTracker.ext.InitHeading
local InitEntry		= eRollTracker.ext.InitEntry
local InitSeparator	= eRollTracker.ext.InitSeparator

---------------------
-- Local Constants --
---------------------
local const_version = "v" .. GetAddOnMetadata("EasyRollTracker", "Version")
local const_namechars =
	"ÁÀÂÃÄÅ" .. "áàâãäå" ..
	"ÉÈÊË"   .. "éèêë"   ..
	"ÍÌÎÏ"   .. "íìîï"   ..
	"ÓÒÔÕÖØ" .. "óòôõöø" ..
	"ÚÙÛÜ"   .. "úùûü"   ..
	"ÝŸ"     .. "ýÿ"     ..
	"ÆÇÐÑ"   .. "æçðñ"   .. "ß"

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

local function ParseRollText(text)
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

local function GetSpec(player)
	return ""
end

local function ToggleVisible()
	if (eRollTrackerFrame:IsShown()) then
		eRollTrackerFrame:Hide()
	else
		eRollTrackerFrame:Show()
	end
end

-- View display update functions for the current roll item.
local function UpdateItemIcon()
	local itemLink = eRollTracker.item
	if (itemLink) then
		local _,_, itemRarity, _,_,_,_,_,_, itemIcon =
			GetItemInfo(itemLink)
		if itemRarity ~= nil then
			ColorizeLayer(eRollTrackerFrame_Item["border"], itemRarity)
		else
			eRollTrackerFrame_Item["border"]:SetVertexColor(0.85, 0.85, 0.85)
		end
		eRollTrackerFrame_Item_Icon["icon"]:SetTexture(itemIcon)
		-- If itemIcon is nil, SetTexture will hide that layer
	end
end
local function UpdateItemText()
	eRollTrackerFrame_EditItem:SetText(eRollTracker.item)
end
local function ClearItem()
	eRollTracker.item = ""
	UpdateItemIcon()
	UpdateItemText()
end

local function GetInsertIndex(roll)
	for i, widget in ipairs(eRollTracker.entries) do
		if widget.roll then
			local roll_compare =
				tonumber(UncolorizeText(widget.roll:GetText()))
			local roll_new =
				tonumber(UncolorizeText(roll))
			if roll_compare < roll_new then
				return i
			end
		end
	end
	return #(eRollTracker.entries) + 1
end

-- Inserts frame as the new frame at index.
-- The current frame at index is pushed down by 1.
local function ScrollInsert(frame, index)
	local frame_prev = nil
	if index == 1 then
		frame_prev = eRollTrackerFrame_Scroll_Layout_PadTop
	else
		frame_prev = eRollTracker.entries[index-1]
	end
	frame:SetPoint("TOP", frame_prev, "BOTTOM")

	local frame_next = nil
	if index == #(eRollTracker.entries)+1 then
		frame_next = eRollTrackerFrame_Scroll_Layout_PadBottom
	else
		frame_next = eRollTracker.entries[index]
	end
	frame_next:SetPoint("TOP", frame, "BOTTOM")

	table.insert(eRollTracker.entries, index, frame)
	
	eRollTrackerFrame_Scroll_Layout:AddLayoutChildren(frame)
	eRollTrackerFrame_Scroll_Layout:Layout()
end
local function ScrollAppend(frame)
	ScrollInsert(frame, #(eRollTracker.entries)+1)
	local max_scroll = eRollTrackerFrame_Scroll:GetVerticalScrollRange()
	eRollTrackerFrame_Scroll:SetVerticalScroll(max_scroll)
end

----------------------
-- Global Functions --
----------------------
-- These are easily accessible from XML.

-- A prettified title string, including the AddOn version string.
function eRollTracker_GetTitle()
	local str_name = Colorize("Easy", const_colortable["Erythro"]) .. " Roll Tracker"
	local str_version = Colorize(const_version, const_colortable["gray"])
	return str_name .. " " .. str_version
end

-- Open the Interface settings menu to the panel for this AddOn.
function eRollTracker_ShowOptions()
end

-- Use the item data on the cursor to update internal variables.
function eRollTracker_AcceptCursor()
	local type, itemID, itemLink = GetCursorInfo();
	if type=="item" and itemLink then
		eRollTracker.item = itemLink
		ClearCursor()
		UpdateItemIcon()
		UpdateItemText()
		eRollTracker_ShowTooltip()
	end
end
function eRollTracker_AcceptText()
	eRollTrackerFrame_EditItem:ClearFocus()
	eRollTracker.item = eRollTrackerFrame_EditItem:GetText()
	UpdateItemIcon()
end
function eRollTracker_SendCursor()
	local type, itemID, itemLink = GetCursorInfo()
	if type=="item" and itemLink then
		eRollTracker.item = itemLink
		ClearCursor()
		UpdateItemIcon()
		UpdateItemText()
		eRollTracker_ShowTooltip()
	elseif eRollTracker.item ~= "" then
		PickupItem(eRollTracker.item);
		eRollTracker.item = ""
		UpdateItemIcon()
		UpdateItemText()
		eRollTracker_HideTooltip()
	end
	-- some code repetition is necessary here;
	-- otherwise we end up in a loop of calling Accept/Send.
end

-- Tooltip display handling for the main Item.
function eRollTracker_ShowTooltip()
	if eRollTracker.item ~= "" then
		GameTooltip:ClearLines()
		GameTooltip:SetOwner(_G["eRollTrackerFrame_Item"], "ANCHOR_NONE")
		GameTooltip:SetPoint("TOPLEFT", eRollTrackerFrame_Item, "BOTTOMLEFT", 0, -4)
		GameTooltip:SetHyperlink(eRollTracker.item)
		GameTooltip:Show()
	end
end
function eRollTracker_HideTooltip()
	GameTooltip:Hide()
	GameTooltip:ClearLines()
end

----------------------------
-- Global State Functions --
----------------------------
-- These functions also handle state transitions for the addon,
-- setting properties based on whether a roll is currently open.

function eRollTracker_OpenRoll()
	eRollTracker.isOpen = true
	local message = "Roll for " .. eRollTracker.item
	SendChatMessage(message, "RAID_WARNING")

	local heading = eRollTracker.pools.heading:Acquire()
	ResetEntry(heading)
	InitHeading(heading, eRollTracker.item)
	heading:Show()
	ScrollAppend(heading)
	eRollTracker.entries = { heading }
end

function eRollTracker_CloseRoll()
	eRollTracker.isOpen = false
	local message = "Closed roll for " .. eRollTracker.item
	SendChatMessage(message, "RAID_WARNING")

	local separator = eRollTracker.pools.separator:Acquire()
	ResetEntry(separator)
	InitSeparator(separator)
	separator:Show()
	ScrollAppend(separator)
	eRollTracker.entries = { separator }

	ClearItem()
end

function eRollTracker_ClearAll()
	if eRollTracker.isOpen then
		eRollTracker_CloseRoll()
	else
		ClearItem()
	end

	eRollTrackerFrame_Scroll_Layout_PadBottom:SetPoint("TOP", eRollTrackerFrame_Scroll_Layout_PadTop, "BOTTOM")

	eRollTracker.pools.heading:ReleaseAll()
	eRollTracker.pools.entry:ReleaseAll()
	eRollTracker.pools.separator:ReleaseAll()

	for _, widget in eRollTracker.pools.heading:EnumerateInactive() do
		widget:SetParent(nil)
	end
	for _, widget in eRollTracker.pools.entry:EnumerateInactive() do
		widget:SetParent(nil)
	end
	for _, widget in eRollTracker.pools.separator:EnumerateInactive() do
		widget:SetParent(nil)
	end

	eRollTracker.entries = {}
	eRollTrackerFrame_Scroll_Layout:Layout()
end

--------------------
-- Event Handlers --
--------------------

-- Dispatcher for arbitrary event types.
function eRollTrackerFrame_OnEvent(self, event, ...)
	eRollTracker.events[event](self, ...)
end

-- Event: CHAT_MSG_SYSTEM
-- If found, insert a new roll entry into the list.
function eRollTracker.events:CHAT_MSG_SYSTEM(...)
	local text = ...
	local isRoll, player, roll, max = ParseRollText(text)
	if isRoll then
		local entry = eRollTracker.pools.entry:Acquire()
		ResetEntry(entry)

		local role = RoleIconString(player)
		local spec = GetSpec(player)
		local name = ColorizeName(player)
		local maxnum = tonumber(max)
		if maxnum == 100 then
			max = Colorize(max, const_colortable["gray"])
		elseif maxnum > 100 then
			max = Colorize(max, const_colortable["red"])
			roll = Colorize(roll, const_colortable["red"])
		elseif maxnum < 100 then
			max = Colorize(max, const_colortable["darkgray"])
		end

		InitEntry(entry, role, spec, name, roll, max)
		entry:Show()
		local index = GetInsertIndex(tonumber(UncolorizeText(roll)))
		ScrollInsert(entry, index)
	end
end

--------------------
-- Slash Commands --
--------------------
SLASH_EASYROLLTRACKER1, SLASH_EASYROLLTRACKER2, SLASH_EASYROLLTRACKER3 =
	"/rolltracker", "/rolltrack", "/rt"
function SlashCmdList.EASYROLLTRACKER(msg, editBox)
	ToggleVisible()
end

--------------------
-- Minimap Button --
--------------------
local const_name_LDB_icon = "Easy Roll Tracker Icon"
local const_path_LDB_icon = "Interface\\AddOns\\EasyRollTracker\\rc\\EasyRollTracker - minimap.tga"

local function MinimapTooltip(tooltip)
	tooltip:ClearLines()
	local name = Colorize("Easy", const_colortable["Erythro"]) .. " Roll Tracker"
	local version = Colorize(const_version, const_colortable["gray"])
	tooltip:AddDoubleLine(name, version)
	local l_click = Colorize(" toggle showing the addon window.", const_colortable["white"])
	local r_click = Colorize(" open the configuration window.", const_colortable["white"])
	tooltip:AddLine("Left-Click:" .. l_click)
	tooltip:AddLine("Right-Click:" .. r_click)
end

-- First create a Data Broker to bind the minimap button to.
local LDB_icon = LibDB:NewDataObject(const_name_LDB_icon, {
	type = "launcher",
	icon = const_path_LDB_icon,
	tocname = "EasyRollTracker",
	label = "Easy Roll Tracker",
	OnTooltipShow = MinimapTooltip,
	OnClick = function(frame, button)
		if button == "LeftButton" then
			ToggleVisible()
		elseif button == "RightButton" then
			eRollTracker_ShowOptions()
		end
	end
})

-- Get minimap button display settings.
local EasyRollTrackerDB = { minimap_icon = { hide = false } }

-- Bind minimap button to previously-created Data Broker.
LibDBIcon:Register(const_name_LDB_icon, LDB_icon, EasyRollTrackerDB.minimap_icon)

-----------------------
-- Smart Positioning --
-----------------------
-- LibWindow allows DPI-independent position saving.

-- TODO: RestorePosition() requires waiting for ADDON_LOADED event
-- LibWindow.RegisterConfig(eRollTrackerFrame, EasyRollTrackerDB.window)
-- LibWindow.MakeDraggable(eRollTrackerFrame)
-- LibWindow.RestorePosition(eRollTrackerFrame)
