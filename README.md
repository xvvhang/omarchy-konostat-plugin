# Konostate / 系统状态

**Konochi** 系列插件，由 Alec Xu 开发。

Omarchy / Quickshell 原生插件，ID：`konochi.konostate`。

## 使用

- 左键点击 Bar 的系统状态图标打开面板；Esc 或点击外部关闭。
- 面板显示 CPU、GPU、内存及 Swap、本地存储、上传/下载网速、风扇和温度传感器。
- 每项右侧开关决定是否将该指标加入 Bar，不影响面板显示和采集。
- 顶部“Bar 仅显示状态图标”开关隐藏所有 Bar 数值，但保留各项选择。
- 默认开启仅图标模式，预选 CPU 和内存；关闭仅图标模式即可看到它们。
- 设置通过 Omarchy 原生接口保存到 `~/.config/omarchy/shell.json`，重启后保留。
- 长面板可滚动；支持横向和纵向 Bar，并跟随当前主题。

## 数据来源和限制

仅依赖系统现有 Python 3 标准库，不联网、不安装软件、不修改硬件设置、不需要 sudo。
单个共享采集进程每 2 秒更新，存储每 30 秒刷新；采集异常时自动重试。

- CPU：`/proc/stat` 差分；启动首次采样暂时不可用。内存：`MemAvailable`。
- GPU：AMD 等驱动提供的 sysfs 利用率和显存；Intel 可读取时显示当前频率。
  NVIDIA 在已安装 `nvidia-smi` 时读取利用率、显存、温度及风扇百分比。
  未公开 GPU 利用率时明确标为不可用，不申请 perf/root 权限。
- 存储：本地 `/dev/` 文件系统，合并同一设备的子卷，不统计 boot/EFI 和网络挂载。
  Bar 显示首个挂载点，优先 `/`。
- 网速：活动物理网卡的字节计数差分，汇总上传/下载；忽略虚拟网卡，避免 VPN/网桥重复计数。
- 风扇/温度：`/sys/class/hwmon`；无 hwmon 温度时尝试 thermal zones。
  面板按组件合并温度范围（CPU、SSD、内存等），Bar 显示最高读数。0 RPM 保留为真实传感器读数。
  NVIDIA 仅提供百分比的风扇显示在 GPU 详情，不冒充 RPM。

## 管理与诊断

```sh
omarchy plugin validate ~/.config/omarchy/plugins/konochi.konostate
omarchy plugin enable konochi.konostate
omarchy plugin disable konochi.konostate
omarchy-shell konochi.konostate status
omarchy-shell shell summon konochi.konostate '{}'
python3 -B ~/.config/omarchy/plugins/konochi.konostate/collect.py --once
```

在本目录执行 `python3 -B -m unittest -v test_collect.py` 运行测试。

## 安装与卸载

需要 Omarchy Quattro 和 Python 3；NVIDIA 指标可选依赖 `nvidia-smi`。
没有额外安装脚本、独立系统服务或提权步骤。

```sh
omarchy plugin add https://github.com/xvvhang/konostate --enable
omarchy plugin disable konochi.konostate
omarchy plugin remove konochi.konostate
```

卸载不修改硬件、其他插件或用户文件。删除前请备份尚未推送的开发修改。

QML 检查须使用 Qt 6（PATH 中默认的 `qmllint` 可能是 Qt 5）：

```sh
omarchy plugin validate .
/usr/lib/qt6/bin/qmllint -I /usr/share/omarchy/shell ./*.qml
```

MIT 许可证，详见 LICENSE。
