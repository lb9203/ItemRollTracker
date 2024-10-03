if iRollTracker == nil then iRollTracker = {} end
if iRollTracker.ext == nil then iRollTracker.ext = {} end

----------------------
-- Imported Aliases --
----------------------
-- Header `#include`s aren't supported.
-- This is the most concise workaround.

-- color.lua
local const_colortable = iRollTracker.ext.const_colortable
local Colorize = iRollTracker.ext.Colorize

---------------
-- Constants --
---------------
local const_text_addonname = "Item Roll Tracker"
local const_version = "v" .. C_AddOns.GetAddOnMetadata("ItemRollTracker", "Version")
local const_time_doubleclick = 0.500	-- Windows' default value
local const_frame_size_ignore = 2.0		-- threshold for counting frame sizes as equal
local const_namechars =
	"ÁÀÂÃÄÅ" .. "áàâãäå" ..
	"ÉÈÊË"   .. "éèêë"   ..
	"ÍÌÎÏ"   .. "íìîï"   ..
	"ÓÒÔÕÖØ" .. "óòôõöø" ..
	"ÚÙÛÜ"   .. "úùûü"   ..
	"ÝŸ"     .. "ýÿ"     ..
	"ÆÇÐÑ"   .. "æçðñ"   .. "ß"
local const_path_icon_LDB =
	"Interface\\AddOns\\ItemRollTracker\\rc\\ItemRollTracker - minimap.tga"
local const_path_icon_unknown =
	"Interface\\AddOns\\ItemRollTracker\\rc\\icon-unknown.tga"

iRollTracker.ext.const_text_addonname = const_text_addonname
iRollTracker.ext.const_version = const_version
iRollTracker.ext.const_time_doubleclick = const_time_doubleclick
iRollTracker.ext.const_frame_size_ignore = const_frame_size_ignore
iRollTracker.ext.const_namechars = const_namechars
iRollTracker.ext.const_path_icon_LDB = const_path_icon_LDB
iRollTracker.ext.const_path_icon_unknown = const_path_icon_unknown
