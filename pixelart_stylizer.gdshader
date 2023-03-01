shader_type spatial;
render_mode unshaded;

uniform sampler2D DEPTH_TEXTURE: hint_depth_texture, filter_nearest;
uniform sampler2D SCREEN_TEXTURE: hint_screen_texture, filter_nearest;

uniform bool shadows_enabled = true;
uniform bool highlights_enabled = true;
uniform float shadow_strength : hint_range(0.0, 1.0, 0.01) = 0.4;
uniform float highlight_strength : hint_range(0.0, 1.0, 0.01) = 0.1;
uniform float depth_smooth_low : hint_range(0.0, 1.0, 0.01) = 0.2;
uniform float depth_smooth_high : hint_range(0.0, 1.0, 0.01) = 0.7;

varying mat4 model_view_matrix;

float linear_depth(in sampler2D depth_texture, in vec2 screen_uv, in mat4 inv_projection_matrix){
//	Credit: https://godotshaders.com/shader/depth-modulated-pixel-outline-in-screen-space/
	float raw_depth = texture(depth_texture, screen_uv)[0];
	vec3 normalized_device_coordinates = vec3(screen_uv * 2.0 - 1.0, raw_depth);
    vec4 view_space = inv_projection_matrix * vec4(normalized_device_coordinates, 1.0);	
	view_space.xyz /= view_space.w;	
	return -view_space.z;
}

float getDepth(vec2 screen_uv, sampler2D depth_texture, mat4 inv_projection_matrix) {
	float ld = linear_depth(depth_texture, screen_uv, inv_projection_matrix);
	return ld;
}

vec3 getPos(float depth, mat4 mvm, mat4 ipm, vec2 suv, mat4 wm, mat4 icm) {
  vec4 pos = inverse(mvm) * ipm * vec4((suv * 2.0 - 1.0), depth * 2.0 - 1.0, 1.0);
  pos.xyz /= (pos.w+0.0001*(1.-abs(sign(pos.w))));
  return (pos*icm).xyz+wm[3].xyz;
}

vec3 computeNormalImproved( sampler2D depth_tx, mat4 mvm, mat4 ipm, vec2 suv, mat4 wm, mat4 icm, vec2 iResolution) {
    vec2 e = vec2(1./iResolution);
//    float c0 = texture(depth_tx,suv).r;
    float c0 = texture(depth_tx, suv).r;
    float l2 = texture(depth_tx, suv-vec2(2,0)*e).r;
    float r1 = texture(depth_tx, suv+vec2(1,0)*e).r;
    float l1 = texture(depth_tx, suv-vec2(1,0)*e).r;
    float r2 = texture(depth_tx, suv+vec2(2,0)*e).r;
    float b2 = texture(depth_tx, suv-vec2(0,2)*e).r;
    float b1 = texture(depth_tx, suv-vec2(0,1)*e).r;
    float t1 = texture(depth_tx, suv+vec2(0,1)*e).r;
    float t2 = texture(depth_tx, suv+vec2(0,2)*e).r;
    
    float dl = abs(l1*l2/(2.0*l2-l1)-c0);
    float dr = abs(r1*r2/(2.0*r2-r1)-c0);
    float db = abs(b1*b2/(2.0*b2-b1)-c0);
    float dt = abs(t1*t2/(2.0*t2-t1)-c0);
    
    vec3 ce = getPos(c0, mvm, ipm, suv, wm, icm);

    vec3 dpdx = (dl<dr) ?  ce-getPos(l1, mvm, ipm, suv-vec2(1,0)*e, wm, icm) : 
                          -ce+getPos(r1, mvm, ipm, suv+vec2(1,0)*e, wm, icm) ;
    vec3 dpdy = (db<dt) ?  ce-getPos(b1, mvm, ipm, suv-vec2(0,1)*e, wm, icm) : 
                          -ce+getPos(t1, mvm, ipm, suv+vec2(0,1)*e, wm, icm) ;

    return normalize(cross(dpdx,dpdy));
}

float normalIndicator(vec3 normalEdgeBias, vec3 baseNormal, vec3 newNormal, float depthDiff) {
	float normalDiff = dot(baseNormal - newNormal, normalEdgeBias);
	float normalIndicator = clamp(smoothstep(-.01, .01, normalDiff), 0.0, 1.0);
	// only the shallower pixel
	float depthIndicator = clamp(sign(depthDiff * .25 + .0025), 0.0, 1.0);
	return (1.0 - dot(baseNormal, newNormal)) * depthIndicator * normalIndicator;
}

