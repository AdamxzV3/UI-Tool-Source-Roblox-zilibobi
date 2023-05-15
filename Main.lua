if game:GetService("RunService"):IsRunning() then return end -- check if running in the playtest mode

local VERSION = "v2.1"
local VERSION_ASSET_ID = 12280247035

local BUILD_INTEGER = 93

-- services
local StudioService = game:GetService("StudioService")
local MarketplaceService = game:GetService("MarketplaceService")

-- set up a module search function
local meta = {}
meta.__call = function(array, query)
	local result = array.modules[query]

	if result then
		return require(result)
	else
		error(
			("/could not find module '%s'/"):format(query)
		)
	end
end

-- find all modules and put them in one table
local list, whitelist = { modules = {} }, { "packages", "source", "tools", "components", "util" }

local function addModule(module, path)
	-- check for name uniqueness
	if list.modules[module.Name] then
		error(
			("/cannot have two identical names '%s'/"):format(module.Name)
		)
	else
		list.modules[module.Name] = module
	end
end

local function search(folder)
	for _, item in ipairs(folder:GetChildren()) do
		if item:IsA("ModuleScript") then
			addModule(item)
		elseif item:IsA("Folder") and table.find(whitelist, item.Name) then
			task.spawn(search, item)
		end
	end
end

search(script)

local main = setmetatable(list, meta)
_G[plugin.Name] = main

-- create the main widget and the buttons
--[[ widget specs ref

DockWidgetPluginGuiInfo.new(
	initState: Enum.InitialDockState,
	initEnabled: boolean,
	overrideEnabledRestore: boolean,
	floatXSize: number,
	floatYSize: number,
	minWidth: number,
	minHeight: number
)

--]]

local widgets = {}

local function makeWidget(name, title, full, specs)
	local widget = plugin:CreateDockWidgetPluginGui(name, specs)
	widget.Name = name .. " ".. VERSION
	widget.Title = full and title .. " " .. VERSION or title
	widget.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	table.insert(widgets, widget)
	return widget
end

local toolbar = plugin:CreateToolbar("UI Tools")
local button = toolbar:CreateButton("Open", "Launch the plugin.", "")
local import = toolbar:CreateButton("Styling", "Import a custom JSON plugin style.", "")

local widget = makeWidget("UI Tools", "UI Tools", true, DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Left, true, false, 275, 300, 275, 300)
)

button:SetActive(widget.Enabled)

button.ClickableWhenViewportHidden = true
import.ClickableWhenViewportHidden = true

-- other widgets
local anchor_widget = makeWidget("Anchor Editor", "Anchor Editor", false, DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Left, false, true, 124, 190, 124, 190)
)

local properties_widget = makeWidget("UI Properties", "UI Properties", false, DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Left, false, true, 251, 385, 251, 385)
)

-- events
button.Click:Connect(function()
	widget.Enabled = not widget.Enabled
	button:SetActive(widget.Enabled)
end)

widget:BindToClose(function()
	button:SetActive(false)
	widget.Enabled = false
end)

-- global references
_G[plugin.Name].widget = widget
_G[plugin.Name].anchor_widget = anchor_widget
_G[plugin.Name].properties_widget = properties_widget

_G[plugin.Name].unbound_connections = {}
_G[plugin.Name].config = main("config")

plugin.Unloading:Connect(function()
	for _, con in pairs(_G[plugin.Name].unbound_connections) do
		con:disconnect()
	end

	for _, widget in ipairs(widgets) do
		widget:Destroy()
	end

	_G[plugin.Name] = nil
end)

-- add interface
for _, folder in ipairs(script.interface:GetChildren()) do
	for _, item in ipairs(folder:GetChildren()) do
		item.Parent = _G[plugin.Name][folder.name]
	end
end

-- initialize
main("settings")

-- check for version
if main.config.settings["Check for updates"] then
	task.spawn(function()
		local success, response = pcall(function()
			return MarketplaceService:GetProductInfo(VERSION_ASSET_ID, Enum.InfoType.Asset)
		end)

		if not success then
			warn(
				("/could not check for updates: %s/"):format(response)
			)
		elseif response.Name ~= VERSION then
			widget.Plugin.Update.Text = string.format("Version <font family=\"Inconsolata\" weight=\"heavy\">%s</font> is now available!", response.Name)
			widget.Plugin.Update.Visible = true
		end
	end)
end

-- show current build id
widget.BuildId.Text = "build " .. string.format("%x", Random.new(BUILD_INTEGER):NextNumber(0, 1) * 0xf00000)

-- main tool modules
main("conversion") -- converts udim and udim2 values to scale or offset
main("anchors") -- anchor editor
main("properties") -- ui properties

-- other
main("scrolling")(widget)
main("scrolling")(properties_widget)

-- import custom style
local theme = main("theme")
local selecting = false

theme.dynamicButton(button, "rbxassetid://13000463547", "rbxassetid://13000537974")
theme.dynamicButton(import, "rbxassetid://13000466281", "rbxassetid://13000539673")

import.Click:Connect(function()
	if selecting then return end
	selecting = true

	local style = StudioService:PromptImportFile({ "json" })
	selecting = false

	if style then
		theme.applyStyling(style:GetBinaryContents())
	end
end)

-- refresh the theme
theme.refresh()
