shader_type canvas_item;

uniform float time;
uniform float strength = 0.1; // 控制可见程度（0~1）
uniform float density = 1000.0; // 控制噪点稀疏程度，越大越稀疏

float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	float noise = rand(UV * density + vec2(time, -time));
	// 生成灰度噪点
	float gray = mix(0.0, 1.0, noise);
	
	// 淡入柔和灰度，非全白非全黑
	COLOR = vec4(vec3(gray * strength), 1.0);
}