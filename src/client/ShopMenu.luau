-- Tienda: rastros, efectos de salto y de deslizamiento, y el pase VIP.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local ClientState = require(script.Parent:WaitForChild("ClientState"))
local HUD = require(script.Parent:WaitForChild("HUD"))
local MapMenu = require(script.Parent:WaitForChild("MapMenu"))
local UI = require(script.Parent:WaitForChild("UI"))

local player = Players.LocalPlayer

local ShopMenu = {}

local PANEL = "Shop"

local currentKind = "Trail"
local grid: ScrollingFrame
local tabButtons: { [string]: TextButton } = {}
local vipButton: TextButton
local panelFrame: Frame

function ShopMenu.promptVip()
	if Config.VipGamePassId == 0 then
		HUD.popup("El pase VIP aún no está configurado", UI.Colors.Bad, "Pon el ID del Game Pass en Config.VipGamePassId")
		return
	end
	MarketplaceService:PromptGamePassPurchase(player, Config.VipGamePassId)
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

local function refresh()
	for kind, button in tabButtons do
		button.BackgroundColor3 = if kind == currentKind then UI.Colors.Accent else UI.Colors.Card
	end
	local data = ClientState.data
	vipButton.Text = if data and data.vip then "⭐ Eres VIP" else "⭐ Hazte VIP"

	for _, child in grid:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
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
	vipButton = UI.button(tabs, "⭐ Hazte VIP", UI.Colors.Gold, {
		Size = UDim2.fromOffset(170, 44),
		LayoutOrder = 10,
		TextColor3 = UI.Colors.Background,
	})
	vipButton.Activated:Connect(function()
		local data = ClientState.data
		if data and data.vip then
			HUD.popup("VIP: mapa Cielo, objetos exclusivos y +50% de monedas", UI.Colors.Gold)
		else
			ShopMenu.promptVip()
		end
	end)

	grid = UI.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 54),
		Size = UDim2.new(1, 0, 1, -54),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, content)
	UI.new("UIGridLayout", {
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
