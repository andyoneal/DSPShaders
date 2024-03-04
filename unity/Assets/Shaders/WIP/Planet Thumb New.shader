Shader "VF Shaders/Forward/Planet Thumb New REPLACE" {
    Properties {
        _HeightMap ("Height map", Cube) = "black" {}
        _Color ("Color", Color) = (1,1,1,1)
        _ShoreLineColor ("Shore Line Color", Color) = (0,0,0,0)
        _RimColor ("Rim Color", Color) = (0,0,0,0)
        _ShoreInvThick ("Shore Inv Thick", Float) = 7
        _ShoreHeight ("Shore Height", Float) = 0
        _WireIntens ("Wire Intensity", Float) = 0.5
        _BioStrength ("Bio Strength", Float) = 0
        _ColorBio0 ("ColorBio0", Color) = (0,0,0,0)
        _ColorBio1 ("ColorBio1", Color) = (0,0,0,0)
        _ColorBio2 ("ColorBio2", Color) = (0,0,0,0)
        _HeightSettings ("Height Setting (x min, y max, z minval, w maxval)", Vector) = (-10,10,0,1)
        _FarHeight ("Far Height   far lerp(z,w,?)", Float) = 0.5
        _SunDir ("Sun Dir", Vector) = (0,0,1,0)
        _Rotation ("Rotation", Vector) = (0,0,0,1)
        _Diameter ("Radius", Float) = 0.1
    }
    SubShader {
        LOD 100
        Tags { "RenderType" = "Opaque" }
        Pass {
            LOD 100
            Tags { "RenderType" = "Opaque" }
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0
            #pragma multi_compile_fwdbase nolightmap nodirlightmap nodynlightmap novertexlight
            #pragma enable_d3d11_debug_symbols
            
            #include "UnityCG.cginc"
            #include "CGIncludes/DSPCommon.cginc"
            
            struct v2f
            {
                float3 upDir : TEXCOORD0;
                float NdotV : TEXCOORD2;
                float3 worldPos : TEXCOORD1;
                float4 pos : SV_POSITION;
            };
            
            struct fout
            {
                float4 sv_target : SV_Target0;
            };
            
            float3 _SunDir;
            float4 _Rotation;
            float4 _Color;
            float4 _ShoreLineColor;
            float4 _RimColor;
            float _ShoreInvThick;
            float _ShoreHeight;
            float _WireIntens;
            float _BioStrength;
            float4 _ColorBio0;
            float4 _ColorBio1;
            float4 _ColorBio2;
            float4 _HeightSettings;
            float _FarHeight;
            float _Diameter;

            samplerCUBE _HeightMap;
            
            v2f vert(appdata_full v)
            {
                v2f o;
  
                float3 upDir = normalize(v.vertex.xyz); //r3.xyz
                float3 worldNormal = rotate_vector_fast(upDir, _Rotation);

                o.upDir.xyz = upDir;
                o.NdotL = dot(worldNormal, _SunDir);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex.xyzw).xyz;
                o.pos.xyzw = UnityObjectToClipPos(v.vertex.xyz);

                return o;
            }

            fout frag(v2f inp)
            {
                fout o;

                float3 upDir = normalize(i.upDir.xyz); //r0.xyz

                float longitude = atan2(i.upDir.z, i.upDir.x); //r0.w

                float polar = acos(verticalPct); //r1.x
                float latitude = UNITY_HALF_PI - polar; //r1.x
                float distFromPoles = cos(latitude); //r1.w
                // 0=north/south pole, 1=equator

                r0.w = lerp(0.5 * (1.0 + cos(18.0 * longitude)), 1.0, saturate(20 * (distFromPoles - 0.45)));
                //1.0 when distFromPoles >= 0.5
                //transitions between 0.45 to 0.5

                float3 camToPos = i.worldPos.xyz - _WorldSpaceCameraPos.xyz; //r2.yzw
                float distCamToPos = length(camToPos); //r1.z
                float distRatio = max(0, (distCamToPos / _Diameter) - 2.0); //r1.z

                r1.y = frac((18.0 / UNITY_PI) * longitude); //18/pi
                r1.x = frac((18.0 / UNITY_PI) * latitude;

                r6.x = (distRatio * 0.6 + 1.0) / 25.0;
                r2.x = r6.x / (0.01 + distFromPoles);
                r1.y = saturate(10 * distFromPoles) * saturate(max((r1.y - (1.0 - r2.x)) / r2.x, (r2.x - r1.y) / r2.x));
                r1.x = saturate(max((r6.x - r1.x) / r6.x, (r1.x - (1.0 - r6.x)) / r6.x));
                r0.w = pow(0.7 * (r1.y * r0.w + r1.x), 2.0) / (distRatio * 0.3 + 1.0);


                float4 heightMap = texCUBE(_HeightMap, upDir.xyz).xyzw; //r4.xyzw
                float nearHeight = saturate((heightMap.x - _HeightSettings.x) / (_HeightSettings.y - _HeightSettings.x)); //r1.w
                nearHeight = lerp(_HeightSettings.z, _HeightSettings.w, r1.w); //r1.w
                float farHeight = lerp(_HeightSettings.z, _HeightSettings.w, _FarHeight); //r2.x

                r3.y = min(1.0, 1.0 / ((distRatio - 1.0) * 0.1 + 1.0));
                r6.y = r0.w * _WireIntens; 
                r0.w = 0.2 * r6.y + (r6.y + 1.0) * lerp(farHeight, nearHeight, r3.y);

                float3 viewDir = normalize(-camToPos); //r2.xyz
                float3 worldNormal = rotate_vector_fast(upDir.xyz, _Rotation); //r5.xyz

                float NdotV = saturate(dot(worldNormal, viewDir)); //r0.x

                r0.z = saturate(i.NdotL * 4.0 + 0.5) * min(1.0, 10 * NdotV);
                r0.z = pow(r0.z, 2.0) * (3.0 - 2.0 * r0.z) * 0.8 + 0.2; //smoothstep
                r0.z = (0.75 + min(0.25, 0.007 * distRatio)) * r0.z;

                float distFalloff = min(1.0, 1.0 / ((distRatio - 1.0) * 0.3 + 1.0)); //r1.x
                r1.y = saturate(1.0 - distFalloff * _ShoreInvThick * abs(heightMap.x - _ShoreHeight));
                float landDetail = r1.y * r0.z * distFalloff * (saturate(i.NdotL * 0.5 + 0.5) * 0.4 + 0.6); //r1.x
                float4 color = r0.wwww * _Color + _ShoreLineColor * landDetail; //r1.xyzw

                float heightFrac = frac(heightMap.y); //r0.w
                heightFrac = pow(heightFrac, 2.0) * (3.0 - heightFrac * 2.0); //smoothstep
                float heightInt = heightMap.y - heightFrac;
                float height = heightFrac + heightInt; //r0.w

                float4 colorBio = _ColorBio1.xyzw * min(saturate(2.0 - height), saturate(height));
                colorBio = _ColorBio0.xyzw * saturate(1.0 - height) + colorBio;
                colorBio = _ColorBio2.xyzw * saturate(height - 1.0) + colorBio;
                colorBio = _BioStrength * colorBio * r0.zzzz;
                colorBio = _BioStrength > 0.00001 ? colorBio : 0;

                r0.x = pow(1.0 - NdotV, (2.5 / (distRatio * 0.3 + 1.0)) + 2.5);
                r0.x = 1.15 * r0.x * 0.5 * saturate(0.5 + i.NdotL) * r3.y;
                color.xyzw = r0.xxxx * _RimColor + colorBio + color;
                o0.xyz = color.xyz * color.www * min(1.0, 10 * NdotV);
                o0.w = 1;

                return o;
            }
            ENDCG
        }
    }
}