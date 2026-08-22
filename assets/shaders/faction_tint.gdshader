shader_type canvas_item;

// Multiplicative palette-swap tint for generic (non-faction-colored) unit
// spritesheets. Preserves shading/highlights instead of flattening color.
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.7;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	COLOR = vec4(mix(tex.rgb, tex.rgb * tint_color.rgb, tint_strength), tex.a);
}
