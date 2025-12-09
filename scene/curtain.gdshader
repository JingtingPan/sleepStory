shader_type spatial;
render_mode blend_mix;

void fragment() {
    vec4 base_color = texture(TEXTURE_ALBEDO, UV) * COLOR;
    float shadow = SHADOW_ATTENUATION(FRAGCOORD.xy);
    ALBEDO = base_color.rgb * shadow;
    ALPHA = base_color.a;
}