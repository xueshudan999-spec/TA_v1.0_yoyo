基于PBR光照模型的枪械渲染与排障复盘
一、 核心实现逻辑
本项目基于PBR光照模型，实现枪械模型的高真实感渲染。核心Shader的光照计算遵循能量守恒定律，将计算解构为直接光照与间接光照两部分：
1. 直接光照
直接光由漫反射与镜面反射组成。采用BRDF微表面模型：
    F0（基础反射率）：由金属度插值计算得到。
    D项（法线分布函数）：使用GGX模型模拟微表面的高光分布。
    F项（菲涅尔方程）：使用Schlick近似，计算不同视角下的反射率。
    G项（几何遮蔽函数）：使用Smith GGX，计算微表面间的自遮蔽效应。

        // 光照物理常量准备
        float3 F0 = lerp(0.04, Basemap, Metallic);
        float3 F = F_FrenelSchlick(NV, F0);
        float D = D_GGXTR(N, H, Roughness);
        float G = G_GeometrySmith(N, V, L, Roughness);
        // 能量守恒分配（KS + KD = 1）
        float3 KS = F;                         // 镜面反射比例
        float3 KD = float3(1,1,1) - KS;
        KD *= 1 - Metallic;                    // 金属材质无漫反射

        float3 Diffuse = KD * Basemap;         // 漫反射项
        float3 DFG = D * F * G;                // 镜面反射分子
        float denominator = max(4 * NV * NL, Eplison); // 防止除零
        float3 Specular = DFG / denominator;
        float3 DirectLight = (Diffuse + Specular) * NL * _LightColor0.rgb;

2. 间接光照
    间接光基于IBL与球谐函数实现：
    间接漫反射：通过Unity内置的ShadeSH9 采样球谐函数，获取低频环境漫反射光照。
    工程注意：Unity底层烘焙的SH已经包含了(/PI)的操作，因此在计算时没有再次除以PI。
    间接镜面反射：采用Epic提出的Split-Sum近似法。
    通过粗糙度映射Mipmap层级，采样预过滤环境贴图。
    BRDF积分项则通过采样LUT或解析近似函数EnvBRDFApprox来模拟解析近似。

        float3 F_InDirectLight = FresnelSchlickRoughness(NV, F0, Roughness);
        float3 Ks = F_InDirectLight;  
        float3 Kd = float3(1,1,1) - Ks;  
        Kd *= 1 - Metallic;
        // 间接漫反射
        float3 InDirectSH = ShadeSH9(float4(N, 1));
        float3 InDirectDiffuse = InDirectSH * Basemap * Kd;
        // 间接镜面反射
        float3 R = reflect(-V, N);
        float mip = Roughness * (1.7 - 0.7 * Roughness) * UNITY_SPECCUBE_LOD_STEPS;
        float4 rgb_mip = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, R, mip);
        float3 EnvSpecularPrefilted = DecodeHDR(rgb_mip, unity_SpecCube0_HDR);
        #ifdef ENABLE_BRDF_LUT
            float2 env_brdf = tex2D(_BRDFLut, float2(lerp(0, 0.99, NV), lerp(0, 0.99, Roughness))).rg;
        #else
            float2 env_brdf = EnvBRDFApprox(Roughness, NV);
        #endif
        float3 InDirectSpecular = EnvSpecularPrefilted * (Ks * env_brdf.r + env_brdf.g);

二、 渲染异常排查与技术排障
在材质赋予模型后，遇到了模型整体呈现死黑且随视角变化产生局部死黑的严重渲染BUG。
1. 排查链路与根因分析
    a：检查Pass标签与宏定义
        检查"LightMode"="ForwardBase"是否声明。
        发现Shader缺少了前向渲染必要的编译指令与头文件，导致引擎未能正确传递主光源数据。
        补充#pragma multi_compile_fwdbase，并引入#include "Lighting.cginc"。
    b：检查贴图类型与法线空间
        排查发现法线贴图的Texture Type未设置为Normal Map。
    c：通过代码二分法验证光照分支
        在Fragment Shader中分别return DirectLight与return InDirectLight。
        发现return DirectLight时模型完全死黑，确认为直接光照未生效。
    根因定位：
    变量名拼写致命错误：获取主光颜色的变量误写为unity_LightColor0，正确应为_LightColor0.rgb。导致直接光强度为0。
    步骤d：检查间接光与球谐函数
        排查LightProbe空间与ShadeSH9的使用。
2. 验证结果
    经过上述修正，重新编译Shader，模型光照物理表现恢复正常。直接光带来的立体感与高光轮廓显现，间接光为暗部提供了正确的环境色彩反弹。

三、 视觉效果调优
光照跑通后，为提升最终画面质感，进行了以下后期与美术向的优化：
环境贴图（Skybox）替换：
问题：原天空盒（Skybox_Scan1）为灰白纯色，导致金属材质反射缺乏细节，且高光环境色单一。
解决：替换为带真实环境细节的HDR贴图，配合Directional Light调整太阳源。枪械表面立刻呈现出了丰富的环境反射细节。
ACES 色调映射（Tone Mapping）：
启用 ACES 色调映射，避免模型高光区域过曝死白，使色彩过渡更加符合物理真实的胶片感。

//注文档说明：
本次排障过程遵循控制变量法与二分法原则，从Shader宏定义 -> 贴图采样 -> 光照公式 -> 变量拼写，自底向上完成了全验证。