Shader "Custom/GlitchPostProcessIntegrated"
{
    Properties
    {
        //[Header(Basic)]
        //_MainTex ("Screen Texture", 2D) = "white" {}

        //[Header(Noise Textures)]
        //_NoiseTex ("Noise Tex", 2D) = "gray" {}
        //_Noise1Tex ("Distort Noise Tex", 2D) = "gray" {}
        //_Noise2Tex ("Glitch Noise Tex", 2D) = "gray" {}

        [Header(HSV Color)]
        _HueShift ("Hue Shift", Range(-1, 1)) = 0
        _SaturationShift ("Saturation Shift", Range(-1, 1)) = 0
        _ValueShift ("Value Shift", Range(-1, 1)) = 0

        [Header(Black White Style)]
        _MonoAmount ("Mono Amount", Range(0, 1)) = 0
        _MonoThreshold ("Mono Threshold", Range(0, 1)) = 0.5
        _MonoNoiseStrength ("Mono Noise Strength", Range(0, 2)) = 0.2

        [Header(Vignette)]
        _VignettePower ("Vignette Power", Range(0, 5)) = 2
        _VignetteStrength ("Vignette Strength", Range(0, 2)) = 0.5

        [Header(Distortion)]
        _DistortStrength ("Sine Distort Strength", Range(0, 0.2)) = 0.01
        _DistortFrequency ("Sine Distort Frequency", Range(0, 50)) = 10
        _DistortSpeed ("Sine Distort Speed", Range(0, 10)) = 0.5
        _NoiseDistortStrength ("Noise Distort Strength", Range(0, 0.2)) = 0.02
        _GlobalJitter ("Global Jitter", Range(0, 0.1)) = 0.02

        [Header(RGB Split)]
        _RGBSplit ("RGB Split Pixels", Range(0, 20)) = 2

        [Header(Glitch Blocks)]
        [Toggle(_GLITCH_BLOCK_ON)] _GlitchBlockOn ("Enable Glitch Blocks", Float) = 0
        _GlitchTileX ("Block Width (px)", Range(2, 200)) = 80
        _GlitchTileY ("Block Height (px)", Range(2, 200)) = 40
        _GlitchChance ("Block Chance", Range(0, 1)) = 0.35
        _GlitchSpeed ("Block Speed", Range(0, 30)) = 5
        _GlitchShift ("Block Shift", Range(0, 0.2)) = 0.02

        [HDR] _GlitchColorA ("Glitch Color A", Color) = (0.1, 1, 0.9, 1)
        [HDR] _GlitchColorB ("Glitch Color B", Color) = (1, 0.1, 0.6, 1)
        _GlitchColorVariation ("Glitch Color Variation", Range(0, 1)) = 0.2
        _GlitchBrightness ("Glitch Brightness", Range(0, 3)) = 1

        [Header(Color Adjust)]
        _ColorPow ("Color Pow", Range(0.2, 4)) = 1
        _ColorBoost ("Color Boost", Range(0, 4)) = 1

        [Header(Scanline Noise)]
        _ScanlineStrength ("Scanline Strength", Range(0, 1)) = 0.2
        _ScanlineDensity ("Scanline Density", Range(0, 2000)) = 800
        _NoiseStrength ("Noise Strength", Range(0, 1)) = 0.03
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Overlay" }
        Cull Off
        ZWrite Off
        ZTest Always
        Blend Off

        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment frag
            #pragma target 3.0
            #pragma shader_feature _ _GLITCH_BLOCK_ON
            #include "UnityCG.cginc"

            sampler2D _MainTex;
            float4 _MainTex_TexelSize;

            sampler2D _NoiseTex;
            float4 _NoiseTex_ST;

            sampler2D _Noise1Tex;
            float4 _Noise1Tex_ST;

            sampler2D _Noise2Tex;
            float4 _Noise2Tex_ST;

            float _HueShift;
            float _SaturationShift;
            float _ValueShift;

            float _MonoAmount;
            float _MonoThreshold;
            float _MonoNoiseStrength;

            float _VignettePower;
            float _VignetteStrength;

            float _DistortStrength;
            float _DistortFrequency;
            float _DistortSpeed;
            float _NoiseDistortStrength;
            float _GlobalJitter;

            float _RGBSplit;

            float _GlitchTileX;
            float _GlitchTileY;
            float _GlitchChance;
            float _GlitchSpeed;
            float _GlitchShift;

            float4 _GlitchColorA;
            float4 _GlitchColorB;
            float _GlitchColorVariation;
            float _GlitchBrightness;

            float _ColorPow;
            float _ColorBoost;

            float _ScanlineStrength;
            float _ScanlineDensity;
            float _NoiseStrength;

            float nrand(float2 st)
            {
                return frac(sin(dot(st, float2(12.9898, 78.233))) * 43758.5453);
            }

            float luma(float3 c)
            {
                return dot(c, float3(0.299, 0.587, 0.114));
            }

            float3 HSVToRGB(float3 c)
            {
                float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
                float3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
                return c.z * lerp(K.xxx, saturate(p - K.xxx), c.y);
            }

            float3 RGBToHSV(float3 c)
            {
                float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
                float4 p = lerp(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
                float4 q = lerp(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));
                float d = q.x - min(q.w, q.y);
                float e = 1.0e-10;
                return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
            }

            float4 frag(v2f_img i) : SV_Target
            {
                float2 uv = i.uv;
                float t = _Time.y;

                // ============ 1.基础扭曲：正弦+噪声 ============
                float wave = sin(uv.x * _DistortFrequency + t * _DistortSpeed) * _DistortStrength;

                float2 noiseUV = uv * _Noise1Tex_ST.xy + _Noise1Tex_ST.zw + t * 0.1;
                float2 n1 = tex2D(_Noise1Tex, noiseUV).rg * 2.0 - 1.0;

                uv += float2(wave, 0.0) + n1 * _NoiseDistortStrength;

                // ============ 2.全局水平抖动 ============
                uv.x += sin(floor(t * 5.0)) * _GlobalJitter;

                // ============ 3.故障方块 ============
                float2 sampleUV = uv;
                float blockOn = 0.0;
                float rBlock2 = 0.0;
                float lineOn = 0.0;

                #ifdef _GLITCH_BLOCK_ON
                    float2 tilePx = max(float2(_GlitchTileX, _GlitchTileY), float2(1.0, 1.0));
                    float2 grid = _ScreenParams.xy / tilePx;
                    float2 blockUV = floor(uv * grid);
                    float tick = floor(t * _GlitchSpeed);

                    float rBlock  = nrand(blockUV + tick * 0.37);
                    float rBlock2Raw = nrand(blockUV.yx + tick * 1.13 + 7.0);

                    float noise2 = tex2D(
                        _Noise2Tex,
                        uv * _Noise2Tex_ST.xy + _Noise2Tex_ST.zw + float2(t * 0.13, t * 0.17)
                    ).r;

                    float rBlockMix = rBlock * 0.75 + noise2 * 0.25;

                    float threshold = 1.0 - saturate(_GlitchChance);

                    // 硬边，方块保持硬块
                    blockOn = step(threshold, rBlockMix);
                    rBlock2 = rBlock2Raw;

                    //方块水平偏移
                    sampleUV.x += blockOn * (rBlock2 - 0.5) * _GlitchShift;

                    //行切片抖动
                    float lineRand = nrand(float2(floor(uv.y * grid.y), tick));
                    lineOn = step(threshold, lineRand);
                    sampleUV.x += lineOn * (lineRand - 0.5) * _GlitchShift * 0.5;
                #endif

                // ============ 4.RGB通道分离 ============
                float2 texel = _MainTex_TexelSize.xy;
                float splitPixels = _RGBSplit;

                #ifdef _GLITCH_BLOCK_ON
                    splitPixels *= (1.0 + blockOn);
                #endif

                float2 split = texel * splitPixels;

                float3 col;
                col.r = tex2D(_MainTex, sampleUV + split).r;
                col.g = tex2D(_MainTex, sampleUV).g;
                col.b = tex2D(_MainTex, sampleUV - split).b;

                // ============ 5.HSV调色 ============
                float3 hsv = RGBToHSV(col);
                hsv.x = frac(hsv.x + _HueShift);
                hsv.y = saturate(hsv.y + _SaturationShift);
                hsv.z = saturate(hsv.z + _ValueShift);
                col = HSVToRGB(hsv);

                // ============ 6.黑白风格化+噪点 ============
                float lum = luma(col);
                float mono = step(lum, _MonoThreshold);

                float noiseMono = tex2D(
                    _NoiseTex,
                    uv * _NoiseTex_ST.xy + _NoiseTex_ST.zw
                ).r;

                float3 monoColor = float3(mono, mono, mono) + noiseMono * _MonoNoiseStrength;
                col = lerp(col, monoColor, saturate(_MonoAmount));

                // ============ 7.颜色Pow/Boost============
                col = pow(saturate(col), _ColorPow) * _ColorBoost;

                // ============ 8.故障方块颜色覆盖============
                #ifdef _GLITCH_BLOCK_ON
                    float3 glitchColor = lerp(_GlitchColorA.rgb, _GlitchColorB.rgb, rBlock2);

                    float brightnessJitter =
                        1.0 + (nrand(float2(rBlock2, rBlock2 * 3.7) + t * 0.9) - 0.5)
                        * 2.0 * _GlitchColorVariation;

                    glitchColor *= _GlitchBrightness * brightnessJitter;

                    col = lerp(col, glitchColor, blockOn);
                #endif

                // ============ 9.扫描线+噪点 ============
                float scan = sin(uv.y * _ScanlineDensity + t * 20.0) * 0.5 + 0.5;
                col *= lerp(1.0, scan, _ScanlineStrength);

                float grain = tex2D(
                    _NoiseTex,
                    uv * _NoiseTex_ST.xy + _NoiseTex_ST.zw + float2(t, t)
                ).r;

                col += (grain - 0.5) * _NoiseStrength;

                // ============ 10.暗角 ============
                float dist = distance(uv, float2(0.5, 0.5));
                float vignette = 1.0 - pow(dist, _VignettePower) * _VignetteStrength;
                col *= saturate(vignette);

                return float4(saturate(col), 1.0);
            }
            ENDCG
        }
    }
    Fallback Off
}
