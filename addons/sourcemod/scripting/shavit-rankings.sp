/*
 * shavit's Timer - Rankings
 * by: shavit
 *
 * This file is part of shavit's Timer.
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 *
*/

// Design idea:
// Rank 1 per map/style/track gets ((points per tier * tier) * 1.5) + (rank 1 time in seconds / 15.0) points.
// Records below rank 1 get points% relative to their time in comparison to rank 1.
//
// Bonus track gets a 0.25* final multiplier for points and is treated as tier 1.
//
// Points for all styles are combined to promote competitive and fair gameplay.
// A player that gets good times at all styles should be ranked high.
//
// Total player points are weighted in the following way: (descending sort of points)
// points[0] * 0.975^0 + points[1] * 0.975^1 + points[2] * 0.975^2 + ... + points[n] * 0.975^n
//
// The ranking leaderboard will be calculated upon: map start.
// Points are calculated per-player upon: connection/map.
// Points are calculated per-map upon: map start, map end, tier changes.
// Rankings leaderboard is re-calculated once per map change.
// A command will be supplied to recalculate all of the above.
//
// Heavily inspired by pp (performance points) from osu!, written by Tom94. https://github.com/ppy/osu-performance

#include <sourcemod>
#include <sdktools>
#include <convar_class>

#include <shavit>
#include <shavit/rankings>
#include <shavit/wr>

#undef REQUIRE_PLUGIN
#include <shavit/stats>



#undef REQUIRE_EXTENSIONS
#include <cstrike>

#pragma newdecls required
#pragma semicolon 1



public Plugin myinfo =
{
	name = "[shavit] Rankings",
	author = "shavit",
	description = "A fair and competitive ranking system for shavit's bhoptimer.",
	version = SHAVIT_VERSION,
	url = "https://github.com/shavitush/bhoptimer"
}

Database2 gH_SQL = null;
Database2 gH_SQL_b = null;
bool gB_HasSQLRANK = false; // whether the sql driver supports RANK()

bool gB_Stats = false;
bool gB_TierQueried = false;
bool gB_Maplimitspeed;

int gI_Tier = 1; // No floating numbers for tiers, sorry.
float gF_Maxvelocity = 3500.0;

char gS_Map[PLATFORM_MAX_PATH];

ArrayList gA_ValidMaps = null;
StringMap gA_MapTiers = null;

Convar gCV_PointsPerTier = null;
Convar gCV_WeightingMultiplier = null;
Convar gCV_WeightingLimit = null;
Convar gCV_LastLoginRecalculate = null;
Convar gCV_MVPRankOnes_Slow = null;
Convar gCV_MVPRankOnes = null;
Convar gCV_MVPRankOnes_Main = null;
Convar gCV_DefaultTier = null;
Convar gCV_DefaultMaxvelocity = null;
ConVar gCV_Maxvelocity = null;

ranking_t gA_Rankings[MAXPLAYERS+1];

int gI_RankedPlayers = 0;
Menu gH_Top100Menu = null;

// Timer settings.
int gI_Styles = 0;

bool gB_WorldRecordsCached = false;
bool gB_WRHolderTablesMade = false;
bool gB_WRHoldersRefreshed = false;
int gI_WRHolders[MaxTrackType][STYLE_LIMIT];
int gI_WRHoldersAll;
int gI_WRHoldersCvar;

#include "shavit-rankings/db/sql.sp"
#include "shavit-rankings/db/create_tables.sp"
#include "shavit-rankings/db/setup_database.sp"
#include "shavit-rankings/db/cache_mapsettings.sp"
#include "shavit-rankings/db/cache_points.sp"
#include "shavit-rankings/db/cache_ranks.sp"
#include "shavit-rankings/db/cache_wr.sp"

#include "shavit-rankings/menu/mapsettings.sp"
#include "shavit-rankings/menu/top100.sp"

#include "shavit-rankings/api.sp"
#include "shavit-rankings/cache.sp"
#include "shavit-rankings/commands.sp"



// ======[ PLUGIN EVENTS ]======

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNatives();

	RegPluginLibrary("shavit-rankings");

	return APLRes_Success;
}

public void OnPluginStart()
{
	if(GetEngineVersion() != Engine_CSGO)
	{
		SetFailState("This plugin only support for CSGO!");
		return;
	}

	LoadTranslations("common.phrases");
	LoadTranslations("shavit-common.phrases");
	LoadTranslations("shavit-rankings.phrases");

	CreateGlobalForwards();
	CreateConVars();
	RegisterCommands();
	HookEvents();
	InitCaches();

	SQL_DBConnect();

	CreateTimer(1.0, Timer_MVPs, 0, TIMER_REPEAT);
}

