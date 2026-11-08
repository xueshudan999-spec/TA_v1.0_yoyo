基于视差映射的卡牌伪3D渲染与排障复盘
1. 项目概述
项目目标：为2D卡牌（如游戏内的卡牌UI或实体卡牌模型）制作的一套伪3D渲染Shader，支持视角转动时的立体层次感、动态流光边框以及卡牌背面的彩虹反光效果。
核心特性：
基于TBN空间与视角的视差映射。
利用VFace语义实现高效的双面（正/背面）差异化渲染。
基于菲涅尔与HSV色彩空间的背面彩虹镭射效果。
多层贴图及动态噪声的Alpha混合叠加。

2. 核心渲染逻辑拆解
2.1 伪3D视差效果
卡牌本身是一个平面的Quad，为了在转动视角时产生“立体”错觉，Shader内部自定义了CardIn、CardIn0和CardOut等函数进行视差计算：
获取世界空间下的法线、切线和副切线，构建TBN矩阵。
将视线向量V转换至切线空间，得到ViewTS。
结合预设的深度参数_Depth0、_Depth、_Depth2和视角夹角theta，计算出UV的偏移量。
对背景、主体、边框进行偏移采样，产生层次错位感。
        float4 CardIn0(in float Depth,in float2 uv,in float4 _Card_ST,in float3 ViewTS)
        {
                    uv=uv*_Card_ST.xy+_Card_ST.zw;
                    float3 n=float3(0,0,1);
                    float theta=saturate(dot(n,ViewTS));
                    float ViewTSLength=Depth/theta;
                    float3 startpos=float3(uv,0);
                    float3 endpos=startpos+ViewTSLength*ViewTS;
                    float4 CardMap=tex2D(_BK,saturate(endpos.xy));
                    return CardMap;
        }
    总结： float2 endUV=uv+ViewTS.xy/ViewTS.z*Depth;

2.2 双面与全息彩虹特效
背面判定：利用float backFace : VFace语义区分正反面。
全息反光（背面）：翻转法线N = -N，计算半角向量H，通过pow(nh, 500)提取极高光（模拟镭射亮斑）。结合 HsvToRgb函数与时间变量，叠加流光色彩，再乘以贴图亮度Luminance(backmap)作为遮罩，实现类似实体闪卡的全息反光效果。

2.3 多层动态叠加
正面渲染分为四层：外发光边框_Frame、主体边框_BK、卡牌主体_Card、背景层Card2。
通过提取各层的Alpha通道进行lerp混合：color=lerp(p2,p1,p1.a); color=lerp(color,frame,frame.a);
结合_Time.y的正弦函数，对边框施加周期性的呼吸发光效果pow(abs(sin( uv.y + _Time.y*0.6)),3)。

3. 渲染异常排查与技术排障
在初步完成视差映射逻辑后，测试转动卡牌视角时，发现了渲染穿帮问题。
3.1 核心问题：转动视角时背景层出现拉伸长条
现象描述：当摄像机以较大角度倾斜查看卡牌时，背景层Card2的边缘出现了明显的像素拉伸，形成一条条放射状的长条，严重破坏画面质感。
根因定位：
由于视差偏移计算使得UV向外扩张，采样到了图片的边缘。因为图片边缘存在非纯黑的有色像素，加上saturate的钳制作用，导致边缘像素被拉伸填满了整个偏移区域。
解决方案：
将原始卡牌素材的四周边缘区域填充为纯黑色。在视差偏移导致UV越界采样到边缘时，采到的也是纯黑色，不会在视觉上产生突兀的拉伸长条。

4. 视觉效果调优
排除穿帮问题后，进入了漫长的画面调优阶段，核心围绕亮度提取Luminance相关的材质表现展开：
图层融合遮罩调优：
代码中大量使用了Luminance()来判断图层分布
由于卡牌背景图明暗不均，直接使用会导致噪点（Noise）在亮部完全消失，在暗部又显得过脏。为此，反复推敲并调整了贴图的亮度分布，并微调了乘以NoiseHint和(1-Luminance(p2))的权重系数，最终让噪点只附着在暗部细节中，达到了满意的质感。

经过不断调参，发现将反向底图的Luminance作为乘法因子，能让暗部贴图的彩虹反光更微弱，亮部更耀眼，模拟出了极佳的金属箔片质感。

5. 局限性与未来优化方向
在实现效果的同时，也从工程与性能角度对该Shader进行了复盘：
采样次数过多：
目前视差计算中，CardIn0、CardIn、CardOut 分别对三张不同的贴图进行了独立采样，外加Noise贴图、RainbowMap 等，导致单个片元的纹理采样次数极高。

优化方案：若项目需要在手机端大量渲染此卡牌，应将主体、背景、边框三张灰度/色彩图打包到一张RGBA贴图的不同通道中。利用一次视差计算得出UV，进行一次tex2D采样后再进行通道分离。