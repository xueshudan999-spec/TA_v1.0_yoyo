Shader "Skybox/sky"
{
    Properties
    {
        _TopColor("Top Color", color) = (0.00, 0.01, 0.05, 1)
        _BottomColor("Bottom Color", color) = (0.02, 0.04, 0.12, 1)
        
        [Header(Aurora Arc Settings)]
        _AuroraTop("Aurora Top Color", color) = (0.1, 1.0, 0.4, 1)
        _AuroraMid("Aurora Mid Color", color) = (0.2, 0.8, 0.9, 1)
        _AuroraBase("Aurora Base Color", color) = (0.6, 0.1, 0.9, 1)
        _AuroraIntensity("Aurora Intensity", range(0, 5)) = 2.5
        _AuroraSpeed("Aurora Flow Speed", range(0, 2)) = 0.5
        _AuroraHeight("Aurora Base Height", range(0, 1)) = 0.2
        
        [Header(Star Settings)]
        _StarDensity("Star Density", range(5, 100)) = 15
        _StarBrightness("Star Brightness", range(0, 10)) = 2.0
    }
    
    SubShader
    {
        Tags { "RenderType"="Background" "Queue"="Background" "PreviewType"="Skybox" }
        LOD 100

        Cull Off
        ZWrite On
        ZTest LEqual
        
        Pass
        {
            Name "Unlit"
            Tags { "LightMode"="ForwardBase" }
            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct MeshData
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };
            
            struct V2FData
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float4 posWS : TEXCOORD7;
            };

            float4 _TopColor;
            float4 _BottomColor;
            float4 _AuroraTop;
            float4 _AuroraMid;
            float4 _AuroraBase;
            float  _AuroraIntensity;
            float  _AuroraSpeed;
            float  _AuroraHeight;
            float  _StarDensity;
            float  _StarBrightness;

            float hash21(float2 p)
            {
                p = frac(p * float2(123.34, 456.21));
                p += dot(p, p + 45.32);
                return frac(p.x * p.y);
            }

            float noise2(float2 p)
            {
                float2 i = floor(p);
                float2 f = frac(p);
                float2 u = f * f * (3.0 - 2.0 * f);
                float a = hash21(i);
                float b = hash21(i + float2(1, 0));
                float c = hash21(i + float2(0, 1));
                float d = hash21(i + float2(1, 1));
                return lerp(lerp(a, b, u.x), lerp(c, d, u.x), u.y);
            }

            float fbm(float2 p)
            {
                float v = 0.0;
                float a = 0.5;
                float2x2 rot = float2x2(0.8, 0.6, -0.6, 0.8);
                [unroll]
                for (int i = 0; i < 5; i++)
                {
                    v += a * noise2(p);
                    p = mul(rot, p) * 2.02;
                    a *= 0.5;
                }
                return v;
            }

            float starLayer(float2 uv, float density, float time)
            {
                float2 gv = uv * density;
                float2 id = floor(gv);
                float2 f  = frac(gv) - 0.5;

                float rnd1 = hash21(id);
                float rnd2 = hash21(id + 17.1);
                float rnd3 = hash21(id + 33.7);

                float2 starPos = (float2(rnd1, rnd2) - 0.5) * 0.5;
                float  d = length(f - starPos);

                float mask = step(0.94, hash21(id + 5.0));
                float shape = exp(-d * 50.0) + exp(-d * 15.0) * 0.4;
                float brightness = pow(rnd3, 2.0); 
                float twinkle = 0.7 + 0.3 * sin(time * (1.0 + rnd1 * 3.0) + rnd2 * 6.283);

                return shape * mask * brightness * twinkle;
            }

            V2FData vert ( MeshData v )
            {
                V2FData o;
                o.uv = v.uv;
                o.posWS = mul(unity_ObjectToWorld, v.vertex);
                o.pos = UnityObjectToClipPos(v.vertex);
                return o;
            }
            
            float4 frag (V2FData i) : SV_Target
            {
                float3 V = normalize(i.posWS.xyz - _WorldSpaceCameraPos);
                float H = V.y; 
                
                // 球面坐标
                float2 suv = float2(atan2(V.z, V.x), asin(clamp(H, -1.0, 1.0)));
                float skyT = saturate(H * 0.5 + 0.5);
                float3 col = lerp(_BottomColor.rgb, _TopColor.rgb, skyT);
                float stars = 0.0f;
                stars += starLayer(suv, _StarDensity, _Time.y);
                stars += starLayer(suv, _StarDensity * 3.0, _Time.y) * 0.4;
                float starMask = smoothstep(-0.05, 0.1, H); 
                col += float3(0.9, 0.95, 1.0) * stars * starMask * _StarBrightness;

                float T = _Time.y * _AuroraSpeed;
                float2 q = float2(fbm(suv * 2.0 + float2(0, T * 0.1)), fbm(suv * 2.0 + float2(5.2, 1.3) + float2(T * 0.05, 0)));
                float2 r = float2(fbm(suv * 2.0 + 3.0 * q + float2(1.7, 9.2) + float2(T * 0.15, 0)), fbm(suv * 2.0 + 3.0 * q + float2(8.3, 2.8) + float2(0, T * 0.08)));
                float curve = _AuroraHeight + sin(suv.x * 2.0 + T * 0.5) * 0.15; 
                curve += fbm(suv * float2(2.5, 0.8) + T * 0.1) * 0.25;
                curve += (r.y - 0.5) * 0.4; 
                curve += (q.x - 0.5) * 0.2;
                float D = suv.y - curve;
                float curtainNoise = fbm(float2(suv.x * 15.0 + r.y * 2.0, suv.y * 1.5 - r.x * 2.0));
                float curtain = pow(saturate(curtainNoise * 1.8), 2.5);

                //极光带遮罩
                float bottomEdge = smoothstep(0.015, 0.0, D); 
                float fade = saturate(1.0 + D / 0.4); 
                float smoke = fbm(float2(suv.x * 4.0, suv.y * 4.0 + T));
                fade = pow(fade, 1.0 + smoke * 2.0);
                float bandShape = bottomEdge * fade * curtain;

                //动态颜色渐变
                float colorMix = saturate((-D) / 0.35); 
                float3 bandColor = _AuroraBase.rgb; 
                bandColor = lerp(bandColor, _AuroraMid.rgb, smoothstep(0.0, 0.5, colorMix)); 
                bandColor = lerp(bandColor, _AuroraTop.rgb, smoothstep(0.4, 1.0, colorMix)); 

                //叠加
                float pulse = 0.8 + 0.3 * r.x;
                col += bandColor * bandShape * _AuroraIntensity * pulse * 3.0;
                return float4(col, 1.0);
            }
            ENDCG
        }
    }
}