public void OnLibraryAdded(const char[] name)
{
	if(StrEqual(name, "shavit-stats"))
	{
		gB_Stats = true;
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if(StrEqual(name, "shavit-stats"))
	{
		gB_Stats = false;
	}
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if(convar == gCV_DefaultMaxvelocity)
	{
		DB_ModifyDefaultMaxvel(gCV_DefaultMaxvelocity.FloatValue);
	}
}

public void Shavit_OnStyleConfigLoaded(int styles)
{
	gI_Styles = styles;
}

public void OnClientConnected(int client)
{
	OnClientConnected_InitCache(client);
}

public void OnClientPutInServer(int client)
{
	OnClientPutInServer_UpdateCache(client);
}

public void OnMapStart()
{
	GetLowercaseMapName(gS_Map);

	if (gH_SQL == null)
	{
		return;
	}

	if (gB_WRHolderTablesMade && !gB_WRHoldersRefreshed)
	{
		DB_RefreshWRHolders();
	}

	// do NOT keep running this more than once per map, as DB_UpdateAllPoints() is called after this eventually and locks up the database while it is running
	if(gB_TierQueried)
	{
		return;
	}

	ForceAllClientsCached();

	// Default tier.
	// I won't repeat the same mistake blacky has done with tier 3 being default..
	gI_Tier = gCV_DefaultTier.IntValue;

	DB_GetMapSettings();

	gB_TierQueried = true;
}

public void OnMapEnd()
{
	gB_TierQueried = false;
	gB_WRHoldersRefreshed = false;
	gB_WorldRecordsCached = false;

	DB_RecalculateCurrentMap();
}

public void Shavit_OnWorldRecordsCached()
{
	gB_WorldRecordsCached = true;
}

public Action Timer_MVPs(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			CS_SetMVPCount_Test(i, Shavit_GetWRCount(i, -1, -1, true));
		}
	}

	static int mvps_offset = -1;

	if (mvps_offset == -1)
	{
		mvps_offset = GetEntSendPropOffs(GetPlayerResourceEntity(), "m_iMVPs");
	}

	ChangeEdictState(GetPlayerResourceEntity(), mvps_offset);

	return Plugin_Continue;
}

public void Player_Event(Event event, const char[] name, bool dontBroadcast)
{
	if(gCV_MVPRankOnes.IntValue == 0)
	{
		return;
	}

	int client = GetClientOfUserId(event.GetInt("userid"));

	if(IsValidClient(client) && !IsFakeClient(client))
	{
		CS_SetMVPCount_Test(client, Shavit_GetWRCount(client, -1, -1, true));
	}
}

public void Shavit_OnFinish_Post(int client, int style, float time, int jumps, int strafes, float sync, int rank, int overwrite, int track)
{
	if (rank != 1)
	{
		return;
	}

	DB_Recalculate(true, track, style);
}

public void Shavit_OnDeleteMapData(int client, const char[] map)
{
	DB_DeleteMapAllSettings(map);
	Shavit_PrintToChat(client, "Deleted all settings for %s.", map);
}



// ======[ PUBLIC ]======

void FormatRecalculate(bool bUseCurrentMap, int track, int style, char[] sQuery, int sQueryLen)
{
	float fMultiplier = Shavit_GetStyleSettingFloat(style, "rankingmultiplier");

	if (Shavit_GetStyleSettingBool(style, "unranked") || fMultiplier == 0.0)
	{
		FormatEx(sQuery, sQueryLen, mysql_FormatRecalculate_unranked,
			style,
			(track > 0) ? '>' : '=',
			(bUseCurrentMap) ? "AND map = '" : "",
			(bUseCurrentMap) ? gS_Map : "",
			(bUseCurrentMap) ? "'" : "");

		return;
	}

	if (bUseCurrentMap)
	{
		if (track == Track_Main)
		{
			if (gB_WorldRecordsCached)
			{
				float fWR = Shavit_GetWorldRecord(style, track);

				FormatEx(sQuery, sQueryLen, mysql_FormatRecalculate_currentmap_track_main_wr_cached,
					gCV_PointsPerTier.FloatValue,
					gI_Tier,
					fWR,
					fWR,
					fMultiplier,
					style,
					gS_Map);
			}
			else
			{
				FormatEx(sQuery, sQueryLen, mysql_FormatRecalculate_currentmap_track_main_wr_not_cached,
					gCV_PointsPerTier.FloatValue,
					gI_Tier,
					fMultiplier,
					style,
					gS_Map);
			}
		}
		else
		{
			FormatEx(sQuery, sQueryLen, mysql_FormatRecalculate_currentmap_track_bonus,
				gCV_PointsPerTier.FloatValue,
				fMultiplier,
				style,
				gS_Map);
		}
	}
	else
	{
		FormatEx(sQuery, sQueryLen, mysql_FormatRecalculate_othermap,
			gCV_PointsPerTier.FloatValue,
			fMultiplier,
			(track > 0) ? "* 0.25" : "",
			style,
			(track > 0) ? '>' : '=');
	}
}

