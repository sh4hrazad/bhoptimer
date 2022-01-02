[![Discord server](https://discordapp.com/api/guilds/389675819959844865/widget.png?style=shield)](https://discord.gg/jyA9q5k)

### RECOMPILE ALL YOUR PLUGINS THAT USE `#include <shavit>` OR STUFF WILL BREAK

# shavit's surf timer

Hope to replace [SurfTimer](https://github.com/surftimer/Surftimer-Official) with this.

Map strippers, zones and tiers are from [HERE](https://github.com/Kyli3Boi/Surftimer-Official-Zones)

[Mapzones Setup Demonstration](https://youtu.be/OXFMGm40F6c)

# Requirements:
* Steam version of Counter-Strike: Global Offensive.
* [Metamod:Source](https://www.sourcemm.net/downloads.php?branch=stable) and [SourceMod 1.10 or above](https://www.sourcemod.net/downloads.php?branch=stable) installed.
* A MySQL database (preferably locally hosted) if your database is likely to grow big. MySQL server version of 5.5.5 or above is required.
* [DHooks](https://github.com/peace-maker/DHooks2/releases)
* [MomSurfFix](https://github.com/GAMMACASE/MomSurfFix)
* [RNGFix](https://github.com/jason-e/rngfix)
* [HeadBugFix](https://github.com/GAMMACASE/HeadBugFix)

# Optional requirements, for the best experience:
* [SteamWorks](https://forums.alliedmods.net/showthread.php?t=229556)
  * Used to grab `{serverip}` in advertisements.
* [ShowPlayerClips](https://forums.alliedmods.net/showthread.php?p=2661942)
* [Stripper](http://www.bailopan.net/stripper/snapshots/1.2/)
  * Used to fix maps(download git129 or above)
* [Boostfix](https://github.com/t5mat/boostfix)
  * Prevent client getting double push/boost
* [sm_closestpos](https://github.com/rtldg/sm_closestpos)
  * Get dynamic time and velocity difference, written in c++ and much faster than sourcepawn
* [NoclipSpeed](https://github.com/GAMMACASE/NoclipSpeed)
  * Set dynamic noclip speed by your custom value, differs from setting sv_noclipspeed convar directly
