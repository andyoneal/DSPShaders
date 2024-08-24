using System;
using System.Collections.Generic;
using System.Diagnostics;
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
        if (mat == null)
        {
            string callerInfo = GetCallerInfo();
            ShaderSwap.logger.LogError($"Material is null. Called from {callerInfo}");
        }
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

    [HarmonyPatch(typeof(UIProductEntry), nameof(UIProductEntry._OnCreate))]
    [HarmonyPostfix]
    public static void UIProductEntry_OnCreate(UIProductEntry __instance)
    {
        ReplaceShaderIfAvailable(__instance.statGraph.material);
    }
    
    private static string GetCallerInfo()
    {
        var stackTrace = new StackTrace(2, true); // Skip 2 frames to get the caller of YourFunction
        var frame = stackTrace.GetFrame(0);
        var method = frame.GetMethod();
        var fileName = frame.GetFileName();
        var lineNumber = frame.GetFileLineNumber();

        return $"{method.DeclaringType}.{method.Name} (File: {fileName}, Line: {lineNumber})";
    }
}