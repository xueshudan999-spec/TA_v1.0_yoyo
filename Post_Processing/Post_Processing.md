赛博朋克故障风后处理技术文档
1. 项目概述
项目目标：基于Unity的一套故障风格后处理，用于营造赛博朋克、数据损坏或黑客入侵的视觉氛围。
技术栈：C#+Shader
效果特征：全屏正弦扭曲、随机噪点扭曲、RGB通道分离、动态故障色块、硬核黑白阈值化、CRT 扫描线与暗角。

2. 渲染管线与架构设计
2.1 C#脚本驱动
使用传统的OnRenderImage机制进行全屏抓取与处理。
[ExecuteInEditMode]：允许在编辑器非运行状态下实时预览调参，极大方便了美术与策划的调试。
[RequireComponent(typeof(Camera))]：确保脚本只能挂载在摄像机上，避免挂载错误。
Graphics.Blit：将抓取到的屏幕纹理（src）传入指定的材质并渲染至目标屏幕。

2.2 Shader 结构设计
采用单Pass高度集成的设计，所有的效果都在Fragment Shader中按顺序进行数学计算。
使用#pragma shader_feature _ _GLITCH_BLOCK_ON宏定义。当勾选“故障色块”时，才会编译相关代码，优化不需要该效果时的性能。
提供HDR颜色属性_GlitchColorA与_GlitchColorB，支持超过1.0的高亮色，以产生泛光效果。

3. 核心渲染算法拆解
Fragment Shader按照“空间扭曲 -> 颜色分离 -> 色彩调整 -> 屏幕叠加”的逻辑执行。主函数中提取了t = _Time.y 作为时间变量驱动动态效果。

3.1 基础扭曲
正弦扭曲：使用sin(uv.x*_DistortFrequency+t * _DistortSpeed) 生成横向的波浪状扭曲。
噪声扭曲：对_Noise1Tex进行UV滚动采样，将采样结果（映射至-1.0到1.0之间）叠加至UV上，产生不规则的画面涟漪。
全局抖动：利用floor(t * 5.0) 生成跳跃的时间步长，配合正弦函数，每隔一段时间对画面整体进行水平位移，模拟信号不稳的顿挫感。

3.2 故障切片与色块
这是效果的核心，结合了屏幕像素网格与伪随机数。
网格划分：利用_ScreenParams.xy/tilePx获取屏幕的区块数量，floor(uv * grid)获取当前像素所在的区块。
伪随机数 (nrand)：基于区块UV和时间tick生成伪随机值rBlock，结合_Noise2Tex滚动噪声，当该值大于阈值（1.0 - _GlitchChance）时，触发blockOn（值为 1）。
行切片抖动：对Y轴划分网格，产生随机行偏移lineOn，使得画面像老式电视一样横向撕裂。
色块覆盖：在blockOn为1的区域，使用lerp(_GlitchColorA, _GlitchColorB, rBlock2)进行颜色混合，并对亮度加入随机抖动，直接覆盖原画面，产生刺眼的故障色块。

3.3 RGB通道分离
在采样屏幕贴图_MainTex时，分别对R、G、B通道加上不同的UV偏移。
如果触发了故障色块，分离强度会动态翻倍splitPixels *= (1.0 + blockOn)，增强故障发生时的视觉冲击力。

3.4 颜色与风格化处理
HSV 调色：内置了RGBToHSV与HSVToRGB函数，独立调整色相、饱和度和明度）。
硬核黑白阈值：计算画面的Luma亮度，利用step(lum, _MonoThreshold)将其强制二值化为纯黑或纯白，并叠加噪声_MonoNoiseStrength。通过_MonoAmount与原画面插值，实现从彩色到美漫风格的平滑过渡。
颜色调整：通过pow提升对比度，_ColorBoost整体提亮。

3.5 屏幕叠加细节
扫描线：利用sin(uv.y * _ScanlineDensity + t * 20.0)生成高密度的波纹，乘以_ScanlineStrength叠加在画面上，模拟CRT显示器质感。
颗粒噪点：随时间滚动的UV采样_NoiseTex，以_NoiseStrength强度加噪。
暗角：计算当前UV距离屏幕中心(0.5, 0.5)的距离，通过pow计算半径衰减，使得画面四周变暗，聚焦中心。

4. 性能考量与优化建议
由于该Shader将所有功能集成在一个Pass中，且进行了多次纹理采样。
优点：算力集中，不像多个后处理脚本那样频繁调用Graphics.Blit导致显存带宽压力过大。

优化空间：
纹理采样：代码中采样 _MainTex(3次, RGB Split)、_NoiseTex(2次)、_Noise1Tex、_Noise2Tex，共计7次屏幕空间/纹理采样。后续可将_Noise1Tex与_Noise2Tex打包至同一张RGBA贴图的不同通道中。

5. 最终效果展示
详见视频链接

6. 局限性
多 Pass 屏幕抓取：在场景中存在多种后处理如 Bloom、Tone Mapping时，需要合理调整脚本挂载的执行顺序。