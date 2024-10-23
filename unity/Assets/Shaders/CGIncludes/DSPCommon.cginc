#include "UnityCG.cginc"

#define INV_TEN_PI 0.0318309888

UNITY_DECLARE_TEXCUBE(_Global_PGI);
float _PGI_Gray;

struct GPUOBJECT
{
    uint objId;
    float3 pos;
    float4 rot;
};

struct AnimData
{
    float time;
    float prepare_length;
    float working_length;
    uint state;
    float power;
};

float3 rotate_vector_fast(float3 v, float4 r){
    return v + cross(2.0 * r.xyz, cross(r.xyz, v) + r.w * v);
}

float3 GammaToLinear_Approx(float c)
{
    return pow((c + 0.055)/1.055, 2.4);
}

float3 GammaToLinear_Approx(float3 c)
{
    return pow((c + 0.055)/1.055, 2.4);
}

float SchlickFresnel_Approx(float F0, float vDotH)
{
    return F0 + (1 - F0) * exp2((-5.55473 * vDotH - 6.98316) * vDotH);
}

sampler2D _NormalTex;

float3 WorldNormalFromNormalMap(float2 uv, float normalMult, float3x3 TBN)
{
    float3 unpackedNormal = UnpackNormal(tex2Dbias(_NormalTex, float4(uv, 0, -1)));
    float3 normal = float3(normalMult * unpackedNormal.xy, unpackedNormal.z);
    normal = normalize(normal);
    float3 worldNormal = mul(normal, TBN);
    worldNormal = normalize(worldNormal); //r2.xyz
    
    return worldNormal;
}

float3 calculateLightFromHeadlamp(float4 headlampPos, float3 upDir, float3 lightDir, float3 normal, float lightSize, float lightRadius, float brightness, bool isReflected, float smoothness) {
    bool isHeadlampOn = headlampPos.w >= 0.5;
    if (!isHeadlampOn) return float3(0, 0, 0);
    
    float lightCoreDistance = length(headlampPos) - lightSize; //r0.z
    float lightingBlendFactor = saturate(5.0 * dot(-upDir, lightDir)) * saturate(lightCoreDistance); //r0.w
    float3 nightLight = lightingBlendFactor * float3(1.3, 1.1, 0.6) * brightness;
    
    float3 worldPosForLighting = lightCoreDistance * upDir;
    
    float3 posToLight = headlampPos - worldPosForLighting; //r4.xyz
    float distToLight = length(posToLight); //r0.z
    float attenuation = pow(max(0, (lightRadius - distToLight) / lightRadius), 2.0); //r1.w
    float3 nightLightDir = posToLight / distToLight; //r4.xyz
    float lightAngle = saturate(dot(nightLightDir, normal)); //r0.z
    
    lightAngle = isReflected ? lightSize * smoothness * pow(lightAngle, exp2((-3.0 / log10(0.5)) * smoothness)) : lightAngle; //r0.z
    
    return distToLight < 0.001 ?  nightLight : attenuation * lightAngle * nightLight; //r0.yzw
}

float3 calculateLightFromHeadlamp(float4 headlampPos, float3 upDir, float3 lightDir, float3 normal, float lightSize, float lightRadius, bool isReflected, float smoothness) {
    return calculateLightFromHeadlamp(headlampPos, upDir, lightDir, normal, lightSize, lightRadius, 1.0, isReflected, smoothness);
}

float distributionGGX(float roughness, float nDotH) {
    float a = roughness; //NDF formula says `a` should be roughness^2
        //"We also adopted Disney’s reparameterization of α = Roughness2."
        //but a = Roughness here
    float denom = rcp(nDotH * nDotH * (a * a - 1.0) + 1); //r0.w
    return denom * denom * a * a; //r0.w
    //missing (1/PI) *
}

float geometrySchlickGGX(float roughness, float nDotV, float nDotL) {
    float k = pow(roughness * roughness + 1.0, 2) * 0.125; //r2.w does "roughness" mean perceptualroughness^2 or ^4?
        //"We also chose to use Disney’s modification to reduce “hotness” by remapping roughness using (Roughness+1)/2 before squaring."
        //but this is doing (Roughness^2+1)/2 before squaring
    float ggxNV = nDotV * (1.0 - k) + k; //r5.x
    float ggxNL = nDotL * (1.0 - k) + k; //r1.z
    return rcp(ggxNL * ggxNV); //r1.x
    //missing (nDotL * nDotV) *
}

