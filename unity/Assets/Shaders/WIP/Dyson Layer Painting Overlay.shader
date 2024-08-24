Shader "VF Shaders/Dyson Sphere/Dyson Layer Painting Overlay REPLACE" {
    Properties {
        _DefaultColor ("Color", Vector) = (1,1,1,1)
        _Stencil ("Stencil", Float) = 100
        _FinalMultiplier ("Final Multiplier", Float) = 1
        _EditorMultiplier ("Editor Multiplier", Float) = 2.2
        _InGameMultiplier ("In Game Multiplier", Float) = 2.5
        _StarmapMultiplier ("Starmap Multiplier", Float) = 1.8
        _SuperBrightness ("Super Brightness", Float) = 3
    }
    SubShader {
        Tags { "QUEUE" = "Transparent" }
        GrabPass {
            "_ScreenTex_Painting"
        }
        Pass {
            Tags { "QUEUE" = "Transparent" }
            ZWrite Off
            Cull Off
            Stencil {
                Ref [_Stencil]
                Comp Equal
                Pass Keep
                Fail Keep
                ZFail Keep
            }
            
            CGPROGRAM
            #pragma vertex vert
            #pragma hull hull
            #pragma domain domain
            #pragma fragment frag
            #pragma target 5.0
            #pragma enable_d3d11_debug_symbols
            
            #include "UnityCG.cginc"
            #include "Tessellation.cginc"
            
            struct v2h
            {
                float4 pos : INTERNALTESSPOS;
                float distToCam : TEXCOORD0;
            };
            
            struct h2d
            {
                float edge[3] : SV_TessFactor;
                float inside : SV_InsideTessFactor;
            };
            
            struct d2f
            {
                float4 pos : SV_POSITION;
                float4 clipPos : TEXCOORD0;
            };
            
            struct fout
            {
                float4 sv_target : SV_Target0;
            };
            
            float3 _Global_DS_SunPosition;
            float _OrbitRadius;
            int _Global_DS_RenderPlace;
            int _Global_VMapEnabled;
            float3 _Global_DS_SunPosition_Map;
            int _IsGraticule;
            float _SuperBrightness;
            float _FinalMultiplier;
            float _EditorMultiplier;
            float _InGameMultiplier;
            float _StarmapMultiplier;
            
            sampler2D _ScreenTex_Painting;
            
            StructuredBuffer<int> _Color32Buffer;
            
            v2h vert(appdata_full v)
            {
                v2h o;
                
                o.pos.xyzw = v.vertex.xyzw;
                
                float distCamToSun = distance(_Global_DS_SunPosition, _WorldSpaceCameraPos); //r0.x
                float distScaler = saturate((distCamToSun - 50000.0) / 100000.0) / 1000.0725 + 1.001; //r0.x
                float4 localPos = _OrbitRadius * v.vertex.xyzw * distScaler;
                float3 worldPos = mul(unity_ObjectToWorld, localPos).xyz; //r0.xyz
                o.distToCam = distance(worldPos, _WorldSpaceCameraPos);
                
                return o;
            }
            
            h2d PatchConstantFunction(InputPatch<v2h, 3> patch)
            {
                h2d o;
                
                uint renderPlace = _Global_DS_RenderPlace; //r0.x
                float orbitRadius = renderPlace < 0.5 ? _OrbitRadius : _OrbitRadius * 0.0003; //r0.x
                float avgDistToCam = (patch[1].distToCam + patch[0].distToCam + patch[2].distToCam) / 3.0; //r0.y
                
                float tessFactor = avgDistToCam < orbitRadius / 20.0 ? 3.0 : 1.0; //r0.x
                o.edge[0] = tessFactor;
                o.edge[1] = tessFactor;
                o.edge[2] = tessFactor;
                o.inside = tessFactor;
                
                return o;
            }
            
            [UNITY_domain("tri")]
            [UNITY_outputcontrolpoints(3)]
            [UNITY_outputtopology("triangle_cw")]
            [UNITY_patchconstantfunc("PatchConstantFunction")]
            [UNITY_partitioning("fractional_odd")]
            v2h hull (InputPatch<v2h, 3> patch, uint id : SV_OutputControlPointID)
            {
                return patch[id];
            }
            
            [UNITY_domain("tri")]
            d2f domain(h2d i, OutputPatch<v2h, 3> patch, float3 coords : SV_DomainLocation)
            {
                d2f o;
                
                float4 patchPos = patch[0].pos * coords.x + patch[1].pos * coords.y + patch[2].pos * coords.z; //r0.xyzw
                float3 patchDir = normalize(patchPos.xyzw).xyz; //r0.xyz
                float3 localPos = _OrbitRadius * patchDir * length(patch[0].pos); //r0.xyz
                
                float3 scaledLocalPos = 0.00025 * localPos; //r0.xyz
                
                localPos = float3(1.001, 1.001, 1.001) * localPos;
                float4 worldPos = mul(unity_ObjectToWorld, float4(localPos, 1.0)); //r1.xyzw
                
                float3 camToPos = worldPos.xyz - _WorldSpaceCameraPos; //r2.xyz
                float distCamToPos = length(camToPos); //r0.w
                float distanceScaler = 10000 * (log(distCamToPos / 10000.0) + 1) / distCamToPos; //r2.w
                camToPos = distCamToPos > 10000 ? camToPos * distanceScaler : camToPos;
                bool inUniverse = _Global_DS_RenderPlace < 0.5; //r0.w
                bool vMapEnabled = _Global_VMapEnabled > 0.5;
                float3 newWorldPos = inUniverse && vMapEnabled ? float4(_WorldSpaceCameraPos + camToPos, 1.0) : worldPos.xyz; //r1.xyz
                
                float distPosToSun = distance(_Global_DS_SunPosition, newWorldPos); //r1.x
                float distPosToSunMap = distance(_Global_DS_SunPosition_Map, newWorldPos); //r1.y
                distPosToSun = inUniverse ? distPosToSun : distPosToSunMap; //r1.x //backwards?
                
                float distCamToSunMap = 3999.99976 * distance(_Global_DS_SunPosition_Map, _WorldSpaceCameraPos); //r1.y
                float distCamToSun = distance(_Global_DS_SunPosition, _WorldSpaceCameraPos); //r1.z
                distCamToSun = inUniverse ? distCamToSun : distCamToSunMap; //r1.y
                
                float distanceSunScaler = inUniverse ? distCamToSun / distPosToSun : 0.98 * distCamToSun / distPosToSun; // r1.y
                
                float3 scaledDistLocalPos = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos + camToPos, 1.0)).xyz; //r2.xyz
                localPos = inUniverse ? scaledDistLocalPos : scaledLocalPos; //r0.xyz
                localPos = distCamToSun < distPosToSun ? localPos * distanceSunScaler : localPos; //r0.xyz
                
                float4 clipPos = mul(unity_MatrixVP, mul(unity_ObjectToWorld, float4(localPos, 1.0))); //r0.xyzw
                
                o.pos.xyzw = clipPos;
                o.clipPos.xyzw = clipPos;
                
                return o;
            }
            
            fout frag(d2f i, uint primitiveID : SV_PrimitiveID)
            {
                fout o;
                  
                uint triId = _IsGraticule > 0.5 ? primitiveID >> 1 : primitiveID; //r0.x
                int packedColor = _Color32Buffer[triId]; //r0.x
                
                uint4 color; //r0.xyzw
                color.y = packedColor & 255;
                color.xzw = packedColor >> int3(24,16,8);
                color.xzw = (int3)color.xzw & int3(255,255,255);
                color.xyzw = (uint4)color.xyzw;
                uint colorAlpha = color.x; //r0.x
                
                float4 gammaColor; //r1.xyzw
                gammaColor.xyz = float3(0.00392156886,0.00392156886,0.00392156886) * color.ywz;
                float superBrightOffset = colorAlpha <= 127.5 ? 0 : 0.5; //r0.y
                gammaColor.w = 2.0 * (colorAlpha * 0.00392156886 - superBrightOffset);
                
                float superBrightness = colorAlpha < 127.5 ? 1.0 : _SuperBrightness; //r0.x
                //lineartogamma (or reverse?)
                float4 linearColor = pow((gammaColor + 0.055)/1.055, 2.4); //r1.xyzw
                linearColor.xyz = 0.95098037 * (0.02 + linearColor.xyz) * superBrightness;
                
                float2 screenPos = ComputeGrabScreenPos(i.clipPos); //r0.xy
                float4 screenTex = tex2D(_ScreenTex_Painting, screenPos); //r0.xyzw
                float4 linearColorAlphaBlended = screenTex.w * linearColor.xyzw;
                linearColorAlphaBlended = (linearColor.xyzw - linearColorAlphaBlended) / 100.0 + linearColorAlphaBlended;
                
                float multiplier = _Global_DS_RenderPlace > 0.5 ? _StarmapMultiplier : _InGameMultiplier; //r1.y
                multiplier = _Global_DS_RenderPlace > 1.5 ? _EditorMultiplier : multiplier; //r1.x
                
                o.sv_target = _FinalMultiplier * lerp(screenTex.xyzw, linearColorAlphaBlended * multiplier, linearColor.w);
                
                return o;
            }
            ENDCG
        }
    }
    Fallback "Diffuse"
}