shader_type spatial;
render_mode blend_add, cull_front, unshaded, depth_draw_never;

/**
 * 远行商人 · 水墨描边着色器
 * 用法：作为模型的第二个材质球，cull_front 渲染反面
 * 通过法线外扩实现水墨风外轮廓
 */

uniform vec3 outline_color : source = "color" = vec3(0.08, 0.06, 0.10);
uniform float outline_width : hint_range(0.0, 0.1) = 0.025;
uniform sampler2D texture_noise : repeat_disable;

void vertex() {
	// 沿法线方向外扩顶点
	vec3 local_normal = NORMAL;
	vec3 scaled_normal = local_normal * outline_width;
	VERTEX += scaled_normal;
}

void fragment() {
	// 简单噪点模拟笔触
	vec2 screen_uv = SCREEN_UV;
	float noise = texture(texture_noise, screen_uv * 10.0).r;
	float alpha = smoothstep(0.3, 0.7, noise) * 0.85;
	
	ALBEDO = outline_color;
	ALPHA = alpha;
}
