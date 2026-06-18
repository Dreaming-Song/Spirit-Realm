# 美术资产策略

> 目标：用 AI + 网络资源快速产出 Q 萌国风素材，不卡美术瓶颈

## 🎨 风格定调

- **参考风格：** 洛克王国 Q 萌国风 + 低模卡通
- **角色比例：** 3-4头身，圆润可爱
- **色彩基调：** 青绿山水为主，红金点缀
- **模型精度：** 低模（<3000面），Godot 卡通渲染

## 🤖 AI 创作管线

### 模型生成（AI 3D）
| 工具 | 用途 | 说明 |
|------|------|------|
| **Meshy / Rodin** | 文字→3D模型 | 输入 prompt 直接生成低模，导出 glb |
| **TripoSR / Zero123** | 图片→3D模型 | 先 AI 出图，再转 3D |
| **Blender + AI 插件** | 模型精修 | 用 AI 辅助展UV、减面 |

> Prompt 示例：`A cute low-poly Chinese-style crane, 3D model, pastel colors, game-ready, <1000 polygons`

### 贴图生成（AI 2D → 模型贴图）
| 工具 | 用途 |
|------|------|
| **Stable Diffusion** (国风 LoRA) | 生成角色概念图、UI 图标、法术特效贴图 |
| **Midjourney** | 场景氛围图、色彩参考 |
| **Clipdrop / Stable Doodle** | 草图→成品贴图 |

### 推荐工作流
```
文字/草图 → AI生成模型(Meshy) → Blender减面/修型 → AI生成贴图 → 导入Godot
                              ↕
                      AI生成概念图(MJ/SD) → 风格统一参考
```

## 🌐 网络资源来源

| 类型 | 推荐来源 | 协议要求 |
|------|---------|---------|
| 免费3D模型 | Sketchfab (CC0/CC-BY)、OpenGameArt、Kenney.nl | 保留署名或选CC0 |
| 国风模型 | 爱给网、模之屋 (部分免费) | 注意商用限制 |
| 音效 | Freesound.org、Zapsplat | 选CC0或署名 |
| BGM | Pixabay Music、OpenGameArt | 选CC0 |
| 特效纹理 | Polyhaven (PBR)、2D特效包 | CC0为主 |
| UI图标 | Flaticon、Game-icons.net | 注意商用授权 |

## 📦 首批资产清单（Phase 1 可落地）

### 高优先 - AI 生成
- [ ] 仙侠角色（男/女各1，Q版3头身）
- [ ] 基础剑模型（御剑用）
- [ ] 丹炉
- [ ] 仙鹤（第一个灵宠）
- [ ] 树木（竹子×2、桃树×1、松树×1）
- [ ] 山石×3
- [ ] 草药发光模型
- [ ] 矿石模型

### 中优先 - 网络资源
- [ ] 草地/地面纹理（Polyhaven）
- [ ] 溪流/水面色调和材质
- [ ] 基础UI框架
- [ ] 背景音乐（轻快国风）
- [ ] 风/水流/鸟鸣环境音

## ⚠️ 注意事项
1. AI 生成模型需手动减面优化（Godot 移动端也跑得动）
2. 网络资源务必检查授权协议，标注来源
3. 先出 MVP 再精细，第一阶段用 placeholder 也不怕
