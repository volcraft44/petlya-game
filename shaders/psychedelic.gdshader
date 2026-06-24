shader_type canvas_item;
// Полноэкранный психоделический эффект (один проход на GPU — дёшево).
// Делает: мягкое волновое искажение, хроматическую аберрацию по краям и
// плавный сдвиг оттенка. Всё масштабируется параметром intensity.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float intensity = 0.0;   // базовая сила (0..1) из настроек
uniform float surge = 0.0;       // доп. усиление (низкое HP / события) 0..1

// Поворот оттенка вокруг оси яркости (формула Родригеса) — корректно и дёшево.
vec3 hue_rotate(vec3 col, float a) {
	const vec3 k = vec3(0.57735026919);
	float ca = cos(a);
	return col * ca + cross(k, col) * sin(a) + k * dot(k, col) * (1.0 - ca);
}

void fragment() {
	float amt = clamp(intensity + surge, 0.0, 1.2);
	if (amt <= 0.001) {
		COLOR = texture(screen_tex, SCREEN_UV);
	} else {
		float t = TIME;
		vec2 uv = SCREEN_UV;

		// 1) Мягкое волновое колыхание
		float warp = 0.0022 * amt;
		vec2 wuv = uv + vec2(
			sin(uv.y * 14.0 + t * 1.2) * warp,
			cos(uv.x * 12.0 + t * 0.9) * warp
		);

		// 2) Хроматическая аберрация — сильнее к краям и при surge
		vec2 c = uv - vec2(0.5);
		float edge = dot(c, c);                       // 0 в центре .. ~0.5 по углам
		float ca = (0.0012 + edge * 0.012) * amt;
		vec2 dir = normalize(c + vec2(0.00001));
		vec3 col;
		col.r = texture(screen_tex, wuv + dir * ca).r;
		col.g = texture(screen_tex, wuv).g;
		col.b = texture(screen_tex, wuv - dir * ca).b;

		// 3) Плавный сдвиг оттенка (медленный, не кислотный)
		float hue = (sin(t * 0.18) * 0.35 + sin(t * 0.07) * 0.2) * amt;
		col = hue_rotate(col, hue);

		// 4) Лёгкая пульсация насыщенности/яркости — «дыхание»
		float pulse = 1.0 + sin(t * 1.6) * 0.03 * amt;
		col *= pulse;

		COLOR = vec4(col, 1.0);
	}
}
