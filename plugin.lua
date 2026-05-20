--!strict
-- Gemini AI Roblox Studio Assistant Plugin
-- Author: Antigravity AI
-- Description: Natural language game modification using Google's Gemini 2.5 API.

local HttpService = game:GetService("HttpService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Selection = game:GetService("Selection")
local Studio = settings().Studio

-- ==========================================
-- CONFIGURATION & CONSTANTS
-- ==========================================
local SETTING_KEY = "GeminiAI_APIKey"
local GEMINI_MODEL = "gemini-2.5-flash"
local DOCK_WIDGET_ID = "GeminiAIAssistantWidget"
local TOOLBAR_NAME = "Gemini AI"
local TOOLBAR_BUTTON_ID = "ToggleGeminiAssistant"

local SYSTEM_INSTRUCTION = [[You are an expert Roblox Studio Developer Assistant.
Your task is to generate valid, executable Luau code that creates, modifies, or inspects instances in the active Roblox game environment based on the user's natural language request.

CRITICAL RULES:
1. ONLY return raw, valid, and executable Luau code.
2. DO NOT wrap the code in markdown code blocks like ```lua ... ``` or ``` ... ```.
3. DO NOT include any explanatory text, comments, warnings, or conversational dialogue. The output must be pure code that can be passed directly to loadstring().
4. Use standard Roblox APIs and services correctly (e.g., game:GetService("Workspace"), Instance.new(), task.wait, etc.).
5. Ensure the code is self-contained and handles basic error cases where appropriate.
6. The script will run within the context of a Roblox Studio plugin, meaning it has full Studio security permissions.

Example User Request: Create a red neon block at the origin
Your Output:
local part = Instance.new("Part")
part.Size = Vector3.new(4, 4, 4)
part.Position = Vector3.new(0, 2, 0)
part.Material = Enum.Material.Neon
part.Color = Color3.fromRGB(255, 0, 0)
part.Anchored = true
part.Parent = workspace
]]

-- ==========================================
-- THEME SYSTEM & STYLING UTILITIES
-- ==========================================
local themedElements = {}

local function getStudioColor(colorType: Enum.StudioStyleGuideColor, modifier: Enum.StudioStyleGuideModifier?)
	local mod = modifier or Enum.StudioStyleGuideModifier.Default
	local success, color = pcall(function()
		return Studio.Theme:GetColor(colorType, mod)
	end)
	if success then
		return color
	else
		-- Fallbacks for backward compatibility
		if colorType == Enum.StudioStyleGuideColor.MainBackground then
			return Color3.fromRGB(46, 46, 46)
		elseif colorType == Enum.StudioStyleGuideColor.MainText then
			return Color3.fromRGB(240, 240, 240)
		else
			return Color3.fromRGB(128, 128, 128)
		end
	end
end

local function registerElement(element: GuiObject, property: string, colorType: Enum.StudioStyleGuideColor, modifier: Enum.StudioStyleGuideModifier?)
	table.insert(themedElements, {
		element = element,
		property = property,
		colorType = colorType,
		modifier = modifier or Enum.StudioStyleGuideModifier.Default
	})
	element[property] = getStudioColor(colorType, modifier)
end

local function updateTheme()
	for _, item in ipairs(themedElements) do
		pcall(function()
			item.element[item.property] = getStudioColor(item.colorType, item.modifier)
		end)
	end
end

Studio.ThemeChanged:Connect(updateTheme)

-- ==========================================
-- UI DESIGN & ASSEMBLY
-- ==========================================
local guiInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Right,
	true,
	false,
	320,
	550,
	280,
	400
)

local dockWidget = plugin:CreateDockWidgetPluginGui(DOCK_WIDGET_ID, guiInfo)
dockWidget.Title = "Gemini AI Assistant"

-- Scrollable main container
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size = UDim2.new(1, 0, 1, 0)
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel = 0
scrollFrame.ScrollBarThickness = 6
scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollFrame.Parent = dockWidget

local uiPadding = Instance.new("UIPadding")
uiPadding.PaddingLeft = UDim.new(0, 12)
uiPadding.PaddingRight = UDim.new(0, 12)
uiPadding.PaddingTop = UDim.new(0, 12)
uiPadding.PaddingBottom = UDim.new(0, 12)
uiPadding.Parent = scrollFrame

