Shader "VF Shaders/Forward/PBR Standard Vertex Toggle Lab REPLACE" {
    Properties {
        _Color ("Color 颜色", Color) = (1,1,1,1)
        _SpecularColor ("Specular Color", Color) = (1,1,1,1)
        _LabColor0 ("Lab Color0", Color) = (1,1,1,1)
        _LabColor1 ("Lab Color1", Color) = (1,1,1,1)
        _LabColor2 ("Lab Color2", Color) = (1,1,1,1)
        _LabColor3 ("Lab Color3", Color) = (1,1,1,1)
        _LabColor4 ("Lab Color4", Color) = (1,1,1,1)
        _LabColor5 ("Lab Color5", Color) = (1,1,1,1)
        _LabColor6 ("Lab Color6", Color) = (1,1,1,1)
        _MainTex ("Albedo (RGB) 漫反射 (A) 颜色遮罩", 2D) = "white" {}
        _NormalTex ("Normal 法线", 2D) = "bump" {}
        _MS_Tex ("Metallic (R) 透贴 (G) 金属 (A) 高光", 2D) = "black" {}
        _EmissionTex ("Emission (RGB) 自发光  (A) 抖动遮罩", 2D) = "black" {}
        _EmissionEffectTex ("Emission Effect 自发光效果图", 2D) = "black" {}
        _AlbedoMultiplier ("漫反射倍率", Float) = 1
        _NormalMultiplier ("法线倍率", Float) = 1
        _MetallicMultiplier ("金属倍率", Float) = 1
        _SmoothMultiplier ("高光倍率", Float) = 1
        _EmissionMultiplier ("自发光倍率", Float) = 5.5
        _EmissionJitter ("自发光抖动倍率", Float) = 0
        _EmissionSwitch ("是否使用游戏状态决定自发光", Float) = 0
        _EmissionUsePower ("是否使用供电数据决定自发光", Float) = 1
        _EmissionJitterTex ("自发光抖动色条", 2D) = "white" {}
        _LOD ("该材质所代表的LOD", Float) = 0
        _AlphaClip ("透明通道剪切", Float) = 0
        _CullMode ("剔除模式", Float) = 2
        [Toggle(_ENABLE_VFINST)] _ToggleVerta ("Enable VFInst ?", Float) = 0
    }
    SubShader {
        LOD 200
        Tags { "DisableBatching" = "true" "RenderType" = "Opaque" }
        Pass {
            Name "FORWARD"
            LOD 200
            Tags { "DisableBatching" = "true" "LIGHTMODE" = "FORWARDBASE" "RenderType" = "Opaque" "SHADOWSUPPORT" = "true" }
            Cull Off
                                                
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0
            #pragma multi_compile_fwdbase nolightmap nodirlightmap nodynlightmap novertexlight
            #pragma multi_compile __ _ENABLE_VFINST
            #pragma enable_d3d11_debug_symbols
            
            #include "UnityCG.cginc"
            #include "CGIncludes/DSPCommon.cginc"
            #include "AutoLight.cginc"
            
            struct v2f
            {
                float4 pos : SV_POSITION;
                float4 TBNW0 : TEXCOORD0;
                float4 TBNW1 : TEXCOORD1;
                float4 TBNW2 : TEXCOORD2;
                float3 uv_visible : TEXCOORD3;
                float3 upDir : TEXCOORD4;
                float3 time_animState_power : TEXCOORD5;
                float3 vertexPos : TEXCOORD6;
                float3 worldPos : TEXCOORD7;
                float2 working_prepare : TEXCOORD8;
                float3 indirectLight : TEXCOORD9;
                UNITY_SHADOW_COORDS(11)
                float4 unkUnused : TEXCOORD12;
            };
                                                
            struct fout
            {
                float4 sv_target : SV_Target0;
            };
            
            StructuredBuffer<uint> _IdBuffer;
            StructuredBuffer<GPUOBJECT> _InstBuffer;
            StructuredBuffer<AnimData> _AnimBuffer;
            StructuredBuffer<float3> _ScaleBuffer;
            StructuredBuffer<uint> _StateBuffer;
            
            float _UseScale;
            uint _Mono_Inst;
            //uint _Mono_AstroId;
            float3 _Mono_Pos;
            //float3 _Mono_Pos2;
            float4 _Mono_Rot;
            //float4 _Mono_Rot2;
            //float _Mono_T1;
            //float _Mono_T2;
            float3 _Mono_Scl;
            float _Mono_Anim_Time;
            float _Mono_Anim_LP;
            float _Mono_Anim_LW;
            uint _Mono_Anim_State;
            float _Mono_Anim_Power;
            uint _Mono_State;
            
            float _EmissionUsePower;
            
            float4 _LightColor0;
            float4 _Global_AmbientColor0;
            float4 _Global_AmbientColor1;
            float4 _Global_AmbientColor2;
            float4 _Global_SunsetColor0;
            float4 _Global_SunsetColor1;
            float4 _Global_SunsetColor2;
            //float _PGI_Gray;
            float4 _Global_PointLightPos;
            float4 _Color;
            float4 _LabColor0;
            float4 _LabColor1;
            float4 _LabColor2;
            float4 _LabColor3;
            float4 _LabColor4;
            float4 _LabColor5;
            float4 _LabColor6;
            float _AlbedoMultiplier;
            float _NormalMultiplier;
            float _MetallicMultiplier;
            float _SmoothMultiplier;
            float _EmissionMultiplier;
            float _EmissionJitter;
            float _EmissionSwitch;
            float _LOD;
            float _AlphaClip;
            float4 _SpecularColor;

            sampler2D _MainTex;
            sampler2D _MS_Tex;
            sampler2D _EmissionTex;
            sampler2D _EmissionEffectTex;
            sampler2D _EmissionJitterTex;
            
            v2f vert(appdata_full v, uint vertexID : SV_VertexID, uint instanceID : SV_InstanceID)
            {
                v2f o;
                
                float3 worldPos = v.vertex.xyz;
                float3 worldNormal = v.normal.xyz;
                float3 worldTangent = v.tangent.xyz;
                
                float time, prepare_length, working_length, power;
                uint animState, state;
                float3 upDir;
                
                uint instId, objId;
                float3 pos, scale;
                float4 rot;
                
                if (_Mono_Inst > 0)
                {
                    instId = 0;
                    objId = 0;
                    
                    pos = _Mono_Pos;
                    rot = _Mono_Rot;
                    
                    time = _Mono_Anim_Time;
                    prepare_length = _Mono_Anim_LP;
                    working_length = _Mono_Anim_LW;
                    animState = _Mono_Anim_State;
                    power = _Mono_Anim_Power;
                    
                    state = _Mono_State;
                    
                    scale = _Mono_Scl;
                }
                else
                {
                    instId = _IdBuffer[instanceID];
                    
                    objId = _InstBuffer[instId].objId;
                    pos = _InstBuffer[instId].pos;
                    rot = _InstBuffer[instId].rot;
                    
                    time = _AnimBuffer[objId].time;
                    prepare_length = _AnimBuffer[objId].prepare_length;
                    working_length = _AnimBuffer[objId].working_length;
                    animState = _AnimBuffer[objId].state;
                    power = _AnimBuffer[objId].power;
                    
                    state = _StateBuffer[instId];
                    
                    scale = _ScaleBuffer[instId];
                }
                
                if(_UseScale > 0.5)
                {
                    worldPos *= scale;
                    worldNormal *= scale;
                }
                
                animateWithVerta(vertexID, time, prepare_length, working_length, worldPos, worldNormal, worldTangent);
                
                rot = normalize(rot);
                worldPos = rotate_vector_fast(worldPos.xyz, rot) + pos;
                worldNormal = normalize(rotate_vector_fast(worldNormal.xyz, rot));
                worldTangent = rotate_vector_fast(worldTangent.xyz, rot);
                
                upDir = normalize(pos);
                
                o.uv_visible.xy = v.texcoord.xy;
                
                /*
                v.color.x has three values for three sections of the mesh:
                * top part = 0.98039 = (249.99999/255.0)
                * base = 0.49804 = (126.99999/255.0)
                * bottom dome connection = 0.19608 = (49.99999/255.0)
                */
                float color = v.color.x - 0.2; //r0.x
                o.uv_visible.z = color < (149.99999/255.0) ? abs(saturate(3.4 * color) - state) : 1.0;
                // top part is always visible
                // base is visible if state = 0
                // bottom dome conn is visible if state = 1
                
                o.upDir.xyz = upDir;
                
                o.time_animState_power.x = time;
                o.time_animState_power.y = animState;
                o.time_animState_power.z = lerp(1.0, power, _EmissionUsePower);
                
                o.vertexPos.xyz = v.vertex.xyz;
                o.worldPos.xyz = worldPos.xyz;
                
                o.working_prepare.x = working_length;
                o.working_prepare.y = prepare_length;
                
                float4 clipPos = UnityObjectToClipPos(worldPos); //r4.xyzw
                o.pos.xyzw = clipPos.xyzw;
                
                worldNormal = UnityObjectToWorldNormal(worldNormal);
                worldTangent = UnityObjectToWorldDir(worldTangent); //r1.xyz
                float3 worldBinormal = calculateBinormal(float4(worldTangent, v.tangent.w), worldNormal); //r2.xyz
                
                o.indirectLight.xyz = ShadeSH9(float4(worldNormal, 1));
                UNITY_TRANSFER_SHADOW(o, float(0,0))
                
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
                
                o.unkUnused.xyzw = float4(0,0,0,0);
                
                return o;
            }

            fout frag(v2f i)
            {
                fout o;
                
                float worldHeight = length(i.worldPos.xyz); //r0.x
                bool isUnderground = worldHeight < 200.2;
                bool isMonoInst = _Mono_Inst > 0; //r0.y
                if (isUnderground && isMonoInst)
                  discard;
                
                bool shouldHide = i.uv_visible.z < 0.5;
                if (shouldHide)
                  discard;
                
                float2 uv = i.uv_visible.xy;
                
                float3 msTex = tex2D(_MS_Tex, uv).xyw; //r0.xyz
                if (msTex.y < _AlphaClip - 0.001)
                  discard;
                  
                float3x3 TBN = float3x3(i.TBNW0.xyz, i.TBNW1.xyz, i.TBNW2.xyz);
                float3 worldNormal = WorldNormalFromNormalMap(uv, _NormalMultiplier, TBN);
                
                float time = i.time_animState_power.x;
                float animState = i.time_animState_power.y;
                float power = i.time_animState_power.z;
                
                float emissLOD = _LOD * 0.5 - 0.5;
                float4 emission = tex2Dbias(_EmissionTex, float4(uv, 0, emissLOD)).xyzw; //r3.xyzw
                
                float emissionAlpha = lerp(1.0, saturate(animState), _EmissionSwitch * emission.w); //r0.z
                emission.xyz = _EmissionMultiplier * emission.xyz * emissionAlpha; //r3.xyz
                
                float effectLOD = 2.0 * saturate(_LOD);
                float2 emissionEffect = tex2Dlod(_EmissionEffectTex, float4(uv, 0, effectLOD)).xy; //r4.xy
                float emitBrightness = saturate(100.0 * emissionEffect.x); //r5.x
                
                float effectColor = emissionEffect.y > 5.7 ? 0 : 6.0 - floor(emissionEffect.y * 5.1 + 0.2); //r4.y
                
                bool isWithinRadius2 = pow(i.vertexPos.x, 2.0) + pow(i.vertexPos.z, 2.0) < 4.0; //r4.z
                if (isWithinRadius2)
                {
                    if (effectColor > 0.5)
                    {
                        bool isFrontOrBackSide = pow(i.vertexPos.x, 2.0) - pow(i.vertexPos.z, 2.0) < 0; //r4.w
                        effectColor = isFrontOrBackSide ? 6.0 - effectColor : effectColor;
                    }
                    else
                    {
                        bool isFrontOrLeftSide = i.vertexPos.x * i.vertexPos.z < 0;
                        effectColor = isFrontOrLeftSide ? 6.0 - effectColor : effectColor;
                    }
                }
                
                float working_length = i.working_prepare.x;
                /*
                working_length is set to one of these values. matrixShaderStates when producing, techShaderStates when researching:
                
                public static float[] matrixShaderStates = new float[10] { 0f, 11111.2f, 22222.2f, 33333.2f, 44444.2f, 55555.2f, 66666.2f, 0f, 0f, 0f };
                public static int[] techShaderStates = new int[51]
                {
                    0, 1110, 2220, 11022, 3330, 11033, 22033, 2310, 4440, 11044,
                    22044, 1420, 33044, 1340, 2340, 23014, 5550, 11055, 22055, 1250,
                    33055, 1350, 2350, 23051, 44055, 1450, 2450, 12045, 3450, 13045,
                    23045, 23514, 66666, 0, 0, 0, 0, 0, 0, 0,
                    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                    0
                };
                */
                float prepare_length = i.working_prepare.y;
                bool inProduceMode = prepare_length < 0.5;
                float3 labColor = float3(1,1,1);
                float colorSelect = inProduceMode ? 3.0 : effectColor;
                
                if (colorSelect > 0.5 && emitBrightness > 0.01) {
                  colorSelect = pow(10.0, -colorSelect) * working_length;
                  colorSelect = colorSelect >= -colorSelect ? frac(abs(colorSelect)) : -frac(abs(colorSelect));
                  colorSelect = floor(10.0 * colorSelect);
                  
                  if (colorSelect > 5.5 && colorSelect < 6.5) {
                      labColor = _LabColor6.xyz;
                  } else if (colorSelect > 4.5 && colorSelect < 5.5) {
                      labColor = _LabColor5.xyz;
                  } else if (colorSelect > 3.5 && colorSelect < 4.5) {
                      labColor = _LabColor4.xyz;
                  } else if (colorSelect > 2.5 && colorSelect < 3.5) {
                      labColor = _LabColor3.xyz;
                  } else if (colorSelect > 1.5 && colorSelect < 2.5) {
                      labColor = _LabColor2.xyz;
                  } else if (colorSelect > 0.5 && colorSelect < 1.5) {
                      labColor = _LabColor1.xyz;
                  } else {
                      labColor = _LabColor0.xyz;
                  }
                  
                  labColor = lerp(float3(1,1,1), labColor, saturate(0.8 + effectColor));
                }
                
                emitBrightness = min(emitBrightness, saturate(100.0 * (1.0 - emissionEffect.x)));
                
                //if in produce mode, prepare_length is 0
                //if in research mode, prepare_length is 1
                float lightSquaresEffect = lerp(saturate(1.112 * (emissionEffect.x - 0.05)), frac(0.7 * i.vertexPos.y), 0.85 * prepare_length); //r4.x
                
                
                lightSquaresEffect = abs(time - lightSquaresEffect);
                lightSquaresEffect = lightSquaresEffect > 0.5 ? 1.0 - lightSquaresEffect : lightSquaresEffect;
                
                float lod = 13.0; //r5.y
                if (_LOD > 1.5)
                    lod = 2.0;
                else if (_LOD > 0.5)
                    lod = 3.0;
                
                //if in produce mode, prepare_length is 0
                //if in research mode, prepare_length is 1
                lightSquaresEffect = lerp(1.0, saturate(200.0 * ((0.2 - 0.05 * prepare_length) - lightSquaresEffect)) * lod, emitBrightness);
                lightSquaresEffect = saturate(_LOD) * 0.5 + lightSquaresEffect; //r2.w
                
                float2 jitterUV = float2(time, 0);
                float jitter = tex2D(_EmissionJitterTex, jitterUV).x; //r4.x
                
                jitter = lerp(1.0, jitter, _EmissionSwitch * _EmissionJitter * emission.w); //r0.z
                
                bool isPowered = power > 0.1; // r5.y
                bool switchedOn = _EmissionSwitch < 0.5; //r5.z
                float emitSwitch = switchedOn || isPowered ? 1.0 : 0; //r5.y
                
                emission.xyz = lightSquaresEffect * labColor.xyz * emission.xyz * jitter * emitSwitch; //r3.xyz
                
                float4 mainTex = tex2D(_MainTex, uv).xyzw; //r1.xyzw
                float3 albedo = _AlbedoMultiplier * mainTex.xyz;
                float3 tint = lerp(float3(1,1,1), _Color.xyz, saturate(1.25 * (mainTex.w - 0.1))); //r6.xyz
                albedo = tint * albedo;
                
                float metallic = saturate(_MetallicMultiplier * msTex.x); //r0.x
                float smoothness = saturate(_SmoothMultiplier * msTex.z); //r0.y
                
                float3 specularColor = _SpecularColor.xyz; //r5.xyz
                float3 worldPos = float3(i.TBNW0.w, i.TBNW1.w, i.TBNW2.w); //r6.yzw
                
                UNITY_LIGHT_ATTENUATION(atten, i, worldPos); //r0.w
                
                metallic = metallic * 0.85 + 0.149; //r6.y
                
                float perceptualRoughness = 1.0 - smoothness * 0.97; //r0.x
                float roughness = perceptualRoughness * perceptualRoughness; //r0.z
                
                float3 upDir = i.upDir.xyz; //r4.xyz
                float3 viewDir = normalize(_WorldSpaceCameraPos - worldPos); //r8.xyz
                float3 lightDir = _WorldSpaceLightPos0.xyz;
                float3 halfDir = normalize(viewDir + lightDir); //r7.xyz
                
                float unclamped_nDotL = dot(worldNormal, lightDir); //r2.w
                float nDotL = max(0, unclamped_nDotL); //r3.w
                float unclamped_nDotV = dot(worldNormal, viewDir); //r4.w
                float nDotV = max(0, unclamped_nDotV); //r4.w
                float unclamped_nDotH = dot(worldNormal, halfDir); //r5.w
                float nDotH = max(0, unclamped_nDotH); //r5.w
                float unclamped_vDotH = dot(viewDir, halfDir); //r6.z
                float vDotH = max(0, unclamped_vDotH); //r6.z
                
                float upDotL = dot(upDir, lightDir); //r6.w
                float nDotUp = dot(worldNormal, upDir); //r7.x
                
                float reflectivity; //r0.x
                float3 reflectColor = reflection(perceptualRoughness, metallic, upDir, viewDir, worldNormal, /*out*/ reflectivity); //r7.yzw
                
                float3 sunlightColor = calculateSunlightColor(_LightColor0.xyz, upDotL, _Global_SunsetColor0.xyz, _Global_SunsetColor1.xyz, _Global_SunsetColor2.xyz); //r9.xyz
                
                atten = 0.8 * (saturate(0.15 * upDotL) * (1.0 - atten) + atten);
                sunlightColor = atten * sunlightColor.xyz;
                
                float specularTerm = GGX(roughness, metallic + 0.5, nDotH, nDotV, nDotL, vDotH); //r0.w
                
                float3 ambientColor = calculateAmbientColor(upDotL, _Global_AmbientColor0.xyz, _Global_AmbientColor1.xyz, _Global_AmbientColor2.xyz); //r10.xyw
                float3 ambientLight = ambientColor * saturate(nDotUp * 0.3 + 0.7) * pow(1.0 + unclamped_nDotL * 0.35, 3.0); //r11.xyz
                
                float3 headlampLight = calculateLightFromHeadlamp(_Global_PointLightPos, upDir, lightDir, worldNormal, 5.0, 20.0, false, 1.0); //r2.xyz
                
                float3 light = sunlightColor * nDotL * pow(1.0 - metallic, 0.6) + (pow(1.0 - metallic, 0.6) * 0.2 + 0.8) * headlampLight; //r12.xyz
                
                specularColor = specularColor * lerp(float3(1,1,1), albedo, metallic);
                float3 specularLight = (nDotL + headlampLight) * specularColor * sunlightColor * (specularTerm + INV_TEN_PI); //r5.xyz
                
                float3 reflectDir = reflect(-viewDir, worldNormal);
                float3 specularHeadlampLight = calculateLightFromHeadlamp(_Global_PointLightPos, upDir, lightDir, reflectDir, 20.0, 40.0, true, smoothness); //r0.yzw
                
                specularLight = lerp(metallic, 1.0, albedo.x / 5.0) * (specularLight + lerp(0.5, albedo, 0.5) * specularHeadlampLight); //r0.yzw
                
                float ambientLuminance = 0.003 + dot(ambientColor.xyx, float3(0.3, 0.6, 0.1)); //r2.w
                float maxAmbient = 0.003 + max(_Global_AmbientColor0.z, max(_Global_AmbientColor0.x, _Global_AmbientColor0.y)); //r3.w
                float3 reflectedAmbient = lerp(ambientLuminance, ambientColor, 0.4) / maxAmbient; //r5.xyz
                reflectedAmbient = float3(1.7, 1.7, 1.7) * reflectedAmbient; //r5.xyz
                
                float3 nightLight = headlampLight + saturate(upDotL * 2.0 + 0.5) * 0.7 + 0.3;
                reflectColor = albedo * reflectColor * reflectedAmbient * nightLight;
                
                float3 finalColor = ambientLight * albedo * (1.0 - metallic * 0.6) + light * albedo + specularLight;
                finalColor = lerp(finalColor, reflectColor, reflectivity); //r0.xyz
                
                float colorIntensity = dot(finalColor, float3(0.3, 0.6, 0.1)); //r0.w
                finalColor = colorIntensity > 1.0 ? (finalColor / colorIntensity) * (log(log(colorIntensity) + 1) + 1) : finalColor;
                
                finalColor = albedo * i.indirectLight.xyz + finalColor + emission.xyz;
                
                o.sv_target.xyz = finalColor;
                o.sv_target.w = 1.0;
                
                return o;
            }
            ENDCG
        }
        Pass {
            Name "ShadowCaster"
            LOD 200
            Tags { "DisableBatching" = "true" "LIGHTMODE" = "SHADOWCASTER" "RenderType" = "Opaque" "SHADOWSUPPORT" = "true" }
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0
            #pragma multi_compile_shadowcaster
            #pragma multi_compile __ _ENABLE_VFINST
            #pragma enable_d3d11_debug_symbols
            
            #include "UnityCG.cginc"
            #include "AutoLight.cginc"
            #include "CGIncludes/DSPCommon.cginc"
            
            struct v2f
            {
                float4 pos : SV_POSITION0;
                float3 uv_visible : TEXCOORD1;
                float3 upDir : TEXCOORD2;
                float3 time_animState_power : TEXCOORD3;
                float3 vertexPos : TEXCOORD4;
                float3 worldPos : TEXCOORD5;
                float2 working_prepare : TEXCOORD6;
            };
            
            struct fout
            {
                float4 sv_target : SV_Target0;
            };

            StructuredBuffer<uint> _IdBuffer;
            StructuredBuffer<GPUOBJECT> _InstBuffer;
            StructuredBuffer<AnimData> _AnimBuffer;
            StructuredBuffer<float3> _ScaleBuffer;
            StructuredBuffer<uint> _StateBuffer;

            float _UseScale;
            uint _Mono_Inst;
            //uint _Mono_AstroId;
            float3 _Mono_Pos;
            //float3 _Mono_Pos2;
            float4 _Mono_Rot;
            //float4 _Mono_Rot2;
            //float _Mono_T1;
            //float _Mono_T2;
            float3 _Mono_Scl;
            uint _Mono_State;
            float _Mono_Anim_Time;
            float _Mono_Anim_LP;
            float _Mono_Anim_LW;
            uint _Mono_Anim_State;
            float _Mono_Anim_Power;
            float _EmissionUsePower;
            float _AlphaClip;
            
            sampler2D _MS_Tex;
            
            v2f vert(appdata_full v, uint vertexID : SV_VertexID, uint instanceID : SV_InstanceID)
            {
                v2f o;
                  
                float3 worldPos = v.vertex.xyz;
                float3 worldNormal = v.normal.xyz;
                float3 worldTangent = v.tangent.xyz;
                
                float time, prepare_length, working_length, power;
                uint animState, state;
                float3 upDir;
                
                uint instId, objId;
                float3 pos, scale;
                float4 rot;
                
                if (_Mono_Inst > 0)
                {
                    instId = 0;
                    objId = 0;
                    
                    pos = _Mono_Pos;
                    rot = _Mono_Rot;
                    
                    time = _Mono_Anim_Time;
                    prepare_length = _Mono_Anim_LP;
                    working_length = _Mono_Anim_LW;
                    animState = _Mono_Anim_State;
                    power = _Mono_Anim_Power;
                    
                    state = _Mono_State;
                    
                    scale = _Mono_Scl;
                }
                else
                {
                    instId = _IdBuffer[instanceID];
                    
                    objId = _InstBuffer[instId].objId;
                    pos = _InstBuffer[instId].pos;
                    rot = _InstBuffer[instId].rot;
                    
                    time = _AnimBuffer[objId].time;
                    prepare_length = _AnimBuffer[objId].prepare_length;
                    working_length = _AnimBuffer[objId].working_length;
                    animState = _AnimBuffer[objId].state;
                    power = _AnimBuffer[objId].power;
                    
                    state = _StateBuffer[instId];
                    
                    scale = _ScaleBuffer[instId];
                }
                
                if(_UseScale > 0.5)
                {
                    worldPos *= scale;
                    worldNormal *= scale;
                }
                
                animateWithVerta(vertexID, time, prepare_length, working_length, worldPos, worldNormal, worldTangent);
                
                rot = normalize(rot);
                worldPos = rotate_vector_fast(worldPos.xyz, rot) + pos;
                worldNormal = normalize(rotate_vector_fast(worldNormal.xyz, rot));
                worldTangent = rotate_vector_fast(worldTangent.xyz, rot);
                
                upDir = normalize(pos);
                
                o.uv_visible.xy = v.texcoord.xy;
                
                float color = v.color.x - 0.2; //r0.x
                o.uv_visible.z = color < (149.99999/255.0) ? abs(saturate(3.4 * color) - state) : 1.0;
                
                o.upDir.xyz = upDir;
                
                o.time_animState_power.x = time;
                o.time_animState_power.y = animState;
                o.time_animState_power.z = lerp(1.0, power, _EmissionUsePower);
                
                o.vertexPos.xyz = v.vertex.xyz;
                o.worldPos = worldPos;
                
                o.working_prepare.x = working_length;
                o.working_prepare.y = prepare_length;
                
                worldNormal = UnityObjectToWorldNormal(worldNormal);
                
                float4 clipPos = UnityClipSpaceShadowCasterPos(float4(worldPos, 1.0), worldNormal);
                o.pos.xyzw = UnityApplyLinearShadowBias(clipPos);
                
                return o;
            }
            
            fout frag(v2f i)
            {
                fout o;
                  
                float worldHeight = length(i.worldPos.xyz);
                bool isUnderground = worldHeight < 200.2;
                bool isMonoInst = _Mono_Inst > 0;
                if (isUnderground && isMonoInst)
                    discard;
                
                bool shouldHide = i.uv_visible.z < 0.5;
                if (shouldHide)
                    discard;
                
                float2 uv = i.uv_visible.xy;
                float msTex = tex2D(_MS_Tex, uv).y;
                if (msTex < _AlphaClip - 0.001)
                    discard;
                
                o.sv_target.xyzw = float4(0,0,0,0);
                
                return o;
            }
            ENDCG
        }
    }
    Fallback "Diffuse"
}