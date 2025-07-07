shader_type spatial;
render_mode unshaded, depth_draw_never;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;

uniform float speed = 50.0;
uniform float distortion_strength = 0.1;
uniform vec4 base_color = vec4(0.8, 0.9, 1.0, 0.15);

// Called for every vertex the material is visible on
void vertex() {
	// Animate UV for heat wave effect
	UV = vec2(UV.x, UV.y - TIME * speed);
}

// Called for every pixel the material is visible on
void fragment() {
	// Create distortion pattern
	vec2 uv = SCREEN_UV;
	float wave = sin(UV.y * 30.0 + TIME * 20.0) * 0.5 + 0.5;

	// Apply distortion to screen texture
	vec2 distorted_uv = uv + vec2(wave * distortion_strength, 0.0);
	vec4 screen_texture = textureLod(SCREEN_TEXTURE, distorted_uv, 0.0);

	// Blend with subtle blue tint
	vec4 final_color = mix(screen_texture, base_color, base_color.a);
	ALBEDO = final_color.rgb;
	ALPHA = final_color.a;
}
