class_name Hazards
## Visuals for static hazards. Collision is a DamageArea built by Level.


## A run of spikes. Origin at the top-left of the first cell.
class SpikeStrip extends Node2D:
	var cells := 1
	var ceiling := false
	var color := Color(0.6, 0.6, 0.7)
	var crystal := false

	func _draw() -> void:
		var T := float(Phys.TILE)
		var dark := color.darkened(0.55)
		var n := cells * 3
		var wspk := T * cells / float(n)
		for i in n:
			var x0 := i * wspk
			var hgt := 18.0 if not crystal else 22.0 + float((i * 7) % 5) * 2.0
			var tip := Vector2(x0 + wspk * 0.5, T - hgt)
			var a := Vector2(x0 + 0.5, T)
			var b := Vector2(x0 + wspk - 0.5, T)
			if ceiling:
				tip.y = hgt
				a.y = 0.0
				b.y = 0.0
			draw_colored_polygon(PackedVector2Array([a, tip, b]), dark)
			var mid := Vector2(x0 + wspk * 0.5, a.y)
			draw_colored_polygon(PackedVector2Array([a.lerp(mid, 0.25), tip, mid]), color)
		var base_y := T - 3.0 if not ceiling else 0.0
		draw_rect(Rect2(0, base_y, T * cells, 3), dark)


## Rectangular water body using a tiny animated shader. Origin at its top-left.
class WaterBody extends ColorRect:
	static var _shader: Shader
	var has_surface := true
	var water_color := Color(0.1, 0.3, 0.4, 0.85)

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if _shader == null:
			_shader = Shader.new()
			_shader.code = SHADER_CODE
		var m := ShaderMaterial.new()
		m.shader = _shader
		m.set_shader_parameter("deep_color", Color(water_color.r * 0.5, water_color.g * 0.5, water_color.b * 0.6, water_color.a))
		m.set_shader_parameter("surface_color", water_color.lightened(0.15))
		m.set_shader_parameter("px_size", size)
		m.set_shader_parameter("has_surface", 1.0 if has_surface else 0.0)
		m.set_shader_parameter("world_x", position.x)
		material = m
		color = Color.WHITE

	const SHADER_CODE := """
shader_type canvas_item;
uniform vec4 deep_color : source_color;
uniform vec4 surface_color : source_color;
uniform vec2 px_size = vec2(64.0, 64.0);
uniform float has_surface = 1.0;
uniform float world_x = 0.0;
void fragment() {
	vec2 p = UV * px_size;
	float x = p.x + world_x;
	float wave = (sin(x * 0.07 + TIME * 2.1) * 2.0 + sin(x * 0.029 - TIME * 1.4) * 1.6) * has_surface;
	float surf = (7.0 + wave) * has_surface;
	if (p.y < surf) { discard; }
	float depth = clamp((p.y - surf) / 56.0, 0.0, 1.0);
	vec4 c = mix(surface_color, deep_color, depth);
	float line = (1.0 - smoothstep(0.0, 2.2, abs(p.y - surf - 1.2))) * has_surface;
	c.rgb += vec3(0.45, 0.55, 0.6) * line;
	c.rgb += 0.035 * sin(x * 0.06 + p.y * 0.09 + TIME * 1.7);
	COLOR = c;
}
"""
