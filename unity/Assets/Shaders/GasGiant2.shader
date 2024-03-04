Shader "Universe/GasGiant REPLACE" {
    Properties {
        _Multiplier ("Multiplier", Float) = 1
        _Color ("Color", Color) = (1,1,1,1)
        _RimColor ("Color", Vector) = (1,1,1,1)
        _FlowColor ("Flow Color", Color) = (1,1,1,1)
        _ColorRamp ("Color Ramp", 2D) = "white" {}
        _FlowRamp ("Flow Ramp", 2D) = "white" {}
        _SpeedRamp ("Speed Ramp", 2D) = "white" {}
        _NoiseTex ("Noise Tex", 2D) = "Black" {}
        _NoiseThres ("Noise Thres", Range(0, 10)) = 0.3
        _Speed ("Speed", Range(-20, 20)) = 1
        _TileX ("TileX", Range(0, 20)) = 1
        _TileY ("TileY", Range(0, 20)) = 1
        _PolarWhirl ("Polar Whirlwind", Range(-3, 10)) = 3
        _PolarWhirlPower ("Polar Whirlwind Power", Float) = 40
        _Distort ("Distort", Range(0, 0.05)) = 0.01
        _DistortSettings1 ("Distort Settings 1", Vector) = (100,27,10,17)
        _DistortSettings2 ("Distort Settings 2", Vector) = (50,13,10,19)
        _SunDir ("Sun Dir", Vector) = (0,1,0,0)
        _Rotation ("Rotation ", Vector) = (0,0,0,1)
        _AmbientColor0 ("Ambient Color 0", Color) = (0,0,0,0)
        _AmbientColor1 ("Ambient Color 1", Color) = (0,0,0,0)
        _AmbientColor2 ("Ambient Color 2", Color) = (0,0,0,0)
        _Distance ("Distance", Float) = 0
        _Radius ("Radius", Float) = 800
    }
    SubShader {
        LOD 200
        Tags { "RenderType" = "Opaque" "ReplaceTag" = "Gas Giant" }
        Pass {
            Name "FORWARD"
            LOD 200
            Tags { "LIGHTMODE" = "FORWARDBASE" "RenderType" = "Opaque" "ReplaceTag" = "Gas Giant" "SHADOWSUPPORT" = "true" }
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0
            #pragma multi_compile_fwdbase nolightmap nodirlightmap nodynlightmap novertexlight
            #pragma enable_d3d11_debug_symbols
            
            #include "UnityCG.cginc"
            #include "AutoLight.cginc"
            #include "CGIncludes/DSPCommon.cginc"
            
            struct v2f
            {
                float4 pos : SV_POSITION;
                float4 TBNW0 : TEXCOORD0;
                float4 TBNW1 : TEXCOORD1;
                float4 TBNW2 : TEXCOORD2;
                float4 upDir_NdotV : TEXCOORD3;
                float2 uv  : TEXCOORD4;
                float3 indirectLight : TEXCOORD5;
                UNITY_SHADOW_COORDS(7)
                float4 unused2 : TEXCOORD8;
            };
            
            struct fout
            {
                float4 sv_target : SV_Target0;
            };

            float4 _LightColor0;
            float _Multiplier;
            float4 _Color;
            float4 _RimColor;
            float4 _FlowColor;
            float _NoiseThres;
            float _Speed;
            float _TileX;
            float _TileY;
            float _PolarWhirl;
            float _PolarWhirlPower;
            float _Distort;
            float4 _DistortSettings1;
            float4 _DistortSettings2;
            float3 _SunDir;
            float4 _AmbientColor0;
            float4 _AmbientColor1;
            float4 _AmbientColor2;
            float _Distance;

            sampler2D _FlowRamp;
            sampler2D _SpeedRamp;
            sampler2D _NoiseTex;
            sampler2D _ColorRamp;

            float SampleNoise(float tileX, float tileY, float tileXInv, float tileYInv, float animStep, float animOffset, float speedRamp, float halfLong, float halfLongInv)
            {
                float tileStep = speedRamp * (frac(0.5 * animStep + animOffset) * 0.4 - 0.2); //r4.w
                
                float2 noiseUV;
                noiseUV.x = tileX + tileStep;
                noiseUV.y = tileY;
                float noise0 = tex2D(_NoiseTex, noiseUV).x; //r5.y
                
                noiseUV.x = tileX * 2.0 + tileStep;
                noiseUV.y = tileY * 1.3 - (0.12 * animStep);
                float noise1 = tex2D(_NoiseTex, noiseUV).x; //r5.z
                
                noiseUV.x = tileX * 0.8 + tileStep;
                noiseUV.y = tileY * 2.0 + (0.6 * animStep);
                float noise2 = tex2D(_NoiseTex, noiseUV).x; // r5.z
                
                noiseUV.x = tileXInv + tileStep;
                noiseUV.y = tileYInv;
                float noise3 = tex2D(_NoiseTex, noiseUV).x; //r5.z
                
                noiseUV.x = tileXInv * 2.0 + tileStep;
                noiseUV.y = tileYInv * 1.3 - (0.12 * animStep);
                float noise4 = tex2D(_NoiseTex, noiseUV).x; //r4.w
                
                noiseUV.x = tileXInv * 0.8 + tileStep;
                noiseUV.y = tileYInv * 2.0 - (0.6 * animStep);
                float noise5 = tex2D(_NoiseTex, noiseUV).x; //r0.x
                
                float noise012 = noise0 + noise1 * 0.6 + 0.15 * noise2; //r5.y
                float noise345 = noise3 + noise4 * 0.6 + 0.15 * noise5; //r0.x
                
                return noise012 * halfLong + noise345 * halfLongInv; //r0.x
            }

            v2f vert(appdata_full v)
            {
                v2f o;
    
                o.pos.xyzw = UnityObjectToClipPos(v.vertex.xyz);
                
                float3 worldPos = mul(unity_ObjectToWorld, v.vertex.xyzw).xyz;
                float3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);
                float3 worldNormal = UnityObjectToWorldNormal(v.normal.xyz);
                float3 worldBinormal = calculateBinormal(float4(worldTangent, v.tangent.w), worldNormal);
                
                o.TBNW0.w = worldPos.x;
                o.TBNW0.x = worldTangent.z;
                o.TBNW0.y = worldBinormal.x;
                o.TBNW0.z = worldNormal.x;
                o.TBNW1.x = worldTangent.x;
                o.TBNW2.x = worldTangent.y;
                o.TBNW1.w = worldPos.y;
                o.TBNW2.w = worldPos.z;
                o.TBNW1.y = worldBinormal.y;
                o.TBNW2.y = worldBinormal.z;
                o.TBNW1.z = worldNormal.y;
                o.TBNW2.z = worldNormal.z;
                
                o.upDir_NdotV.xyz = normalize(v.vertex.xyz);
                
                float3 viewDir = normalize(_WorldSpaceCameraPos - worldPos.xyz); //r0.xyz
                float3 normalDir = UnityObjectToWorldDir(v.normal.xyz); //r1.xyz
                float NdotV = dot(viewDir, normalDir); //r0.x
                o.upDir_NdotV.w = abs(NdotV);
                
                o.uv.xy = v.texcoord.xy;
                o.indirectLight.xyz = ShadeSH9(float4(worldNormal, 1.0));
                UNITY_TRANSFER_SHADOW(o, float(0,0))
                o.unused2.xyzw = float4(0,0,0,0);
                
                return o;
            }

            fout frag(v2f i)
            {
                fout o;
                
                float animStep = _Time.x * _Speed; //r0.x
                
                float longitude = atan2(i.upDir_NdotV.z, i.upDir_NdotV.x); //r0.y
                float normLong = frac(UNITY_INV_TWO_PI * longitude); //r0.z
                float normLongInv = frac(UNITY_INV_TWO_PI * longitude + 0.5); //r0.y
                
                float verticalPct = normalize(i.upDir_NdotV.xyz).y; // r0.w
                float polar = acos(verticalPct); //r1.x
                float latitude = UNITY_HALF_PI - polar; //r0.w
                // angle from -pi/2 to pi/2 with 0=equator and pi/2=north pole
                float signedNormLat = latitude * (2.0 / UNITY_PI); //r1.x
                // angle from -1 to 1 with 0=equator
                float normLat = latitude * UNITY_INV_PI + 0.5; //r2.y
                // angle from 0 to 1 with 0.5=equator
                
                float polarWhirlPower = pow(abs(signedNormLat), _PolarWhirlPower); //r0.w
                // _PolarWhirlPower = 5, 8, 10, 20, or 50
                float polarWhirl = polarWhirlPower * _PolarWhirl + 0.5; //r0.w
                // _PolarWhirl = -0.2, -0.3, or -0.4
                
                float halfLong = 1.0 - 2.0 * abs(0.5 - normLong); //r1.z
                // angle around sphere from 0 to 1, 0=front, 1=back
                float halfLongInv = 1.0 - 2.0 * abs(0.5 - normLongInv); //r1.w
                // angle around sphere from 0 to 1, 0=back, 1=front
                
                float tileX = _TileX * normLong * polarWhirl; //r3.x
                float tileY = _TileY * signedNormLat; //r3.y
                float tileXInv = _TileX * normLongInv * polarWhirl; //r0.w
                float tileYInv = tileY;
                
                float2 rampUV; //r2.xy
                rampUV.x = 0.5;
                rampUV.y = normLat;
                
                float3 flowColor = tex2D(_FlowRamp, rampUV).xyz;
                flowColor = flowColor * 2.0 * _FlowColor.xyz; //r4.xyz
                
                float speedRamp = tex2D(_SpeedRamp, rampUV).x; //r2.x 
                speedRamp = speedRamp * 2.0 - 1.0; //r2.x
                
                float distFromPoles = 1.0 - abs(signedNormLat); //r1.x
                //range from 0 to 1, 0=north/south pole, 1=equator
                float distortAmt = _Distort * distFromPoles;
              
                if (_Distort > 0)
                {
                    float distortY = distortAmt * sin(tileX * _DistortSettings1.x + 2.0 * animStep) * sin(tileX * _DistortSettings1.y);
                    tileY = distortY + tileY; //r6.y
                    float distortYInv = distortAmt * sin(tileXInv * _DistortSettings1.x + 2.0 * animStep) * sin(tileXInv * _DistortSettings1.y); //r3.w
                    tileYInv = distortYInv + tileY; //r6.w
                }
                
                float noiseComp1 = SampleNoise(tileX, tileY, tileXInv, tileYInv, animStep, 0.0, speedRamp, halfLong, halfLongInv);
                float noiseComp2 = SampleNoise(tileX, tileY, tileXInv, tileYInv, animStep, 0.5, speedRamp, halfLong, halfLongInv);
                
                float noiseAnimUpDown = 1.0 - 2.0 * abs(0.5 - frac(0.5 * animStep)); //r3.y
                //0 to 1 to 0, every sec/10 * _Speed
                float noiseAnimNegPosPtTwo = 1.0 - 2.0 * abs(0.5 - frac(0.5 * animStep + 0.5)); //r3.w
                //-0.2 to 0.2, every sec/20 * _Speed
                float polarWhirlPowerInv = 1.0 - polarWhirlPower; //r1.y (moved from where polarwhirl was calculated above)
                float noise = polarWhirlPowerInv * (noiseAnimUpDown * noiseComp1 + noiseAnimNegPosPtTwo * noiseComp2); //r0.x
                
                if (_Distort > 0)
                {
                    float distort0 = (i.upDir_NdotV.y * 0.3 + i.upDir_NdotV.x) * _DistortSettings1.z + _DistortSettings1.w * 0.2 * animStep; //r0.y
                    float distort1 = i.upDir_NdotV.y                     * _DistortSettings2.x + _DistortSettings2.y * sin(0.2 * animStep); //r0.w
                    float distort2 = (i.upDir_NdotV.y * 0.7 + i.upDir_NdotV.z) * _DistortSettings2.z + _DistortSettings2.w * 0.2 * animStep; //r0.z
                    float distort = sin(distort0) * sin(distort1) * sin(distort2); //r0.y
                    
                    rampUV.y = distortAmt * distort * (noise - 0.5) * 10 + rampUV.y;
                }

                float3 color = tex2D(_ColorRamp, r2.zw);
                float NdotV = i.upDir_NdotV.w;
                color = color * lerp(_Color.xyz, _RimColor.xyz, pow(1.0 - NdotV, 2.0));
                
                float flowAlpha = _FlowColor.w * saturate(noise * (_NoiseThres + 1.0) - _NoiseThres);
                color = _Multiplier * lerp(color, flowColor.xyz * _Color.xyz, flowAlpha);
                
                float3 worldPos = float3(i.TBNW0.w, i.TBNW1.w, i.TBNW2.w);
                UNITY_LIGHT_ATTENUATION(atten, i, worldPos); //r0.w
                
                float3 worldNormal = normalize(float3(i.TBNW0.z, i.TBNW1.z, i.TBNW2.z)); //r1.xyz
                float3 NdotL = dot(worldNormal, _SunDir.xyz); //r1.x
                float3 NdotL_clamped = max(0, NdotL);
                NdotL_clamped = NdotL_clamped > 0.5 ? 0.5 * (log(2.0 * NdotL_clamped) + 1) : NdotL_clamped; // should this be longHemiInv?
                
                float lod1 = 1.0 + 2.0 * saturate(0.5 * log(_Distance) - 4.2); //r2.z
                float3 ambientColor0 = _AmbientColor0.xyz * lod1;
                float3 ambientColor1 = _AmbientColor1.xyz;
                float lod2 = min(1.0, 0.4 + max(0, (400 - _Distance) / 150.0)); //r2.x
                float3 ambientColor2 = _AmbientColor2.xyz * lod2;
                float3 ambientColor = calculateAmbientColor(NdotL, ambientColor0, ambientColor1, ambientColor2); //r2.xyw
                
                atten = 0.8 * lerp(atten, 1, saturate(0.15 * NdotL));
                float3 sunLight = _LightColor0.xyz * NdotL_clamped * atten;
                
                o.sv_target.xyz = color * (i.indirectLight.xyz + sunLight + ambientColor);
                o.sv_target.w = 1;
                
                return o;
            }
            ENDCG
        }
    }
    Fallback "Diffuse"
}