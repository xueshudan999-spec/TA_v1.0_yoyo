# 技术美术 (TA) 作品集 - 渲染方向
> 三个月独立手写完成。包含底层光照模型、体积渲染、程序化生成、后处理。

<!-- 【重要！】请在这里插入一张 3 张图横向拼接的效果图。你可以去仓库新建个 images 文件夹传上去，然后把路径贴在这里 --><img width="674" height="437" alt="屏幕截图 2026-11-04 155832" src="https://github.com/user-attachments/assets/3179ab40-c432-4b45-a43a-0b48c7681890" /><img width="641" height="361" alt="屏幕截图 2026-11-09 201639" src="https://github.com/user-attachments/assets/a5afe9d2-a80d-4ef3-a375-c2da433504af" /><img width="1181" height="660" alt="屏幕截图 2026-11-05 201315" src="https://github.com/user-attachments/assets/7daf0472-076c-4830-a0de-a17190d69346" />


[作品集展示](图片链接放这里.png) 

---

## 核心项目导航

- [01. NPR 角色渲染 (NPR Rendering)](./NPR/NPR.md) - 三渲二、风格化光照、法线与切线描边
- [02. 全屏故障后处理 (Post Processing)](./Post_Processing/Post_Processing.md) - 全屏扭曲、RGB 分离、伪随机色块
- [03. PBR 枪械渲染 (PBR Weapon)](./PBR/PBR_Weapon.md) - Cook-Torrance、GGX、IBL、Split-Sum
- [04. 视差卡牌 (Parallax Card)](./Parallax%20Card/Parallax%20Card.md) - 切线空间、UV 偏移、双面渲染、排障复盘
- [05. 体积云 (Volumetric Cloud)](./volumetric%20cloud/volumetric%20cloud.md) - Raymarching、SDF、多重散射、Beer-Lambert
- [06. 故障特效 (Glitch)](./Glitch/Glitch.md) - 顶点位移、时间分片控制、菲涅尔融合
- [07. 极光天空盒 (Skybox)](./Sky/Sky.md) - 纯程序化生成、FBM、域扭曲、零贴图

## 核心项目shader代码导航

- [01. NPR 角色渲染 (NPR Rendering)](./NPR/NPR.shader)
- [02. 全屏故障后处理 (Post Processing)](./Post_Processing/Post_Processing.shader)
- [03. PBR 枪械渲染 (PBR Weapon)](./PBR/PBR.shader)
- [04. 视差卡牌 (Parallax Card)](./Parallax%20Card/Parallax%20Card.shader)
- [05. 体积云 (Volumetric Cloud)](./volumetric%20cloud/volumetric%20cloud.shader)
- [06. 故障特效 (Glitch)](./Glitch/Glitch.shader)
- [07. 极光天空盒 (Skybox)](./Sky/Sky.shader)


---

##  关于我 & 工程规范

- **求职意向**：技术美术实习生 (渲染向) 
- **技术标签**：`HLSL` `Unity Built-in` `URP` `RenderDoc` `性能优化` `工程化排障`。
- **文档说明**：仓库内所有 `.md` 文件均为对应项目的技术说明。包含了详细的核心公式推导、排障复盘（如体积云边缘拉伸、PBR死黑排查）以及移动端降级方案。所有代码均经过严格测试与规范重写。

联系方式：
- 姓名：薛淑丹
- 邮箱：15110534406@163.com / xueshudan2024@qq.com
- 电话：15110534406
