using System;
using System.Collections.Generic;
using HarmonyLib;
using UnityEngine;

namespace ShaderSwap;

public static class SwapShaderPatches
{
    private static readonly Dictionary<string, Shader> ReplaceShaderMap = new();

    [HarmonyPatch(typeof(VFPreload), nameof(VFPreload.SaveMaterial))]
    [HarmonyPrefix]
    public static bool VFPreload_SaveMaterial_Prefix(Material mat)
    {
        if (mat == null) return false;
        ReplaceShaderIfAvailable(mat);
        
        return true;
    }

    [HarmonyPatch(typeof(VFPreload), nameof(VFPreload.SaveMaterials), typeof(Material[]))]
    [HarmonyPrefix]
    public static bool VFPreload_SaveMaterials_Prefix(Material[] mats)
    {
        if (mats == null) return false;

        foreach (var mat in mats)
        {
            if (mat == null) continue;
            ReplaceShaderIfAvailable(mat);
        }

        return true;
    }

    [HarmonyPatch(typeof(VFPreload), nameof(VFPreload.SaveMaterials), typeof(Material[][]))]
    [HarmonyPrefix]
    public static bool VFPreload_SaveMaterials_Prefix(Material[][] mats)
    {
        if (mats == null) return false;

        foreach (var matarray in mats)
        {
            if (matarray == null) continue;
            foreach (var mat in matarray)
            {
                if (mat == null) continue;
                ReplaceShaderIfAvailable(mat);
            }
        }

        return true;
    }
    
    private static void ReplaceShaderIfAvailable(Material mat)
    {
        var oriShaderName = mat.shader.name;
        if (ReplaceShaderMap.TryGetValue(oriShaderName, out var replacementShader))
        {
            mat.shader = replacementShader;
            ShaderSwap.logger.LogInfo($"Replaced shader on {mat.name} with {replacementShader.name}");
        }
    }

    internal static void AddSwapShaderMapping(string oriShaderName, Shader replacementShader)
    {
        if (replacementShader == null)
            throw new ArgumentNullException(nameof(replacementShader));
        
        ReplaceShaderMap.Add(oriShaderName, replacementShader);
        ShaderSwap.logger.LogInfo($"Added Mapping. {oriShaderName} -> {replacementShader.name}");
        
    }
    
    [HarmonyPatch(typeof(Configs), nameof(Configs.Awake))]
    [HarmonyPostfix]
    public static void Configs_Awake(Configs __instance)
    {
        ComputeShader LODCulling = ShaderSwap.bundle.LoadAsset<ComputeShader>("LODCulling");
        if (LODCulling != null)
        {
            __instance.m_gpgpu.LODCullingShader = LODCulling;
            ShaderSwap.logger.LogInfo($"Replaced LODCulling compute shader");
        }
    }
}