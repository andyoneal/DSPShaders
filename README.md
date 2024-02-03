# DSP Shaders

A collection of random shaders that I've reverse engineered. Sometimes for use in a mod, but mostly for fun. You can find the finished ones in the `unity/Assets/Shaders` directory and the unfinished/semi-functional ones in WIP. 

You can package them into an asset bundle by opening the unity directory in Unity Editor 2018.4.12f, including or excluding by selecting each shader and using the dropdown at the very bottom right of the screen, and building an asset bundle by going to Window > DSP Tools > Build Asset Bundles > Compressed. In a few seconds, `dspshaders-bundle` will appear in `/Assets/StreamingAssets/AssetBundles/`.

Also included a super simple bepinex mod that will load all shaders out of the bundle and swap them out with vanilla shaders that match their name with "REPLACE" at the end. When you run DSP with the mod and it looks like nothing happened, that means I recreated all of the shaders perfectly. More likely, you'll see some graphics glitches and know where I still have some work to.

For example, water/oceans on planets is currently pretty bad. Planet terrain looks a little off too.

<img width="700" alt="vff-water-shader-glitchy" src="https://github.com/andyoneal/DSPShaders/assets/2807932/4f7ec138-d3ef-4146-9483-8b441d863ae4">

Metal and Stone Veins look pretty good.

<img width="700" alt="metal-vein-shader" src="https://github.com/andyoneal/DSPShaders/assets/2807932/68e87b49-9848-46ab-b94f-4dd04fe67d80">
<img width="700" alt="stone-vein-shader" src="https://github.com/andyoneal/DSPShaders/assets/2807932/e49b78f9-bfc9-406e-8086-099af70fc5bb">

Crystal Veins still need some work

<img width="526" alt="crystal-vein-shader" src="https://github.com/andyoneal/DSPShaders/assets/2807932/886a5fa3-99f0-43fe-a194-be417c6ec1ff">

Cargo Containers look right, but belts look terrible.

<img width="700" alt="cargo-shader" src="https://github.com/andyoneal/DSPShaders/assets/2807932/6c397614-e04f-4b82-bea9-4bfc5d3bcf2a">
<img width="700" alt="belt-shader" src="https://github.com/andyoneal/DSPShaders/assets/2807932/fd289e95-e4bd-4627-b026-8bf2435b1d7f">
