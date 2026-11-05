class_name Palettes
## Per-level visual themes. Every colour in the world comes from here so the art direction
## stays consistent: cold, desaturated worlds with warm light from the player and lanterns.
##
## ground:   terrain fill by depth from the surface (edge -> deep interior)
## surface:  rim/top colour, surface_style picks the top decoration
## backdrop: silhouette style for the parallax layers
## particles: ambient particle style

static func get_theme(id: String) -> Dictionary:
	var t: Dictionary = THEMES.get(id, THEMES["path"])
	return t


const THEMES := {
	"path": {
		"sky_top": Color("#141a33"), "sky_bottom": Color("#3a3552"),
		"far": Color("#2b2c47"), "mid": Color("#1f2036"), "near": Color("#151526"),
		"fog": Color(0.55, 0.5, 0.7, 0.18),
		"ground": [Color("#3b3550"), Color("#2c2740"), Color("#221e33"), Color("#1a1728")],
		"outline": Color("#110e1c"), "surface": Color("#5f8a7a"), "surface2": Color("#86b39a"),
		"surface_style": "grass", "platform": Color("#6b5a48"), "spike": Color("#9aa0b8"),
		"accent": Color("#ffb45c"), "water": Color(0.15, 0.25, 0.4, 0.85),
		"backdrop": "hills", "particles": "dust", "moon": true,
	},
	"moss": {
		"sky_top": Color("#08130f"), "sky_bottom": Color("#16291f"),
		"far": Color("#15261d"), "mid": Color("#0f1d16"), "near": Color("#0a140f"),
		"fog": Color(0.4, 0.7, 0.5, 0.14),
		"ground": [Color("#2d3b2c"), Color("#223022"), Color("#1a251a"), Color("#131c13")],
		"outline": Color("#0a100a"), "surface": Color("#4f8a3e"), "surface2": Color("#7fbf5a"),
		"surface_style": "moss", "platform": Color("#5a4a36"), "spike": Color("#a3b78a"),
		"accent": Color("#9df58a"), "water": Color(0.1, 0.25, 0.2, 0.85),
		"backdrop": "cave", "particles": "spores", "moon": false,
	},
	"village": {
		"sky_top": Color("#1d1420"), "sky_bottom": Color("#4a2f2b"),
		"far": Color("#3a2629"), "mid": Color("#28191d"), "near": Color("#180f13"),
		"fog": Color(0.8, 0.5, 0.35, 0.14),
		"ground": [Color("#4a3a33"), Color("#382b27"), Color("#2a201e"), Color("#1e1716")],
		"outline": Color("#120c0b"), "surface": Color("#7a6a4a"), "surface2": Color("#a08a5a"),
		"surface_style": "grass", "platform": Color("#7a5a3a"), "spike": Color("#b0a090"),
		"accent": Color("#ff9a4a"), "water": Color(0.2, 0.2, 0.25, 0.85),
		"backdrop": "village", "particles": "embers", "moon": true,
	},
	"woods": {
		"sky_top": Color("#07141a"), "sky_bottom": Color("#163039"),
		"far": Color("#12282f"), "mid": Color("#0c1c22"), "near": Color("#071115"),
		"fog": Color(0.45, 0.7, 0.75, 0.16),
		"ground": [Color("#2a3a3a"), Color("#1f2d2d"), Color("#172222"), Color("#111919")],
		"outline": Color("#081010"), "surface": Color("#3f7a6a"), "surface2": Color("#6ab39a"),
		"surface_style": "grass", "platform": Color("#4a3a2e"), "spike": Color("#6a8a70"),
		"accent": Color("#bff0ff"), "water": Color(0.1, 0.2, 0.25, 0.85),
		"backdrop": "forest", "particles": "spores", "moon": false,
	},
	"crystal": {
		"sky_top": Color("#0c0820"), "sky_bottom": Color("#22174a"),
		"far": Color("#1d1640"), "mid": Color("#140f30"), "near": Color("#0c0920"),
		"fog": Color(0.6, 0.45, 0.95, 0.14),
		"ground": [Color("#342c55"), Color("#272044"), Color("#1d1834"), Color("#151127")],
		"outline": Color("#0b0818"), "surface": Color("#7a6ac8"), "surface2": Color("#9fe8ff"),
		"surface_style": "crystal", "platform": Color("#4e4478"), "spike": Color("#9fe8ff"),
		"accent": Color("#8fe3ff"), "water": Color(0.2, 0.15, 0.45, 0.85),
		"backdrop": "crystal", "particles": "sparkle", "moon": false,
	},
	"sunken": {
		"sky_top": Color("#051018"), "sky_bottom": Color("#0e2a36"),
		"far": Color("#0d2430"), "mid": Color("#091a23"), "near": Color("#051017"),
		"fog": Color(0.3, 0.6, 0.7, 0.16),
		"ground": [Color("#23383d"), Color("#1a2c30"), Color("#142226"), Color("#0e191c")],
		"outline": Color("#060d0f"), "surface": Color("#3a7a74"), "surface2": Color("#5fb0a4"),
		"surface_style": "moss", "platform": Color("#3e4a48"), "spike": Color("#7aa0a0"),
		"accent": Color("#7ff5e0"), "water": Color(0.05, 0.3, 0.38, 0.82),
		"backdrop": "cave", "particles": "bubbles", "moon": false,
	},
	"ruins": {
		"sky_top": Color("#0e0c16"), "sky_bottom": Color("#27233a"),
		"far": Color("#221f33"), "mid": Color("#181626"), "near": Color("#0f0e18"),
		"fog": Color(0.55, 0.5, 0.75, 0.15),
		"ground": [Color("#3d3a4a"), Color("#302d3b"), Color("#24222d"), Color("#1a1921")],
		"outline": Color("#0c0b12"), "surface": Color("#6a6680"), "surface2": Color("#8c88a8"),
		"surface_style": "stone", "platform": Color("#57536a"), "spike": Color("#a8a4c0"),
		"accent": Color("#c9a6ff"), "water": Color(0.15, 0.12, 0.25, 0.85),
		"backdrop": "ruins", "particles": "dust", "moon": true,
	},
	"fortress": {
		"sky_top": Color("#120809"), "sky_bottom": Color("#341416"),
		"far": Color("#2a1114"), "mid": Color("#1c0b0d"), "near": Color("#110607"),
		"fog": Color(0.8, 0.3, 0.25, 0.14),
		"ground": [Color("#43363a"), Color("#34292d"), Color("#271f22"), Color("#1c1618")],
		"outline": Color("#0d0909"), "surface": Color("#7a5a50"), "surface2": Color("#a4786a"),
		"surface_style": "brick", "platform": Color("#5a4038"), "spike": Color("#c0a0a0"),
		"accent": Color("#ff6a4a"), "water": Color(0.25, 0.08, 0.08, 0.85),
		"backdrop": "fortress", "particles": "embers", "moon": false,
	},
	"throne": {
		"sky_top": Color("#0d0a05"), "sky_bottom": Color("#2e2410"),
		"far": Color("#2a210f"), "mid": Color("#1c160a"), "near": Color("#110d06"),
		"fog": Color(0.85, 0.7, 0.35, 0.13),
		"ground": [Color("#3e3628"), Color("#30291e"), Color("#241f17"), Color("#1a1611")],
		"outline": Color("#0c0a06"), "surface": Color("#a08a4a"), "surface2": Color("#d4b862"),
		"surface_style": "brick", "platform": Color("#6a5a34"), "spike": Color("#d4c08a"),
		"accent": Color("#ffd36a"), "water": Color(0.2, 0.15, 0.05, 0.85),
		"backdrop": "throne", "particles": "embers", "moon": false,
	},
	"sanctuary": {
		"sky_top": Color("#2a2a4a"), "sky_bottom": Color("#a08aa0"),
		"far": Color("#7a6a8a"), "mid": Color("#5a4a6a"), "near": Color("#3a2e48"),
		"fog": Color(1.0, 0.9, 0.85, 0.18),
		"ground": [Color("#6a5e78"), Color("#554a63"), Color("#44394f"), Color("#352c3e")],
		"outline": Color("#231c2a"), "surface": Color("#e6d6b0"), "surface2": Color("#fff2cc"),
		"surface_style": "stone", "platform": Color("#8a7a6a"), "spike": Color("#f0e0c0"),
		"accent": Color("#fff0b0"), "water": Color(0.4, 0.35, 0.5, 0.8),
		"backdrop": "sanctuary", "particles": "motes", "moon": false,
	},
}
