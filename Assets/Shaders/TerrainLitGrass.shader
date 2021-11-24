Shader "Custom/TerrainLitGrass"
{
    Properties
    {
	    ///////////////////////////////////////////////////////////////////////////////////////
        [Header(Grass)]
    	[Enum(TerrainLayerEnum)]_GrassLayerIndex("Grass Layer Index", int) = 1
    	
        _TopColor("Top Color", Color) = (1,1,1,1)
		_BottomColor("Bottom Color", Color) = (1,1,1,1)
        
        _BendRotationRandom("Bend Rotation Random", Range(0, 1)) = 0.2

		_BladeWidth("Blade Width", Float) = 0.05
		_BladeWidthRandom("Blade Width Random", Float) = 0.02
		_BladeHeight("Blade Height", Float) = 0.5
		_BladeHeightRandom("Blade Height Random", Float) = 0.3
        
        _BladeForward("Blade Forward Amount", Float) = 0.38
		_BladeCurve("Blade Curvature Amount", Range(1, 4)) = 2
        
        _WindDistortionMap("Wind Distortion Map", 2D) = "bump" {}
		_WindFrequency("Wind Frequency", Vector) = (0.05, 0.05, 0, 0)
		
		_WindStrength("Wind Strength", Range(0.001, 1)) = 1
        
        _TessGrassDistance("Tessellation Grass Distance", Range(0.1, 2)) = 0.2
        
//        _MinViewDistance("Min View Distance", Float) = 40
    	_MaxViewDistance("Max View Distance", Float) = 60
    	
    	_AmbientStrength("Ambient Strength", Range(0, 1)) = 0.5
    	
    	///////////////////////////////////////////////////////////////////////////////////////
    	[Header(Interactor)]
    	_InteractorRadius("Interactor Radius", Float) = 0.3
		_InteractorStrength("Interactor Strength", Float) = 5
    	
    	///////////////////////////////////////////////////////////////////////////////////////
        
        [HideInInspector] [ToggleUI] _EnableHeightBlend("EnableHeightBlend", Float) = 0.0

        [Header(Terrain)]
        _HeightTransition("Height Transition", Range(0, 1.0)) = 0.0
        // Layer count is passed down to guide height-blend enable/disable, due
        // to the fact that heigh-based blend will be broken with multipass.
        [HideInInspector] [PerRendererData] _NumLayersCount ("Total Layer Count", Float) = 1.0

        // set by terrain engine
        [HideInInspector] _Control("Control (RGBA)", 2D) = "red" {}
        [HideInInspector] _Splat3("Layer 3 (A)", 2D) = "grey" {}
        [HideInInspector] _Splat2("Layer 2 (B)", 2D) = "grey" {}
        [HideInInspector] _Splat1("Layer 1 (G)", 2D) = "grey" {}
        [HideInInspector] _Splat0("Layer 0 (R)", 2D) = "grey" {}
        [HideInInspector] _Normal3("Normal 3 (A)", 2D) = "bump" {}
        [HideInInspector] _Normal2("Normal 2 (B)", 2D) = "bump" {}
        [HideInInspector] _Normal1("Normal 1 (G)", 2D) = "bump" {}
        [HideInInspector] _Normal0("Normal 0 (R)", 2D) = "bump" {}
        [HideInInspector] _Mask3("Mask 3 (A)", 2D) = "grey" {}
        [HideInInspector] _Mask2("Mask 2 (B)", 2D) = "grey" {}
        [HideInInspector] _Mask1("Mask 1 (G)", 2D) = "grey" {}
        [HideInInspector] _Mask0("Mask 0 (R)", 2D) = "grey" {}
        [HideInInspector][Gamma] _Metallic0("Metallic 0", Range(0.0, 1.0)) = 0.0
        [HideInInspector][Gamma] _Metallic1("Metallic 1", Range(0.0, 1.0)) = 0.0
        [HideInInspector][Gamma] _Metallic2("Metallic 2", Range(0.0, 1.0)) = 0.0
        [HideInInspector][Gamma] _Metallic3("Metallic 3", Range(0.0, 1.0)) = 0.0
        [HideInInspector] _Smoothness0("Smoothness 0", Range(0.0, 1.0)) = 0.5
        [HideInInspector] _Smoothness1("Smoothness 1", Range(0.0, 1.0)) = 0.5
        [HideInInspector] _Smoothness2("Smoothness 2", Range(0.0, 1.0)) = 0.5
        [HideInInspector] _Smoothness3("Smoothness 3", Range(0.0, 1.0)) = 0.5

        // used in fallback on old cards & base map
        [HideInInspector] _MainTex("BaseMap (RGB)", 2D) = "grey" {}
        [HideInInspector] _BaseColor("Main Color", Color) = (1,1,1,1)

		[HideInInspector] _TerrainHolesTexture("Holes Map (RGB)", 2D) = "white" {}

        [ToggleUI] _EnableInstancedPerPixelNormal("Enable Instanced per-pixel normal", Float) = 1.0
    }
    HLSLINCLUDE

	#pragma multi_compile_fragment __ _ALPHATEST_ON

	ENDHLSL

    SubShader
    {
        Tags { "Queue" = "Geometry-100" "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "UniversalMaterialType" = "Lit" "IgnoreProjector" = "False"}

    	Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }
            HLSLPROGRAM
            #pragma target 3.0

            #pragma vertex SplatmapVert
            #pragma fragment SplatmapFragment

            #define _METALLICSPECGLOSSMAP 1
            #define _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A 1

            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile_fog
            #pragma multi_compile_instancing
            #pragma instancing_options assumeuniformscaling nomatrices nolightprobe nolightmap

            #pragma shader_feature_local_fragment _TERRAIN_BLEND_HEIGHT
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local_fragment _MASKMAP
            // Sample normal in pixel shader when doing instancing
            #pragma shader_feature_local _TERRAIN_INSTANCED_PERPIXEL_NORMAL

            #include "Packages/com.unity.render-pipelines.universal/Shaders/Terrain/TerrainLitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/Terrain/TerrainLitPasses.hlsl"
            ENDHLSL
        }
    	
        Pass
        {
            Name "GrassPass"
        	
            HLSLPROGRAM
            // #pragma target 4.6

            #pragma require geometry  //4.0
            #pragma require tessellation tessHW    //4.6

            #pragma vertex GrassVert
			#pragma hull hull
			#pragma domain domain
   
            #pragma geometry GrassGeom
            #pragma fragment GrassFrag

            #define BLADE_SEGMENTS 4

            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fog

            #include "Packages/com.unity.render-pipelines.universal/Shaders/Terrain/TerrainLitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/Terrain/TerrainLitPasses.hlsl"
            
            #include "TerrainGrassInclude.hlsl"

            float4 _TopColor;
			float4 _BottomColor;
            float _AmbientStrength;

            half _WindSpeed;

            // int _GrassLayerIndex;

            half _InteractorRadius, _InteractorStrength;
            
            uniform float3 _PositionMoving;

            struct TestOutput
            {
	            float4 clipPos : SV_POSITION;
            	float4 uvMainAndLM  : TEXCOORD0;
            	float4 splatControl  : TEXCOORD1;
            };
                        
            // Vertex shader which translates from object to world space.
            TessellationControlPoint GrassVert (Attributes v)
            {
            	TessellationControlPoint o = (TessellationControlPoint)0;
            	o.positionOS = v.positionOS;
            	o.normalOS = v.normalOS;
            	o.texcoord = v.texcoord;

            	return o;
            }

            half4 GrassFrag(GeometryOutput IN) : SV_TARGET
			{
			    // UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);

				float4 shadowCoord = TransformWorldToShadowCoord(IN.worldPos);
				
				#if _MAIN_LIGHT_SHADOWS
					Light mainLight = GetMainLight(shadowCoord);
				#else
					Light mainLight = GetMainLight();
				#endif
				
				float shadow = mainLight.shadowAttenuation;
				
				float4 baseColor = lerp(_BottomColor, _TopColor, saturate(IN.uv.y));

				// multiply with lighting color
				float4 litColor = (baseColor * float4(mainLight.color, 1));
				
				float4 final = litColor * shadow;
				
				// add in basecolor when lights turned down
				final += saturate((1 - shadow) * baseColor * 0.2);

				return final;
			}
            
            GeometryOutput GenerateGrassVertex(float3 baseWorldPos, float3 offset, float2 uv, float3x3 transformMatrix, float3 faceNormal)
			{					
				float3 grassWorldPos = baseWorldPos + mul(transformMatrix, offset);
					
				GeometryOutput o;
				o.pos = TransformWorldToHClip(grassWorldPos);
				o.uv = uv;
				o.worldPos = grassWorldPos;
				o.normal = faceNormal;

            	float fogFactor = ComputeFogFactor(o.pos.z);
				o.fogFactor = fogFactor;

				return o;
			}

            [maxvertexcount(BLADE_SEGMENTS * 2 + 1)]
			void GrassGeom(point InterpolatorsVertex IN[1], inout TriangleStream<GeometryOutput> triStream)
			{
				// bool b = UnityWorldViewFrustumCull(IN[0].position + unity_ObjectToWorld._m03_m13_m23, IN[1].position + unity_ObjectToWorld._m03_m13_m23, IN[2].position + unity_ObjectToWorld._m03_m13_m23, 2.0);

				float3 pos = IN[0].vertex; //world position

            	float distanceFromCamera = distance(pos, _WorldSpaceCameraPos);
				if (distanceFromCamera > _MaxViewDistance)
				{
					return;
				}

				float2 splatUV = (IN[0].uv * (_Control_TexelSize.zw - 1.0f) + 0.5f) * _Control_TexelSize.xy;
				half4 splatControl = SAMPLE_TEXTURE2D_LOD(_Control, sampler_Control, splatUV, 0);

				if (splatControl[_GrassLayerIndex] < 0.1)
				{
					return;
				}				

				float3 vNormal = IN[0].normal;
				float4 vTangent = IN[0].tangent;
				float3 vBinormal = cross(vNormal, vTangent.xyz) * vTangent.w;

				float3x3 tangentToLocal = float3x3(
					vTangent.x, vBinormal.x, vNormal.x,
					vTangent.y, vBinormal.y, vNormal.y,
					vTangent.z, vBinormal.z, vNormal.z
					);

				//We use the input position pos as the random seed for our rotation. This way, every blade will get a different rotation, but it will be consistent between frames.
				float3x3 facingRotationMatrix = AngleAxis3x3(rand(pos) * TWO_PI, float3(0, 0, 1.0f));

				//We use the position again as our random seed, this time swizzling it to create a unique seed. 
				float3x3 bendRotationMatrix = AngleAxis3x3(rand(pos.zzx) * _BendRotationRandom * PI * 0.5, float3(-1.0f, 0, 0));


				float2 windUV = pos.xz * _WindDistortionMap_ST.xy + _WindDistortionMap_ST.zw + _WindFrequency * _Time.y;
				float2 windSample = (tex2Dlod(_WindDistortionMap, float4(windUV, 0, 0)).xy * 2 - 1) * _WindStrength;
    			// float2 windSample = float2(0.73, 0.73);
    			// float2 windSample = (float2(0.5, 1) * 2 - 1) * _WindStrength;

				float3 windAxis = normalize(float3(windSample.x, windSample.y, 0));
				float3x3 windRotation = AngleAxis3x3(PI * windSample, windAxis);

				// Transform the grass blades to the correct tangent space.
				float3x3 baseTransformationMatrix = mul(tangentToLocal, facingRotationMatrix);
				float3x3 tipTransformationMatrix = mul(mul(mul(tangentToLocal, windRotation), facingRotationMatrix), bendRotationMatrix);
				
				float width = (rand(pos.xzy) * 2 - 1) * _BladeWidthRandom + _BladeWidth;
				float height = (rand(pos.zyx) * 2 - 1) * _BladeHeightRandom + _BladeHeight;		
				float forward = rand(pos.yyz) * _BladeForward;

				width = lerp(0, width, splatControl[_GrassLayerIndex]);
				height = lerp(0, height, splatControl[_GrassLayerIndex]);

            	// Interactivity
				float3 dis = distance(_PositionMoving, pos); // distance for radius
				float3 radius = 1 - saturate(dis / _InteractorRadius); // in world radius based on objects interaction radius
				float3 sphereDisp = pos - _PositionMoving; // position comparison
				sphereDisp *= radius; // position multiplied by radius for falloff
									  // increase strength
				sphereDisp = clamp(sphereDisp.xyz * _InteractorStrength, -0.8, 0.8);

				float3 faceNormal = float3(0, 1, 0);
				faceNormal = mul(faceNormal, facingRotationMatrix);

				for (int i = 0; i < BLADE_SEGMENTS; i++)
				{
					float t = i / (float)BLADE_SEGMENTS;

					float segmentWidth = width * (1 - t);
					float segmentHeight = height * t;
					float segmentForward = pow(t, _BladeCurve) * forward;

					// the first (0) grass segment is thinner
					segmentWidth = i == 0 ? width * 0.3 : segmentWidth;
					
					float3 offset = float3(segmentWidth, segmentForward, segmentHeight);
				
					float3x3 transformMatrix = i == 0 ? baseTransformationMatrix : tipTransformationMatrix;

					// first grass (0) segment does not get displaced by interactivity
					float3 newPos = i == 0 ? pos : pos + (float3(sphereDisp.x, sphereDisp.y, sphereDisp.z) * t);

					triStream.Append(GenerateGrassVertex(newPos, float3( offset.x, offset.y, offset.z), float2(0, t), transformMatrix, faceNormal));
					triStream.Append(GenerateGrassVertex(newPos, float3( -offset.x, offset.y, offset.z), float2(1, t), transformMatrix, faceNormal));
				}

            	triStream.Append(GenerateGrassVertex(pos + float3(sphereDisp.x * 1.5, sphereDisp.y, sphereDisp.z * 1.5), float3(0, forward, height), float2(0.5, 1), tipTransformationMatrix, faceNormal));

            	// restart the strip to start another grass blade
				// triStream.RestartStrip();
			}
            
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            ZWrite On
            ColorMask 0

            HLSLPROGRAM
            #pragma target 2.0

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            #pragma multi_compile_instancing
            #pragma instancing_options assumeuniformscaling nomatrices nolightprobe nolightmap

            #include "Packages/com.unity.render-pipelines.universal/Shaders/Terrain/TerrainLitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/Terrain/TerrainLitPasses.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "GBuffer"
            Tags{"LightMode" = "UniversalGBuffer"}

            HLSLPROGRAM
            #pragma exclude_renderers gles
            #pragma target 3.0
            #pragma vertex SplatmapVert
            #pragma fragment SplatmapFragment

            #define _METALLICSPECGLOSSMAP 1
            #define _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A 1

            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            //#pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            //#pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT
            //#pragma multi_compile_fog
            #pragma multi_compile_instancing
            #pragma instancing_options assumeuniformscaling nomatrices nolightprobe nolightmap

            #pragma shader_feature_local _TERRAIN_BLEND_HEIGHT
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _MASKMAP
            // Sample normal in pixel shader when doing instancing
            #pragma shader_feature_local _TERRAIN_INSTANCED_PERPIXEL_NORMAL
            #define TERRAIN_GBUFFER 1

            #include "Packages/com.unity.render-pipelines.universal/Shaders/Terrain/TerrainLitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/Terrain/TerrainLitPasses.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            ColorMask 0

            HLSLPROGRAM
            #pragma target 2.0

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            #pragma multi_compile_instancing
            #pragma instancing_options assumeuniformscaling nomatrices nolightprobe nolightmap

            #include "Packages/com.unity.render-pipelines.universal/Shaders/Terrain/TerrainLitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/Terrain/TerrainLitPasses.hlsl"
            ENDHLSL
        }

        // This pass is used when drawing to a _CameraNormalsTexture texture
        Pass
        {
            Name "DepthNormals"
            Tags{"LightMode" = "DepthNormals"}

            ZWrite On

            HLSLPROGRAM
            #pragma target 2.0
            #pragma vertex DepthNormalOnlyVertex
            #pragma fragment DepthNormalOnlyFragment

            #pragma shader_feature_local _NORMALMAP
            #pragma multi_compile_instancing
            #pragma instancing_options assumeuniformscaling nomatrices nolightprobe nolightmap

            #include "Packages/com.unity.render-pipelines.universal/Shaders/Terrain/TerrainLitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/Terrain/TerrainLitPasses.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "SceneSelectionPass"
            Tags { "LightMode" = "SceneSelectionPass" }

            HLSLPROGRAM
            #pragma target 2.0

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            #pragma multi_compile_instancing
            #pragma instancing_options assumeuniformscaling nomatrices nolightprobe nolightmap

            #define SCENESELECTIONPASS
            #include "Packages/com.unity.render-pipelines.universal/Shaders/Terrain/TerrainLitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/Terrain/TerrainLitPasses.hlsl"
            ENDHLSL
        }

        UsePass "Hidden/Nature/Terrain/Utilities/PICKING"
    }
    Dependency "AddPassShader" = "Hidden/Universal Render Pipeline/Terrain/Lit (Add Pass)"
    Dependency "BaseMapShader" = "Hidden/Universal Render Pipeline/Terrain/Lit (Base Pass)"
    Dependency "BaseMapGenShader" = "Hidden/Universal Render Pipeline/Terrain/Lit (Basemap Gen)"

//    CustomEditor "UnityEditor.Rendering.Universal.TerrainLitShaderGUI"

    Fallback "Hidden/Universal Render Pipeline/FallbackError"
}
