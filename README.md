```
分支复刻自: https://github.com/Ciallo-Ani/mytimer/tree/gokz-framework
本 Fork 为 Timer 的 CS 起源移植版, 不支持 CS:GO.
别的东西暂时没写, 因为还没移植完.
```

#### 要改的:
- 隐藏玩家没效果
- 录像 bot 起步左下角刷速度信息
- 区域方框显示位置不对
- 起点开穿墙不停止计时, 而是暂停计时
- `!ms` 无法更改设置
- WRCP循环播放bot不播进入终点后的部分(最后一关除外)
- 给起源用的区域设置与stripper

#### 要加的:
- 区域传送点可设置为 info_teleport_destination 的位置
https://github.com/sh4hrazad/bhoptimer/commit/68f0930c340571e92a66ee67c9647b7e91ac73a8
- 把 eventqueue 支持加回来 (考虑到部分地图触发需要)
- 禁止起跳区域
- 自动连跳区域
- 起点直接禁止连跳起步
- 可在 `!ms` 中设置某个 Track 能否自动跳
- !saveloc posX|posY|posZ|angleX|angleY|angleZ|velX|velY|velZ