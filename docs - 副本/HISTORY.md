# 历史材料

REVISION_17.md、REVISION_18.md及相应revision17/18日志/patch/json为早先交付时的记录；其中的延迟、测试范围与NOT_VERIFIED状态均属于当时版本。修订18后来收到的实测时序报告位于baseline_rev18/。

修订19源码与当时状态记录于REVISION_19.md、revision19_validation.json和revision19_tests.log。冻结参考RTL只用于仿真，不在综合QSF中。


## 修订20

依据用户修订19的−0.410 ns Setup报告调整峰值归并、32位计时器和跳帧减法；保持57,458拍默认分析延迟与UART/PC接口。详细说明、实际验证记录和重新拟合要求见REVISION_20.md。

## 修订21

依据用户上传修订20的−0.328 ns Setup报告，拆分FFT b13（D=8）的逻辑读取及减法反馈路径。默认分析延迟增加2拍至57,460拍。该历史版本的交付状态以REVISION_21.md及revision21_validation.json为准；历史报告与日志只说明对应旧版状态。交付时未拟合；本轮收到的修订21实测报告补充在baseline_rev21/。

## 修订22

修订21实测最差Setup改善到−0.114 ns，仅2条所列违例位于t8的虚部加法；资源为8,611 LE。修订22在共享旋转器现有两级内拆分进位，保持57,460拍默认分析延迟。当前源码状态以REVISION_22.md及revision22_validation.json为准。修订22尚无Quartus拟合结果。


## 修订23候选版

修订22用户实测：Setup −0.253 ns、所列100条中63条违例；所列50条Hold最差+0.402 ns，LE为8,821（85%）。修订23仅修改共享旋转器实部，使用直接低位借位与高位双候选选择，保持流水结构。算术模型穷举通过；RTL仿真和拟合未执行。当前状态以REVISION_23.md和revision23_validation.json为准，前面各版测试结果仅属历史。
