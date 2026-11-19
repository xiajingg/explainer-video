# explainer-video

把「图片 + 文案」批量变成带中文人声和字幕的讲解视频。适合公众号、视频号、课程这类「一张图讲一段」的内容。

一条命令出片，不需要剪辑软件、不需要 GPU、不需要 API Key。

## 效果

- 90 秒 1080p 成片约 3 MB，CPU 渲染 2~3 分钟
- Edge-TTS 免费配音（默认云希男声，可换晓晓等）
- 字幕来自 TTS 时间戳，不跑 Whisper、不下载模型
- 同一份文案可同时出 16:9、9:16、1:1

`sample/` 是一期完整示例（5 张幻灯片 + 412 字文案），装完可以直接跑。

![示例幻灯片](sample/16x9/01.png)

## 快速开始

```bash
git clone https://github.com/xiajingg/explainer-video.git
cd explainer-video
./setup.sh
```

`setup.sh` 会准备 Python 虚拟环境、下载 [MoneyPrinterTurbo](https://github.com/harry0703/MoneyPrinterTurbo) 源码、安装依赖、找系统中文字体。首次约 3~5 分钟。

然后建一期内容：

```bash
./scripts/new-episode.sh 我的第一期 "这一期的标题"
```

得到：

```
我的第一期/
├── 标题.txt        # 第一行 = 成片文件名前缀
├── 文案.txt        # 每行一段
├── 16x9/           # 横版图片
├── 9x16/           # 竖版图片
└── 成片/<比例>/<标题>-<比例>.mp4
```

放好图片、写完文案后渲染：

```bash
./render.sh 我的第一期          # 所有存在的比例
./render.sh 我的第一期 9x16     # 只出竖版
```

## 文案怎么写

- **每行一段，80~95 个汉字**，对应 15~20 秒配音
- **段落数 = 每个比例的图片数**，不等会提示错位
- 第一段是钩子、最后一段收束，不要小标题、不要 Markdown
- 用短句和句号制造停顿，不要用省略号、括号注释、表情符号
- 英文缩写尽量展开（TTS 会把 `ETF` 读成三个字母）

## 图片怎么做

- 分辨率和目标比例严格一致：1920×1080 / 1080×1920 / 1080×1080
- **底部 12% 留空**（字幕在距底约 6.5% 处）
- 1080p 下标题 ≥ 72px、正文 ≥ 32px
- 文件名按顺序：`01.png`、`02.png`……
- `sample/make_slides.py` 是生成示例幻灯片的脚本，可以照着改版式

## 为什么不用剪映「图文成片」

剪映会自动配素材，但用的是它自己的库；换成你的图要一张张替换，也没法批量、没法接脚本。这套的定位是「固定模板 + 批量生产」：文案和图片准备好，一条命令出片，版式改一次全部生效。

## 已知限制（重要）

- **不支持「第 N 段配第 N 张图」**。它按顺序把图片铺满音轨，脚本会按配音总时长均分每张停留时间；段落长短差异大时，中间会逐渐和旁白错位。段落写等长（80~95 字）基本能对上。
- 幻灯片不能开图片推拉：默认的 `zoom` 每秒放大 3%，18 秒会放大到 1.54 倍，边缘文字会被裁。脚本已固定 `static`。
- 转场必须硬切：`fade-in` 会在每次切图插入一帧全黑。脚本已固定 `none`。
- 版式是静态的：没有元素逐个出现、没有章节动画。需要这些请换 HyperFrames / Remotion 这类代码渲染方案。
- Edge-TTS 走微软公共接口，不保证长期可用；失效时换 Azure TTS（需要 Key）。

## 目录结构

```
explainer-video/
├── render.sh                 核心：解析期目录 → 配音 → 渲染 → 命名
├── setup.sh                  一次性安装
├── scripts/new-episode.sh    建期目录
├── sample/                   示例（可直接渲染）
└── MoneyPrinterTurbo/        setup.sh 下载，不入库
```

## 依赖与许可

- [MoneyPrinterTurbo](https://github.com/harry0703/MoneyPrinterTurbo)（MIT）：负责配音、字幕、合成。本仓库不包含其源码，由 `setup.sh` 下载。
- [Edge-TTS](https://github.com/rany2/edge-tts)（GPL-3.0）：免费中文配音。
- 本仓库代码：MIT。
