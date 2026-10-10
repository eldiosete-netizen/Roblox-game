-- Tienda: rastros, efectos de salto y de deslizamiento (con monedas) y
-- pases de Robux (VIP y multiplicadores de monedas, que se compran en orden).

local MarketplaceService = game:GetService("MarketplaceService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local ClientState = require(script.Parent:WaitForChild("ClientState"))
local HUD = require(script.Parent:WaitForChild("HUD"))
local MapMenu = require(script.Parent:WaitForChild("MapMenu"))
local UI = require(script.Parent:WaitForChild("UI"))

local ShopMenu = {}

local PANEL = "Shop"
local PASSES = "Passes" -- pestaña de Robux

local currentKind = "Trail"
local grid: ScrollingFrame
local gridLayout: UIGridLayout
local tabButtons: { [string]: TextButton } = {}
local panelFrame: Frame

-- El servidor comprueba que se pueda comprar (orden de los pases) y abre la compra
function ShopMenu.promptPass(key: string)
	Remotes.PromptPass:FireServer(key)
end

function ShopMenu.promptVip()
	ShopMenu.promptPass("vip")
end

local function itemState(item: Catalog.Item): string
	local data = ClientState.data
	if not data then
		return "locked"
	end
	local equipped = data.equipped[item.kind] or Catalog.Defaults[item.kind]
	if equipped == item.id then
		return "equipped"
	end
	if item.vip then
		return if data.vip then "owned" else "vip"
	end
	if item.price == 0 or data.owned[item.id] then
		return "owned"
	end
	return if data.coins >= item.price then "buy" else "expensive"
end

local function onItemClicked(item: Catalog.Item, state: string)
	if state == "vip" then
		ShopMenu.promptVip()
		return
	end
	local remote = if state == "buy" then Remotes.Purchase elseif state == "owned" then Remotes.Equip else nil
	if not remote then
		if state == "expensive" then
			HUD.popup("No tienes suficientes monedas", UI.Colors.Bad)
		end
		return
	end
	local ok, message = remote:InvokeServer(item.id)
	if message then
		HUD.popup(message, if ok then UI.Colors.Good else UI.Colors.Bad)
	end
end

-- Pases de Robux ----------------------------------------------------------------------

type PassInfo = {
	key: string,
	id: number,
	title: string,
	description: string,
	color: Color3,
	emblem: string,
	requires: string?,
	requiresName: string?,
}

-- Color de cada pase (igual que en sus imágenes)
local PASS_COLORS = {
	vip = Color3.fromRGB(255, 205, 40),
	coins2 = Color3.fromRGB(0, 168, 255),
	coins3 = Color3.fromRGB(0, 201, 107),
	coins5 = Color3.fromRGB(155, 77, 255),
	coins10 = Color3.fromRGB(255, 46, 91),
}

local function passList(): { PassInfo }
	local list = {
		{
			key = "vip",
			id = Config.VipGamePassId,
			title = "VIP",
			description = "Mapa Cielo, objetos exclusivos y +50% monedas",
			color = PASS_COLORS.vip,
			emblem = "👑",
		},
	}
	for i, pass in Config.CoinPasses do
		local previous = Config.CoinPasses[i - 1]
		table.insert(list, {
			key = pass.key,
			id = pass.id,
			title = string.format("Monedas x%d", pass.multiplier),
			description = string.format("Ganas %d veces más monedas", pass.multiplier),
			color = PASS_COLORS[pass.key] or UI.Colors.Gold,
			emblem = "⚡",
			requires = previous and previous.key,
			requiresName = previous and string.format("x%d", previous.multiplier),
		})
	end
	return list
end

-- Precio e imagen de cada pase (se piden a Roblox una vez y se guardan)
type ProductInfo = { price: number?, icon: number? }
local productInfo: { [number]: ProductInfo | false } = {}
local refresh: () -> ()

local function getInfo(id: number): ProductInfo?
	local info = productInfo[id]
	if info == nil and id ~= 0 then
		productInfo[id] = false
		task.spawn(function()
			local ok, result = pcall(MarketplaceService.GetProductInfo, MarketplaceService, id, Enum.InfoType.GamePass)
			productInfo[id] = {
				price = if ok and result then result.PriceInRobux else nil,
				icon = if ok and result and result.IconImageAssetId ~= 0 then result.IconImageAssetId else nil,
			}
			if panelFrame.Visible and currentKind == PASSES then
				refresh()
			end
		end)
	end
	return if info then info else nil
end

-- Imagen del pase: la que subiste a Roblox o, si aún no hay, una moneda dibujada
local function passImage(parent: Instance, pass: PassInfo)
	local info = getInfo(pass.id)
	if info and info.icon then
		local image = UI.new("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 10),
			Size = UDim2.fromOffset(78, 78),
			BackgroundTransparency = 1,
			Image = "rbxassetid://" .. info.icon,
		}, parent)
		UI.corner(image, 12)
		return
	end
	local emblem = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.fromOffset(70, 70),
		BackgroundColor3 = Color3.fromRGB(255, 200, 40),
	}, parent)
	UI.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, emblem)
	UI.new("UIStroke", { Color = pass.color, Thickness = 4 }, emblem)
	UI.new("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(255, 245, 170), Color3.fromRGB(240, 150, 0)),
		Rotation = 90,
	}, emblem)
	UI.label(emblem, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.7, 0.7),
		Text = pass.emblem,
	})
