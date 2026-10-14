# 修订23候选版：实部直接借位与高位双候选选择

日期：2026-10-12。基于本轮上传的修订22工程、Setup/Hold文本和Flow Summary截图。

**候选版：算术模型检查通过；没有执行Verilog仿真、Quartus综合/拟合、厂商IP仿真或板测。不能宣称功能回归通过或200 MHz时序收敛。**

## 修订22实际结果

| 项目 | 修订21历史记录 | 本轮修订22报告/截图 |
|---|---:|---:|
| 最差Setup | −0.114 ns | **−0.253 ns** |
| 所列Setup违例 | 100条中2条 | **100条中63条** |
| 所列Hold最差裕量 | +0.383 ns | **+0.402 ns** |
| 所列Hold违例 | 50条中0条 | 50条中0条 |
| 逻辑单元 | 8,611 / 10,320（83%） | **8,821 / 10,320（85%）** |
| 寄存器 | 7,226 | 7,264 |
| 存储位 | 302,208 / 423,936 | 302,208 / 423,936（71%） |
| 9位乘法器 | 44 / 46 | 44 / 46（96%） |

Setup退步0.139 ns，LE增加210。Flow Summary的Successful仅表示编译流程完成。两份文本均为Slow 1200mV 85C Model，不能证明Fast工况Hold及其他检查通过。

| 修订22违例分组 | 所列记录数 | 最差裕量 | 本轮处理 |
|---|---:|---:|---|
| `t8` → `real_carry6` | 37 | −0.253 ns | 直接低位减法提取借位 |
| `t14` → `real_carry6` | 21 | −0.156 ns | 同一共享模块修改 |
| `t17` → `yr[11]` | 1 | −0.079 ns | 高位双候选寄存，下一拍选择 |
| `b16` → 反馈存储 | 2 | −0.116 ns | RTL未改，增加定向输入报告 |
| 测试源 → `phase/phase2` | 2 | −0.079 ns | RTL未改，增加包含所有起点的报告 |

这些路径记录包含不同跳变条件，不能等同于63个独立逻辑问题。原始报告、截图和统计见`baseline_rev22/`。报告未附与拟合结果绑定的源码哈希，工程与报告的对应关系依据用户提供的版本名称。

## 修订22的瓶颈

最差路径为`t8|p1[0]`→`t8|real_carry6`，Data Delay 5.298 ns，13级逻辑。详细路径先经过`Add2`进位链，再经过`real_carry6`进位链，两者之间有0.541 ns连线。对应源码：

```verilog
{1'b0,p1[10:0]} + {1'b0,~p2[10:0]} + 12'd1
```

该三项表达式在这次拟合中形成串接运算，仅从源码看到“11/12位分段”不足以确认硬件是单段短进位链。

`t17|real_carry6`→`t17|yr[11]`另有−0.079 ns违例：Data Delay 4.505 ns、5级逻辑，Clock Skew −0.575 ns。它经过前缀进位修正及轴向选择，所以进位寄存器后的输出路径也需要处理。


## 唯一RTL修改

只修改`rtl/r22_twiddle.v`，六个旋转器实例共用。实部低11位直接零扩展减法，最高位是借位。原第7级同时寄存高12位的两个候选，原第8级根据借位选择：

```verilog
wire [11:0] real_low_diff = {1'b0,p1[10:0]} - {1'b0,p2[10:0]};
// 原第7级
real_hi6        <= p1[22:11] - p2[22:11];
real_hi_borrow6 <= p1[22:11] + (~p2[22:11]);
real_borrow6    <= real_low_diff[11];
// 原第8级
yr <= ep[5] ? er6 : (real_borrow6 ? real_hi_borrow6 : real_hi6);
```

`H0=Ahi-Bhi`，`H1=Ahi+~Bhi=Ahi-Bhi-1 mod 4096`。低位借位不参与高位候选的组合计算；实部输出也不再调用`add_carry12`。虚部保留修订22实现。实际能否按预期映射及改善时序尚未验证。

数学关系是`floor((A-B)/2048) mod 4096 = (Ahi-Bhi-borrow) mod 4096`，保持原负数右移、结果位[22:11]及12位回绕规则。

没有新增流水级，也没有改valid、计数器、轴向标志或旁路对齐。设计预期仍为每拍一个复数样点、默认分析延迟57,460拍（200 MHz下287.300 μs，不含UART传输）；**该延迟本轮未在RTL仿真中重新测量**。

每个旋转器增加一个12位候选寄存器，六个实例RTL层面共增加72位状态，并移除实部前缀修正逻辑。实际LE/寄存器变化未知，85%资源基线下必须检查新Fitter结果。

QPF、QSF、SDC、ROM及其他15个RTL文件与上传修订22逐字节一致。上位机只将标题改为Revision 23；UART协议、PLL和引脚沿用原工程。

## 本轮检查

| 检查 | 结果及边界 |
|---|---|
| 全部低11位操作数组合 | 4,194,304组通过；借位对照独立无符号大小比较 |
| 全部高12位操作数及两种借位 | 33,554,432组通过；对照完整减法后右移和截断 |
| 全宽有符号26位随机数 | 1,048,576组通过，固定种子2300123 |
| 源码范围与冻结参考 | 通过；唯一RTL变化为旋转器，冻结22参考仅重命名模块 |
| Python语法 | 通过；数量详见revision23_source_checks.json |
| Verilog编译、逐拍回归、整机串口 | **未执行**；缺少iverilog/vvp，可用依赖源也未提供所尝试的验证工具 |
| Quartus、厂商IP和板测 | **未执行** |

Python整数检查不是RTL仿真。它验证分组算术关系，不能证明Verilog编译、流水控制、复位、UART或物理时序。旧revision22及更早的PASS日志仅属历史，不代表修订23通过。

本轮证据为`revision23_arithmetic.log/json`、`revision23_rtl_preflight.log`、`revision23_source_checks.json`、`revision23_rtl.patch`及`revision23_validation.json`。

## 下一步验证

在装有Icarus Verilog 11+及Python依赖的环境运行：

```bat
python scripts/check_revision23_arithmetic.py
python scripts/test_revision23.py
python scripts/run_tests.py --core-only
```

新增专项对照冻结修订22和独立模型，覆盖六种旋转因子长度、连续输入、空拍、处理中复位、完整FFT数据/frame/bin逐拍关系。测试已附上，**本轮未执行**。完整历史回归入口为`python scripts/run_tests.py`；厂商RAM模型入口为`do scripts/run_vendor_revision23.do`，也未执行。

在新的英文目录打开`spectrum_streaming.qpf`完整编译，再运行：

```bat
quartus_sta -t scripts/report_timing.tcl
python scripts/collect_reports.py
```

返回`quartus_reports_rev23.zip`和Flow Summary。报告仍覆盖所有可用工况，新增借位/双候选寄存器两侧、b16反馈，以及测试源相位寄存器的所有起点。后者可捕捉被综合合并到顶层`heartbeat`的计数位。缺失端点会警告，不作为通过证据。

需要同时确认目标路径改善、其余4条旧违例、新违例和资源占用。5.000 ns约束未放宽，未新增内部false path或multicycle。本包不含已验证SOF/JIC。
