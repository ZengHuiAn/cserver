
local vart = [[
attribute vec4 a_position;
attribute vec2 a_texCoord;
attribute vec4 a_color;

#ifdef GL_ES
varying lowp vec4 v_fragmentColor;
varying mediump vec2 v_texCoord;
#else
varying vec4 v_fragmentColor;
varying vec2 v_texCoord;
#endif

void main()
{
    gl_Position = CC_PMatrix * a_position;

    // gl_Position = CC_MVPMatrix * a_position;

    v_fragmentColor = a_color;
    v_texCoord = a_texCoord;
}
]]

local frag = [[

#ifdef GL_ES
precision mediump float;
#endif

uniform float color_offset;

varying vec2 v_texCoord;
varying vec4 v_fragmentColor;

vec3 rgb2hsv(vec3 c)
{
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));

    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c)
{
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void main(void)
{
	vec4 col = texture2D(CC_Texture0, v_texCoord);

	vec3 c3 = rgb2hsv(col.rgb);
		
	c3.r = c3.r + color_offset;
	c3.r = c3.r - floor(c3.r);

	// c3.g = c3.g * sin(v_texCoord.y * 300) / 2;

	vec3 col2 = hsv2rgb(c3);

	gl_FragColor = v_fragmentColor * vec4(col2.r, col2.g, col2.b, col.a);
}
]]


local scanLine_vart = [[
attribute vec4 a_position;
attribute vec2 a_texCoord;
attribute vec4 a_color;

#ifdef GL_ES
varying lowp vec4 v_fragmentColor;
varying mediump vec2 v_texCoord;
#else
varying vec4 v_fragmentColor;
varying vec2 v_texCoord;
#endif

void main()
{
    gl_Position = CC_MVPMatrix * a_position;

    v_fragmentColor = a_color;
    v_texCoord = a_texCoord;
}
]]

local scanLine_frag = [[
precision highp float;
varying vec4 v_fragmentColor;
varying vec2 v_texCoord;

uniform float color_offset;

//TE scanline effect
//some code by iq, extended to make it look right
//ported to Rajawali by Davhed

float rand(vec2 co) {
	return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

void main() {
	float uTime = color_offset;

	vec2 uv = v_texCoord;


	float a = texture2D(CC_Texture0,v_texCoord).a;

	vec3 oricol = texture2D(CC_Texture0,v_texCoord).xyz;
	vec3 col;
	float q = 0.5;

	// start with the source texture and misalign the rays it a bit
	// TODO animate misalignment upon hit or similar event
	col.r = texture2D(CC_Texture0,vec2(uv.x+0.003,uv.y)).x;
    col.g = texture2D(CC_Texture0,vec2(uv.x+0.000,uv.y)).y;
	col.b = texture2D(CC_Texture0,vec2(uv.x-0.003,uv.y)).z;

	// contrast curve
	col = clamp(col*0.5+0.5*col*col*1.2,0.0,1.0);

	//vignette	
	col *= 0.6 + 0.4*16.0*uv.x*uv.y*(1.0-uv.x)*(1.0-uv.y);

	//color tint
	col *= vec3(0.9,1.0,0.7);

	//scanline (last 2 constants are crawl speed and size)
	//TODO make size dependent on viewport
	col *= 0.8+0.2*sin(10.0*uTime+uv.y*900.0);

	//flickering (semi-randomized)
	col *= 1.0-0.07*rand(vec2(uTime, tan(uTime)));

	//smoothen
	float comp = smoothstep( 0.2, 0.7, sin(uTime) );
	col = mix( col, oricol, clamp(-2.0+2.0*q+3.0*comp,0.0,1.0) );
	gl_FragColor = vec4(col,a);
}
]]


local color_offset_program = nil;
local color_offset_program_2 = nil;
return {
	set =  function (node, delay, from, to)
		if not xx_GLAction then
			return;
		end

		if color_offset_program == nil  then
			local program = cc.GLProgram:new();
			program:initWithByteArrays(vart, frag);
			program:link();
			program:updateUniforms();
			color_offset_program = program;
			color_offset_program:retain();
		end

		node:setGLProgramState(cc.GLProgramState:create(color_offset_program));

		if not delay then
			node:runAction(cc.RepeatForever:create(cc.Sequence:create(
				xx_GLAction(3.0, "color_offset", 1.0, 0.0)
			)))
		else
			print(from, "->", to);
			node:runAction(cc.Sequence:create(
				xx_GLAction(delay, "color_offset", from, to)
			))
		end
	end,


	set2 =  function (node)
		if not xx_GLAction then
			return;
		end

		if color_offset_program_2 == nil  then
			local program = cc.GLProgram:new();
			program:initWithByteArrays(scanLine_vart, scanLine_frag);
			program:link();
			program:updateUniforms();
			color_offset_program_2 = program;
			color_offset_program_2:retain();
		end

		node:setGLProgramState(cc.GLProgramState:create(color_offset_program_2));

		node:runAction(cc.RepeatForever:create(cc.Sequence:create(
			xx_GLAction(1, "color_offset", 0, 0)
		)))
	end
}