local uiList = Instance.new("UIListLayout")
uiList.SortOrder = Enum.SortOrder.LayoutOrder
uiList.Padding = UDim.new(0, 14)
uiList.Parent = scrollFrame

-- Standard Header Label Builder
local function createSectionHeader(text: string, layoutOrder: number)
	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(1, 0, 0, 20)
	header.BackgroundTransparency = 1
	header.Font = Enum.Font.SourceSansBold
	header.TextSize = 14
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.LayoutOrder = layoutOrder
	registerElement(header, "TextColor3", Enum.StudioStyleGuideColor.SubText)
	header.Text = text:upper()
	header.Parent = scrollFrame
	return header
end

-- ------------------------------------------
-- 1. API KEY CONFIGURATION SECTION
-- ------------------------------------------
createSectionHeader("1. API Key Setup", 1)

local apiKeyFrame = Instance.new("Frame")
apiKeyFrame.Size = UDim2.new(1, 0, 0, 36)
apiKeyFrame.BorderSizePixel = 0
apiKeyFrame.LayoutOrder = 2
registerElement(apiKeyFrame, "BackgroundColor3", Enum.StudioStyleGuideColor.MainBackground)
apiKeyFrame.Parent = scrollFrame

local apiKeyStroke = Instance.new("UIStroke")
apiKeyStroke.Thickness = 1
registerElement(apiKeyStroke, "Color", Enum.StudioStyleGuideColor.Border)
apiKeyStroke.Parent = apiKeyFrame

local apiKeyCorner = Instance.new("UICorner")
apiKeyCorner.CornerRadius = UDim.new(0, 6)
apiKeyCorner.Parent = apiKeyFrame

local keyInput = Instance.new("TextBox")
keyInput.Size = UDim2.new(1, -95, 1, 0)
keyInput.Position = UDim2.new(0, 10, 0, 0)
keyInput.BackgroundTransparency = 1
keyInput.Font = Enum.Font.SourceSans
keyInput.TextSize = 14
keyInput.TextXAlignment = Enum.TextXAlignment.Left
keyInput.PlaceholderText = "Enter Gemini API Key..."
keyInput.ClearTextOnFocus = false
registerElement(keyInput, "TextColor3", Enum.StudioStyleGuideColor.InputFieldValue)
keyInput.Parent = apiKeyFrame

