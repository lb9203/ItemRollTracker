if iRollTracker == nil then iRollTracker = {} end
if iRollTracker.ext == nil then iRollTracker.ext = {} end

-- This needs to be handled separately because FramePoolMixin provides
-- very little control over refresh/init/destroy of its children.

-- Most anchors are set here, and not in the template itself.
-- The template doesn't know about the rest of the UI before
-- being created.

----------------------
-- Imported Aliases --
----------------------
-- Header `#include`s aren't supported.
-- This is the most concise workaround.

-- consts.lua
local const_path_icon_unknown = iRollTracker.ext.const_path_icon_unknown

-- color.lua
local ColorizeLayerSpec		= iRollTracker.ext.ColorizeLayerSpec
local ColorizeLayerRarity	= iRollTracker.ext.ColorizeLayerRarity

---------------------
-- Reset Functions --
---------------------
-- Functions to reset Frame templates to a cleared state.

local function ResetHeading(frame)
	frame.item = nil
	frame.icon:SetTexture(nil)
	frame.border:SetVertexColor(0.85, 0.85, 0.85)
	frame.label:SetText("")

	frame:ClearAllPoints()
	frame:Hide()
end
iRollTracker.ext.ResetHeading = ResetHeading

local function ResetEntry(frame)
	frame.role:SetText("")
	frame.spec:SetText("")
	frame.name:SetText("")
	frame.roll:SetText("")
	frame.max:SetText("")
	
	frame.specBackground:SetVertexColor(0, 0, 0, 0)

	frame:ClearAllPoints()
	frame:Hide()
end
iRollTracker.ext.ResetEntry = ResetEntry


--------------------
-- Init Functions --
--------------------
-- Functions to init a newly created/acquired Frame template.

local const_heading_label_blank =
	"|cFFD95777~|r" ..
	"|cFFD9B857~|r" ..
	"|cFF77D957~|r" ..
	"|cFF5777D9~|r" ..
	"|cFFB857D9~|r"
local function InitHeading(frame, item)
	frame:SetParent(iRollTrackerFrame_Scroll_Layout)
	frame.item = item
	if item then
		local _, itemLink, itemRarity, _,_,_,_,_,_, itemIcon =
			GetItemInfo(item)
		if itemRarity ~= nil then
			ColorizeLayerRarity(frame.border, itemRarity)
		else
			frame.border:SetVertexColor(0.85, 0.85, 0.85)
		end

		if item == "" then
			frame.icon:SetTexture(const_path_icon_unknown)
			frame.label:SetText(const_heading_label_blank)
		elseif itemIcon == nil then
			frame.icon:SetTexture(const_path_icon_unknown)
			frame.label:SetText(item)
		else
			frame.icon:SetTexture(itemIcon)
			frame.label:SetText(itemLink)
		end
	end
end
iRollTracker.ext.InitHeading = InitHeading

local function InitEntry(frame, role, spec, name, roll, max)
	frame:SetParent(iRollTrackerFrame_Scroll_Layout)
	frame:SetPoint("LEFT", iRollTrackerFrame_Scroll, "LEFT", 4, 0)
	frame:SetPoint("RIGHT", iRollTrackerFrame_Scroll, "RIGHT", -20, 0)
	frame.role:SetPoint("LEFT", frame, "LEFT", 4, 0)
	frame.max:SetPoint("RIGHT", frame, "RIGHT", -20, 0)
	frame.spec:SetPoint("LEFT", frame.role, "RIGHT")
	frame.roll:SetPoint("RIGHT", frame.max, "LEFT")
	frame.name:SetPoint("LEFT", frame.spec, "RIGHT", 2, 0)
	frame.name:SetPoint("RIGHT", frame.roll, "LEFT")
	frame.specBackground:SetPoint("CENTER", frame.spec)
	
	frame.spec:SetShadowColor(0, 0, 0, 0)
	frame.spec:SetShadowOffset(0, 0)

	frame.role:SetText(role)
	frame.spec:SetText(spec)
	frame.name:SetText(name)
	frame.roll:SetText(roll)
	frame.max:SetText(max)
end
iRollTracker.ext.InitEntry = InitEntry