float GGX(float roughness, float metallic, float nDotH, float nDotV, float nDotL, float vDotH) {

    float D = distributionGGX(roughness, nDotH);
    float G = geometrySchlickGGX(roughness, nDotV, nDotL); //r1.x
    float F = SchlickFresnel_Approx(metallic, vDotH);

    return (D * F * G) / 4.0;
}

#if defined(_ENABLE_VFINST)

int _VertexSize;
uint _VertexCount;
uint _FrameCount;
StructuredBuffer<float> _VertaBuffer;

void animateWithVerta(uint vertexID, float time, float prepare_length, float working_length, inout float3 pos, inout float3 normal, inout float3 tangent) {
    float frameCount = prepare_length > 0 ? _FrameCount - 1 : _FrameCount; //r0.w
    bool skipVerta = frameCount <= 0 || (_VertexSize != 9 && _VertexSize != 6 && _VertexSize != 3) || _VertexCount <= 0 || working_length <= 0; //r0.x
    if (!skipVerta) {
      float prepareTime = time >= prepare_length && prepare_length > 0 ? 1.0 : 0; //r0.x
      prepareTime = frac(time / (prepare_length + working_length)) * (frameCount - 1) + prepareTime;
      prepareTime = frameCount - 1 <= 0 ? 0 : prepareTime; //r0.x
      uint prepareTimeSec = (uint)prepareTime; //r0.z
      float prepareTimeFrac = frac(prepareTime); //r0.x
      int frameStride = _VertexSize * _VertexCount; //r0.w
      int offset = vertexID * _VertexSize; //r1.x
      uint frameIdx = mad(frameStride, prepareTimeSec, offset); //r3.y
      uint nextFrameIdx = mad(frameStride, prepareTimeSec + 1, offset); //r0.z

      if (_VertexSize == 3) {
        pos.x = lerp(_VertaBuffer[frameIdx], _VertaBuffer[nextFrameIdx], prepareTimeFrac);
        pos.y = lerp(_VertaBuffer[frameIdx + 1], _VertaBuffer[nextFrameIdx + 1], prepareTimeFrac);
        pos.z = lerp(_VertaBuffer[frameIdx + 2], _VertaBuffer[nextFrameIdx + 2], prepareTimeFrac);
      } else {
        if (_VertexSize == 6) {
          pos.x = lerp(_VertaBuffer[frameIdx], _VertaBuffer[nextFrameIdx], prepareTimeFrac);
          pos.y = lerp(_VertaBuffer[frameIdx + 1], _VertaBuffer[nextFrameIdx + 1], prepareTimeFrac);
          pos.z = lerp(_VertaBuffer[frameIdx + 2], _VertaBuffer[nextFrameIdx + 2], prepareTimeFrac);
          normal.x = lerp(_VertaBuffer[frameIdx + 3], _VertaBuffer[nextFrameIdx + 3], prepareTimeFrac);
          normal.y = lerp(_VertaBuffer[frameIdx + 4], _VertaBuffer[nextFrameIdx + 4], prepareTimeFrac);
          normal.z = lerp(_VertaBuffer[frameIdx + 5], _VertaBuffer[nextFrameIdx + 5], prepareTimeFrac);
        } else {
          if (_VertexSize == 9) {
            pos.x = lerp(_VertaBuffer[frameIdx], _VertaBuffer[nextFrameIdx], prepareTimeFrac);
            pos.y = lerp(_VertaBuffer[frameIdx + 1], _VertaBuffer[nextFrameIdx + 1], prepareTimeFrac);
            pos.z = lerp(_VertaBuffer[frameIdx + 2], _VertaBuffer[nextFrameIdx + 2], prepareTimeFrac);
            normal.x = lerp(_VertaBuffer[frameIdx + 3], _VertaBuffer[nextFrameIdx + 3], prepareTimeFrac);
            normal.y = lerp(_VertaBuffer[frameIdx + 4], _VertaBuffer[nextFrameIdx + 4], prepareTimeFrac);
            normal.z = lerp(_VertaBuffer[frameIdx + 5], _VertaBuffer[nextFrameIdx + 5], prepareTimeFrac);
            tangent.x = lerp(_VertaBuffer[frameIdx + 6], _VertaBuffer[nextFrameIdx + 6], prepareTimeFrac);
            tangent.y = lerp(_VertaBuffer[frameIdx + 7], _VertaBuffer[nextFrameIdx + 7], prepareTimeFrac);
            tangent.z = lerp(_VertaBuffer[frameIdx + 8], _VertaBuffer[nextFrameIdx + 8], prepareTimeFrac);
          }
        }
      }
    }
}

