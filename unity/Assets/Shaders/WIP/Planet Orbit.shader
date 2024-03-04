Shader "Universe/Starmap/Planet Orbit REPLACE" {
    Properties {
        _Multiplier ("Multiplier", Float) = 1
        _TileScale ("Width Scale", Float) = 1
        _DistScale ("Dist Scale", Float) = 0.03
        _DistPower ("Dist Power", Float) = 0.9
        _MinDistScale ("Min Dist Scale", Float) = 1
        _MaxDistScale ("Min Dist Scale", Float) = 10
        _LineColorA ("Line Color", Color) = (1,1,1,1)
        _LineColorB ("Line Color", Color) = (1,1,1,1)
        _LineTexture ("Line Texture", 2D) = "white" {}
        _Position ("Position (set by code)", Vector) = (0,0,0,0)
        _Rotation ("Rotation (set by code)", Vector) = (0,0,0,1)
        _Radius ("Radius", Float) = 1
        _Stencil ("Stencil", Float) = 101
    }
    SubShader {
        Tags { "QUEUE" = "Transparent+2" "RenderType" = "Transparent" }
        Pass {
            Tags { "QUEUE" = "Transparent+2" "RenderType" = "Transparent" }
            Blend One One, One One
            ZWrite Off
            Cull Off
            //depth always
            Stencil {
                ref [_Stencil]
                Comp NotEqual
                Pass Replace
                Fail Keep
                ZFail Keep
            }
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0
            #pragma enable_d3d11_debug_symbols
            #include "CGIncludes/DSPCommon.cginc"
            
            #include "UnityCG.cginc"
            
            struct v2f
            {
                float4 pos : SV_Position0;
                float2 uv : TEXCOORD0;
                float3 originToCam : TEXCOORD1;
                float3 camToPos : TEXCOORD2;
            };
            
            struct fout
            {
                float4 sv_target : SV_Target0;
            };
            
            float4 _Position;
            float4 _Rotation;
            float _Multiplier;
            float _TileScale;
            float _DistScale;
            float _DistPower;
            float _MinDistScale;
            float _MaxDistScale;
            float4 _LineColorA;
            float4 _LineColorB;
            float _Radius;

            sampler2D _LineTexture;
            
            v2f vert(appdata_full v)
            {
                v2f o;
                
                o.pos = UnityObjectToClipPos(v.vertex.xyz);
                float3 worldPos = mul(unity_ObjectToWorld, v.vertex.xyzw).xyz; //r0.xyz
                
                o.uv.xy = v.texcoord.xy; //tx0
                
                //_Position = planet.orbitAroundPlanet == null ? (planet.star.uPosition - starmap.viewTargetUPos) * 0.00025 : (planet.orbitAroundPlanet.uPosition - starmap.viewTargetUPos) * 0.00025;
                //vector from planet to center of orbit
                //_Rotation = planet.runtimeOrbitRotation * Quaternion.Euler(0f, 0f - planet.runtimeOrbitPhase, 0f);
                //quaternion for the planets current position in its orbit
                float3 originToCam = _WorldSpaceCameraPos.xyz - _Position.xyz; //r4.xyz
                o.originToCam.xyz = rotate_vector_fast(originToCam, _Rotation);
                float3 camToPos = worldPos.xyz - _WorldSpaceCameraPos.xyz; //r0.xyz
                o.camToPos.xyz = rotate_vector_fast(camToPos, _Rotation);
                
                return o;
            }

            fout frag(v2f inp)
            {
                fout o;
                float3 eyeVec = normalize(i.camToPos.xyz); //r0.xyz
                
                r0.w = dot(i.originToCam.xyz, eyeVec.xyz);
                float3 diffCamToPosOrigin = i.originToCam.xyz - dot(i.originToCam.xyz, eyeVec.xyz) * eyeVec.xyz; //r1.xyz
                float diffCamToPosOriginMagSqr = dot(diffCamToPosOrigin, diffCamToPosOrigin); //r1.x
                float diffCamToPosOriginMag = length(diffCamToPosOrigin); //r1.y
                
                if (1.01 * _Radius < diffCamToPosOriginMag)
                    discard;
                if (diffCamToPosOriginMag <= 0)
                    discard;
                
                // _Radius = planet.orbitRadius * 10f
                float distUnk = 0f; //r1.z
                float distUnkInv = 0f; //r0.w
                if (diffCamToPosOriginMag < 0.9999 * _Radius)
                {
                    float distCamToOrbit = sqrt(pow(_Radius, 2.0) - diffCamToPosOriginMagSqr); //r1.x
                    distUnk = max(0, distCamToOrbit - r0.w); //r1.z
                    distUnkInv = max(0, -distCamToOrbit - r0.w); //r0.w
                }
                
                float heightRatio = eyeVec.y == 0.0 ? 0.0 : max(0.0, -i.originToCam.y / eyeVec.y); //r1.x
                // if origin is higher than planet, heightRatio > 1
                
                float3 originToOrbitVec0 = eyeVec.xyz * distUnk + i.originToCam.xyz; // r2.xyz
                float3 originToOrbitVec1 = eyeVec.xyz * distUnkInv + i.originToCam.xyz; //r3.xyz
                float3 originToOrbitVec2 = eyeVec.xyz * heightRatio + i.originToCam.xyz; //r0.xyz
                
                float azimuth0 = frac(UNITY_INV_TWO_PI * atan2(originToOrbitVec0.x, originToOrbitVec0.z)); // r1.y
                float azimuth1 = frac(UNITY_INV_TWO_PI * atan2(originToOrbitVec1.x, originToOrbitVec1.z)); // r1.w
                float azimuth2 = frac(UNITY_INV_TWO_PI * atan2(originToOrbitVec2.x, originToOrbitVec2.z)); // r2.x
                
                float distUnkScaled = min(_MaxDistScale, max(_MinDistScale, pow(_DistScale * distUnk, _DistPower))); //r2.z
                float distUnkInvScaled = min(_MaxDistScale, max(_MinDistScale, pow(_DistScale * distUnkInv, _DistPower))); //r2.w
                float heightRatioScaled = min(_MaxDistScale, max(_MinDistScale, pow(_DistScale * heightRatio, _DistPower))); //r3.z
                
                float tile0 = _TileScale * (abs(originToOrbitVec0.y) / distUnkScaled); //r2.y
                float tile1 = _TileScale * (abs(originToOrbitVec1.y) / distUnkInvScaled); //r2.z
                float tile2 = _TileScale * (abs(length(originToOrbitVec2.xyz) - _Radius) / heightRatioScaled); //r0.x
                
                float2 uv;
                uv.x = i.uv.x;
                uv.y = 2.0 * tile0;
                float4 lineColor0 = tex2D(_LineTexture, uv.xy); //r5.xyzw
                
                uv.y = 2.0 * tile1;
                float4 lineColor1 = tex2D(_LineTexture, uv.xy); //r4.xyzw
                
                uv.y = 2.0 * tile2;
                float4 lineColor2 = tex2D(_LineTexture, uv.xy); //r3.xyzw
                
                lineColor0 = distUnk == 0.0 || tile0 > 0.5 ? float4(0,0,0,0) : lineColor0;
                lineColor1 = distUnkInv == 0.0 || tile1 > 0.5 ? float4(0,0,0,0) : lineColor1;
                float4 lineColor3 = heightRatio == 0.0 || tile2 > 0.5 ? float4(0,0,0,0) : lineColor2; //r0.xyzw
                
                lineColor0 = lineColor0 * lerp(_LineColorA, _LineColorB, pow(azimuth0, 5.0) * lineColor2); //r5.xyzw
                lineColor1 = lineColor1 * lerp(_LineColorA, _LineColorB, pow(azimuth1, 5.0)); //r1.xyzw
                lineColor2 = lineColor3 * lerp(_LineColorA, _LineColorB, pow(azimuth2, 5.0)); //r0.xyzw
                
                o.sv_target.xyzw = _Multiplier * max(max(lineColor0, lineColor1), lineColor2);
                
                return o;
            }
            ENDCG
        }
    }
}