void vertex(){
    model_view_matrix = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 e = vec2(1./VIEWPORT_SIZE.xy);
	float depth_here = getDepth(SCREEN_UV, DEPTH_TEXTURE, INV_PROJECTION_MATRIX);
	
	float depth_diff = 0.;
	float du = getDepth(SCREEN_UV+vec2(0., -1.)*e, DEPTH_TEXTURE, INV_PROJECTION_MATRIX);
	float dr = getDepth(SCREEN_UV+vec2(1., 0.)*e, DEPTH_TEXTURE, INV_PROJECTION_MATRIX);
	float dd = getDepth(SCREEN_UV+vec2(0., 1.)*e, DEPTH_TEXTURE, INV_PROJECTION_MATRIX);
	float dl = getDepth(SCREEN_UV+vec2(-1., 0.)*e, DEPTH_TEXTURE, INV_PROJECTION_MATRIX);
	depth_diff += clamp(du - depth_here, 0., 1.);
	depth_diff += clamp(dr - depth_here, 0., 1.);
	depth_diff += clamp(dd - depth_here, 0., 1.);
	depth_diff += clamp(dl - depth_here, 0., 1.);
	depth_diff = smoothstep(depth_smooth_low, depth_smooth_high, depth_diff);
//	ALBEDO = vec3(depth_diff);
	
	// Normals
	vec3 normal = computeNormalImproved(DEPTH_TEXTURE, model_view_matrix, INV_PROJECTION_MATRIX, SCREEN_UV, MODEL_MATRIX, VIEW_MATRIX, VIEWPORT_SIZE.xy);
	vec3 nu = computeNormalImproved(DEPTH_TEXTURE, model_view_matrix, INV_PROJECTION_MATRIX, SCREEN_UV+vec2(0., -1.)*e, MODEL_MATRIX, VIEW_MATRIX, VIEWPORT_SIZE.xy);
	vec3 nr = computeNormalImproved(DEPTH_TEXTURE, model_view_matrix, INV_PROJECTION_MATRIX, SCREEN_UV+vec2(1., 0.)*e, MODEL_MATRIX, VIEW_MATRIX, VIEWPORT_SIZE.xy);
	vec3 nd = computeNormalImproved(DEPTH_TEXTURE, model_view_matrix, INV_PROJECTION_MATRIX, SCREEN_UV+vec2(0., 1.)*e, MODEL_MATRIX, VIEW_MATRIX, VIEWPORT_SIZE.xy);
	vec3 nl = computeNormalImproved(DEPTH_TEXTURE, model_view_matrix, INV_PROJECTION_MATRIX, SCREEN_UV+vec2(-1., -1.)*e, MODEL_MATRIX, VIEW_MATRIX, VIEWPORT_SIZE.xy);
	vec3 normalEdgeBias = vec3(1., 1., 1.);
	float normal_diff = 0.;
	normal_diff += normalIndicator(normalEdgeBias, normal, nu, depth_diff);
	normal_diff += normalIndicator(normalEdgeBias, normal, nr, depth_diff);
	normal_diff += normalIndicator(normalEdgeBias, normal, nd, depth_diff);
	normal_diff += normalIndicator(normalEdgeBias, normal, nl, depth_diff);
	normal_diff /= 4.;
	normal_diff = smoothstep(0.1, 0.3, normal_diff);
	
//	ALBEDO = vec3(normal_diff);
	
	vec3 original_color = texture(SCREEN_TEXTURE, SCREEN_UV).rgb;
	vec3 highlight_color = mix(original_color, vec3(1.), highlight_strength);
	vec3 shadow_color = mix(original_color, vec3(0.), shadow_strength);
	
	vec3 final = original_color;
	if (highlights_enabled) {
		final = mix(final, highlight_color, normal_diff);
	}
	if (shadows_enabled) {
		final = mix(final, shadow_color, depth_diff);
	}
	ALBEDO = final;
	
	float alpha_mask = depth_diff * float(shadows_enabled) + normal_diff * float(highlights_enabled);
	ALPHA = clamp((alpha_mask) * 5., 0., 1.);
	
}
