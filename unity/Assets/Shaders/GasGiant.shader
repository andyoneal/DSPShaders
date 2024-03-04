Shader "Universe/GasGiant REPLACE" {
	Properties {
		_Multiplier ("Multiplier", Float) = 1
		_Color ("Color", Color) = (1,1,1,1)
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
                float3 upDir : TEXCOORD3;
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

			float SampleNoise(float tileX, float tileY, float tileX_2, float tileY_2, float animStep, float animOffset, float speedRamp, float verticalPct, float longHemi, float longHemiInv)
            {
                float tileStep = (frac(0.5 * animStep + animOffset) * 0.4 - 0.2) * speedRamp; //r4.w
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
                
                noiseUV.x = tileX_2 + tileStep;
                noiseUV.y = tileY_2;
                float noise3 = tex2D(_NoiseTex, noiseUV).x; //r5.z
                
                noiseUV.x = tileX_2 * 2.0 + tileStep;
                noiseUV.y = tileY_2 * 1.3 - (0.12 * animStep);
                float noise4 = tex2D(_NoiseTex, noiseUV).x; //r4.w
                
                noiseUV.x = tileX_2 * 0.8 + tileStep;
                noiseUV.y = tileY_2 * 2.0 - (0.6 * animStep);
                float noise5 = tex2D(_NoiseTex, noiseUV).x; //r0.x
                
                float noise012 = noise0 + noise1 * 0.6 + 0.15 * noise2; //r5.y
                float noise345 = noise3 + noise4 * 0.6 + 0.15 * noise5; //r0.x
                
                float oneMinusAsinY = 1.0 - asin(verticalPct); // r1.y
                return oneMinusAsinY * (noise012 * longHemi + noise345 * longHemiInv); //r0.x
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
                
                o.upDir.xyz = normalize(v.vertex.xyz);
                o.uv.xy = v.texcoord.xy;
                o.indirectLight.xyz = ShadeSH9(float4(worldNormal, 1.0));
				UNITY_TRANSFER_SHADOW(o, float(0,0))
                o.unused2.xyzw = float4(0,0,0,0);
                
                return o;
			}

			fout frag(v2f i)
			{
				fout o;
				
                float longitude = atan2(i.upDir.z, i.upDir.x); //r0.y
    
                float longNorm = frac(UNITY_INV_TWO_PI * longitude); //r0.z
                float longNormInv = frac(UNITY_INV_TWO_PI * longitude + 0.5); //r0.y
                
                float verticalPct = normalize(i.upDir.xyz).y; // r0.w
                float latitude = acos(verticalPct); //r1.x

			    float oneMinusTwoDivPiY = 1.0 - (2.0 * UNITY_INV_PI * latitude); // r1.x // should this be 1 - (lat / 2pi)?

			    // _PolarWhirl = -0.2, -0.3, or -0.4
                // _PolarWhirlPower = 5, 8, 10, 20, or 50
                float polarWhirl = pow(oneMinusTwoDivPiY, _PolarWhirlPower) * _PolarWhirl + 0.5; //r0.w
                float tileX = _TileX * longNormInv * polarWhirl; //r3.x
                float tileY = _TileY * oneMinusTwoDivPiY; //r3.y
                float tileX_2 = _TileX * longNormInv * pow(polarWhirl, 2); //r0.w
                float tileY_2 = tileY;
                
                float2 rampUV; //r2.xy
                rampUV.x = 0.5;
                rampUV.y = tileX_2 * UNITY_INV_PI + 0.5;
                float3 flowColor = 2.0 * _FlowColor.xyz * tex2D(_FlowRamp, rampUV).xyz; //r4.xyz
                
                float speedRamp = tex2D(_SpeedRamp, rampUV).x; //r2.x 
                speedRamp = speedRamp * 2.0 - 1.0; //r2.x
                
                float animStep = _Time.x * _Speed; //r0.x
                float distortX_2 = 0;
                float distortAmt = _Distort * (1.0 - abs(oneMinusTwoDivPiY)); //_Distort * r1.x
              
                if (_Distort > 0)
                {
                    float distortX = distortAmt * sin(tileX * _DistortSettings1.x + 2.0 * animStep) * sin(tileX * _DistortSettings1.y);
                    tileY = distortX + tileY; //r6.y
                    distortX_2 = distortAmt * sin(tileX_2 * _DistortSettings1.x + 2.0 * animStep) * sin(tileX_2 * _DistortSettings1.y); //r3.w
                    tileY_2 = distortX_2 + tileY; //r6.w
                }
                
                float longHemi = 1.0 - 2.0 * abs(0.5 - longNorm); //r1.z
                float longHemiInv = 1.0 - 2.0 * abs(0.5 - longNormInv); //r1.w
                float noiseComp1 = SampleNoise(tileX, tileY, tileX_2, tileY_2, animStep, 0.0, speedRamp, verticalPct, longHemi, longHemiInv);
                float noiseComp2 = SampleNoise(tileX, tileY, tileX_2, tileY_2, animStep, 0.5, speedRamp, verticalPct, longHemi, longHemiInv);
                
                float noiseAnim = 1.0 - 2.0 * abs(0.5 - frac(0.5 * animStep)); //r3.y
                float noiseDistort = 1.0 - 2.0 * abs(0.5 - distortX_2); //r3.w
                float noise = noiseAnim * noiseComp1 + noiseDistort * noiseComp2; //r0.x
                
                if (_Distort > 0)
                {
                    float distort0 = (i.upDir.y * 0.3 + i.upDir.x) * _DistortSettings1.z + _DistortSettings1.w * 0.2 * animStep; //r0.y
                    float distort1 = i.upDir.y                     * _DistortSettings2.x + _DistortSettings2.y * sin(0.2 * animStep); //r0.w
                    float distort2 = (i.upDir.y * 0.7 + i.upDir.z) * _DistortSettings2.z + _DistortSettings2.w * 0.2 * animStep; //r0.z
                    float distort = sin(distort0) * sin(distort1) * sin(distort2); //r0.y
                    
                    rampUV.y = distortAmt * distort * (noise - 0.5) * 10 + rampUV.y;
                }
                
                float3 color = _Color.xyz * tex2D(_ColorRamp, rampUV).xyz; //r0.yzw
                float flowAlpha = _FlowColor.w * saturate(lerp(_NoiseThres, 1.0, noise)); //r0.x
                color = _Multiplier * lerp(color, flowColor.xyz * _Color.xyz, flowAlpha); //r0.xyz
                
                float3 worldPos = float3(i.TBNW0.w, i.TBNW1.w, i.TBNW2.w);
                UNITY_LIGHT_ATTENUATION(atten, i, worldPos); //r0.w
                
                float3 worldNormal = normalize(float3(i.TBNW0.z, i.TBNW1.z, i.TBNW2.z)); //r1.xyz
                float3 NdotL = dot(worldNormal, _SunDir.xyz); //r1.x
                float3 NdotL_clamped = max(0, NdotL);
                NdotL_clamped = longHemiInv > 0.5 ? 0.5 * (log(2.0 * NdotL_clamped) + 1) : NdotL_clamped; // should this be longHemiInv?
                
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