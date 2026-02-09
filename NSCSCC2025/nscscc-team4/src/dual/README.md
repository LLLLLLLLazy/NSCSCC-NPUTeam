# 双发八级流水线CPU设计

## 主要特性

- 工作频率:90MHz
- 八级流水线阶段:PIF, IF, ID, FIFO, IS, EX1, EX2, MEM

## 参考设计

- **TLB设计**:采用二级TLB架构,参考oringebird的[ServalCat](https://gitee.com/orangebird/serval_cat)
- **AXI**:直接使用openla500的[代码](https://gitee.com/loongson-edu/open-la500)
- **乘除法器**:参考openla500
- **分支预测**:参考openla500,预测率有非常显著的提升

## 关于头文件header

- **DEBUG宏**:用于代码调试,打开会在最后加一个CM流水级用于顺序输出,vivado仿真只需要打开DEBUG
- **TLB表项数修改**:修改TLB_NUM, WIDTH_TLB_INDEX为对应的数,(2,1)到(32,5)都是可行的,但是小于16项在DIFFTEST会爆神秘错误
  
## 关于DIFFTEST

- 一般打开DEBUG,保留下面的DIFFTEST_DEBUG
- 使用前记得改tlb表项到(32,5),或者替换nemu,可以到[NEMU仓库](https://gitee.com/wwt_panache/la32r-nemu)自行编译tlb表项数16位的nemu
- 关闭DEBUG,打开undef DIFFTEST_EN可以更快跑完linux测试(为了减少工作量在DIFFTEST中取消了前递),但是不能检测错误
- 经过踩坑,强烈建议用22.04或者更高版本的ubuntu,低版本会有神秘错误
- 双发跑的时间很长,尽量用性能强的电脑跑.注意,ARM架构的macbook可以用虚拟机跑DIFFTEST,toolchain里可以找到对应的工具链和22.04版本的QEMU,NEMU可以自己在虚拟机编译出来

## 项目说明

本设计基于初赛的单发修改得出,在chiplab的614c047及之前的版本均可以正常运行并上板
代码结构我们参考了[nscscc-2024-team](https://gitee.com/differential1012/nscscc-2024-team),能够通过比赛初赛提供的功能测试的58个测试点,性能测试分数为2.159,并正常启动 Linux 操作系统
关于性能计数,可查看[原仓库](https://gitee.com/yan098/cpu-grass)cache_stall分支,可以查看性能计数的结果
后面还做了一些优化,可以达到更高频率,参考[原仓库](https://gitee.com/yan098/cpu-grass)save_perf分支.但是在构建新的流水级之后出现95MHz上板不稳定的情况

## 展望未来

希望早日搓出乱序多发+NPUSoC+NPULinux(参考强校的CPU设计),不要出现最后几天手动编译Linux+手动魔改soc发现不会搞搞不通的情况🤓
