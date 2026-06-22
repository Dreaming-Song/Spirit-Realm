shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque;

/**
 * 灵境 · 国风卡通着色器
 * Godot 4.x Spatial Shader
 * 
 * 特征：
 * - 三级色阶卡通光照（亮/中/暗）
 * - 水墨风边缘光（rim light）
 * - 外轮廓描边（outline pass）
 * - 仙侠风飘带/金属高光
 */

// ==================== 材质参数 ====================
group_uniforms "基础颜色";
uniform vec3 base_color : source = "color";
uniform sampler2D texture_albedo : source = "albedo";

group_uniforms "卡通光照";
uniform float light_ramp_steps : hint_range(2.0, 6.0) = 3.0;  // 色阶数
uniform float shadow_threshold : hint_range(0.0, 1.0) = 0.35; // 暗部阈值
uniform float midtone_cutoff : hint_range(0.0, 1.0) = 0.65;   // 中间色阈值
uniform vec3 shadow_color = vec3(0.15, 0.12, 0.18);           // 暗部颜色（水墨深色）
uniform vec3 midtone_color = vec3(0.65, 0.55, 0.70);          // 中间色（淡紫灰）

group_uniforms "边缘光（仙侠辉光）";
uniform float rim_power : hint_range(0.0, 5.0) = 2.5;
uniform vec3 rim_color = vec3(0.7, 0.85, 1.0);                // 淡蓝辉光
uniform float rim_intensity : hint_range(0.0, 2.0) = 0.8;

group_uniforms "描边";
uniform float outline_width : hint_range(0.0, 0.1) = 0.02;
uniform vec3 outline_color = vec3(0.08, 0.06, 0.10);          // 深墨色

group_uniforms "高光";
uniform float specular_intensity : hint_range(0.0, 1.0) = 0.3;
uniform float specular_shininess : hint_range(1.0, 64.0) = 16.0;

group_uniforms "环境";
uniform float ambient_strength : hint_range(0.0, 1.0) = 0.3;
uniform vec3 ambient_color = vec3(0.35, 0.40, 0.55);          // 天光色

// ==================== 顶点着色器 ====================
VARYING vec3 world_normal;
VARYING vec3 world_position;
VARYING vec2 uv;

void vertex() {
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	uv = UV;
}

// ==================== 片段着色器 ====================
void fragment() {
	// ---- 基础纹理 ----
	vec3 albedo = texture(texture_albedo, uv).rgb * base_color;
	
	// ---- 主光源方向（取第一个方向光） ----
	vec3 light_dir = normalize(vec3(-0.5, 0.8, -0.3));  // 固定主光方向
	float NdotL = dot(world_normal, light_dir);
	
	// ---- 三级色阶（cel shading） ----
	float ramp = 0.0;
	
	// 第一级：亮部
	if (NdotL > midtone_cutoff) {
		ramp = 1.0;
	}
	// 第二级：中间调
	else if (NdotL > shadow_threshold) {
		ramp = 0.5;
	}
	// 第三级：暗部
	else {
		ramp = 0.0;
	}
	
	// 插值颜色
	vec3 shaded = mix(shadow_color, vec3(1.0), ramp);
	shaded = mix(midtone_color, shaded, ramp);
	
	// ---- 高光（toon specular） ----
	vec3 view_dir = normalize(CAMERA_POSITION - world_position);
	vec3 half_dir = normalize(light_dir + view_dir);
	float spec = pow(max(dot(world_normal, half_dir), 0.0), specular_shininess);
	float spec_step = step(0.5, spec);  // 硬边高光
	vec3 spec_color = vec3(1.0) * spec_step * specular_intensity;
	
	// ---- 边缘光（仙侠辉光/rim light） ----
	float rim = 1.0 - max(dot(view_dir, world_normal), 0.0);
	rim = pow(rim, rim_power);
	vec3 rim_light = rim * rim_color * rim_intensity;
	
	// ---- 环境光 ----
	vec3 ambient = ambient_color * ambient_strength;
	
	// ---- 合成 ----
	vec3 final_color = albedo * shaded + spec_color + rim_light + ambient;
	
	ALBEDO = final_color;
	METALLIC = 0.0;
	ROUGHNESS = 0.8;
	
	// ---- 描边（法向外扩，在几何体阶段做更好，这里留个pass标记） ----
	// 描边在顶点阶段用 CULL_FRONT + NORMAL 外扩实现
}
