Shader "VF Shaders/Forward/Rocket Instancing REPLACE" {
    Properties {
        _Color ("Color 颜色", Vector) = (1,1,1,1)
        _SpecularColor ("Specular Color", Vector) = (1,1,1,1)
        _EmissionMask ("自发光正片叠底色", Vector) = (1,1,1,1)
        _MainTex ("Albedo (RGB) 漫反射 (A) 颜色遮罩", 2D) = "white" {}
        _NormalTex ("Normal 法线", 2D) = "bump" {}
        _MS_Tex ("Metallic (R) 透贴 (G) 金属 (A) 高光", 2D) = "black" {}
        _EmissionTex ("Emission (RGB) 自发光  (A) 抖动遮罩", 2D) = "black" {}
        _AlbedoMultiplier ("漫反射倍率", Float) = 1
        _NormalMultiplier ("法线倍率", Float) = 1
        _MetallicMultiplier ("金属倍率", Float) = 1
        _SmoothMultiplier ("高光倍率", Float) = 1
        _EmissionMultiplier ("自发光倍率", Float) = 5.5
        _EmissionJitter ("自发光抖动倍率", Float) = 0
        _EmissionJitterTex ("自发光抖动色条", 2D) = "white" {}
        _AlphaClip ("透明通道剪切", Float) = 0
        _CullMode ("剔除模式", Float) = 2
        _NoiseMap ("噪声贴图", 2D) = "white" {}
        [Toggle(_ENABLE_VFINST)] _ToggleVerta ("Enable VFInst ?", Float) = 0
    }
    SubShader {
        LOD 200
        Tags {
            "DisableBatching" = "true" "RenderType" = "Opaque"
        }
        Pass {
            Name "FORWARD"
            LOD 200
            Tags {
                "DisableBatching" = "true" "LIGHTMODE" = "FORWARDBASE" "RenderType" = "Opaque" "SHADOWSUPPORT" = "true"
            }
            Cull Off
            CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 5.0
			#pragma multi_compile_fwdbase nolightmap nodirlightmap nodynlightmap novertexlight
            #pragma enable_d3d11_debug_symbols
			
			#include "UnityCG.cginc"
			#include "AutoLight.cginc"
            #include "CGIncludes/DSPCommon.cginc"

			struct DysonRocketRenderingData
            {
                uint id;
                float3 rPos;
                float4 rRot;
                float3 rVel;
                float t;
            };
			
			struct v2f
			{
				float4 pos : SV_POSITION0;
				float4 TBNW0 : TEXCOORD0;
				float4 TBNW1 : TEXCOORD1;
				float4 TBNW2 : TEXCOORD2;
				float4 uv_lod_id : TEXCOORD3;
				float3 upDir : TEXCOORD4;
				float3 t : TEXCOORD5;
				float3 indirectLight : TEXCOORD6;
				UNITY_SHADOW_COORDS(8)
				float4 unk : TEXCOORD9;
			};
			
			struct fout
			{
				float4 sv_target : SV_Target0;
			};

			StructuredBuffer<DysonRocketRenderingData> _RocketBuffer;
			
			float4 _LightColor0;
			float4 _Global_AmbientColor0;
			float4 _Global_AmbientColor1;
			float4 _Global_AmbientColor2;
			float4 _Global_SunsetColor0;
			float4 _Global_SunsetColor1;
			float4 _Global_SunsetColor2;
			float4 _Global_PointLightPos;
			float4 _Color;
			float _AlbedoMultiplier;
			float _NormalMultiplier;
			float _MetallicMultiplier;
			float _SmoothMultiplier;
			float _EmissionMultiplier;
			float4 _EmissionMask;
			float _AlphaClip;
			float4 _SpecularColor;
			int _Global_DS_RenderPlace;
			
			sampler2D _MainTex;
			sampler2D _MS_Tex;
			sampler2D _NormalTex;
			sampler2D _EmissionTex;
			samplerCUBE _Global_PGI;
			
			v2f vert(appdata_full v, uint instanceID : SV_InstanceID)
			{
			    v2f o;
			    
                bool isStarOrDysonMap = _Global_DS_RenderPlace > 0.5; //r0.w
                float3 localPos = isStarOrDysonMap ? v.vertex.xyz / 4000.0 : v.vertex.xyz; //r0.xyz

                float3 rPos = _RocketBuffer[instanceID].rPos; //r1.xyz
                float distRPosToCam = distance(rPos, _WorldSpaceCameraPos); //r2.x
                float scaleFactor = 2.0 * max(1.0, pow(5.0 * distRPosToCam, 0.7)); //r2.y
                localPos = isStarOrDysonMap ? scaleFactor * localPos : localPos; //r0.xyz

                float4 rRot = _RocketBuffer[instanceID].rRot; //r3.xyzw
			    float3 worldPos = rotate_vector_fast(localPos, rRot) + rPos; //r5.xyz

                float3 camToPos = worldPos - _WorldSpaceCameraPos; //r0.xyz
                float distScale = 10000 * (log(length(camToPos) / 10000) + 1) / length(camToPos); //r1.y
			    worldPos = isStarOrDysonMap || distRPosToCam > 6000.0 || distCamToPos <= 10000.0 ? worldPos : camToPos * distScale + _WorldSpaceCameraPos; //r5.xyz
			    
			    float4 clipPos = mul(UNITY_MATRIX_VP, float4(worldPos, 1.0)); //r5.xyzw
                o.pos.xyzw = clipPos;
			    
                float3 worldTangent = UnityObjectToWorldDir(rotate_vector_fast(v.tangent.xyz, rRot)); // r6.xyz
			    float3 worldNormal = UnityObjectToWorldNormal(rotate_vector_fast(v.normal.xyz, rRot)); //r2.xyz
			    float3 worldBinormal = calculateBinormal(float4(worldTangent, v.tangent.w), worldNormal); //r3.xyz

			    o.TBNW0.x = worldTangent.x;
                o.TBNW0.y = worldBinormal.x;
			    o.TBNW0.z = worldNormal.x;
                o.TBNW0.w = worldPos.x;
                o.TBNW1.x = worldTangent.y;
                o.TBNW1.y = worldBinormal.y;
			    o.TBNW1.z = worldNormal.y;
			    o.TBNW1.w = worldPos.y;
                o.TBNW2.x = worldTangent.z;
                o.TBNW2.y = worldBinormal.z;
                o.TBNW2.z = worldNormal.z;
			    o.TBNW2.w = worldPos.z;

                uint id = _RocketBuffer[instanceID].id; //r1.x //r0.z
			    o.uv_lod_id.xy = v.texcoord.xy;
                o.uv_lod_id.z = isStarOrDysonMap ? saturate((600.0 - distRPosToCam) / 200.0) : 1.0;
			    float distanceThreshold = isStarOrDysonMap ? 800 : 6000;
                o.uv_lod_id.w = distRPosToCam <= distanceThreshold ? id : 0;
			    
			    o.upDir.xyz = normalize(rPos.xyz);
			    
			    float t = _RocketBuffer[instanceID].t; //r0.x
                o.t.xyz = float3(t, t, t);
			    
			    o.indirectLight = ShadeSH9(float4(worldNormal, 1.0));
			    UNITY_TRANSFER_SHADOW(o, float(0,0))
                o9.xyzw = float4(0,0,0,0);

                return o;
			}

			fout frag(v2f i)
			{
                float id = i.uv_lod_id.w;
                if (id < 0.5)
                    discard;

                float uv = uv_lod_id.xy;
                float3 mstex = tex2D(_MS_TEX, uv).xyw; //r0.xyz
                
                if (mstex.y < _AlphaClip - 0.001)
                    discard;

                float4 albedo = tex2D(_MainTex, uv); //r1.xyzw

                float3 unpackedNormal = UnpackNormal(tex2Dbias(_NormalTex, float4(uv, 0, -1)));
                float3 normal = float3(_NormalMultiplier * unpackedNormal.xy, unpackedNormal.z);
                normal = normalize(normal); //r2.xyz

                float3 emission = tex2Dbias(_EmissionTex, float4(uv,0,-1)).xyz; // r3.xyz
			    emission = _EmissionMask.xyz * _EmissionMultiplier * emission; //r3.xyz

                albedo.xyz = _AlbedoMultiplier * albedo.xyz; //r1.xyz
                float3 color = lerp(float3(1,1,1), _Color.xyz, saturate(1.25 * (albedo.w - 0.1)));
                float lod = i.uv_lod_id.z;
                albedo.xyz = lod * color.xyz * albedo.xyz; //r1.xyz

                float metallic = saturate(_MetallicMultiplier * mstex.x); //r0.x
                float smoothness = saturate(_SmoothMultiplier * mstex.z); //r0.y

                float3 starMapEmission = float3(0.8, 1.3, 1.1) * lod * albedo.xyz; //r5.xyz
                float3 dysonMapEmission = float3(1.2, 1.95, 1.65) * lod * albedo.xyz; // * lod twice?
                bool isDysonMap = _Global_DS_RenderPlace > 1.5; //r0.z
                bool isStarOrDysonMap = _Global_DS_RenderPlace > 0.5; //r0.w
                emission = isDysonMap ? dysonMapEmission.xyz : isStarOrDysonMap ? starMapEmission.xyz : emission; //r3.xyz

                float3 upDir = i.upDir.xyz; //r4.xyz
                float3 specularColor = _SpecularColor.xyz; //r5.xyz

                float3 worldPos = float3(i.TBNW0.w, i.TBNW1.w, i.TBNW2.w); //r6.yzw
                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - worldPos.xyz); //r8.xyz

                UNITY_LIGHT_ATTENUATION(atten, i, worldPos); // r0.w

                float3 worldNormal;
                worldNormal.x = dot(TBNW0.xyz, normal.xyz);
                worldNormal.y = dot(TBNW1.xyz, normal.xyz);
                worldNormal.z = dot(TBNW2.xyz, normal.xyz);
                float3 worldNormal = normalize(worldNormal.xyz); //r2.xyz

                float metallicLow = metallic * 0.85 + 0.149; //r6.y
                float metallicHigh = metallicLow + 0.5; //r6.x
                float perceptualRoughness = 1.0 - smoothness * 0.97; //r0.x
                float halfDir = normalize(viewDir.xyz + _WorldSpaceLightPos0.xyz); //r7.xyz
                float roughness = pow(perceptualRoughness, 2.0); //r0.z

                float nDotL = dot(worldNormal.xyz, _WorldSpaceLightPos0.xyz); //r2.w
                float nDotL_clamped = max(0, nDotL); //r3.w
                float nDotV = max(0, dot(worldNormal.xyz, viewDir.xyz)); //r4.w
                float nDotH = max(0, dot(worldNormal.xyz, halfDir.xyz)); //r5.w
                float vDotH = max(0, dot(viewDir.xyz, halfDir.xyz)); //r6.z
                float upDotL = dot(upDir.xyz, _WorldSpaceLightPos0.xyz); //r6.w
                float nDotUp = dot(worldNormal.xyz, upDir.xyz); //r7.x

                float reflectivity; //r0.x
                float3 reflectColor = reflection(perceptualRoughness, metallicLow, upDir, viewDir, worldNormal, /*out*/ reflectivity); //r7.yzw

                float3 sunlightColor = calculateSunlightColor(_LightColor0.xyz, upDotL, _Global_SunsetColor0.xyz, _Global_SunsetColor1.xyz, _Global_SunsetColor2.xyz); //r9.xyz
                atten = 0.8 * lerp(atten, 1.0, saturate(0.15 * upDotL)); //r0.w
                sunlightColor = atten * sunlightColor; //r9.xyz

                float specularTerm = GGX(roughness, metallicHigh, nDotH, nDotV, nDotL, vDotH); //r0.w

                float3 ambientColor = calculateAmbientColor(upDotL, _Global_AmbientColor1.xyz, _Global_AmbientColor1.xyz, _Global_AmbientColor1.xyz); //r10.xyw
                float ambientLight = ambientColor * saturate(nDotUp * 0.3 + 0.7) * pow(nDotL * 0.35 + 1.0, 3.0); //r11.xyz

                float3 nightLightOne = calculateLightFromHeadlamp(_Global_PointLightPos, upDir, _WorldSpaceLightPos0.xyz, worldNormal, 5.0, 20.0, false); //r2.xyz
                float3 reflectDir = reflect(-viewDir, worldNormal); //r8.xyz
                float3 nightLightTwo = calculateLightFromHeadlamp(_Global_PointLightPos, upDir, _WorldSpaceLightPos0.xyz, reflectDir, 20.0, 40.0, true); //r0.yzw
                
                float glossiness = 1.0 - metallicLow;
                float3 specularLight  = (nDotL_clamped + nightLightOne) * sunlightColor * specularColor * lerp(float3(1,1,1), albedo.xyz, glossiness) * (specularTerm + 0.0318309888); //r5.xyz
                float3 lightColor  = albedo.xyz * ambientLight * (1.0 - 0.6 * glossiness)
                                   + albedo.xyz * sunlightColor * nDotL_clamped * pow(glossiness, 0.6)
                                   + albedo.xyz * nightLightOne * (0.8 + 0.2 * pow(glossiness, 0.6))
                                   + ((albedo.xyz * 0.5 + 0.5) * nightLightTwo + specularLight) * (0.2 * glossiness * albedo.x + metallicLow); //r0.yzw
                                   

                float ambientGreyscale = 0.003 + dot(ambientColor.xyx, float3(0.3, 0.6, 0.1)); //r2.w
                float ambientIntensity = 0.003 + max(_Global_AmbientColor0.z, max(_Global_AmbientColor0.x, _Global_AmbientColor0.y)); //r3.w
                reflectColor = reflectColor * float3(1.7, 1.7, 1.7) / ambientIntensity * (0.4 * (ambientColor - ambientGreyscale) + ambientGreyscale);
                reflectColor = reflectColor * ((saturate(upDotL * 2.0 + 0.5) * 0.7 + 0.3) + nightLightOne); //r2.xyz
			    
                float3 finalColor = lerp(lightColor, reflectColor * albedo.xyz, reflectivity); //r0.xyz
                
                float colorIntensity = dot(finalColor, float3(0.3, 0.6, 0.1));
                finalColor.xyz = colorIntensity > 1 ? (finalColor / colorIntensity) * (log(log(colorIntensity) + 1.0) + 1.0) : finalColor.xyz;

                finalColor.xyz = albedo.xyz * i.indirectLight.xyz
			        + emission
			        + finalColor;

                o.sv_target.xyz = finalColor.xyz;
                o.sv_target.w = 1;

                return o;
			}
			ENDCG
        }
        Pass {
            Name "ShadowCaster"
            LOD 200
            Tags {
                "DisableBatching" = "true" "LIGHTMODE" = "SHADOWCASTER" "RenderType" = "Opaque" "SHADOWSUPPORT" = "true"
            }
            Cull Off
            CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 5.0
            #pragma multi_compile_shadowcaster
            #pragma enable_d3d11_debug_symbols
            
            #include "UnityCG.cginc"
            #include "AutoLight.cginc"
            #include "CGIncludes/DSPCommon.cginc"

			struct DysonRocketRenderingData
            {
                uint id;
                float3 rPos;
                float4 rRot;
                float3 rVel;
                float t;
            };
			
			struct v2f
			{
				float4 position : SV_POSITION0;
				float4 uv_lod_id : TEXCOORD1;
				float3 upDir : TEXCOORD2;
				float3 t : TEXCOORD3;
			};
			
			struct fout
			{
				float4 sv_target : SV_Target0;
			};

			StructuredBuffer<DysonRocketRenderingData> _RocketBuffer;
			
			float _AlphaClip;

			sampler2D _MS_Tex;
			
			// Keywords: SHADOWS_DEPTH
			v2f vert(appdata_full v)
			{
                v2f o;

                bool isStarOrDysonMap = _Global_DS_RenderPlace > 0.5; //r0.w
                float3 localPos = isStarOrDysonMap ? v.vertex.xyz / 4000.0 : v.vertex.xyz; //r0.xyz
                
                float3 rPos = _RocketBuffer[instanceID].rPos; //r1.xyz
                float distRPosToCam = distance(rPos.xyz, _WorldSpaceCameraPos.xyz); //r2.x
                float scaleFactor = 2.0 * max(1.0, pow(5.0 * distRPosToCam, 0.7)); //r2.y
                localPos = isStarOrDysonMap ? scaleFactor * localPos : localPos; //r0.xyz
                
                float4 rRot = _RocketBuffer[instanceID].rRot; //r3.xyzw
                float3 worldPos = rotate_vector_fast(localPos, rRot) + rPos; //r5.xyz
                
                float3 camToPos = worldPos - _WorldSpaceCameraPos; //r0.xyz
                float distScale = 10000 * (log(length(camToPos) / 10000) + 1) / length(camToPos); //r1.y
                worldPos = isStarOrDysonMap || distRPosToCam > 6000.0 || distCamToPos <= 10000.0 ? worldPos : camToPos * distScale + _WorldSpaceCameraPos; //r1.xyz
                
                float3 worldNormal = UnityObjectToWorldNormal(rotate_vector_fast(v.normal.xyz, rRot)); //r2.xyz
              
                float4 clipPos = UnityClipSpaceShadowCasterPos(float4(worldPos, 1.0), worldNormal);
                o.pos.xyzw = UnityApplyLinearShadowBias(clipPos);
              
                uint id = _RocketBuffer[instanceID].id; //r1.x //r0.z
                o.uv_lod_id.xy = v.texcoord.xy;
                o.uv_lod_id.z = isStarOrDysonMap ? saturate((600.0 - distRPosToCam) / 200.0) : 1.0;
                float distanceThreshold = isStarOrDysonMap ? 800 : 6000;
                o.uv_lod_id.w = distRPosToCam <= distanceThreshold ? id : 0;
                
                o.upDir.xyz = normalize(rPos);
              
                float t = _RocketBuffer[instanceID].t; //r0.x
                o.t.xyz = float3(t, t, t);
                
                return o;
			}
			
			fout frag(v2f inp)
			{
                fout o;

                if (i.uv_log_id.w) < 0.5)
                    discard;
                    
                float alpha = tex2D(_MS_Tex, i.uv).y;
                if (alpha < _AlphaClip - 0.001)
                    discard;

                o.sv_target = float4(0,0,0,0);
                return o;
			}
			ENDCG
        }
    }
    Fallback "Diffuse"
}