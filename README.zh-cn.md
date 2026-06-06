# GestionePuntiRipristino

Windows 11 图形工具，用于创建、查看、修改和删除系统还原点。

## 系统要求

- **Windows 11**（也适用于 Windows 10）
- **PowerShell 5.1+**
- **以管理员身份运行**（需要与 Volume Shadow Copy 交互）

## 安装

下载 `GestionePuntiRipristino.ps1` 并以管理员身份运行：

```powershell
.\GestionePuntiRipristino.ps1
```

或者在资源管理器中：右键 → **使用 PowerShell 运行**。

## 功能

- **列出还原点** — 显示所有现有还原点及日期和描述
- **删除** — 确认后删除指定还原点
- **创建** — 创建新的还原点
- **编辑描述** — 自定义还原点描述（保存在 HKCU\Software\OttimizzaWindows）
- **启动系统还原** — 打开 Windows 原生界面（`rstrui.exe`）

## 安全性

- 每次 `vssadmin` 操作前进行严格的 UUID 验证
- 通过 `Process.Start` 执行进程，无 shell 中间层
- 30 秒超时防止卡死
- 审计日志记录到 Windows 事件日志（源：`OttimizzaWindows`）
- 描述存储在注册表中（HKCU），而非临时文件

## 许可证

MIT
