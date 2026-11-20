# 技术美术 (TA) 作品集 - 渲染方向
> 耗时3个月的学习成果。包含光照模型、体积渲染、程序化生成、后处理等。

<div align="center">
  <img src="https://github.com/user-attachments/assets/8949735a-936b-4470-b694-cd5067f5de56" width="80%" />
</div>
<div align="center">
  <img src="https://github.com/user-attachments/assets/48f9cfd6-b910-4af4-bb42-1c904297c79b" width="80%" />
</div>
<div align="center">
  <img src="https://github.com/user-attachments/assets/eb07d4d6-d752-42f1-a9e6-6fdaf19983d4" width="90%" />
</div>
<div align="center">
  <img src="https://github.com/user-attachments/assets/0dbed41a-25ac-4bc0-840f-efd0b837c6a0" width="80%" />
</div>

[作品集展示]([https://b23.tv/3WDU13Z) 

---

## 核心项目导航

- [01. NPR 角色渲染 (NPR Rendering)](./NPR/NPR.md) - 三渲二、风格化光照、法线与切线描边
- [02. 全屏故障后处理 (Post Processing)](./Post_Processing/Post_Processing.md) - 全屏扭曲、RGB 分离、伪随机色块
- [03. PBR 枪械渲染 (PBR Weapon)](./PBR/PBR_Weapon.md) - Cook-Torrance、GGX、IBL、Split-Sum
- [04. 视差卡牌 (Parallax Card)](./Parallax_Card/Parallax_Card.md) - 切线空间、UV 偏移、双面渲染、排障复盘
- [05. 体积云 (Volumetric Cloud)](./volumetric_cloud/volumetric_cloud.md) - Raymarching、SDF、多重散射、Beer-Lambert
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
