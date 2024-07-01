Shader "VF Shaders/Forward/Logistic Ship Instancing" {
	Properties {
		_Color ("Color 颜色", Color) = (1,1,1,1)
		_SpecularColor ("Specular Color", Color) = (1,1,1,1)
		_EmissionMask ("自发光正片叠底色", Color) = (1,1,1,1)
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
		Tags { "DisableBatching" = "true" "RenderType" = "LogisticShip" }
		Pass {
			Name "FORWARD"
			LOD 200
			Tags { "DisableBatching" = "true" "LIGHTMODE" = "FORWARDBASE" "RenderType" = "LogisticShip" "SHADOWSUPPORT" = "true" }
			Cull Off
			
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 5.0
			#pragma multi_compile_fwdbase nolightmap nodirlightmap nodynlightmap novertexlight
            #pragma enable_d3d11_debug_symbols
			
			#include "UnityCG.cginc"
			#include "AutoLight.cginc"
            #include "../CGIncludes/DSPCommon.cginc"

			struct ShipRenderingData
            {
                int gid;
                float3 pos;
                float3 vel;
                float4 rot;
                float4 anim;
                uint itemId;
            };
			
			struct v2f
            {
                float4 pos : SV_POSITION;
                float4 TBNW0 : TEXCOORD0;
                float4 TBNW1 : TEXCOORD1;
                float4 TBNW2 : TEXCOORD2;
                float3 uv_gid : TEXCOORD3;
                float3 itemColor : TEXCOORD4;
                float3 upDir : TEXCOORD5;
                float3 anim : TEXCOORD6;
                float3 indirectLight : TEXCOORD7;
                UNITY_SHADOW_COORDS(9)
                float4 unk : TEXCOORD10;
            };
			
			struct fout
			{
				float4 sv_target : SV_Target0;
			};

			StructuredBuffer<ShipRenderingData> _ShipBuffer;
            StructuredBuffer<uint> _Global_ItemIconIndexBuffer;
            StructuredBuffer<float> _Global_ItemDescBuffer;
			
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
			float _EmissionJitter;
			float _AlphaClip;
			float4 _SpecularColor;
			
			sampler2D _MainTex;
			sampler2D _MS_Tex;
			sampler2D _NormalTex;
			sampler2D _EmissionTex;
			sampler2D _EmissionJitterTex;
			
			v2f vert(appdata_full v, uint instanceID : SV_InstanceID)
			{
			    v2f o;
			    
                int gid = _ShipBuffer[instanceID].gid; //r0.x
                float3 pos = _ShipBuffer[instanceID].pos; //r0.yzw
                float distPosToCam = distance(pos, _WorldSpaceCameraPos); //r0.y

                float4 rot = _ShipBuffer[instanceID].rot; //r2.xyzw
                float3 worldPos = rotate_vector_fast(v.vertex.xyz, rot) + pos; //r3.xyz
                float3 worldNormal = rotate_vector_fast(v.normal.xyz, rot); // r6.xyz
                float3 worldTangent = rotate_vector_fast(v.tangent.xyz, rot); // r5.xyz

                worldNormal = normalize(worldNormal); //r2.xyz
                worldTangent = normalize(worldTangent); //r4.xyz

                o.upDir.xyz = normalize(pos);

                float4 anim = _ShipBuffer[instanceID].anim;
                o.anim.xyz = anim.xyz;

                uint itemId = _ShipBuffer[instanceID].itemid; //r0.z //r0.w

                if (itemId > 0.5) {
                    uint itemDescIdx = _Global_ItemIconIndexBuffer[itemId]; //r0.z
                    itemDescIdx = 0.49999 + itemDescIdx; //r0.z
                    int baseIndex = itemDesc * 40; //r0.w

                    float3 faceColor; // r1.xyz
                    faceColor.x = _Global_ItemDescBuffer[baseIndex];
                    faceColor.y = _Global_ItemDescBuffer[baseIndex + 1];
                    faceColor.z = _Global_ItemDescBuffer[baseIndex + 2];
                    faceColor = GammaToLinear_Approx(faceColor);

                    float3 faceEmission; //r5.xyz
                    faceEmission.x = _Global_ItemDescBuffer[baseIndex + 8];
                    faceEmission.y = _Global_ItemDescBuffer[baseIndex + 9];
                    faceEmission.z = _Global_ItemDescBuffer[baseIndex + 10];
                    faceEmission = GammaToLinear_Approx(faceEmission);

                    o.itemColor.xyz = faceEmission.xyz + faceColor.xyz;
                } else {
                    o.itemColor.xyz = float3(1,1,1);
                }

                o.uv_gid.z = distPosToCam > 10000.0 ? 0 : gid;

                worldPos = mul(unity_ObjectToWorld, float4(worldPos, v.vertex.w)).xyz; //r0.xyz

                float4 clipPos = UnityObjectToClipPos(worldPos); // r1.xyzw

                worldNormal = UnityObjectToWorldNormal(worldNormal); //r2.xyz
                worldTangent = UnityObjectToWorldDir(worldTangent); //r3.xyz
                float3 worldBinormal = calculateBinormal(float4(worldTangent, v.tangent.w), worldNormal); //r4.xyz

                o.pos.xyzw = clipPos;

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

                o.uv_gid.xy = v.texcoord.xy;

                o.indirectLight = ShadeSH9(float4(worldNormal, 1.0));
                UNITY_TRANSFER_SHADOW(o, float(0,0))
                o.unk.xyzw = float4(0,0,0,0);

                return o;
			}
			
			fout frag(v2f i)
			{
                fout o;

                if (i.uv_gid.z < 0.5)
                    discard;

                float3 msTex = tex2D(_MS_Tex, i.uv_gid.xy).xyw; //r0.xyz

                if (msTex.y < _AlphaClip - 0.001)
                    discard;

                float4 mainTex = tex2D(_MainTex, i.uv_gid.xy); //r1.xyzw

                float3 unpackedNormal = UnpackNormal(tex2Dbias(_NormalTex, float4(i.uv_gid.xy, 0, -1)));
                float3 normal = float3(_NormalMultiplier * unpackedNormal.xy, unpackedNormal.z);
                normal = normalize(normal); //r2.xyz

                float4 emissionTex = _EmissionTex.SampleBias(s6_s, i.uv_gid.xy, -1).xyzw; //r3.xyzw

                float2 jitterUV = float2(i.anim.x, 0); //r4.xy
                float jitterTex = tex2D(_EmissionJitterTex, jitterUV).x; // r2.w

                float3 albedo = _AlbedoMultiplier * mainTex.xyz; // r1.xyz
                float3 itemTint = lerp(float3(1,1,1), i.itemColor.xyz, saturate(1.25 * (mainTex.w - 0.1)));
                albedo = _Color.xyz * itemTint * albedo;

                float metallic = saturate(_MetallicMultiplier * msTex.x); //r0.x
                float smoothness = saturate(_SmoothMultiplier * msTex.z); //r0.y

                float3 emission = _EmissionMultiplier * emissionTex.xyz; // r3.xyz
                float jitter = lerp(1.0, jitterTex, _EmissionJitter * emissionTex.w); //r0.z
                emission = _EmissionMask.xyz * emission * jitter; //r3.xyz

                float3 upDir = i.upDir.xyz; //r4.xyz
                float3 specularColor = _SpecularColor.xyz; //r5.xyz
                float3 worldPos = float3(i.TBNW0.w, i.TBNW1.w, i.TBNW2.w); // r6.yzw

                float3 posToCam = _WorldSpaceCameraPos - worldPos; //r7.xyz
                float3 viewDir = normalize(posToCam); //r8.xyz

                UNITY_LIGHT_ATTENUATION(atten, inp, worldPos); //r0.w

                float3 worldNormal = float3(
                    dot(TBNW0.xyz, normal),
                    dot(TBNW1.xyz, normal),
                    dot(TBNW2.xyz, normal)
                );
                worldNormal = normalize(worldNormal); //r2.xyz

                metallic = metallic * 0.85 + 0.149; //r6.y

                float perceptualRoughness = 1.0 - smoothness * 0.97; // r0.x

                float3 lightDir = _WorldSpaceLightPos0.xyz;
                float3 halfDir = normalize(viewDir + lightDir); //r7.xyz

                float roughness = perceptualRoughness * perceptualRoughness; //r0.z
                float roughnessSqr = roughness * roughness; //r1.w

                float nDotL = dot(worldNormal, lightDir); // r2.w
                float nDotL_clamped = max(0, nDotL); // r3.w
                float nDotV = max(0, dot(worldNormal, viewDir)); //r4.w
                float nDotH = max(0, dot(worldNormal, halfDir)); //r5.w
                float vDotH = max(0, dot(viewDir, halfDir)); //r6.z

                float upDotL = dot(upDir, lightDir); //r6.w
                float nDotUp = dot(worldNormal, upDir); // r7.x

                float reflectivity; //r0.x
                float3 reflectColor = reflection(perceptualRoughness, metallicLow, upDir, viewDir, worldNormal, /*out*/ reflectivity); //r7.yzw

                float3 sunlightColor = calculateSunlightColor(_LightColor0, upDotL, _Global_SunsetColor0.xyz, _Global_SunsetColor1.xyz, _Global_SunsetColor2.xyz); //r9.xyz
                atten = 0.8 * lerp(atten, 1.0, saturate(0.15 * upDotL)); //r0.w
                sunlightColor = atten * sunlightColor;

                float specularTerm = GGX(roughness, metallic + 0.5, nDotH, nDotV, nDotL, vDotH); //r0.z * r0.w

                float3 ambientColor = calculateAmbientColor(i.upDir, lightDir, _Global_AmbientColor0.xyz, _Global_AmbientColor0.xyz, _Global_AmbientColor0.xyz); //r10.xyw
                float3 ambientLight = ambientColor * saturate(nDotUp * 0.3 + 0.7) * pow(nDotL * 0.35 + 1.0, 3.0); //r11.xyz

                float3 headlampLight = calculateLightFromHeadlamp(_Global_PointLightPos, upDir, lightDir, worldNormal, 5.0, 20.0, false, 1.0); //r2.xyz

                float3 light = (sunlightColor * nDotL_clamped) * pow(1.0 - metallic, 0.6) + (pow(1.0 - metallic, 0.6) * 0.2 + 0.8) * headlampLight; //r12.xyz

                specularColor = specularColor * lerp(float3(1,1,1), albedo, metallic); //r5.xyz
                float3 specularLight = (nDotL_clamped + headlampLight) * specularColor * sunlightColor * (specularTerm + INV_TEN_PI); //r5.xyz

                float3 reflectDir = reflect(-viewDir, worldNormal);
                float3 specularHeadlampLight = calculateLightFromHeadlamp(_Global_PointLightPos, upDir, lightDir, reflectDir, 20.0, 40.0, true, smoothness); //r0.yzw

                specularLight = lerp(metallic, 1.0, albedo.x / 5.0) * (specularLight + (albedo * 0.5 + 0.5) * specularHeadlampLight);

                float ambientLuminance = 0.003 + dot(ambientColor.xyx, float3(0.3, 0.6, 0.1)); //r2.w
                float maxAmbient = 0.003 + max(_Global_AmbientColor0.z, max(_Global_AmbientColor0.x, _Global_AmbientColor0.y)); //r3.w
                float3 reflectedAmbient = lerp(ambientLuminance, ambientColor, 0.4) / maxAmbient; //r5.xyz
                reflectColor = reflectColor * float3(1.7, 1.7, 1.7) * reflectedAmbient; //r5.xyz
                float3 nightLight = (saturate(upDotL * 2.0 + 0.5) * 0.7 + 0.3) + headlampLight; //r2.xyz
                reflectColor = reflectColor * nightLight; //r2.xyz

                float3 finalColor = ambientLight * albedo * (1.0 - metallic * 0.6)
                                  + light * albedo
			                      + specularLight; // r0.yzw
                finalColor = lerp(finalColor, reflectColor * albedo, reflectivity); //r0.xyz

                float finalColorLuminance = dot(finalColor, float3(0.3, 0.6, 0.1)); //r0.w
                finalColor = finalColorLuminance > 1.0 ? finalColor / finalColorLuminance * (log(log(finalColorLuminance) + 1.0) + 1.0) : finalColor;

                finalColor = albedo * i.indirectLight.xyz + finalColor + emission;

                o.sv_target.xyz = finalColor;
                o.sv_target.w = 1;
			    
                return o;
			}
			ENDCG
		}
		Pass {
			Name "ShadowCaster"
			LOD 200
			Tags { "DisableBatching" = "true" "LIGHTMODE" = "SHADOWCASTER" "RenderType" = "LogisticShip" "SHADOWSUPPORT" = "true" }
			Cull Off
			
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 5.0
            #pragma multi_compile_shadowcaster
            #pragma enable_d3d11_debug_symbols
			
			#include "UnityCG.cginc"
			#include "AutoLight.cginc"
            #include "../CGIncludes/DSPCommon.cginc"

			struct ShipRenderingData
            {
                int gid;
                float3 pos;
                float3 vel;
                float4 rot;
                float4 anim;
                uint itemId;
            };
			
			struct v2f
            {
                float4 pos : SV_POSITION;
                float3 uv_gid : TEXCOORD0;
            };
			
			struct fout
			{
				float4 sv_target : SV_Target0;
			};
			
			float _AlphaClip;
			
			sampler2D _MS_Tex;
			
			v2f vert(appdata_full v)
			{
                v2f o;
			    
                int gid = _ShipBuffer[instanceID].gid; //r0.x
                float3 pos = _ShipBuffer[instanceID].pos; //r0.yzw
                float distPosToCam = distance(pos, _WorldSpaceCameraPos); //r0.y

                float4 rot = _ShipBuffer[instanceID].rot; //r2.xyzw
                float3 worldPos = rotate_vector_fast(v.vertex.xyz, rot) + pos; //r3.xyz
                float3 worldNormal = rotate_vector_fast(v.normal.xyz, rot); // r6.xyz

                worldNormal = normalize(worldNormal); //r2.xyz

                o.uv_gid.z = distPosToCam > 10000.0 ? 0 : gid;

                worldPos = mul(unity_ObjectToWorld, float4(worldPos, v.vertex.w)).xyz; //r0.xyz
                worldNormal = UnityObjectToWorldNormal(worldNormal); //r2.xyz

                float4 clipPos = UnityClipSpaceShadowCasterPos(float4(worldPos, 1.0), worldNormal);
                o.pos.xyzw = UnityApplyLinearShadowBias(clipPos);

                o.uv_gid.xy = v.texcoord.xy;

                return o;
			}
			
			fout frag(v2f inp)
			{
                fout o;

                if (i.uv_gid.z < 0.5)
                    discard;
                    
                float alpha = tex2D(_MS_Tex, i.uv_gid.xy).y;
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