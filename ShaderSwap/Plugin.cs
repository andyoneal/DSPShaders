using System.IO;
using System.Reflection;
using BepInEx;
using BepInEx.Logging;
using HarmonyLib;
using UnityEngine;

namespace ShaderSwap
{
    [BepInPlugin(GUID, NAME, VERSION)]
    public class ShaderSwap : BaseUnityPlugin
    {
        public const string GUID = "com.andy.shaderswap";
        public const string NAME = "ShaderSwap";
        public const string VERSION = "1.0.0";
        
        private static readonly string AssemblyPath = Path.GetDirectoryName(Assembly.GetAssembly(typeof(ShaderSwap)).Location);
        private static AssetBundle bundle;
        
        public static ManualLogSource logger;
        
        private void Awake()
        {
            logger = Logger;
            logger.LogInfo($"{PluginInfo.PLUGIN_NAME} is loaded!");
            
            var path = Path.Combine(AssemblyPath, "dspshaders-bundle");
            bundle = AssetBundle.LoadFromFile(path);

            var loadedShaders = bundle.LoadAllAssets<Shader>();
            foreach (var s in loadedShaders)
            {
                var shaderToReplace = s.name.Replace(" REPLACE", "");
                SwapShaderPatches.AddSwapShaderMapping(shaderToReplace, s);
            }
            
            Harmony.CreateAndPatchAll(typeof(SwapShaderPatches));
        }
    }
}
