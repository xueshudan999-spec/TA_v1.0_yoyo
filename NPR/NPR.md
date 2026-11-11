《罪恶装备》风格 NPR 角色渲染
1. 项目概述
项目目标：参考《罪恶装备》系列的标志性三渲二风格，基于Unity管线的NPR角色着色器。
资源来源：美术资产（_BaseMap、_ShadowMap、_LightMap 等）均通过RenderDoc对目标游戏进行截帧提取。
涉及范围：当前文档展示的Shader代码主要应用于角色身体部分（包含服饰、护具等），头部渲染逻辑与此类似，故未重复展示。
性能考量：由于资产来源于截帧，本项目重点在于还原视觉效果与材质表达，暂未针对性能优化方面的解决方案。

2. 资产与通道分析
基于RenderDoc截帧资源，分析出了一套高度自定义的通道拆分方案。结合顶点色与贴图通道，实现了一套Shader跑通全身材质。
_BaseMap：RGB基础颜色填充，控制角色固有色彩。
_BaseMap.a：身体表面的层次纹理/黑色阴影（BodyMask）。
_ShadowMap.a：材质分层遮罩LayerMask.a>0.1判定为深色布料/皮革,代码中利用该通道进行特殊边缘光的叠加。
_LightMap.r：金属判定_LightMap.r>0.4视为金属材质。
RampOffsetMask：_LightMap.g*2-1，用于偏移明暗交界线的位置。
_LightMap.b：高光遮罩 (SpecularIntensityMask)，控制高光区域强度。
_LightMap.a：内勾线 (InnerLineMask)，用于表现模型内部的硬边缘线条。
_LineMap：RGB战损线条纹理，用于叠加脏迹和磨损。
_DecalMap：RGB贴花纹理，用于叠加额外的图案细节。
VertexColor.r：常暗纹理线条 (ShadowAOMask)，控制基础阴影，同时用作内勾线遮罩。
VertexColor.a：描边粗细控制，同时参与区分身体亮/暗部的计算。

3. 核心渲染逻辑拆解
Shader采用了两个Pass：基础光照与材质表现和背面描边。
核心理念是不拆分材质球，通过通道值在一个Shader内进行材质区分。

3.1 光照模型与阴影分级
未使用Unity内置的标准光照，而是手写了一套基于Half-Lambert的阶梯式卡通阴影：
基础漫反射：计算N·L得到半兰伯特值HalfLambert。
阴影阈值与渐变：结合_LightThreshold、_RampOffSet及_LightMap.g 通道，利用smoothstep函数生成明暗交界的阈值，并与顶点色R通道的AO相乘，形成硬边缘阴影。
暗部处理：通过_DarkSideThreshold和_dark参数，使用lerp将BaseMap与BaseMap*ShadowMap进行混合，生成暗部颜色，还原了赛璐璐风格中暗部色彩的特点。

3.2 材质区分与高光表现
核心理念：通过LightMap和ShadowMap的通道值在Shader内进行if分支判断，实现多材质表现。
基础高光：利用_NHWidth控制N·H阈值，生成卡通高光。
边缘光：基于N·V (法线点乘视线) 计算菲涅尔，结合_RimColor、_FresnelIntensity和_FresnelPow控制边缘发光，并与阴影阈值（1.0 - Threshold）相乘，保证暗部边缘光的逻辑正确（罪恶装备游戏的风格）。
金属材质表现：当_LightMap.r>0.4时，叠加基于_Metallicwidth和_MetallicIntensity的视角高光，模拟金属反射质感。
布料/皮革特殊边缘光：当LayerMask (shadowmap.a)>0.1时（深色布料区域），通过basemap=basemap*basemap.a 压暗布料固有色，并叠加一层基于_ComWidth和_ComIntensity的comFresnelMask边缘光，最后用max(0, specular) 防止减法出现负色。

3.3 描边算法
本方案采用了基于屏幕空间的等宽外扩：
背面剔除：Cull Front，仅渲染背面。同时读取法线与切线。
视空间外扩：将法线与切线变换至观察空间，并投影到屏幕XY平面。
解决了斜视视角描边变细或断开的问题。
粗细控制：利用v.vertexColor.a控制局部外扩力度。

4. 开发过程中的问题与反思
在初步还原效果后，进行了排查与优化：
明确点：“卡通渲染的核心在于材质的表达（布料、皮肤、头发、金属等），且应尽量在同一个材质球内通过通道（如亮度值）进行区分”。
方案：严格按照RenderDoc截帧资源，将材质区分逻辑（如_LightMap.r>0.4判金属_ShadowMap.a>0.1判布料），统一使用一套Shader渲染。
结果：实现阴影色阶彻底统一，达到了整体一致性。

初期描边算法选择（法线和切线）
现象：测试初仅使用切线方向外扩，导致身体主体完全没有轮廓，但衣领等部位却有。
原因：切线平行于表面，无法让模型“膨胀”；法线垂直表面，才是外扩的基础。
解决方案：采用法线主导产生基础轮廓 + 切线辅助补偿的双向叠加方案，解决了单用切线导致的局部缺失问题。

视角旋转导致的描边断裂
原因：模型空间外扩的偏移量是固定的，经透视投影后，斜视角度下外扩方向与视线垂直，导致屏幕投影宽度变窄。
解决方案：采用基于屏幕空间的等宽外扩，解决了因视角旋转导致描边断裂的问题。

5. 最终效果展示
详见视频链接。

6. 局限性与未来优化方向
    a. 资源限制：基于RenderDoc截帧，贴图未做最优化的通道合并（如将LightMap与ShadowMap的灰度图打包到同一张RGBA中），后续若用于实际项目，可大幅缩减Draw Call。
    b. 法线平滑：描边在极度锐利的边缘仍可能存在少量断线，后续可考虑引入平滑法线（Smooth Normal）烘焙贴图。