end

local function renderPasses()
	local data = ClientState.data
	local owned = data and data.ownedPasses or {}
	for i, pass in passList() do
		local card = UI.new("Frame", {
			Name = pass.key,
			BackgroundColor3 = UI.Colors.Card,
			LayoutOrder = i,
		}, grid)
		UI.corner(card, 10)
		UI.new("UIStroke", { Color = pass.color, Thickness = 2, Transparency = 0.3 }, card)

		passImage(card, pass)
		UI.label(card, {
			Position = UDim2.fromOffset(8, 94),
			Size = UDim2.new(1, -16, 0, 26),
			Font = Enum.Font.GothamBlack,
			TextColor3 = pass.color,
			Text = pass.title,
		})
		UI.label(card, {
			Position = UDim2.fromOffset(8, 122),
			Size = UDim2.new(1, -16, 0, 30),
			Font = Enum.Font.Gotham,
			TextColor3 = UI.Colors.Muted,
			TextWrapped = true,
			Text = pass.description,
		})

		local text, color, textColor, action = "", UI.Colors.Card, UI.Colors.Text, nil
		if owned[pass.key] then
			text, color = "✓ Comprado", UI.Colors.Good
		elseif pass.id == 0 then
			text, textColor = "Próximamente", UI.Colors.Muted
		elseif pass.requires and not owned[pass.requires] then
			text, textColor = "🔒 Antes " .. (pass.requiresName or ""), UI.Colors.Muted
			action = function()
				HUD.popup("Primero compra Monedas " .. (pass.requiresName or ""), UI.Colors.Bad)
			end
		else
			local info = getInfo(pass.id)
			local price = if info and info.price then string.format("R$ %d", info.price) else "Comprar"
			text, color, textColor = price, UI.Colors.Gold, UI.Colors.Background
			action = function()
				ShopMenu.promptPass(pass.key)
			end
		end
		local button = UI.button(card, text, color, {
			Position = UDim2.new(0, 10, 1, -46),
			Size = UDim2.new(1, -20, 0, 36),
			TextColor3 = textColor,
		})
		if action then
			button.Activated:Connect(action)
		end
	end
end

