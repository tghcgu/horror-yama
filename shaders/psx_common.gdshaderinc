// PS1 風の見た目の共通部品。
// 頂点を画面の粗い格子にスナップして、カメラを動かすとポリゴンがプルプル震える感じを出す。
global uniform float psx_resolution;  // 画面の縦の画素数（0 なら無効）

vec4 psx_snap(vec4 clip, vec2 viewport_size) {
	if (psx_resolution <= 0.0) {
		return clip;
	}
	vec2 grid = vec2(psx_resolution * viewport_size.x / viewport_size.y, psx_resolution) * 0.5;
	vec3 ndc = clip.xyz / clip.w;
	ndc.xy = round(ndc.xy * grid) / grid;
	return vec4(ndc * clip.w, clip.w);
}

// 面の向きに合わせて 3 方向から貼る（UV のない地形や、形がばらばらの置き物用）
vec3 psx_triplanar(sampler2D tex, vec3 p, vec3 normal) {
	vec3 w = pow(abs(normal), vec3(4.0));
	w /= (w.x + w.y + w.z);
	return texture(tex, p.zy).rgb * w.x + texture(tex, p.xz).rgb * w.y + texture(tex, p.xy).rgb * w.z;
}

vec3 psx_saturate(vec3 color, float amount) {
	return mix(vec3(dot(color, vec3(0.299, 0.587, 0.114))), color, amount);
}
