#ifndef TERRAIN_GRASS_INCLUDED
#define TERRAIN_GRASS_INCLUDED

float _BendRotationRandom;
		
float _BladeHeight;
float _BladeHeightRandom;	
float _BladeWidth;
float _BladeWidthRandom;

float _BladeForward;
float _BladeCurve;

sampler2D _WindDistortionMap;
float4 _WindDistortionMap_ST;
float2 _WindFrequency;
float _WindStrength;

float _TessGrassDistance; //草的间隔，间隔越小，草越多

// float _MinViewDistance;
float _MaxViewDistance;

int _GrassLayerIndex;

// Simple noise function, sourced from http://answers.unity.com/answers/624136/view.html
// Extended discussion on this function can be found at the following link:
// https://forum.unity.com/threads/am-i-over-complicating-this-random-function.454887/#post-2949326
// Returns a number in the 0...1 range.
float rand(float3 co)
{
	return frac(sin(dot(co.xyz, float3(12.9898, 78.233, 53.539))) * 43758.5453);
}

// Construct a rotation matrix that rotates around the provided axis, sourced from:
// https://gist.github.com/keijiro/ee439d5e7388f3aafc5296005c8c3f33
float3x3 AngleAxis3x3(float angle, float3 axis)
{
	float c, s;
	sincos(angle, s, c);

	float t = 1 - c;
	float x = axis.x;
	float y = axis.y;
	float z = axis.z;

	return float3x3(
		t * x * x + c, t * x * y - s * z, t * x * z + s * y,
		t * x * y + s * z, t * y * y + c, t * y * z - s * x,
		t * x * z - s * y, t * y * z + s * x, t * z * z + c
		);
}

struct TessellationControlPoint
{
	float4 positionOS : INTERNALTESSPOS;
	float3 normalOS : NORMAL;
	float2 texcoord : TEXCOORD0;
	// float4 density  : TEXCOORD1;
};

struct InterpolatorsVertex
{
	float4 vertex : SV_POSITION;
	float3 normal : NORMAL;
	float4 tangent : TANGENT;
	float2 uv  : TEXCOORD0;
};

struct TessellationFactors
{
	float edge[3] : SV_TessFactor;
	float inside  : SV_InsideTessFactor;
};

struct GeometryOutput
{
	float4 pos : SV_POSITION;
	float2 uv : TEXCOORD0;
	float3 worldPos : TEXCOORD1;
	float normal : TEXCOORD2;
	float fogFactor : TEXCOORD3;
};

// Vertex shader which just passes data to tessellation stage.
InterpolatorsVertex tessVert(TessellationControlPoint v)
{
	InterpolatorsVertex o;
	o.vertex = float4(TransformObjectToWorld(v.positionOS), 1.f);
	o.normal = TransformObjectToWorldNormal(v.normalOS);
	o.tangent.xyz = cross(v.normalOS, float3(0,0,1));
	o.tangent.w = -1;
	o.uv = v.texcoord;
	
	return o;
}

float tessellationEdgeFactor(TessellationControlPoint vert0, TessellationControlPoint vert1)
{
	float3 v0 = vert0.positionOS.xyz;
	float3 v1 = vert1.positionOS.xyz;

	float3 edgeLength = distance(v0, v1);

	return (edgeLength/_TessGrassDistance);
}

bool needTessellation(TessellationControlPoint vert)
{
	float2 splatUV = (vert.texcoord * (_Control_TexelSize.zw - 1.0f) + 0.5f) * _Control_TexelSize.xy;
	half4 splatControl = SAMPLE_TEXTURE2D_LOD(_Control, sampler_Control, splatUV, 0);

	return splatControl[_GrassLayerIndex] >= 0.1;
}

// Tessellation hull and domain shaders derived from Catlike Coding's tutorial:
// https://catlikecoding.com/unity/tutorials/advanced-rendering/tessellation/

// The patch constant function is where we create new control
// points on the patch. For the edges, increasing the tessellation
// factors adds new vertices on the edge. Increasing the inside
// will add more 'layers' inside the new triangle.
TessellationFactors patchConstantFunc(InputPatch<TessellationControlPoint, 3> patch)
{
	TessellationFactors f;

	if (needTessellation(patch[0]) || needTessellation(patch[1]) || needTessellation(patch[2]))
	{
		f.edge[0] = tessellationEdgeFactor(patch[1], patch[2]);
		f.edge[1] = tessellationEdgeFactor(patch[2], patch[0]);
		f.edge[2] = tessellationEdgeFactor(patch[0], patch[1]);
		f.inside = (f.edge[0] + f.edge[1] + f.edge[2]) / 3.0f;
	}else
	{
		f.edge[0] = 1;
		f.edge[1] = 1;
		f.edge[2] = 1;
		f.inside = 1;
	}

	return f;
}

// The hull function is the first half of the tessellation shader.
// It operates on each patch (in our case, a patch is a triangle),
// and outputs new control points for the other tessellation stages.
//
// The patch constant function is where we create new control points
// (which are kind of like new vertices).
[domain("tri")]
[outputcontrolpoints(3)]
[outputtopology("triangle_cw")]
[partitioning("fractional_odd")]
[patchconstantfunc("patchConstantFunc")]
TessellationControlPoint hull(InputPatch<TessellationControlPoint, 3> patch, uint id : SV_OutputControlPointID)
{
	return patch[id];
}

// In between the hull shader stage and the domain shader stage, the
// tessellation stage takes place. This is where, under the hood,
// the graphics pipeline actually generates the new vertices.

// The domain function is the second half of the tessellation shader.
// It interpolates the properties of the vertices (position, normal, etc.)
// to create new vertices.
[domain("tri")]
InterpolatorsVertex domain(TessellationFactors factors, OutputPatch<TessellationControlPoint, 3> patch, float3 barycentricCoordinates : SV_DomainLocation)
{
	TessellationControlPoint i;

	#define INTERPOLATE(fieldname) i.fieldname = \
		patch[0].fieldname * barycentricCoordinates.x + \
		patch[1].fieldname * barycentricCoordinates.y + \
		patch[2].fieldname * barycentricCoordinates.z;

	INTERPOLATE(positionOS)
	INTERPOLATE(normalOS)
	INTERPOLATE(texcoord)

	return tessVert(i);
}
#endif