-- Mask API key helper
local function getMaskedKey(key: string): string
	if #key <= 8 then
		return string.rep("•", #key)
	end
	return string.sub(key, 1, 4) .. string.rep("•", #key - 8) .. string.sub(key, -4)
end

local savedKey = plugin:GetSetting(SETTING_KEY) or ""
local currentKey = savedKey
if savedKey ~= "" then
	keyInput.Text = getMaskedKey(savedKey)
end

keyInput.Focused:Connect(function()
	if currentKey ~= "" then
		keyInput.Text = currentKey
	end
end)

keyInput.FocusLost:Connect(function()
	currentKey = keyInput.Text
	if currentKey ~= "" and currentKey ~= savedKey then
		-- Keep showing current value until saved or refocused
	elseif currentKey == "" then
		keyInput.Text = ""
	else
		keyInput.Text = getMaskedKey(currentKey)
	end
end)

local saveKeyBtn = Instance.new("TextButton")
saveKeyBtn.Size = UDim2.new(0, 75, 1, -8)
saveKeyBtn.Position = UDim2.new(1, -80, 0, 4)
saveKeyBtn.BorderSizePixel = 0
saveKeyBtn.Font = Enum.Font.SourceSansBold
saveKeyBtn.TextSize = 13
saveKeyBtn.Text = "Save Key"
registerElement(saveKeyBtn, "BackgroundColor3", Enum.StudioStyleGuideColor.Button)
registerElement(saveKeyBtn, "TextColor3", Enum.StudioStyleGuideColor.ButtonText)
saveKeyBtn.Parent = apiKeyFrame

local saveKeyCorner = Instance.new("UICorner")
saveKeyCorner.CornerRadius = UDim.new(0, 4)
saveKeyCorner.Parent = saveKeyBtn

-- Save action
saveKeyBtn.MouseButton1Click:Connect(function()
	local keyToSave = currentKey
	if keyToSave ~= "" then
		plugin:SetSetting(SETTING_KEY, keyToSave)
		savedKey = keyToSave
		keyInput.Text = getMaskedKey(keyToSave)
		keyInput:ReleaseFocus()
		print("[Gemini AI] API Key saved securely.")
	else
		plugin:SetSetting(SETTING_KEY, nil)
		savedKey = ""
		keyInput.Text = ""
		print("[Gemini AI] API Key cleared.")
	end
end)

-- Save button Hover Effect
saveKeyBtn.MouseEnter:Connect(function()
	saveKeyBtn.BackgroundColor3 = getStudioColor(Enum.StudioStyleGuideColor.Button, Enum.StudioStyleGuideModifier.Hover)
end)
saveKeyBtn.MouseLeave:Connect(function()
	saveKeyBtn.BackgroundColor3 = getStudioColor(Enum.StudioStyleGuideColor.Button)
end)

-- ------------------------------------------
-- 2. PROMPT INPUT SECTION
-- ------------------------------------------
createSectionHeader("2. Instruct Gemini", 3)

local promptFrame = Instance.new("Frame")
promptFrame.Size = UDim2.new(1, 0, 0, 110)
promptFrame.BorderSizePixel = 0
promptFrame.LayoutOrder = 4
registerElement(promptFrame, "BackgroundColor3", Enum.StudioStyleGuideColor.InputFieldBackground)
promptFrame.Parent = scrollFrame

local promptStroke = Instance.new("UIStroke")
promptStroke.Thickness = 1
registerElement(promptStroke, "Color", Enum.StudioStyleGuideColor.InputFieldBorder)
promptStroke.Parent = promptFrame

local promptCorner = Instance.new("UICorner")
promptCorner.CornerRadius = UDim.new(0, 6)
promptCorner.Parent = promptFrame

local promptInput = Instance.new("TextBox")
promptInput.Size = UDim2.new(1, -16, 1, -16)
promptInput.Position = UDim2.new(0, 8, 0, 8)
promptInput.BackgroundTransparency = 1
promptInput.MultiLine = true
promptInput.TextWrapped = true
promptInput.Font = Enum.Font.SourceSans
promptInput.TextSize = 14
promptInput.TextXAlignment = Enum.TextXAlignment.Left
promptInput.TextYAlignment = Enum.TextYAlignment.Top
promptInput.PlaceholderText = "e.g., Create a helix of neon parts that change color on touch..."
promptInput.ClearTextOnFocus = false
registerElement(promptInput, "TextColor3", Enum.StudioStyleGuideColor.InputFieldValue)
promptInput.Parent = promptFrame

-- ------------------------------------------
-- 3. ACTIONS PANEL SECTION
-- ------------------------------------------
local actionsFrame = Instance.new("Frame")
actionsFrame.Size = UDim2.new(1, 0, 0, 36)
actionsFrame.BackgroundTransparency = 1
actionsFrame.LayoutOrder = 5
actionsFrame.Parent = scrollFrame

local actionsLayout = Instance.new("UIListLayout")
actionsLayout.FillDirection = Enum.FillDirection.Horizontal
actionsLayout.SortOrder = Enum.SortOrder.LayoutOrder
actionsLayout.Padding = UDim.new(0, 10)
actionsLayout.Parent = actionsFrame

-- Generic button builder
local function createActionButton(text: string, layoutOrder: number)
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(0.5, -5, 1, 0)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.SourceSansBold
	button.TextSize = 14
	button.Text = text
	button.LayoutOrder = layoutOrder
	registerElement(button, "BackgroundColor3", Enum.StudioStyleGuideColor.Button)
	registerElement(button, "TextColor3", Enum.StudioStyleGuideColor.ButtonText)
	button.Parent = actionsFrame
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = button
	
	button.MouseEnter:Connect(function()
		button.BackgroundColor3 = getStudioColor(Enum.StudioStyleGuideColor.Button, Enum.StudioStyleGuideModifier.Hover)
	end)
	button.MouseLeave:Connect(function()
		button.BackgroundColor3 = getStudioColor(Enum.StudioStyleGuideColor.Button)
	end)
	
	return button
end

local runCodeBtn = createActionButton("⚡ Run Code Directly", 1)
local makeScriptBtn = createActionButton("📁 Create Script", 2)

-- ------------------------------------------
-- 4. CONSOLE / LOG OUTPUT SECTION
-- ------------------------------------------
createSectionHeader("3. Console Log", 6)

local consoleFrame = Instance.new("Frame")
consoleFrame.Size = UDim2.new(1, 0, 0, 160)
consoleFrame.BorderSizePixel = 0
consoleFrame.LayoutOrder = 7
registerElement(consoleFrame, "BackgroundColor3", Enum.StudioStyleGuideColor.DarkerBackground)
consoleFrame.Parent = scrollFrame

local consoleStroke = Instance.new("UIStroke")
consoleStroke.Thickness = 1
registerElement(consoleStroke, "Color", Enum.StudioStyleGuideColor.Border)
consoleStroke.Parent = consoleFrame

local consoleCorner = Instance.new("UICorner")
consoleCorner.CornerRadius = UDim.new(0, 6)
consoleCorner.Parent = consoleFrame

local consoleScroll = Instance.new("ScrollingFrame")
consoleScroll.Size = UDim2.new(1, -12, 1, -12)
consoleScroll.Position = UDim2.new(0, 6, 0, 6)
consoleScroll.BackgroundTransparency = 1
consoleScroll.BorderSizePixel = 0
consoleScroll.ScrollBarThickness = 4
consoleScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
consoleScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
consoleScroll.Parent = consoleFrame

local consoleList = Instance.new("UIListLayout")
consoleList.SortOrder = Enum.SortOrder.LayoutOrder
consoleList.Padding = UDim.new(0, 4)
consoleList.Parent = consoleScroll

local function logConsole(message: string, logType: "Info" | "Success" | "Warning" | "Error")
	local timeString = os.date("%X")
	local logLabel = Instance.new("TextLabel")
	logLabel.Size = UDim2.new(1, 0, 0, 0)
	logLabel.AutomaticSize = Enum.AutomaticSize.Y
	logLabel.BackgroundTransparency = 1
	logLabel.Font = Enum.Font.Code
	logLabel.TextSize = 12
	logLabel.TextWrapped = true
	logLabel.TextXAlignment = Enum.TextXAlignment.Left
	logLabel.Parent = consoleScroll
	
	local color = Color3.fromRGB(200, 200, 200)
	if logType == "Success" then
		color = Color3.fromRGB(85, 255, 127)
	elseif logType == "Warning" then
		color = Color3.fromRGB(255, 170, 0)
	elseif logType == "Error" then
		color = Color3.fromRGB(255, 85, 85)
	elseif logType == "Info" then
		color = Color3.fromRGB(85, 170, 255)
	end
	logLabel.TextColor3 = color
	logLabel.Text = string.format("[%s] %s: %s", timeString, logType:upper(), message)
	
	-- Autoscroll to bottom
	task.defer(function()
		consoleScroll.CanvasPosition = Vector2.new(0, consoleScroll.AbsoluteCanvasSize.Y)
	end)
end

logConsole("Plugin loaded successfully. Ready for instructions.", "Success")

-- ==========================================
-- CORE LOGIC & API INTEGRATION
-- ==========================================

local function sanitizeCode(rawCode: string): string
	-- Trim starting and trailing whitespace
	local clean = rawCode:gsub("^%s+", ""):gsub("%s+$", "")
	
	-- Handle markdown block extraction (```lua ... ``` or ``` ... ```)
	if clean:match("^```") then
		clean = clean:gsub("^```%w*\n*", "")
		clean = clean:gsub("```$", "")
	end
	
	-- Final whitespace trim
	clean = clean:gsub("^%s+", ""):gsub("%s+$", "")
	return clean
end

local function callGemini(apiKey: string, prompt: string): (string?, string?)
	local url = "https://generativelanguage.googleapis.com/v1beta/models/" .. GEMINI_MODEL .. ":generateContent?key=" .. apiKey
	
	local requestBody = {
		contents = {
			{
				role = "user",
				parts = {
					{ text = prompt }
				}
			}
		},
		systemInstruction = {
			parts = {
				{ text = SYSTEM_INSTRUCTION }
			}
		},
		generationConfig = {
			temperature = 0.15, -- Low temp for highly deterministic code generation
			maxOutputTokens = 2048
		}
	}
	
	local encodedBody
	local encodeSuccess, encodeErr = pcall(function()
		encodedBody = HttpService:JSONEncode(requestBody)
	end)
	
	if not encodeSuccess then
		return nil, "JSON serialization error: " .. tostring(encodeErr)
	end
	
	local success, response = pcall(function()
		return HttpService:RequestAsync({
			Url = url,
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/json"
			},
			Body = encodedBody
		})
	end)
	
	if not success then
		return nil, "Connection failed. Please ensure 'Allow HTTP Requests' is checked in game Security settings.\nDetails: " .. tostring(response)
	end
	
	if not response.Success then
		local okJson, errObj = pcall(function()
			return HttpService:JSONDecode(response.Body)
		end)
		if okJson and errObj and errObj.error and errObj.error.message then
			return nil, "Gemini API Error: " .. tostring(errObj.error.message)
		else
			return nil, "HTTP Request returned status: " .. tostring(response.StatusCode) .. " (" .. tostring(response.StatusMessage) .. ")"
		end
	end
	
	local okDecode, parsedData = pcall(function()
		return HttpService:JSONDecode(response.Body)
	end)
	
	if not okDecode then
		return nil, "Failed to parse Gemini response JSON."
	end
	
	local codeText
	pcall(function()
		codeText = parsedData.candidates[1].content.parts[1].text
	end)
	
	if not codeText or codeText == "" then
		return nil, "No response generated by the model. The input may have triggered safety filters."
	end
	
	return codeText, nil
end

local function executeRequest(actionType: "Run" | "Create")
	local apiKey = savedKey
	if apiKey == "" then
		logConsole("Error: Please provide a Gemini API Key first.", "Error")
		return
	end
	
	local prompt = promptInput.Text
	if prompt == "" or prompt == promptInput.PlaceholderText then
		logConsole("Error: Please enter a command prompt.", "Error")
		return
	end
	
	logConsole("Contacting Gemini API...", "Info")
	
	task.spawn(function()
		local rawCode, err = callGemini(apiKey, prompt)
		
		if err then
			logConsole(err, "Error")
			return
		end
		
		if not rawCode then
			logConsole("No output returned.", "Error")
			return
		end
		
		local sanitized = sanitizeCode(rawCode)
		if sanitized == "" then
			logConsole("Generated code was empty.", "Error")
			return
		end
		
		if actionType == "Run" then
			logConsole("Compiling Luau execution function...", "Info")
			local runner, compileErr = loadstring(sanitized, "GeminiAI_GeneratedRunner")
			if not runner then
				logConsole("Compilation Error: " .. tostring(compileErr), "Error")
				return
			end
			
			logConsole("Executing script inside Workspace...", "Info")
			ChangeHistoryService:SetWaypoint("Before Gemini Execution")
			
			local runSuccess, runErr = pcall(runner)
			
			if runSuccess then
				ChangeHistoryService:SetWaypoint("After Gemini Execution")
				logConsole("Successfully completed code execution! Scene updated.", "Success")
			else
				logConsole("Runtime Error: " .. tostring(runErr), "Error")
			end
			
		elseif actionType == "Create" then
			logConsole("Creating new Script instance...", "Info")
			ChangeHistoryService:SetWaypoint("Before Script Creation")
			
			local newScript = Instance.new("Script")
			newScript.Name = "GeminiAI_GeneratedScript"
			newScript.Source = "-- Generated by Gemini AI Assistant\n-- Prompt: " .. prompt .. "\n\n" .. sanitized
			newScript.Parent = workspace
			
			Selection:Set({newScript})
			
			ChangeHistoryService:SetWaypoint("After Script Creation")
			logConsole("Script created in Workspace and highlighted!", "Success")
		end
	end)
end

-- Wire buttons
runCodeBtn.MouseButton1Click:Connect(function()
	executeRequest("Run")
end)

makeScriptBtn.MouseButton1Click:Connect(function()
	executeRequest("Create")
end)

-- ==========================================
-- RIBBON BUTTON INITIALIZATION
-- ==========================================
local toolbar = plugin:CreateToolbar(TOOLBAR_NAME)
local toolbarButton = toolbar:CreateButton(
	TOOLBAR_BUTTON_ID,
	"Toggle Gemini AI Assistant",
	"rbxassetid://14254425712", -- Sparkle/AI style star icon
	"Gemini Assistant"
)

toolbarButton.Click:Connect(function()
	dockWidget.Enabled = not dockWidget.Enabled
end)

dockWidget:GetPropertyChangedSignal("Enabled"):Connect(function()
	toolbarButton:SetActive(dockWidget.Enabled)
end)

toolbarButton:SetActive(dockWidget.Enabled)

updateTheme()
