shader_type spatial;
render_mode unshaded;


uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float distance_falloff : hint_range(0, 5) = 1;
uniform float smoothing_cutoff : hint_range(0, 1) = 0.1;
uniform float smoothing_max : hint_range(0, 1) = 0.1;

varying flat mat4 model_view_matrix;

void vertex(){
    model_view_matrix = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

float linear_depth(in sampler2D depth_texture, in vec2 screen_uv, in mat4 inv_projection_matrix){
//	Credit: https://godotshaders.com/shader/depth-modulated-pixel-outline-in-screen-space/
	
	// get raw depth, this is not a linear value in godot 4.0 vulkan rendering
	float raw_depth = texture(depth_texture, screen_uv)[0];
    
	vec3 normalized_device_coordinates = vec3(screen_uv * 2.0 - 1.0, raw_depth);
	
	//convert NDC to view space via the inverse projection matrix
    vec4 view_space = inv_projection_matrix * vec4(normalized_device_coordinates, 1.0);	
    
	//linearize the depth
	view_space.xyz /= view_space.w;	
	
	// camera view points in the negative Z direction, so all depths are negative
	// we invert the sign here to get positive depth values
	return -view_space.z;
}

vec3 getPos(float depth, mat4 mvm, mat4 ipm, vec2 suv, mat4 wm, mat4 icm){
  vec4 pos = inverse(mvm) * ipm * vec4((suv * 2.0 - 1.0), depth * 2.0 - 1.0, 1.0);
  pos.xyz /= (pos.w+0.0001*(1.-abs(sign(pos.w))));
  return (pos*icm).xyz+wm[3].xyz;
}

vec3 computeNormalImproved( sampler2D depth_tx, mat4 mvm, mat4 ipm, vec2 suv, mat4 wm, mat4 icm, vec2 iResolution) {
    vec2 e = vec2(1./iResolution);
//    float c0 = texture(depth_tx,suv).r;
    float c0 = linear_depth(depth_tx, suv, ipm);
//    float l2 = texture(depth_tx,suv-vec2(2,0)*e).r;
    float l2 = linear_depth(depth_tx, suv-vec2(2,0)*e, ipm);
    float r1 = linear_depth(depth_tx, suv+vec2(1,0)*e, ipm);
    float l1 = linear_depth(depth_tx, suv-vec2(1,0)*e, ipm);
    float r2 = linear_depth(depth_tx, suv+vec2(2,0)*e, ipm);
    float b2 = linear_depth(depth_tx, suv-vec2(0,2)*e, ipm);
    float b1 = linear_depth(depth_tx, suv-vec2(0,1)*e, ipm);
    float t1 = linear_depth(depth_tx, suv+vec2(0,1)*e, ipm);
    float t2 = linear_depth(depth_tx, suv+vec2(0,2)*e, ipm);
    
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

vec3 computeNormalNaive( sampler2D depth_tx, mat4 mvm, mat4 ipm, vec2 suv, mat4 wm, mat4 icm, vec2 iResolution) {
//    vec2 e = vec2(1./iResolution);
//    vec3 l1 = getPos(linear_depth(depth_tx, suv-vec2(1,0)*e, ipm) ,mvm, ipm, suv-vec2(1,0)*e, wm, icm);
//    vec3 r1 = getPos(linear_depth(depth_tx, suv+vec2(1,0)*e, ipm) ,mvm, ipm, suv+vec2(1,0)*e, wm, icm);
//    vec3 t1 = getPos(linear_depth(depth_tx, suv+vec2(0,1)*e, ipm) ,mvm, ipm, suv+vec2(0,1)*e, wm, icm);
//    vec3 b1 = getPos(linear_depth(depth_tx, suv-vec2(0,1)*e, ipm) ,mvm, ipm, suv-vec2(0,1)*e, wm, icm);
//    vec3 dpdx = r1-l1;
//    vec3 dpdy = t1-b1;
//    return normalize(cross(dpdx,dpdy));
//
//    alternative
//	float d = texture(depth_tx, suv).x;
	float d = linear_depth(depth_tx, suv, ipm);
	d = d / 2.;
    vec3 pos = getPos(d,mvm, ipm, suv, wm, icm);
    return normalize(cross(dFdx(pos),dFdy(pos)));
}

float normalIndicator(vec3 normalEdgeBias, vec3 baseNormal, vec3 newNormal, float depthDiff) {
	float normalDiff = dot(baseNormal - newNormal, normalEdgeBias);
	float normalIndicator = clamp(smoothstep(-.01, .01, normalDiff), 0.0, 1.0);
	// only the shallower pixel
	float depthIndicator = clamp(sign(depthDiff * .25 + .0025), 0.0, 1.0);
	return (1.0 - dot(baseNormal, newNormal)) * depthIndicator * normalIndicator;
}

void fragment() {
	float d = linear_depth(DEPTH_TEXTURE, SCREEN_UV, INV_PROJECTION_MATRIX);
	
	// calculate the screen uv offset size of a single pixel
	vec2 screen_size = vec2(textureSize(SCREEN_TEXTURE, 1));
	vec2 pixel_size = (distance_falloff / d) / vec2(screen_size.x, screen_size.y);
	
	float du = linear_depth(DEPTH_TEXTURE, SCREEN_UV+vec2(0.0, pixel_size.y), INV_PROJECTION_MATRIX);
	float dd = linear_depth(DEPTH_TEXTURE, SCREEN_UV+vec2(0.0, -pixel_size.y), INV_PROJECTION_MATRIX);
	float dr = linear_depth(DEPTH_TEXTURE, SCREEN_UV+vec2(pixel_size.x, 0.0), INV_PROJECTION_MATRIX);
	float dl = linear_depth(DEPTH_TEXTURE, SCREEN_UV+vec2(-pixel_size.x, 0.0), INV_PROJECTION_MATRIX);
	
	// combine all the differences in depth of neighbors
	float diff = 0.0;
	diff += clamp(du - d, 0., 1.);
	diff += clamp(dd - d, 0., 1.);
	diff += clamp(dr - d, 0., 1.);
	diff += clamp(dl - d, 0., 1.);
	diff = smoothstep(0.2, 0.3, diff);
	float depthOutline = diff;

	
//	ALBEDO = computeNormalNaive(DEPTH_TEXTURE, model_view_matrix, INV_PROJECTION_MATRIX, SCREEN_UV, MODEL_MATRIX, VIEW_MATRIX, VIEWPORT_SIZE.xy);
//	ALBEDO = computeNormalImproved(DEPTH_TEXTURE, model_view_matrix, INV_PROJECTION_MATRIX, SCREEN_UV, MODEL_MATRIX, VIEW_MATRIX, VIEWPORT_SIZE.xy);
	
	float depthVisual = clamp(d / 50., 0., 1.);
//	ALBEDO = vec3(depthVisual);

//	Normal outline
	vec2 e = vec2(1./VIEWPORT_SIZE.xy);
	vec3 normal = computeNormalImproved(DEPTH_TEXTURE, model_view_matrix, INV_PROJECTION_MATRIX, SCREEN_UV, MODEL_MATRIX, VIEW_MATRIX, VIEWPORT_SIZE.xy);
	vec3 nu = computeNormalImproved(DEPTH_TEXTURE, model_view_matrix, INV_PROJECTION_MATRIX, SCREEN_UV+vec2(0, 1)*e, MODEL_MATRIX, VIEW_MATRIX, VIEWPORT_SIZE.xy);
	vec3 nr = computeNormalImproved(DEPTH_TEXTURE, model_view_matrix, INV_PROJECTION_MATRIX, SCREEN_UV+vec2(1, 0)*e, MODEL_MATRIX, VIEW_MATRIX, VIEWPORT_SIZE.xy);
	vec3 nd = computeNormalImproved(DEPTH_TEXTURE, model_view_matrix, INV_PROJECTION_MATRIX, SCREEN_UV+vec2(0, -1)*e, MODEL_MATRIX, VIEW_MATRIX, VIEWPORT_SIZE.xy);
	vec3 nl = computeNormalImproved(DEPTH_TEXTURE, model_view_matrix, INV_PROJECTION_MATRIX, SCREEN_UV+vec2(-1, 0)*e, MODEL_MATRIX, VIEW_MATRIX, VIEWPORT_SIZE.xy);
	float depthDiff = d;
	vec3 normalEdgeBias = vec3(1., 1., 1.);
	
	float normalOutline = 0.;
	normalOutline += normalIndicator(normalEdgeBias, normal, nu, depthDiff);
	normalOutline += normalIndicator(normalEdgeBias, normal, nr, depthDiff);
	normalOutline += normalIndicator(normalEdgeBias, normal, nd, depthDiff);
	normalOutline += normalIndicator(normalEdgeBias, normal, nl, depthDiff);
	normalOutline = smoothstep(0.2, 0.8, normalOutline);
	
//	Debugging stuff
//	float combinedOutline = normalOutline + depthOutline;
//	float bothOutline = normalOutline + depthOutline - 1.;
//
//	ALBEDO = vec3(combinedOutline);
	
//	Coloring based on the outlines
	vec3 original = texture(SCREEN_TEXTURE, SCREEN_UV).rgb;
	vec3 highlightColor = mix(original, vec3(1.), .03);
	vec3 shadowColor = mix(original, vec3(0.), .4);
	vec3 final = original;
	final = mix(final, highlightColor, normalOutline);
	final = mix(final, shadowColor, depthOutline);
	ALBEDO = final;
}