function refresh()
	for kind, button in tabButtons do
		local selected = kind == currentKind
		button.BackgroundColor3 = if selected then UI.Colors.Accent elseif kind == PASSES then UI.Colors.Gold else UI.Colors.Card
		button.TextColor3 = if kind == PASSES and not selected then UI.Colors.Background else UI.Colors.Text
	end

	for _, child in grid:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	-- Las tarjetas de pases son más altas para que quepa la imagen
	gridLayout.CellSize = if currentKind == PASSES then UDim2.fromOffset(150, 200) else UDim2.fromOffset(150, 150)
	if currentKind == PASSES then
		renderPasses()
		return
	end

	for i, item in Catalog.Items do
		if item.kind ~= currentKind then
			continue
		end
		local state = itemState(item)
		local card = UI.new("Frame", {
			Name = item.id,
			BackgroundColor3 = UI.Colors.Card,
			LayoutOrder = i,
		}, grid)
		UI.corner(card, 10)

		local preview = UI.new("Frame", {
			Position = UDim2.fromOffset(10, 10),
			Size = UDim2.new(1, -20, 0, 50),
			BackgroundColor3 = Color3.new(1, 1, 1),
		}, card)
		UI.corner(preview, 8)
		UI.new("UIGradient", { Color = Catalog.colorSequence(item) }, preview)

		UI.label(card, {
			Position = UDim2.fromOffset(10, 66),
			Size = UDim2.new(1, -20, 0, 24),
			Text = (if item.vip then "⭐ " else "") .. item.name,
		})

		local text, color
		if state == "equipped" then
			text, color = "Equipado", UI.Colors.Good
		elseif state == "owned" then
			text, color = "Equipar", UI.Colors.Accent
		elseif state == "vip" then
			text, color = "Solo VIP", UI.Colors.Gold
		elseif state == "buy" then
			text, color = string.format("🪙 %d", item.price), UI.Colors.Gold
		else
			text, color = string.format("🪙 %d", item.price), UI.Colors.Muted
		end
		local button = UI.button(card, text, color, {
			Position = UDim2.new(0, 10, 1, -46),
			Size = UDim2.new(1, -20, 0, 36),
			TextColor3 = if state == "buy" or state == "vip" then UI.Colors.Background else UI.Colors.Text,
		})
		button.Activated:Connect(function()
			onItemClicked(item, state)
		end)
	end
end

function ShopMenu.open(kind: string?)
	if kind then
		currentKind = kind
	end
	UI.open(PANEL)
end

function ShopMenu.start()
	local frame, content = UI.panel(HUD.gui, PANEL, "🛒  Tienda", UDim2.fromOffset(720, 560))
	panelFrame = frame

	local tabs = UI.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 44),
	}, content)
	UI.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 10),
	}, tabs)
	for i, kind in Catalog.Kinds do
		local button = UI.button(tabs, kind.name, UI.Colors.Card, {
			Size = UDim2.fromOffset(150, 44),
			LayoutOrder = i,
		})
		button.Activated:Connect(function()
			currentKind = kind.id
			refresh()
		end)
		tabButtons[kind.id] = button
	end
	local passesButton = UI.button(tabs, "⭐ Robux", UI.Colors.Gold, {
		Size = UDim2.fromOffset(170, 44),
		LayoutOrder = 10,
		TextColor3 = UI.Colors.Background,
	})
	passesButton.Activated:Connect(function()
		currentKind = PASSES
		refresh()
	end)
	tabButtons[PASSES] = passesButton

	grid = UI.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 54),
		Size = UDim2.new(1, 0, 1, -54),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, content)
	gridLayout = UI.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(150, 150),
		CellPadding = UDim2.fromOffset(12, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid)

	UI.onOpen(PANEL, refresh)
	ClientState.Changed:Connect(function()
		if panelFrame.Visible then
			refresh()
		end
	end)

	HUD.addSideButton("🛒 Tienda", 20, UI.Colors.Gold, function()
		UI.toggle(PANEL)
	end)

	-- Puesto de tienda del lobby: abre directamente los pases
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Name == "ShopPrompt" then
			ShopMenu.open(PASSES)
		end
	end)

	-- Mapas VIP bloqueados en el selector
	MapMenu.decorateCards(function(_card, folder, playButton)
		local data = ClientState.data
		if folder:GetAttribute("Vip") and not (data and data.vip) then
			playButton.Text = "⭐ VIP"
			playButton.BackgroundColor3 = UI.Colors.Gold
			playButton.TextColor3 = UI.Colors.Background
			return ShopMenu.promptVip
		end
		return nil
	end)
end

return ShopMenu