#else

void animateWithVerta(uint vertexID, float time, float prepare_length, float working_length, inout float3 pos, inout float3 normal, inout float3 tangent) {
    return;
}


#endif

float3 calculateBinormal(float4 tangent, float3 normal ) {
    float sign = tangent.w * unity_WorldTransformParams.w;
    float3 binormal = cross(normal.xyz, tangent.xyz) * sign;
    return binormal;
}



/* What image is reflected in metallic surfaces and how reflective is it? */
float3 reflection(float perceptualRoughness, float3 metallic, float3 upDir, float3 viewDir, float3 worldNormal, out float reflectivity) {
    bool validUpDir = dot(upDir, upDir) > 0.01;
    bool upDirNotStraightUp = upDir.y < 0.9999;
    
    float3 rightDir = normalize(cross(upDir, float3(0, 1, 0)));
    rightDir = validUpDir && upDirNotStraightUp ? rightDir : float3(1, 0, 0);
    
    bool validRightDir = dot(rightDir, rightDir) > 0.01;
    
    float3 fwdDir = normalize(cross(rightDir, upDir));
    fwdDir = validUpDir && validRightDir ? fwdDir : float3(0, 0, 1);
    
    float3 reflectDir = reflect(-viewDir, worldNormal);
    
    float3 worldReflect;
    worldReflect.x = dot(reflectDir, -rightDir);
    worldReflect.y = dot(reflectDir, upDir);
    worldReflect.z = dot(reflectDir, -fwdDir);
    
    float lod = 10.0 * pow(perceptualRoughness, 0.4);
    float3 reflectColor = UNITY_SAMPLE_TEXCUBE_LOD(_Global_PGI, worldReflect, lod).xyz;
    float greyscaleReflectColor = dot(reflectColor, float3(0.29, 0.58, 0.13));
    reflectColor = lerp(reflectColor, greyscaleReflectColor.xxx, _PGI_Gray);
    
    float scaledMetallic = metallic * 0.7 + 0.3;
    float smoothness = 1.0 - perceptualRoughness;
    reflectivity = scaledMetallic * smoothness;
    
    return reflectColor * reflectivity;
}

float3 calculateSunlightColor(float3 sunlightColor, float upDotL, float3 sunsetColor0, float3 sunsetColor1, float3 sunsetColor2, float3 lightColorScreen) {
    sunlightColor = lerp(sunlightColor, float3(1,1,1), lightColorScreen);

    float3 sunsetColor = float3(1,1,1);
    if (upDotL <= 1) {
        sunsetColor0 = lerp(sunsetColor0, float3(1,1,1), lightColorScreen);
        sunsetColor1 = lerp(sunsetColor1, float3(1,1,1), lightColorScreen) * float3(1.25, 1.25, 1.25);
        sunsetColor2 = lerp(sunsetColor2, float3(1,1,1), lightColorScreen) * float3( 1.5,  1.5,  1.5);

        float3 blendDawn     = lerp(float3(0,0,0), sunsetColor2,  saturate( 5 * (upDotL + 0.3)));
        float3 blendSunrise  = lerp(sunsetColor2,  sunsetColor1,  saturate( 5 * (upDotL + 0.1)));
        float3 blendMorning  = lerp(sunsetColor1,  sunsetColor0,  saturate(10 * (upDotL - 0.1)));
        float3 blendDay      = lerp(sunsetColor0,  float3(1,1,1), saturate( 5 * (upDotL - 0.2)));

        sunsetColor = upDotL > -0.1 ? blendSunrise : blendDawn;
        sunsetColor = upDotL >  0.1 ? blendMorning : sunsetColor.xyz;
        sunsetColor = upDotL >  0.2 ? blendDay     : sunsetColor.xyz;
    }

    return sunsetColor.xyz * sunlightColor.xyz;
}

