Shader "VF Shaders/Forward/Unlit Additive Lab REPLACE" {
    Properties {
        _TintColor ("Tint Color", Color) = (1,1,1,1)
        _LabColor0 ("Lab Color0", Color) = (1,1,1,1)
        _LabColor1 ("Lab Color1", Color) = (1,1,1,1)
        _LabColor2 ("Lab Color2", Color) = (1,1,1,1)
        _LabColor3 ("Lab Color3", Color) = (1,1,1,1)
        _LabColor4 ("Lab Color4", Color) = (1,1,1,1)
        _LabColor5 ("Lab Color5", Color) = (1,1,1,1)
        _LabColor6 ("Lab Color6", Color) = (1,1,1,1)
        _Multiplier ("Multiplier", Float) = 1
        _AlphaMultiplier ("Alpha Multiplier", Float) = 1
        _MainTex ("Main Texture", 2D) = "white" {}
        _MainTex2 ("Main Texture 2", 2D) = "white" {}
        _MainTex3 ("Main Texture 3", 2D) = "white" {}
        _MaskTex ("Mask Texture", 2D) = "white" {}
        _UVSpeed ("UV Speed", Vector) = (0,0,0,0)
        _EmissionSwitch ("是否使用游戏状态决定自发光", Float) = 0
        _InvFade ("Soft Particles Factor", Range(0.01, 3)) = 1
        _SideFade ("侧面消隐", Range(0, 2)) = 0
        _Center ("Center", Vector) = (0,2.7,0,0)
        [Toggle(_ENABLE_VFINST)] _ToggleVerta ("Enable VFInst ?", Float) = 0
    }
    SubShader {
        Tags { "DisableBatching" = "true" "IGNOREPROJECTOR" = "true" "QUEUE" = "Transparent" "RenderType" = "Transparent" }
        Pass {
            Tags { "DisableBatching" = "true" "IGNOREPROJECTOR" = "true" "QUEUE" = "Transparent" "RenderType" = "Transparent" }
            Blend SrcAlpha One, SrcAlpha One
            ColorMask RGB -1
            ZWrite Off
            Cull Off
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0
            #pragma enable_d3d11_debug_symbols
            
            //#pragma multi_compile_particles
            //#pragma multi_compile __ _ENABLE_VFINST
            
            #include "UnityCG.cginc"
            #include "CGIncludes/DSPCommon.cginc"
            //#include "VFVerta.cginc"
            //#include "VFInst.cginc"
            
            struct v2f
            {
                float4 pos : SV_POSITION0;
                float2 uv : TEXCOORD0;
                float animState : TEXCOORD1;
                float power : TEXCOORD3;
                float4 clipPos : TEXCOORD2;
                float3 worldPos : TEXCOORD4;
                float3 worldNormal : TEXCOORD5;
                float4 labColor_cubeSwitch : TEXCOORD6;
                float2 prepare_tubelasers : TEXCOORD7;
            };
            
            struct fout
            {
                float4 sv_target : SV_Target0;
            };

            StructuredBuffer<GPUOBJECT> _InstBuffer;
            StructuredBuffer<uint> _IdBuffer;
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
            
            float4 _TintColor;
            float4 _LabColor0;
            float4 _LabColor1;
            float4 _LabColor2;
            float4 _LabColor3;
            float4 _LabColor4;
            float4 _LabColor5;
            float4 _LabColor6;
            
            float _Multiplier;
            float _AlphaMultiplier;
            float4 _UVSpeed;
            float _EmissionSwitch;
            float _InvFade;
            float _SideFade;
            float3 _Center;
            float4 _MainTex_ST;
            
            sampler2D _MainTex2;
            sampler2D _MainTex3;
            sampler2D _MainTex;
            sampler2D _MaskTex;
            UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);

            float3 RotateXZ(float3 pt, float angle)
            {
                float s, c;
                sincos(angle, s, c);
                
                return float3(
                    pt.x * c - pt.z * s,   // x' = x*cos(θ) - z*sin(θ)
                    pt.y,                     // y unchanged
                    pt.x * s + pt.z * c    // z' = x*sin(θ) + z*cos(θ)
                );
            }
            
            v2f vert(appdata_full v, uint vertexID : SV_VertexID, uint instanceID : SV_InstanceID)
            {
                v2f o;
                /*
                model has three sections grouped by their color.y value:
                * single quad that the spinning cube effect is rendered on
                * five rings that get rendered inside the glass sphere as laser-ish effects
                * the lasers inside the four tubes along the corners of the model
                
                ringNum = 1 through 5, or 0 if it is the spinning cube or laser tube effect
                tubeLasers = 1 if it is the laser tube effect, 0 otherwise.
                */
                float ringNum = floor(v.color.y * 5.1 + 0.2); // r0.x
                bool isRing = ringNum > 0.5;
                float tubeLasers = saturate(500.0 * v.color.y * (0.5 - ringNum)); // r1.y
                bool isTubeLasers = tubeLasers > 0.5;
                
                bool monoInst = _Mono_Inst > 0; //r0.y
                
                uint instId = _IdBuffer[instanceID]; //r2.x
                instId = monoInst ? 0 : instId; //r0.z
                
                uint objId = _InstBuffer[instId].objId; //r2.x
                objId = monoInst ? 0 : objId; //r0.w
                
                float prepare_length = _AnimBuffer[objId].prepare_length; //r2.x
                prepare_length = monoInst ? _Mono_Anim_LP : prepare_length; //r1.x
                bool inProduceMode = prepare_length < 0.5;
                
                float3 labColor = float3(1,1,1); //r2.yzw
                  
                if (isRing || isTubeLasers) {
                    float working_length = _AnimBuffer[objId].working_length;
                    working_length = monoInst ? _Mono_Anim_LW : working_length; // r2.x
                    
                    float colorSelect = working_length * pow(10.0, 1.0 - ringNum);
                    int colorIndex = floor(fmod(colorSelect, 10.0)); //r2.x
                    
                    switch(colorIndex)
                    {
                        case 1:
                            labColor = _LabColor1.xyz;
                            break;
                        case 2:
                            labColor = _LabColor2.xyz;
                            break;
                        case 3:
                            labColor = _LabColor3.xyz;
                            break;
                        case 4:
                            labColor = _LabColor4.xyz;
                            break;
                        case 5:
                            labColor = _LabColor5.xyz;
                            break;
                        case 6:
                            labColor = _LabColor6.xyz;
                            break;
                        default:
                            labColor = _LabColor0.xyz;
                            break;
                    }
                }
                  
                if (isTubeLasers) {
                    if (inProduceMode) {
                        uint animState = _AnimBuffer[objId].state; //r3.w
                        animState = monoInst ? _Mono_Anim_State : animState; //r1.w
                        
                        float colorSelect = animState / 100.0;
                        int colorIndex = floor(fmod(colorSelect, 10.0)); //r1.w

                        switch(colorIndex)
                        {
                            case 1:
                                labColor = _LabColor1.xyz;
                                break;
                            case 2:
                                labColor = _LabColor2.xyz;
                                break;
                            case 3:
                                labColor = _LabColor3.xyz;
                                break;
                            case 4:
                                labColor = _LabColor4.xyz;
                                break;
                            case 5:
                                labColor = _LabColor5.xyz;
                                break;
                            case 6:
                                labColor = _LabColor6.xyz;
                                break;
                            default:
                                labColor = _LabColor0.xyz;
                                break;
                        }
                    } else {
                        labColor = float3(0.5, 0.5, 0.5);
                    }
                }
                  
                o.labColor_cubeSwitch.xyz = lerp(labColor, float3(1,1,1), 0.2 * prepare_length); //prepare_length
              
                // Center-relative position
                float3 localPos = v.vertex.xyz - _Center.xyz; //r3.xyz
                
                if (isRing)
                {
                    // Base ring scaling
                    float ringScale = 0.7 + (ringNum * 0.04);
                    
                    // Primary rotation
                    float rotationSpeed = 5.0 + (ringNum * 3.0);
                    float angle1 = _Time.y * rotationSpeed + objId;
                    
                    // Breathing scale effect
                    float breatheScale = sin(_Time.y + ringNum + objId) * 0.4 + 1.17;
                    
                    // Secondary rotation
                    float angle2 = (ringNum * (0.4 * UNITY_PI)) + _Time.x + objId; // ~2π/5
                    
                    localPos = RotateXZ(localPos * ringScale, angle1);
                    localPos = localPos * breatheScale;
                    localPos = RotateXZ(localPos, angle2);
                }
                  
                float3 vertPos = localPos.xyz + _Center.xyz; //r3.xyz
                
                objId = _InstBuffer[instId].objId; //r4.x
                float3 pos = _InstBuffer[instId].pos; //r4.yzw
                
                objId = monoInst ? 0 : objId;
                pos = monoInst ? _Mono_Pos.xyz : pos;
                
                float4 rot = _InstBuffer[instId].rot; //r5.xyzw
                rot = monoInst ? _Mono_Rot.xyzw : rot;
                
                float time = _AnimBuffer[objId].time; //r6.x
                prepare_length = _AnimBuffer[objId].prepare_length; //r6.y
                float working_length = _AnimBuffer[objId].working_length; //r6.z
                uint animState = _AnimBuffer[objId].state; //r6.w
                
                time = monoInst ? _Mono_Anim_Time : time; // r6.x
                prepare_length = monoInst ? _Mono_Anim_LP : prepare_length; //r6.y
                working_length = monoInst ? _Mono_Anim_LW : working_length; //r6.z
                animState = monoInst ? _Mono_Anim_State : animState; //r6.w
                
                float power = _AnimBuffer[objId].power; //r7.x
                o.power = monoInst ? _Mono_Anim_Power : power;
                
                float3 normal = v.normal.xyz;
                float3 tangent = v.tangent.xyz;
                
                float3 scale = _ScaleBuffer[instId];
                scale = monoInst ? _Mono_Scl.xyz : scale;
                  
                if(_UseScale > 0.5)
                {
                    vertPos *= scale;
                    normal *= scale;
                }
                  
                animateWithVerta(vertexID, time, prepare_length, working_length, vertPos, normal, tangent);
                
                float3 worldPos = rotate_vector_fast(vertPos, rot) + pos; //r3.xyz
                float3 worldNormal = rotate_vector_fast(normal, rot); //r0.yzw
                
                float3 viewRight = normalize(UNITY_MATRIX_V[0].xyz); //r4.xyz
                float3 viewUp = normalize(UNITY_MATRIX_V[1].xyz); //r5.xyz
                
                float3 cubePos = worldPos.xyz
                    + viewRight * (v.vertex.x * 200.0)
                    + viewUp * (v.vertex.z * 200.0); //r2.xyz
                  
                float2 tubeUV;
                tubeUV.x = _Time.y - 0.3 * v.texcoord.x;
                tubeUV.y = 4.0 * v.texcoord.y;
                
                float cubeSwitch = 1.0;
                float2 uv = v.texcoord.xy;
                
                if (!isTubeLasers && !isRing)
                {
                    worldPos = cubePos;
                    cubeSwitch = 0;
                }
                else if (isTubeLasers)
                {
                    uv = tubeUV;
                }
                
                float4 worldPos2 = mul(unity_ObjectToWorld, float4(worldPos,1.0)); //r3.xyzw
                float4 clipPos = mul(UNITY_MATRIX_VP, worldPos2);
                
                o.uv.xy = TRANSFORM_TEX(uv, _MainTex);
                
                o.animState = animState > 0 ? 1.0 : 0;
                
                o.worldNormal.xyz = mul((float3x3)unity_ObjectToWorld, worldNormal);
                o.pos.xyzw = clipPos.xyzw;
                o.clipPos.xyzw = clipPos.xyzw;
                
                o.labColor_cubeSwitch.w = cubeSwitch;
                o.worldPos.xyz = worldPos2.xyz;
                
                o.prepare_tubelasers.x = prepare_length; //r1.x
                o.prepare_tubelasers.y = tubeLasers; //r1.y
                
                return o;
            }
            
            fout frag(v2f i)
            {
                fout o;
                
                float3 eyeVec = normalize(i.worldPos.xyz - _WorldSpaceCameraPos.xyz); //r0.xyz
                float3 normal = normalize(i.worldNormal.xyz); //r1.xyz
                
                float fade = dot(normal, eyeVec);
                fade = pow(abs(fade), _SideFade); //r0.x
                
                float2 animUV = _Time.yy * _UVSpeed.xy + i.uv.xy; //r0.yz
                float4 cubeTex1 = tex2D(_MainTex3, animUV).xyzw; //r1.xyzw
                float4 cubeTex0 = tex2D(_MainTex2, animUV).xyzw; //r2.xyzw
                float4 laserEffect = tex2D(_MainTex, animUV).xyzw; //r3.xyzw
                
                float prepare_length = i.prepare_tubelasers.x;
                float tubeLasers = i.prepare_tubelasers.y;
                float cubeSwitch = i.labColor_cubeSwitch.w;
                
                float4 cubeColor = lerp(0.18 * cubeTex0.xyzw, cubeTex1.xyzw, prepare_length); //r1.xyzw
                float4 finalColor = lerp(cubeColor, laserEffect, cubeSwitch);
                
                float4 tubeLaserEffect = tex2D(_MaskTex, i.uv.xy).xyzw; //r2.xyzw
                finalColor = lerp(finalColor, 2.0 * tubeLaserEffect, saturate(tubeLasers)); //r1.xyzw
                
                finalColor.xyzw = _TintColor.xyzw * finalColor.xyzw;
                finalColor.xyz = _Multiplier * finalColor.xyz;
                finalColor.w = _AlphaMultiplier * finalColor.w;
                
                float power = i.power > 0.1 ? 1.0 : 0;
                float alpha = saturate(finalColor.w * lerp(1.0, i.animState * power, _EmissionSwitch)); //r0.y
                
                finalColor.xyz = i.labColor_cubeSwitch.xyz * finalColor.xyz;
                
                alpha = alpha * fade; //r0.x
                
                float4 screenPos = ComputeScreenPos(i.clipPos.xyzw); //r2.xyzw
                float2 depthUV = (screenPos.xy + screenPos.zz) / screenPos.ww; //r0.yz
                float sceneZ = LinearEyeDepth(tex2D(_CameraDepthTexture, depthUV).x);
                o.sv_target.w = alpha * saturate(_InvFade * (sceneZ - screenPos.w));
                
                o.sv_target.xyz = finalColor.xyz * (1.0 - 0.8 * prepare_length);
                
                return o;
            }
            ENDCG
        }
    }
}


