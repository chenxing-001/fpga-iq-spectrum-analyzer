# 200 MSPS IQ → 8192点FFT → UART → 电脑上位机

**修订23候选版：实部直接借位与高位双候选选择。算术模型检查通过；本轮未执行Verilog仿真、Quartus或板测，不能视为功能回归或200 MHz时序已通过。**

详细状态见`docs/REVISION_23.md`和`docs/revision23_validation.json`。

## 本轮结果

修订22实测Setup最差−0.253 ns，所列100条中63条违例；所列50条Hold无违例，最差+0.402 ns（仅Slow 1200mV 85C）。资源为8,821/10,320 LE（85%）、7,264寄存器、302,208存储位（71%）、44/46个9位乘法器（96%）。

本候选版只修改`rtl/r22_twiddle.v`：低11位直接减法提取借位，高12位并行寄存两个候选，下一拍选择。虚部保持原实现，流水级数未增加。设计预期分析延迟仍为57,460拍／287.300 μs，不含串口发送；本轮未实测RTL延迟。

整数算术检查通过4,194,304组低位操作数、33,554,432组高位/借位及1,048,576组全宽随机数。这是算术模型检查，不是RTL仿真。QPF/QSF/SDC、ROM和其他15个RTL文件与修订22一致，上位机仅改标题。

`b16`反馈和测试源的4条旧报告违例未做RTL修改，新拟合仍需关注它们。

## 先验证功能

需Icarus Verilog 11+以及numpy、matplotlib、pyserial。在工程根目录运行：

```bat
python scripts/check_revision23_arithmetic.py
python scripts/test_revision23.py
python scripts/run_tests.py --core-only
```

新增专项测试含冻结22旋转器/FFT逐拍对照，已附上但本轮未执行。完整历史回归入口为`python scripts/run_tests.py`。厂商RAM模型入口为`do scripts/run_vendor_revision23.do`，本轮也未执行。

## 硬件与编译

工程面向 **EP4CE10F17C8 / Quartus II 13.1**。板载50 MHz时钟经PLL产生200 MHz目标时钟。数据源是内部12位I/Q测试信号，无外部ADC接口。

解压到新的英文目录，打开`spectrum_streaming.qpf`完整编译，保持`rtl/`和`data/`结构。完成后在工程根目录运行：

```bat
quartus_sta -t scripts/report_timing.tcl
python scripts/collect_reports.py
```

输出`quartus_reports_rev23.zip`。时序脚本包含所有可用工况的Setup/Hold、Recovery/Removal、脉宽、时钟、未约束路径、约束检查和定向报告。Flow Summary的Successful不能代替时序通过。

独立多种子编译沿用`python scripts/close_timing.py --seeds 1,2,3,4,5,6,7,8`，或`scripts/build.bat`／`bash scripts/build.sh`。通过时使用相应种子目录的SOF和报告。本包不含已验证SOF/JIC。

## 功能与上位机

- 每拍一个12位I＋12位Q复数样点，8192点流式FFT。
- 内部信号循环：+25 MHz单音、+25/−12.5 MHz双音、突发单音、扫频。
- 统计主峰bin、近似半功率连通带宽、时域峰值、能量、活动点数、跨度、最长连续段及分析周期数。
- UART为115200、8-N-1、单向FPGA→PC，每包1330字节，包含CRC16。
- 上位机显示波形、频谱和统计，支持CSV／JSON导出。
- 默认刷新等待40,000,000拍，加上串口时间约每秒3次快照。FFT连续运行，UART发送选定快照，并不传送全部200 MSPS数据。
- 每包含前256点IQ及256列频谱；整帧统计使用8192点。突发模式前256点IQ为零属预期。

在带Tk的Python 3.10+环境中启动：

```bat
cd host
python -m pip install -r requirements.txt
python app.py
```

选择串口后连接115200。演示模式为`python app.py --demo`，由电脑合成数据，不代表板测。

| 端口 | 引脚 | 含义 |
|---|---|---|
| sys_clk | M2 | 50 MHz时钟 |
| sys_rst_n | M1 | 低有效复位 |
| uart_txd | M7 | 3.3 V UART发送 |
| led[0] | D11 | PLL锁定，低亮 |
| led[1] | C11 | UART忙，低亮 |
| led[2] | E10 | 快照就绪／发送中，低亮 |
| led[3] | F9 | 心跳 |

默认`UART_CLKS_PER_BIT=1736`、`REFRESH_CYCLES=40000000`。单音期望主峰bin=1024，带宽1 bin，活动点／跨度／最长段均8192。1 bin对应24.4140625 kHz离散分辨率。

## 文件导航

| 路径 | 内容 |
|---|---|
| rtl/、data/ | FPGA源码与ROM |
| host/ | 上位机、协议和启动脚本 |
| docs/REVISION_23.md | 本轮诊断、修改及验证边界 |
| docs/baseline_rev22/ | 用户时序报告、资源截图和汇总 |
| docs/revision23_arithmetic.log | 本轮实际执行的算术模型检查 |
| docs/revision23_source_checks.json | 源码范围与冻结参考检查 |
| docs/revision23_rtl.patch | RTL补丁 |
| scripts/test_revision23.py | 冻结22逐拍对照入口，本轮未执行 |
| docs/PROTOCOL.md | 串口协议 |

`SHA256SUMS.txt`覆盖本包文件。修订22及更早文档、日志是历史证据，不代表当前候选版通过相应测试。
