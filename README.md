```
分支复刻自: https://github.com/Ciallo-Ani/mytimer/tree/gokz-framework
本 Fork 为 Timer 的 CS 起源移植版, 不支持 CS:GO.
别的东西暂时没写, 因为还没移植完.
```

## TODO:

### 要改的:
- 隐藏玩家没效果
- 录像 bot 起步左下角刷速度信息
- 绿色 `{green}` 无法正常显示

### 要加的:
- ✔️ 将区域传送点设置到 `info_teleport_destination`
- 把 eventqueuefix 支持加回来 (考虑到部分地图触发需要)
- ✔️ 禁止起跳区域
- ✔️ 自动连跳区域
- 可设置 `!r` 应传送回关卡或 Track 起点
- ✔️ 重做起步限速
- HUD 显示时间/速度差, 剩余时间, 同步率, 预估排名
- ✔️ 可在 `!ms` 中设置某个 Track 能否自动跳
- 复刻存点 `!saveloc posX|posY|posZ|angleX|angleY|angleZ|velX|velY|velZ` (ksf feature)
- WRCP循环播放bot不播进入终点后的部分(最后一关除外)
- 合并 `showspeed.sp` 并添加速度差显示
- 合并原存点菜单与使用他人存点菜单
- 给起源用的 zones 和 stripper
- 自定义检查点 (ksf feature)
- 可以给关卡或奖励关起名
- 优化练习模式, 可选择是否始终处于练习模式
