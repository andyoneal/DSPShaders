Shader "VF Shaders/Forward/Rocket Effect Instancing REPLACE" {
    Properties {
        _Color ("Color 颜色", Color) = (1,1,1,1)
        _EmissionMask ("自发光正片叠底色", Color) = (1,1,1,1)
        _MainTex ("Albedo (RGB) 漫反射 (A) 颜色遮罩", 2D) = "white" {}
        _EmissionTex ("Emission (RGB) 自发光  (A) 抖动遮罩", 2D) = "black" {}
        _EffectTex1 ("特效图1", 2D) = "black" {}
        _EffectTex2 ("特效图2", 2D) = "black" {}
        _AlbedoMultiplier ("漫反射倍率", Float) = 1
        _EmissionMultiplier ("自发光倍率", Float) = 5.5
        _EmissionJitter ("自发光抖动倍率", Float) = 0
        _EmissionJitterTex ("自发光抖动色条", 2D) = "white" {}
        _NoiseMap ("噪声贴图", 2D) = "white" {}
        _ZMin ("Z Min", Float) = 0
        _ZMax ("Z Max", Float) = 1
        [Toggle(_ENABLE_VFINST)] _ToggleVerta ("Enable VFInst ?", Float) = 0
    }
    SubShader {
        LOD 200
        Tags { "DisableBatching" = "true" "RenderType" = "Opaque" }
        Pass {
            LOD 200
            Tags { "DisableBatching" = "true" "RenderType" = "Opaque" }
            Blend SrcAlpha One, SrcAlpha One
            ZWrite Off
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
                Vector3 rPos;
                Quaternion rRot;
                Vector3 rVel;
                float t;
            };
            
            struct v2f
            {
                float4 pos : SV_POSITION0;
                float4 uv_uv : TEXCOORD0;
                float3 unk : TEXCOORD1;
                float3 upDir : TEXCOORD2;
                float4 unk2 : TEXCOORD3;
                float4 screenPos : TEXCOORD4;
                float4 effSelect : TEXCOORD5;
            };
            
            struct fout
            {
                float4 sv_target : SV_Target0;
            };
            
            StructuredBuffer<DysonRocketRenderingData> _RocketBuffer;
            
            float4 _Color;
            float _AlbedoMultiplier;
            float _EmissionJitter;
            float _ZMin;
            float _ZMax;
            int _Global_DS_RenderPlace;
            
            sampler2D _CameraDepthTexture;
            sampler2D _MainTex;
            sampler2D _EffectTex1;
            sampler2D _EffectTex2;
            sampler2D _EmissionTex;
            sampler2D _EmissionJitterTex;
            sampler2D _WarpMap;
            
            v2f vert(appdata_full v, uint instanceID : SV_InstanceID)
            {
                v2f o;
                
                float3 rPos = _RocketBuffer[instanceID].rPos; //r0.xyz
                float4 rRot = _RocketBuffer[instanceID].rRot; // r1.xyzw
                
                uint effectSelector = 255 * v.color.x; //r2.x
                float3 localPos = v.vertex.xyz; //r2.yzw
                
                float2 effectTransform = float2(0, 0); //r3.xy
                float4 effectSelOutput = float4(0, 0, 0, 1); //r4.xyzw
                
                if (effectSelector >= 0.5)
                {
                    float2 noiseUV;
                    noiseUV.x = 2.0 * _Time.y;
                    noiseUV.y = (1.0/256) - rPos.z / 128.0;
                    float noise = _NoiseMap.SampleLevel(s0_s, noiseUV.xy, 0).x; //r3.z
                    noise = noise - 0.5;
                    
                    // == 1
                    if (effectSelector < 1.5) 
                    {
                        localPos.xyz = lerp(float3(0, 0, -5.5), v.vertex.xyz, noise * 0.15 + 1.05);
                        effectSelOutput.y = 1;
                        effectSelOutput.w = 0;
                    }
                    // == 2+
                    else 
                    {
                        float3 posToCam = _WorldSpaceCameraPos.xyz - rPos.xyz; // r5.xyz
                        float distPosToCam = distance(rPos, _WorldSpaceCameraPos); //r4.w
                        float camDistScaler = 1.0 + max(0, (20/11) * log(distPosToCam + 1.0) - 11.0); //r5.w
                        
                        // == 2
                        if (effectSelector < 2.5)
                        {
                            float3 viewDir = normalize(posToCam); //r5.xyz
                            
                            float3 yAxis; //r8.xyz
                            r6.yzw = rRot.yzy + rRot.yzy;
                            r7.xyz = r6.yzw * rRot.yyw;
                            yAxis.x = -rRot.x * r6.z - r7.z;
                            yAxis.y = r1.w * (2.0 * rRot.x) - r7.y;
                            yAxis.z = (rRot.x * (2.0 * rRot.x) + r7.x) - 1.0;
                            
                            effectTransform.xy = float2(12, 6) * v.vertex.xy * camDistScaler;
                            effectSelOutput.z = 0.8
                                * (_Global_Dimlight_Gain + (1.0 / pow(camDistScaler, 0.2)))
                                * (1.0 / (1.0 + max(0, distPosToCam / 120000 - 1.0)))
                                * saturate(2.0 * (1.0 + dot(viewDir, yAxis))+ 0.3);
                            
                            localPos = float3(0, 0, 0.4 * v.vertex.z);
                        }
                        // == 3+
                        else
                        {
                            // == 5+
                            if (effectSelector > 4.5)
                            {
                                effectSelOutput.x = 1.0 / pow(max(1.0, 0.5 * camDistScaler), 0.3);
                                if (v.vertex.z < -4.95)
                                {
                                    float3 rVel = _RocketBuffer[instanceID].rVel; //r1.yzw
                                    localPos.z = (4.95 + v.vertex.z) * (3.3 + length(rVel) * 0.023 + 0.7 * noise) - 4.95;
                                }
                                
                                localPos.xy = localPos.z < -3.95 ? v.vertex.xy * max(1.0, 0.5 * camDistScaler) : v.vertex.xy;
                            }
                            // == 3 or 4
                            else
                            {
                                effectSelOutput.x = 1;
                            }
                        }
                    }
                }
                
                float distCamToPos = distance(_WorldSpaceCameraPos.xyz, rPos.xyz); //r0.w
                r0.xyz = distCamToPos > 10000.0 ? camToPos.xyz * ((10000.0 * r1.z) / distCamToPos) : camToPos.xyz;
                float3 scaledRPos = _WorldSpaceCameraPos.xyz + r0.xyz; //r0.xyz
                
                localPos = rotate_vector_fast(localPos, rRot); //r6.xyz
                float4 worldPos = float4(localPos + scaledRPos, 1.0); // r1.xyz
                
                float3 camRightDir = normalize(UNITY_MATRIX_V._11_21_31); //r0.xyz
                // camRightDir.x = unity_MatrixV[0].x;
                // camRightDir.y = unity_MatrixV[1].x;
                // camRightDir.z = unity_MatrixV[2].x;
                // camRightDir = normalize(camRightDir); //r0.xyz
                
                float3 camUpDir = normalize(UNITY_MATRIX_V._12_22_32); //r2.xyz
                // camUpDir.x = unity_MatrixV[0].y;
                // camUpDir.y = unity_MatrixV[1].y;
                // camUpDir.z = unity_MatrixV[2].y;
                // camUpDir = normalize(camUpDir); //r2.xyz
                
                worldPos = worldPos + camRightDir * effectTransform.x + camUpDir * effectTransform.y; //r0.xyz
                worldPos = mul(unity_ObjectToWorld, float4(worldPos.xyz, 1); //r0.xyzw
                
                float4 clipPos = mul(UNITY_MATRIX_VP, worldPos); //r1.xyzw
                
                o.pos.xyzw = clipPos.xyzw;
                o.uv_uv.xyzw = v.texcoord.xyxy;
                o.unk.xyz = float3(1,1,1);
                o.upDir.xyz = normalize(scaledRPos);
                o.unk2.xyzw = float4(0,0,1,0);
                
                o.screenPos.xyw = ComputeScreenPos(clipPos).xyw;
                
                // r0.y = unity_MatrixV[1].z * worldPos.y;
                // r0.x = unity_MatrixV[0].z * worldPos.x + r0.y;
                // r0.x = unity_MatrixV[2].z * worldPos.z + r0.x;
                // r0.x = unity_MatrixV[3].z * worldPos.w + r0.x;
                o.screenPos.z = -dot(UNITY_MATRIX_V._13_23_33_43, worldPos);
                
                o.effSelect.xyzw = effectSelOutput.xyzw;
                return o;
            }

            fout frag(v2f inp)
            {
                fout o;
                
                if (_Global_DS_RenderPlace > 0.5)
                    discard;
                
                if (i.unk2.z < 0.001)
                    discard;
                
                float2 projUV = i.screenPos.xy / i.screenPos.ww;
                float sceneZ = LinearEyeDepth(tex2D(_CameraDepthTexture, projUV).x); //r0.x
                
                float fade = 0.2 + _ZMax - _ZMin; //r0.z
                float fade_1 = saturate((0.2 + (sceneZ - i.screenPos.z) - _ZMin) / fade); //r0.x
                float fade_2 = saturate(i.screenPos.z / fade); //r0.y
                
                float fade_toggle = _ZMax < (sceneZ - i.screenPos.z) ? 1.0 : 0.0; //r1.x
                fade_1 = fade == 0.0 ? fade_toggle : fade_1;
                fade_2 = fade == 0.0 ? 1.0 : fade_2;
                fade = fade_1 * r0.y; //r0.x
                
                float4 mainTex = tex2D(_MainTex, i.uv_uv.xy); //r2.xyzw
                float4 effTex1 = tex2D(_EffectTex1, i.uv_uv.xy); //r3.xyzw
                float4 effTex2 = tex2D(_EffectTex2, i.uv_uv.xy); //r4.xyzw
                
                float2 emissionUV;
                emissionUV.x = i.uv_uv.x * 0.8 + (_Time.y - 3.0);
                emissionUV.y = i.uv_uv.y;
                float3 emission = tex2D(_EmissionTex, emissionUV); //r1.xyz
                
                float2 jitterUV;
                jitterUV.x = _Time.y;
                jitterUV.y = 0.0;
                float jitter = tex2D(_EmissionJitterTex, jitterUV).x; //r0.z
                jitter = lerp(1.0, jitter, _EmissionJitter);
                
                emission.xyz = emission.xyz * pow(1.0 - i.uv_uv.z, 5.0) * saturate(pow(4.0 * i.uv_uv.z, 3.0));
                
                float3 mainTex_temp = _Color.xyz * _AlbedoMultiplier * mainTex.xyz;
                mainTex.xyz = 0.7 * saturate(20.0 * mainTex_temp * jitter + mainTex_temp); //r1.xyzw
                mainTex.w = 0.7 * i.unk2.z * mainTex.w; //r1.xyzw
                
                effTex1.xyz = _Color.xyz * _AlbedoMultiplier * effTex1.xyz;
                effTex1.w = i.unk2.z * effTex1.w; //r2.xyzw
                
                effTex2.xyz = pow(_Color.xyz * _AlbedoMultiplier * effTex2.xyz, 1.1);
                effTex2.w = i.unk2.z * effTex2.w; //r4.xyzw
                
                float2 warpUV;
                warpUV.x = i.unk2.w;
                warpUV.y = 0.5;
                float4 warpMap = _WarpMap.SampleLevel(s5_s, warpUV, 0).xyzw; //r3.xyzw
                
                
                float4 finalColor = 2.6 * i.effSelect.zzzz * effTex2.xyzw * jitter
                                  + 0.8 * i.effSelect.xxxx * mainTex.xyzw
                                  + 1.3 * i.effSelect.yyyy * effTex1.xyzw * jitter;
                finalColor.xyz = finalColor.xyz * fade;
                finalColor.xyz = saturate(5 * i.unk2.w) * (dot(finalColor.xyz, float3(0.36, 0.72, 0.12)) - finalColor.xyz * 1.2) + 1.2 * finalColor.xyz;
                
                o.sv_target.xyz = (exp2(log(10)/log(2) * warpMap.w) - 1.0) * warpMap.xyz * finalColor.xyz + finalColor.xyz;
                o_sv_target.w = finalColor.w;
                
                return o;
            }
            ENDCG
        }
    }
}