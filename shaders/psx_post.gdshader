// 画面全体の PS1 風の加工：解像度を落とし、色数を減らし、網目状のディザを入れ、少しザラつかせる。
// 文字やゲージ（HUD）はこの上に描くので、加工されない。
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float resolution = 240.0;    // 縦の画素数
uniform float color_levels = 32.0;   // 1 色あたりの段階数
uniform float dither_strength = 1.0;
uniform float grain = 0.025;         // ザラつき

const float BAYER[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 virtual_size = vec2(floor(resolution * screen_size.x / screen_size.y), resolution);
	vec2 cell = floor(SCREEN_UV * virtual_size);
	vec3 color = texture(screen_texture, (cell + 0.5) / virtual_size).rgb;

	int index = int(mod(cell.y, 4.0)) * 4 + int(mod(cell.x, 4.0));
	float threshold = BAYER[index] / 16.0 - 0.5;
	color += threshold * dither_strength / color_levels;
	color += (hash(cell + floor(TIME * 24.0)) - 0.5) * grain;
	color = floor(color * (color_levels - 1.0) + 0.5) / (color_levels - 1.0);
	COLOR = vec4(clamp(color, 0.0, 1.0), 1.0);
}