float Sourcepawn_GetRecordPoints(int rtrack, float rtime, float pointspertier, float stylemultiplier, float pwr, int ptier)
{
	float ppoints = 0.0;

	if (rtrack > 0)
	{
		ptier = 1;
	}

	ppoints = ((pointspertier * ptier) * 1.5) + (pwr / 15.0);

	if (rtime > pwr)
	{
		ppoints = ppoints * (pwr / rtime);
	}

	ppoints = ppoints * stylemultiplier;

	if (rtrack > 0)
	{
		ppoints = ppoints * 0.25;
	}

	return ppoints;
}

void CS_SetMVPCount_Test(int client, int count)
{
	CS_SetMVPCount(client, count);
	SetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iMVPs", count, 4, client);
}



// ======[ PRIVATE ]======

static void CreateConVars()
{
	gCV_PointsPerTier = new Convar("shavit_rankings_pointspertier", "50.0", "Base points to use for per-tier scaling.\nRead the design idea to see how it works: https://github.com/shavitush/bhoptimer/issues/465", 0, true, 1.0);
	gCV_WeightingMultiplier = new Convar("shavit_rankings_weighting", "0.975", "Weighing multiplier. 1.0 to disable weighting.\nFormula: p[1] * this^0 + p[2] * this^1 + p[3] * this^2 + ... + p[n] * this^(n-1)\nRestart server to apply.", 0, true, 0.01, true, 1.0);
	gCV_WeightingLimit = new Convar("shavit_rankings_weighting_limit", "0", "Limit the number of times retreived for calculating a player's weighted points to this number.\n0 = no limit\nFor reference, a weighting of 0.975 to the power of 200 is 0.00632299938 and results in pretty much nil points for any further weighted times.\nUnused when shavit_rankings_weighting is 1.0.\nYou probably won't need to change this unless you have hundreds of thousands of player times in your database.", 0, true, 0.0, false);
	gCV_LastLoginRecalculate = new Convar("shavit_rankings_llrecalc", "10080", "Maximum amount of time (in minutes) since last login to recalculate points for a player.\nsm_recalcall does not respect this setting.\n0 - disabled, don't filter anyone", 0, true, 0.0);
	gCV_MVPRankOnes_Slow = new Convar("shavit_rankings_mvprankones_slow", "1", "Uses a slower but more featureful MVP counting system.\nEnables the WR Holder ranks & counts for every style & track.\nYou probably won't need to change this unless you have hundreds of thousands of player times in your database.", 0, true, 0.0, true, 1.0);
	gCV_MVPRankOnes = new Convar("shavit_rankings_mvprankones", "2", "Set the players' amount of MVPs to the amount of #1 times they have.\n0 - Disabled\n1 - Enabled, for all styles.\n2 - Enabled, for default style only.\n(CS:S/CS:GO only)", 0, true, 0.0, true, 2.0);
	gCV_MVPRankOnes_Main = new Convar("shavit_rankings_mvprankones_maintrack", "1", "If set to 0, all tracks will be counted for the MVP stars.\nOtherwise, only the main track will be checked.\n\nRequires \"shavit_stats_mvprankones\" set to 1 or above.\n(CS:S/CS:GO only)", 0, true, 0.0, true, 1.0);
	gCV_DefaultTier = new Convar("shavit_rankings_default_tier", "1", "Sets the default tier for new maps added.", 0, true, 1.0, true, 8.0);
	gCV_DefaultMaxvelocity = new Convar("shavit_rankings_defaultmap_maxvelocity", "3500.0", "Sets the default maxvelocity for new maps added.", 0, true, 3500.0);
	gCV_DefaultMaxvelocity.AddChangeHook(OnConVarChanged);
	Convar.AutoExecConfig();

	gCV_Maxvelocity = FindConVar("sv_maxvelocity");
}

static void HookEvents()
{
	HookEvent("player_spawn", Player_Event);
	HookEvent("player_team", Player_Event);
}

static void ForceAllClientsCached()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i) && IsClientInGame(i))
		{
			OnClientPutInServer(i);
		}
	}
}