```
分支复刻自: https://github.com/Ciallo-Ani/mytimer/tree/gokz-framework
本 Fork 为 Timer 的 CS 起源移植版, 不支持 CS:GO.
别的东西暂时没写, 因为还没移植完.
```

### 要改的:
- 隐藏玩家没效果
- 录像 bot 起步左下角刷速度信息
(录像播放的原理是将bot一帧一帧地传送到特定位置, 而在区域内传送时会触发 `EndTouchPost()`)
- 起点开穿墙不停止计时, 而是暂停计时
- `!ms` 无法更改设置 (fixed)

### 要加的:
- 将区域传送点设置到 info_teleport_destination
- 把 eventqueue 支持加回来 (考虑到部分地图触发需要)
- 禁止起跳区域 (ksf feature)
- 自动连跳区域 (surf_tycho_fix中的bhop trigger)
- 起点直接禁止连跳起步
- 可在 `!ms` 中设置某个 Track 能否自动跳
- !saveloc posX|posY|posZ|angleX|angleY|angleZ|velX|velY|velZ (ksf feature)
- WRCP循环播放bot不播进入终点后的部分(最后一关除外)
- 合并 `showspeed.sp` 并添加速度差显示
- 给起源用的zones和stripper
- 自定义检查点 (ksf feature)
