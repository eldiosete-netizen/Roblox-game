-- Tienda con estilo de dibujos: cabecera verde, secciones y tarjetas de colores.
--   Pases (Robux): VIP y multiplicadores de monedas, que se compran en orden.
--   Cosméticos (monedas): rastros, efectos de salto y de deslizamiento.

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
local FONT = Enum.Font.FredokaOne
local ROBUX = utf8.char(0xE002) -- icono de Robux en las fuentes de Roblox

local COLORS = {
	Header = Color3.fromRGB(70, 210, 50),
	HeaderLight = Color3.fromRGB(150, 245, 110),
	Body = Color3.fromRGB(42, 43, 50),
	BodyDark = Color3.fromRGB(28, 29, 34),
	Outline = Color3.fromRGB(15, 15, 20),
	Close = Color3.fromRGB(220, 30, 30),
	Price = Color3.fromRGB(90, 220, 60),
	Gold = Color3.fromRGB(255, 215, 60),
	Disabled = Color3.fromRGB(90, 92, 105),
	Equip = Color3.fromRGB(40, 150, 255),
}

-- Degradado de fondo de cada pase
local PASS_STYLE = {
	vip = { ColorSequence.new(Color3.fromRGB(255, 225, 90), Color3.fromRGB(215, 140, 0)), "👑" },
	coins2 = { ColorSequence.new(Color3.fromRGB(110, 210, 255), Color3.fromRGB(0, 105, 225)), "⚡" },
	coins3 = { ColorSequence.new(Color3.fromRGB(120, 245, 150), Color3.fromRGB(0, 165, 75)), "⚡" },
	coins5 = { ColorSequence.new(Color3.fromRGB(210, 150, 255), Color3.fromRGB(115, 45, 215)), "⚡" },
	coins10 = {
		ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 90)),
			ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 190, 40)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 220, 110)),
			ColorSequenceKeypoint.new(0.75, Color3.fromRGB(60, 160, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 80, 255)),
		}),
		"⚡",
	},
}

local panelFrame: Frame
local body: ScrollingFrame

-- Utilidades de estilo ----------------------------------------------------------------------

local function stroke(parent: Instance, thickness: number, color: Color3?)
	UI.new("UIStroke", { Thickness = thickness, Color = color or COLORS.Outline }, parent)
end

-- Texto blanco con contorno negro (como en los juegos de Roblox)
local function cartoonText(parent: Instance, props: { [string]: any }, strokeSize: number?): TextLabel
	local label = UI.label(parent, props)
	label.Font = FONT
	stroke(label, strokeSize or 2.5)
	return label
end

-- Botón con contorno negro; el texto va en una etiqueta aparte con su propio contorno
local function cartoonButton(parent: Instance, text: string, color: Color3, props: { [string]: any }): TextButton
	local button = UI.new("TextButton", {
		BackgroundColor3 = color,
		Text = "",
		AutoButtonColor = true,
	}, nil)
	for key, value in props do
		(button :: any)[key] = value
	end
	UI.corner(button, 8)
	UI.new("UIStroke", {
		Thickness = 3,
		Color = COLORS.Outline,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, button)
	cartoonText(button, {
		Position = UDim2.new(0, 6, 0, 5),
		Size = UDim2.new(1, -12, 1, -10),
		Text = text,
		ZIndex = button.ZIndex,
	})
	button.Parent = parent
	return button
end

-- Brillo diagonal: capa blanca con franjas hechas con un degradado de transparencia
-- (los marcos girados no se recortan, así que no usamos rotación)
local function shine(parent: GuiObject, radius: number?)
	local overlay = UI.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = parent.ZIndex,
	}, parent)
	if radius then
		UI.corner(overlay, radius)
	end
	UI.new("UIGradient", {
		Rotation = 60,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, 1),
			NumberSequenceKeypoint.new(0.31, 0.8),
			NumberSequenceKeypoint.new(0.42, 0.8),
			NumberSequenceKeypoint.new(0.43, 1),
			NumberSequenceKeypoint.new(0.5, 1),
			NumberSequenceKeypoint.new(0.51, 0.85),
			NumberSequenceKeypoint.new(0.54, 0.85),
			NumberSequenceKeypoint.new(0.55, 1),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, overlay)
end

local function section(title: string, order: number, cellSize: Vector2): Frame
	cartoonText(body, {
		Size = UDim2.new(1, 0, 0, 52),
		LayoutOrder = order,
		TextColor3 = COLORS.Gold,
		Text = "-- " .. title .. " --",
	}, 3)
	local grid = UI.new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = order + 1,
	}, body)
	UI.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(cellSize.X, cellSize.Y),
		CellPadding = UDim2.fromOffset(14, 14),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid)
	return grid