float3 calculateSunlightColor(float3 sunlightColor, float upDotL, float3 sunsetColor0, float3 sunsetColor1, float3 sunsetColor2) {
    return calculateSunlightColor(sunlightColor, upDotL, sunsetColor0, sunsetColor1, sunsetColor2, float3(0,0,0));
}

float3 calculateAmbientColor(float UpdotL, float3 ambientColor0, float3 ambientColor1, float3 ambientColor2) {
    //UpdotL: position of star in the sky, relative to the object.
    //1 is noon
    //0 is sunrise/sunset
    //-1 is midnight
    
    //starting when the star is below the horizon, lerp from ambient2 to ambient1 to ambient0 at noon, then back down again
    float3 ambientTwilight = lerp(ambientColor2, ambientColor1, saturate(UpdotL * 3.0 + 1)); //-33% to 0%
    float3 ambientLowSun = lerp(ambientColor1, ambientColor0, saturate(UpdotL * 3.0)); // 0% - 33%
    return UpdotL > 0 ? ambientLowSun : ambientTwilight;
}

float3 calculateAmbientColor(float3 upDir, float3 lightDir, float3 ambientColor0, float3 ambientColor1, float3 ambientColor2) {
    float UpdotL = dot(upDir, lightDir);
    return calculateAmbientColor(UpdotL, ambientColor0, ambientColor1, ambientColor2);
}

float4x4 quaternionToMatrix(float4 quat)
{
	float4x4 m = float4x4(float4(0, 0, 0, 0), float4(0, 0, 0, 0), float4(0, 0, 0, 0), float4(0, 0, 0, 0));
	float x = quat.x, y = quat.y, z = quat.z, w = quat.w;
	float x2 = x + x, y2 = y + y, z2 = z + z;
	float xx = x * x2, xy = x * y2, xz = x * z2;
	float yy = y * y2, yz = y * z2, zz = z * z2;
	float wx = w * x2, wy = w * y2, wz = w * z2;
    m[0][0] = 1.0 - (yy + zz);
    m[0][1] = xy - wz;
    m[0][2] = xz + wy;
    m[1][0] = xy + wz;
    m[1][1] = 1.0 - (xx + zz);
    m[1][2] = yz - wx;
    m[2][0] = xz - wy;
    m[2][1] = yz + wx;
    m[2][2] = 1.0 - (xx + yy);
    m[3][3] = 1.0;
	return m;
}

/*
int _Mono_Inst;
float3 _Mono_Pos;
float4 _Mono_Rot;

float _Mono_Anim_Time;
float _Mono_Anim_LP;
float _Mono_Anim_LW;
uint _Mono_Anim_State;
float _Mono_Anim_Power;

float _Mono_State;

float3 _Mono_Scl;

float _UseScale;

StructuredBuffer<uint> _IdBuffer;
StructuredBuffer<GPUOBJECT> _InstBuffer;
StructuredBuffer<AnimData> _AnimBuffer;
StructuredBuffer<float3> _ScaleBuffer;
StructuredBuffer<uint> _StateBuffer;

void LoadVFINSTWithMono(uint instanceID, uint vertexID, inout float3 vertex, inout float3 normal, inout float3 tangent, inout float3 upDir, inout float time, inout float prepare_length, inout float working_length, inout uint animState, inout float power, inout uint state)
{
    
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
        vertex *= scale;
        normal *= scale;
    }
    
    animateWithVerta(vertexID, time, prepare_length, working_length, vertex, normal, tangent);
    
    rot = normalize(rot);
    vertex = rotate_vector_fast(vertex.xyz, rot) + pos;
    normal = normalize(rotate_vector_fast(normal.xyz, rot));
    tangent = rotate_vector_fast(tangent.xyz, rot);
    
    upDir = normalize(pos);
}
*/