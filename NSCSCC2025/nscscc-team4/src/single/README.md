# 单发六级流水线CPU设计

## 主要特性

- 工作频率：120-130MHz
- 六级流水线阶段：PIF, IF, ID, EX1, EX2, MEM

## 参考设计

- **TLB设计**：采用二级TLB架构，参考oringebird的[ServalCat](https://gitee.com/orangebird/serval_cat)
- **AXI**：直接使用openla500的[代码](https://gitee.com/loongson-edu/open-la500)
  
## 关于DIFFTEST

- 建议直接到[NEMU仓库](https://gitee.com/wwt_panache/la32r-nemu)自行编译tlb表项数16位的nemu
- 经过踩坑,强烈建议用22.04或者更高版本的ubuntu,低版本会有神秘错误

## 项目说明

本设计为初赛提交版本, 能够通过比赛初赛提供的功能测试的58个测试点, 95MHz频率下性能测试分为1.421,并成功启动linux,但是在25年的chiplab环境上板超过105MHz就会卡死在功能测试的0x30测试,原因不明,但是用24年的chiplab是正常的
分支预测后面做了很多更复杂的版本,但是在性能测试上无显著效果