end

-- Tarjeta base: fondo con degradado, contorno negro y brillo
local function card(parent: Instance, order: number, gradient: ColorSequence): Frame
	local frame = UI.new("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		LayoutOrder = order,
	}, parent)
	UI.corner(frame, 10)
	UI.new("UIStroke", { Thickness = 3, Color = COLORS.Outline, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, frame)
	UI.new("UIGradient", { Color = gradient, Rotation = 35 }, frame)
	shine(frame, 10)
	return frame
end

-- Pases de Robux -----------------------------------------------------------------------------

type PassInfo = { key: string, id: number, title: string, description: string, requires: string?, requiresName: string? }

local function passList(): { PassInfo }
	local list = {
		{ key = "vip", id = Config.VipGamePassId, title = "VIP", description = "¡Mapa Cielo, objetos exclusivos y +50% monedas!" },
	}
	for i, pass in Config.CoinPasses do
		local previous = Config.CoinPasses[i - 1]
		table.insert(list, {
			key = pass.key,
			id = pass.id,
			title = string.format("x%d Monedas", pass.multiplier),
			description = string.format("¡Obtén x%d monedas!", pass.multiplier),
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
			if panelFrame.Visible then
				refresh()
			end
		end)
	end
	return if info then info else nil
end

-- El servidor comprueba que se pueda comprar (orden de los pases) y abre la compra
function ShopMenu.promptPass(key: string)
	Remotes.PromptPass:FireServer(key)
end

function ShopMenu.promptVip()
	ShopMenu.promptPass("vip")
end

-- Imagen del pase: la subida a Roblox o, si aún no hay, una moneda/corona dibujada
local function passIcon(parent: Instance, pass: PassInfo)
	local info = getInfo(pass.id)
	if info and info.icon then
		UI.new("ImageLabel", {
			Position = UDim2.fromOffset(12, 14),
			Size = UDim2.fromOffset(110, 110),
			BackgroundTransparency = 1,
			Image = "rbxassetid://" .. info.icon,
		}, parent)
		return
	end
	local coin = UI.new("Frame", {
		Position = UDim2.fromOffset(16, 18),
		Size = UDim2.fromOffset(100, 100),
		BackgroundColor3 = Color3.new(1, 1, 1),
	}, parent)
	UI.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, coin)
	UI.new("UIStroke", { Thickness = 4, Color = COLORS.Outline }, coin)
	UI.new("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(255, 240, 150), Color3.fromRGB(235, 150, 0)),
		Rotation = 90,
	}, coin)
	UI.label(coin, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.68, 0.68),
		Text = PASS_STYLE[pass.key] and PASS_STYLE[pass.key][2] or "⚡",
	})
end

local function renderPasses(order: number)
	local grid = section("Pases", order, Vector2.new(352, 150))
	local data = ClientState.data
	local owned = data and data.ownedPasses or {}

	for i, pass in passList() do
		local style = PASS_STYLE[pass.key] or PASS_STYLE.coins2
		local frame = card(grid, i, style[1])
		passIcon(frame, pass)
		cartoonText(frame, {
			Position = UDim2.fromOffset(128, 10),
			Size = UDim2.new(1, -138, 0, 34),
			Text = pass.title,
		}, 3)
		cartoonText(frame, {
			Position = UDim2.fromOffset(132, 46),
			Size = UDim2.new(1, -146, 0, 48),
			TextWrapped = true,
			Text = pass.description,
		})

		local text, color, onClick = "", COLORS.Disabled, nil
		if owned[pass.key] then
			text = "✓ Comprado"
		elseif pass.id == 0 then
			text = "Próximamente"
		elseif pass.requires and not owned[pass.requires] then
			text = "🔒 Compra " .. (pass.requiresName or "")
			onClick = function()
				HUD.popup("Primero compra Monedas " .. (pass.requiresName or ""), UI.Colors.Bad)
			end
		else
			local info = getInfo(pass.id)
			text = if info and info.price then ROBUX .. " " .. info.price else ROBUX .. " Comprar"
			color = COLORS.Price
			onClick = function()
				ShopMenu.promptPass(pass.key)
			end
		end
		local button = cartoonButton(frame, text, color, {
			Position = UDim2.new(0, 132, 1, -52),
			Size = UDim2.new(1, -144, 0, 42),
		})
		if onClick then
			button.Activated:Connect(onClick)
		end
	end
