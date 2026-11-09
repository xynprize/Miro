extends RefCounted
# Keep strong references: a texture loaded only inside _draw can be freed before rendering.
const TEXTURES := {
	"remote": preload("res://assets/weapons/remote.svg"),
	"pistol": preload("res://assets/weapons/pistol.svg"),
	"smg": preload("res://assets/weapons/smg.svg"),
	"shank": preload("res://assets/weapons/shank.svg"),
	"blanket": preload("res://assets/weapons/blanket.svg"),
	"c4": preload("res://assets/weapons/c4.svg"),
	"guitar": preload("res://assets/weapons/guitar_red_v2.png")
}
