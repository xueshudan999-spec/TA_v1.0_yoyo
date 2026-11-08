基于Raymarching的实时体积云渲染技术文档
1. 项目概述
项目目标：基于Unity使用Shader实现一套实时的、支持动态变换的体积云/体积雾渲染方案。
技术栈：CG/HLSL、Raymarching、SDF、体积渲染积分、大气散射模型。
核心特性：
AABB包围盒求交：通过射线与包围盒求交，将计算限制在有效体积内，大幅提升性能。
SDF形状构建：利用球体和圆环SDF平滑组合出动态变化的云层基础形状。
3D噪声干扰：通过采样3D Noise贴图，打破平滑形状，生成云朵的边缘絮状细节。
高级光照模型：结合Beer-Lambert定律计算透射率，引入Henyey-Greenstein相函数模拟前向/后向散射，并实现了多重散射近似效果。

2. 核心渲染逻辑拆解
该Shader包含一个基础的Pass，在片元着色器中通过Raymarching算法模拟光线在介质中的传播。

2.1 基础形状构建
在map函数中，通过数学公式构建了基础的符号距离场：
使用SDSphere构建了两个在空间中随时间做正弦运动的小球。
使用sdTorus构建了一个圆环。
利用opSmoothUnion将球体与圆环进行平滑融合，产生类似“云团”的基础物理形状。

2.2 光线与包围盒求交
为了避免对屏幕上的每一个像素都进行无意义的Raymarching，首先利用intersectAABB函数计算视线与体积云所在的边界框的交点：
计算得到进入点tNear和离开点tFar。
优化点：只从射线进入包围盒的startPos开始步进，且最大步进距离限制为maxDistance = tFar - tNear。

2.3 体积密度计算
在Cloud函数中，计算当前采样点的云层密度：
读取_3DMeshTexture获得基础SDF形状。如果sdf > 0（在形状外部），则直接返回密度0。
采样3D噪声贴图_3DTex，利用frac和时间_Time.y实现流动感。
通过remap函数，将SDF值域根据噪声强度重新映射，得出最终的云层密度

2.4 体积光线步进与光照积分
这是整个Shader最耗性能也是最具含金量的部分，采用了从前向后的积分方式：
视线步进：主循环执行32次迭代。利用SDF的形状特性，currentStep = max(sdfDensity, step)实现了自适应步长，快速跳过无云区域。
光源步进：当当前采样点存在云层密度时，向光源方向发射射线，进行64次迭代，累加光源方向的密度。
光照计算：
透射率：使用exp(-intensity * step * _Scale)遵循Beer-Lambert定律，计算当前步进距离的局部透射率。
能量累积：FinalColor.rgb += (1.0 - localTransmittance) * CurrentColor * FinalColor.a; 累加当前步进吸收到的光照能量。
透明度衰减：FinalColor.a *= localTransmittance; 更新视线的整体透射率。

2.5 高级散射模型
HG 相函数：hg和HenyeyGreenstein函数用于计算光线在云层中的散射分布。通过lerp(hg(a, _G0), hg(a, _G1), _BackForwardLerp)实现了前向散射和后向散射的混合，让云层在逆光和顺光下有更真实的亮暗变化。
多重散射：multipleOctaves函数通过8次循环，每次都使用更小的衰减系数和权重，模拟光线在云层内部经过多次碰撞散射后透出的能量。这有效避免了云层阴影过死、缺乏通透感的问题。

3. 性能考量与优化建议
纹理采样：内层光源循环执行了 64 次，每次都会调用 Cloud 函数，意味着单像素最多会进行 32 * 64 = 2048 次 3D 纹理采样。
优化方向：使用蓝噪声进行抖动采样。