end

-- Cosméticos (monedas) -----------------------------------------------------------------------

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

local SECTION_TITLES = { Trail = "Rastros", Jump = "Efectos de salto", Slide = "Efectos de deslizar" }

local function renderCosmetics(kind: string, order: number)
	local grid = section(SECTION_TITLES[kind] or kind, order, Vector2.new(170, 160))
	for i, item in Catalog.Items do
		if item.kind ~= kind then
			continue
		end
		local state = itemState(item)
		local frame = card(grid, i, Catalog.colorSequence(item))
		cartoonText(frame, {
			Position = UDim2.fromOffset(8, 12),
			Size = UDim2.new(1, -16, 0, 34),
			Text = (if item.vip then "⭐ " else "") .. item.name,
		}, 3)
		cartoonText(frame, {
			Position = UDim2.fromOffset(8, 50),
			Size = UDim2.new(1, -16, 0, 40),
			Text = if item.vip then "VIP" elseif item.price == 0 then "Gratis" else "🪙 " .. item.price,
		})

		local text, color = "", COLORS.Disabled
		if state == "equipped" then
			text, color = "✓ Equipado", COLORS.Price
		elseif state == "owned" then
			text, color = "Equipar", COLORS.Equip
		elseif state == "vip" then
			text, color = "⭐ Solo VIP", COLORS.Gold
		elseif state == "buy" then
			text, color = "Comprar", COLORS.Price
		else
			text = "🪙 " .. item.price
		end
		local button = cartoonButton(frame, text, color, {
			Position = UDim2.new(0, 10, 1, -52),
			Size = UDim2.new(1, -20, 0, 42),
		})
		button.Activated:Connect(function()
			onItemClicked(item, state)
		end)
	end
end

function refresh()
	for _, child in body:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
	renderPasses(1)
	for i, kind in Catalog.Kinds do
		renderCosmetics(kind.id, 10 * (i + 1))
	end
end

-- Panel -------------------------------------------------------------------------------------

local function build()
	panelFrame = UI.new("Frame", {
		Name = PANEL,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(800, 600),
		BackgroundColor3 = COLORS.Body,
		ClipsDescendants = true,
	}, HUD.gui)
	UI.corner(panelFrame, 12)
	UI.new("UIStroke", { Thickness = 5, Color = COLORS.Outline }, panelFrame)
	UI.new("UIGradient", {
		Color = ColorSequence.new(COLORS.Body, COLORS.BodyDark),
		Rotation = 90,
	}, panelFrame)
	UI.autoScale(panelFrame)

	-- Cabecera verde con brillos
	local header = UI.new("Frame", {
		Size = UDim2.new(1, 0, 0, 78),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 2,
	}, panelFrame)
	UI.new("UIGradient", { Color = ColorSequence.new(COLORS.HeaderLight, COLORS.Header), Rotation = 90 }, header)
	UI.new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 5),
		BackgroundColor3 = COLORS.Outline,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, header)
	shine(header)
	cartoonText(header, {
		Position = UDim2.fromOffset(24, 8),
		Size = UDim2.new(0.5, 0, 0, 60),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Tienda",
		ZIndex = 3,
	}, 4)

	local close = cartoonButton(header, "X", COLORS.Close, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, -2),
		Size = UDim2.fromOffset(60, 56),
		ZIndex = 3,
	})
	close.Activated:Connect(function()
		UI.close(PANEL)
	end)

	body = UI.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 82),
		Size = UDim2.new(1, 0, 1, -86),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Color3.fromRGB(200, 200, 210),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, panelFrame)
	UI.new("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	}, body)
	UI.new("UIPadding", {
		PaddingLeft = UDim.new(0, 18),
		PaddingRight = UDim.new(0, 22),
		PaddingBottom = UDim.new(0, 18),
	}, body)

	UI.registerPanel(PANEL, panelFrame)
end

-- "Passes" lleva a los pases (arriba del todo); otros valores se ignoran
function ShopMenu.open(_kind: string?)
	UI.open(PANEL)
	body.CanvasPosition = Vector2.zero
end

function ShopMenu.start()
	build()

	UI.onOpen(PANEL, refresh)
	ClientState.Changed:Connect(function()
		if panelFrame.Visible then
			refresh()
		end
	end)

	HUD.addSideButton("🛒 Tienda", 20, UI.Colors.Gold, function()
		UI.toggle(PANEL)
	end)

	-- Puesto de tienda del lobby
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Name == "ShopPrompt" then
			ShopMenu.open("Passes")
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
