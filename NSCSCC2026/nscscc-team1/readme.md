# **西北工业大学一队(不会计组😡😠🤬😤)参赛作品**

## **项目简介**

**提供三个版本的cpu设计**

- 七级流水线，原仓库地址[七级流水线](https://gitee.com/unlastingstar/cpu-design)，请看main分支的cpu-design\7_stage_pipeline文件夹
- 单发射乱序，原仓库地址同上，cpu-design\ooo_single_issue文件夹
- 乱序四发射，原仓库地址[乱序四发射](https://gitee.com/unlastingstar/superscalar-cpu-for-loongarch)，请看main分支

**BDOT.W是今年团队赛的题目**

## **如果您有问题，欢迎与我们沟通！**

 QQ：3040098721 zhujian（添加请备注龙芯杯参赛）

## 开源设计

### 浙大

大家好，我们是浙江大学「脑烧超算冲刺」队，我们在 NSCSCC 2026 的参赛作品 Gemmont 现已于 GitHub 开源，包括核心 Gemmont，报告与答辩幻灯片，chiplab SoC，linux，rootfs，go，picoclaw 等多个仓库。希望大家来瞧一瞧看一看，点点 star，传播宣传，非常感谢各位！![img](file:///[崇拜])![img](file:///[崇拜])

欢迎查看我们的 slides：https://github.com/SuperscalarCrash/report/blob/main/build/slides.pdf
主仓库：https://github.com/SuperscalarCrash/Gemmont

Gemmont 是一款 32 位龙架构精简版（LoongArch32 Reduced / LA32R）乱序超标量处理器核心，采用基于 Tomasulo 算法与重排序缓存（ROB）的乱序多发射微架构，包括 5 条执行流水线，4 取指、3 译码、3 提交，最长 13 级流水线。相较往届作品，我们在微架构上的主要创新为引入了 AI 分支预测器、64 KiB 统一 L2 缓存、L1 预取器等。 性能方面，我们最终主频达到 109.09 MHz，在所有乱序核中排名第一；周期数相对 openLA500 基线几何平均加速 1.975x，总加速 6.583x；最终成绩在所有参赛队伍中排名 4/549。 系统展示方面，为替换大赛提供的 Linux 5.14.0-rc2 陈旧内核与 GCC 8 等工具链，我们将最新 Linux 7.1.4 主线内核、最新 GCC 16、glibc 2.44 与 Go 语言移植至 LA32R 指令集。我们使用 Buildroot 构建包含 SSH、X 桌面、PicoClaw 等应用软件的嵌入式 Linux 发行版，并通过 NFS root 启动。另外，我们在微架构上设置 DP4 点积扩展指令，在端侧实现了 10 s/token 的大模型推理。Gemmont 可以稳定启动 Linux 并运行发行版中所有软件，同时驱动板上包括全速 USB 在内的全部外设。

### 中科大

大家好，中国科学技术大学也西湖队参赛作品 YeXiHuCore 现已开源。为了增加其开源价值，我们在公开 chisel 源码的基础上，附上了详细的设计文档和设计过程中留下的思考和决策。详见 https://github.com/YeXiHuTeam/YeXiHuCore/

### 武汉大学

开源一下我做的核：https://github.com/guyuyv/NSCSCC_2026 单发射顺序六级流水，个人赛二等奖。第一次参赛，还有很多不足，不过也有一些自己的尝试，仅供参考，欢迎交流～![img](appimg://D:/QQ%E6%96%87%E4%BB%B6/Tencent%20Files/3040098721/nt_qq/nt_data/Emoji/BaseEmojiSyastems/EmojiSystermResource/318/apng/318.png)
