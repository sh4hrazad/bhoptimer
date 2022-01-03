# 非常感谢你看到了我写的插件

我希望用这个插件去替代大多数社区都在用的滑翔插件[SurfTimer](https://github.com/surftimer/Surftimer-Official)

地图的stripper，区域还有难度数据库都在[这里](https://github.com/Kyli3Boi/Surftimer-Official-Zones)

上述数据库已集成到本插件中，即本仓库的[mysql](https://github.com/Ciallo-Ani/surftimer/tree/surf/mysql)目录

# 一定要安装的东西:
* 只支持CSGO.
* [Metamod:Source](https://www.sourcemm.net/downloads.php?branch=stable) 和 [SourceMod 1.10 或以上版本](https://www.sourcemod.net/downloads.php?branch=stable).
* MySQL数据库(最好是本地托管的), 需要MySQL服务器版本5.5.5或更高版本。
* [DHooks](https://github.com/peace-maker/DHooks2/releases)
* [MomSurfFix](https://github.com/GAMMACASE/MomSurfFix)
* [RNGFix](https://github.com/jason-e/rngfix)
* [HeadBugFix](https://github.com/GAMMACASE/HeadBugFix)

# 可选安装，以获得最佳体验:
* [SteamWorks](https://forums.alliedmods.net/showthread.php?t=229556)
  * 用于抓取广告中的`{serverip}`.
* [ShowPlayerClips](https://forums.alliedmods.net/showthread.php?p=2661942)
  - 用于显示空气墙.
* [Stripper](http://www.bailopan.net/stripper/snapshots/1.2/)
  * 用于修复地图(下载git129或更高版本)
* [Boostfix](https://github.com/t5mat/boostfix)
  * 防止客户端卡bug加速
* [sm_closestpos](https://github.com/rtldg/sm_closestpos)
  * 获得动态时间差和速度差，用c++编写的扩展，比sourcepawn快得多。
* [NoclipSpeed](https://github.com/GAMMACASE/NoclipSpeed)
  * 通过自定义值设置穿墙速度，不同于直接设置sv_noclipspeed cvar值
