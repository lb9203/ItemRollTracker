if iRollTracker == nil then iRollTracker = {} end
if iRollTracker.ext == nil then iRollTracker.ext = {} end

local LibDBIcon	= LibStub("LibDBIcon-1.0")

function iRollTrackerFrame_Options_OnShow(self)
	self:ClearAllPoints()
	self:SetPoint("CENTER", iRollTrackerFrame)

	local DB = ItemRollTrackerDB
	self.showMinimapButton:SetChecked(not DB.ldbicon.hide)
	self.maxRollThreshold.editbox:SetNumber(DB.options.maxRollThreshold)
end

function iRollTrackerFrame_Options_SetDefaults(self, button, down)
	local window = self:GetParent()
	window.showMinimapButton:SetChecked(true)
	window.maxRollThreshold.editbox:SetNumber(100)
end

function iRollTrackerFrame_Options_OnAccept(self, button, down)
	local window = self:GetParent()

	ItemRollTrackerDB.ldbicon.hide = not window.showMinimapButton:GetChecked()

	if ItemRollTrackerDB.ldbicon.hide then
		LibDBIcon:Hide("Item Roll Tracker Icon")
	else
		LibDBIcon:Show("Item Roll Tracker Icon")
	end

	window:Hide()
end
