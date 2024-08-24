Shader "UI Ex/Production Stat Histogram REPLACE" {
    Properties {
        _Multiplier ("Multiplier", Float) = 1.55
        _ProductColor1 ("Product Color 1", Color) = (1,1,1,1)
        _ConsumeColor1 ("Consume Color 1", Color) = (1,1,1,1)
        _ZeroColor ("ZeroColor", Color) = (1,1,1,1)
        _MaxCount1 ("Max Count 1", Float) = 0
        _StencilComp ("Stencil Comparison", Float) = 8
        _Stencil ("Stencil ID", Float) = 0
        _StencilOp ("Stencil Operation", Float) = 0
        _StencilWriteMask ("Stencil Write Mask", Float) = 255
        _StencilReadMask ("Stencil Read Mask", Float) = 255
        _ColorMask ("Color Mask", Float) = 15
    }
    SubShader {
        Tags { "CanUseSpriteAtlas" = "true" "IGNOREPROJECTOR" = "true" "PreviewType" = "Plane" "QUEUE" = "Transparent" "RenderType" = "Transparent" }
        Pass {
            Tags { "CanUseSpriteAtlas" = "true" "IGNOREPROJECTOR" = "true" "PreviewType" = "Plane" "QUEUE" = "Transparent" "RenderType" = "Transparent" }
            Blend SrcAlpha One
            ColorMask [_ColorMask]
            ZWrite Off
            Cull Off
            ZTest [unity_GUIZTestMode]
            Stencil {
                Ref [_Stencil]
                ReadMask [_StencilReadMask]
                WriteMask [_StencilWriteMask]
                Comp [_StencilComp]
                Pass [_StencilOp]
            }
            
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0
            #pragma enable_d3d11_debug_symbols
            
            #include "UnityCG.cginc"

            #define Y_CENTER 0.495
            #define LEVEL_LENGTH 600

            struct appdata_min
            {
                float4 vertex : POSITION;
                float4 texcoord : TEXCOORD0;
            };
            
            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
            };
            
            struct fout
            {
                float4 sv_target : SV_Target0;
            };
            
            float _Multiplier;
            float4 _ProductColor1;
            float4 _ConsumeColor1;
            float4 _ZeroColor;
            float _MaxCount1;
            
            /*
             *_Buffer1 is a copy of the data in ProductData.count, selected by level (1min, 10min, etc), where production is the first 600 elements
             * and consumption is the last 600, ordered from oldest to most recent production/consumption amounts. ProductData.count stores each
             * time period divided over 600 samples, so if the 1 Hour time period is selected, each of the 600 elements shows production over 0.1 min.
             * 
             * note that the array sent to _Buffer1 is long[1200] array, but the shader uses uint[]. this appears to the shader as 2 array elements
             * per long (so it's uint[2400]), where all elements with an odd array index are 0. The odd indices are ignored, so if the time period
             * selected is 100 hours and a single item is being produced at a rate of over 429.5k/min, it'd max out the graph. (100hr = 6000min / 600
             * = 10min per sample. max uint size is 4,294,967,295 / 10min = 429.5k/min)
            */
            StructuredBuffer<uint> _Buffer1;

            v2f vert(appdata_min v)
            {
                v2f o;
                
                // Just placing the graph on the right place on the screen
                o.pos = UnityObjectToClipPos(v.vertex.xyz);
                
                // Pass along the coordinates of the graph.
                o.uv = v.texcoord.xy;
                
                return o;
            }
            
            fout frag(v2f i)
            {
                fout o;
                
                // Coordinates of the where the current pixel falls on the graph. (0,0) is bottom-left, (1,1) is top-right.
                float2 graphCoords = i.uv;
                
                float offsetFromYCenter = abs(graphCoords.y - Y_CENTER);
                
                //draw the x-axis line in the vertical center of the graph
                //the middle 0.5% (2 * 0.0025) of the graph is drawn as a line in the color _ZeroColor
                if (offsetFromYCenter < 0.0025) {
                    o.sv_target.xyzw = _ZeroColor;
                    return o;
                }
                
                //do not draw in the vertical margins on the top and bottom of the graph
                //top 1.25% is not drawn, bottom 0.25% is not drawn
                //why the top margin is larger than the bottom margin, I don't know
                //save this vertical offset as the full range that can be used by the graph
                float graphVertOffset = (offsetFromYCenter - 0.0025) / 0.49;
                if (graphVertOffset > 1)
                    discard;
                
                // based on where the horizontal position of this pixel, determine which sample it represents of the 600 possible.
                float sampleNumber = round(graphCoords.x * LEVEL_LENGTH - 0.5);
                
                //generate the background patterns for the graph, which includes and fine pattern every other sample and a coarse pattern every 10 samples
                //alternate 0 and 1 every other sample, adding 0.1 before saturating, resulting in 0.1 and 1 
                float bgPatternEveryOther = 2.0 * frac(0.5 * sampleNumber);
                bgPatternEveryOther = saturate(bgPatternEveryOther + 0.1);
                
                //alternate 0 and 1 every 10 samples, adding 0.8 before saturating, resulting in 0.8 and 1
                float bgPatternEveryTen = 2.0 * frac(0.5 * floor(sampleNumber / 60.0));
                bgPatternEveryTen = saturate(bgPatternEveryTen + 0.8);
                
                //combine the two patterns
                float bgPatterns = bgPatternEveryOther * bgPatternEveryTen;
                
                //if this pixel falls above the vertical center of the graph, we are drawing production. Otherwise, we're drawing consumption.
                bool drawingProduction = graphCoords.y > Y_CENTER;
                
                //select the color based on if we're drawing production or consumption
                float4 dataColor = drawingProduction ? _ProductColor1 : _ConsumeColor1;
                
                //production starts at index 0. consumption starts at index 1200.
                float baseIndex = drawingProduction ? 0 : 1200;
                // add the sample offset (times 2 since we're converting longs to uints)
                uint indexOffset = 2 * sampleNumber;
                uint index = baseIndex + indexOffset;
                //finally, grab the actual count produced/consumed from the buffer
                uint count = _Buffer1[index];
                
                //should draw as data if this pixel's position on the graph is within the vertical range of how much was actually produced/consumed
                float maxCount = _MaxCount1 > 0.001 ? _MaxCount1 : 1;
                float percentOfMax = count / maxCount;
                bool shouldDrawAsData = graphVertOffset < percentOfMax;
                
                //draw the data or the dimmed background patterns
                float brightness = shouldDrawAsData ? 1.0 : 0.15 * bgPatterns;
                
                //output the produce/consumed color, brightness determined by where this pixel falls on the graph, and the constant multiplier (1.52).
                o.sv_target.xyzw = dataColor * brightness * _Multiplier;
                
                return o;
            }
            ENDCG
        }
    }
}