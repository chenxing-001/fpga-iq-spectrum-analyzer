# 串口电脑上位机

需要Python 3.10+、Tk、numpy、matplotlib、pyserial。Windows常规Python安装应启用Tcl/Tk支持；Linux需要对应发行版的Tk支持包。

```text
python -m pip install -r requirements.txt
python app.py
```

选择开发板串口并连接，固定115200、8数据位、无校验、1停止位，无硬件流控。程序只接收数据，不发送控制命令。串口接收在后台线程进行，绘图与界面更新在主线程进行。

`python app.py --demo` 运行电脑合成演示，不需要串口。`python app.py --render-demo preview.png` 可直接生成演示波形图片，无需桌面显示环境。

界面显示：前256个连续IQ样点、256列频谱、主峰频率、近似半功率带宽、时域峰值/RMS、分析耗时及门限活动区间。数据来自FPGA统计；PC只换算单位和绘制曲线。波形单位为数字码值，未经外部模拟电压标定。

“导出当前帧”生成三个文件：

- JSON：统计元数据、source=hardware/demo、数据说明；reserved为协议保留字。
- `_time.csv`：time_s、I、Q。
- `_spectrum.csv`：group_center_Hz、power_code、approx_dBFS。

解析器检查1330字节长度、IQFT帧头、v1版本及CRC16。收到错误包时自动寻找下一帧头恢复。旧v1包的偏移42..43即使非零也可接收，但不再作为屏幕信息显示。

突发模式的前256点全零是预期行为：信号从第1024个样点开始；整8192点窗口的活动点数、RMS等仍正常显示。
