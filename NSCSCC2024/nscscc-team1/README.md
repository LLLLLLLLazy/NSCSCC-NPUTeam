# 2024NSCSCC-NPU1Team

#### 介绍

第八届全国大学生计算机系统能力培养大赛（龙芯杯）西北工业大学一队决赛参赛作品

#### 功能实现

- 在WSL2环境下(或同等虚拟机环境下)使用chiplab能在verilator仿真环境通过func、coremark测试,亦能启动该环境下的Linux系统,并且通过了该环境下数十万条随机指令的检测(tips:此环境下无法识别其他在vivado中添加的IP核,因而无法直接跑通；若有需求,请修改dcache中data_bank_ram和tagv_ram的实例化)

- 决赛参赛作品能实现稳定60MHz的上板跑分,通过u-boot上板启动Linux系统

#### 项目架构

```plaintext
2024NSCSCC-NPU1Team/
├── src/
│   ├── mycpu/
│   │   ├── mycpu_xilinx_ip/
│   │   │   ├── DATA_BANK_RAM/
│   │   │   ├── dcache_data_bank_ram/
│   │   │   └── TAGV_RAM/
│   │   ├── .v (all source code)
├── npu_1.pptx
└── README.md
```

#### 使用说明

- 下载[chiplab](https://gitee.com/loongson-edu/chiplab?_from=gitee_search)项目,在/fpga/nscscc-team中创建vivado项目环境

- 直接导入mycpu文件夹中所有文件

- 可以更换axi_ram中的coe文件进行功能验证；或者更改clk_pll中合适的cpu_clk综合、实现以及生成比特流文件上板

#### 参考
 - 本项目初期完整完成了[CPU设计实战：LoongArch版](https://bookdown.org/loongson/_book3/)中所有的实验,流水线之间的握手信号、译码等等均有参考

 - 除法模块、AXI转接桥均采用龙芯开源项目[openLA500](https://gitee.com/loongson-edu/open-la500)

 - 乘法模块采用[ServalCat](https://gitee.com/orangebird/serval_cat)项目中的实现方式,该项目在第七届龙芯杯团体赛决赛中频率达到145.45MHz,具有较高的参考价值