-- Objetos de la tienda (solo estéticos: no dan ventaja en las carreras).

local Catalog = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

export type Item = {
	id: string,
	kind: string, -- "Trail", "Jump" o "Slide"
	name: string,
	price: number,
	vip: boolean?,
	colors: { Color3 },
}

Catalog.Kinds = {
	{ id = "Trail", name = "Rastros" },
	{ id = "Jump", name = "Salto" },
	{ id = "Slide", name = "Deslizar" },
}

Catalog.Items = {
	-- Rastros (se ven a alta velocidad; los ven todos los jugadores)
	{ id = "trail_blue", kind = "Trail", name = "Eléctrico", price = 0, colors = { rgb(0, 200, 255), rgb(170, 80, 255) } },
	{ id = "trail_fire", kind = "Trail", name = "Fuego", price = 150, colors = { rgb(255, 220, 0), rgb(255, 60, 0) } },
	{ id = "trail_toxic", kind = "Trail", name = "Tóxico", price = 300, colors = { rgb(180, 255, 0), rgb(0, 160, 60) } },
	{ id = "trail_ice", kind = "Trail", name = "Hielo", price = 450, colors = { rgb(255, 255, 255), rgb(120, 200, 255) } },
	{ id = "trail_gold", kind = "Trail", name = "Oro", price = 800, colors = { rgb(255, 240, 150), rgb(255, 170, 0) } },
	{
		id = "trail_rainbow",
		kind = "Trail",
		name = "Arcoíris",
		price = 1500,
		colors = { rgb(255, 60, 60), rgb(255, 170, 0), rgb(255, 240, 0), rgb(0, 220, 90), rgb(0, 150, 255), rgb(170, 70, 255) },
	},
	{
		id = "trail_galaxy",
		kind = "Trail",
		name = "Galaxia",
		price = 0,
		vip = true,
		colors = { rgb(255, 80, 220), rgb(80, 40, 200), rgb(10, 10, 60) },
	},

	-- Efecto al saltar
	{ id = "jump_none", kind = "Jump", name = "Ninguno", price = 0, colors = { rgb(90, 90, 100) } },
	{ id = "jump_sparks", kind = "Jump", name = "Chispas", price = 100, colors = { rgb(255, 240, 80), rgb(255, 140, 0) } },
	{ id = "jump_frost", kind = "Jump", name = "Escarcha", price = 250, colors = { rgb(255, 255, 255), rgb(140, 210, 255) } },
	{ id = "jump_toxic", kind = "Jump", name = "Veneno", price = 400, colors = { rgb(160, 255, 0), rgb(0, 140, 40) } },
	{ id = "jump_stars", kind = "Jump", name = "Estrellas", price = 0, vip = true, colors = { rgb(255, 215, 0), rgb(255, 255, 255) } },

	-- Efecto al deslizar
	{ id = "slide_dust", kind = "Slide", name = "Polvo", price = 0, colors = { rgb(220, 220, 230) } },
	{ id = "slide_fire", kind = "Slide", name = "Llamas", price = 200, colors = { rgb(255, 200, 0), rgb(255, 50, 0) } },
	{ id = "slide_neon", kind = "Slide", name = "Neón", price = 350, colors = { rgb(0, 255, 230), rgb(255, 0, 200) } },
	{ id = "slide_gold", kind = "Slide", name = "Oro", price = 0, vip = true, colors = { rgb(255, 215, 0) } },
} :: { Item }

Catalog.Defaults = {
	Trail = "trail_blue",
	Jump = "jump_none",
	Slide = "slide_dust",
}

Catalog.byId = {} :: { [string]: Item }
for _, item in Catalog.Items do
	Catalog.byId[item.id] = item
end

function Catalog.colorSequence(item: Item): ColorSequence
	local colors = item.colors
	if #colors == 1 then
		return ColorSequence.new(colors[1])
	end
	local keypoints = {}
	for i, color in colors do
		table.insert(keypoints, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), color))
	end
	return ColorSequence.new(keypoints)
end

return Catalog
