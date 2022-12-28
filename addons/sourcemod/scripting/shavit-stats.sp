/*
 * shavit's Timer - Player Stats
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

#include <sourcemod>
#include <geoip>
#include <convar_class>
#include <shavit/core>
#include <shavit/wr>
#include <shavit/stats>
#include <shavit/surftimer>

#undef REQUIRE_PLUGIN
#include <shavit/rankings>

#undef REQUIRE_EXTENSIONS
#include <cstrike>

#pragma newdecls required
#pragma semicolon 1



public Plugin myinfo =
{
	name = "[shavit] Player Stats",
	author = "shavit",
	description = "Player stats for shavit's bhop timer.",
	version = SHAVIT_VERSION,
	url = "https://github.com/shavitush/bhoptimer"
}



// modules
bool gB_Rankings = false;

// database handle
Database gH_SQL = null;

// cache
bool gB_CanOpenMenu[MAXPLAYERS+1];
int gI_MapType[MAXPLAYERS+1];
int gI_Style[MAXPLAYERS+1];
int gI_MenuPos[MAXPLAYERS+1];
int gI_Track[MAXPLAYERS+1];
int gI_TargetSteamID[MAXPLAYERS+1];
char gS_TargetName[MAXPLAYERS+1][MAX_NAME_LENGTH];

// playtime things
float gF_PlaytimeStart[MAXPLAYERS+1];
float gF_PlaytimeStyleStart[MAXPLAYERS+1];
int gI_CurrentStyle[MAXPLAYERS+1];
float gF_PlaytimeStyleSum[MAXPLAYERS+1][STYLE_LIMIT];
bool gB_HavePlaytimeOnStyle[MAXPLAYERS+1][STYLE_LIMIT];
bool gB_QueriedPlaytime[MAXPLAYERS+1];

bool gB_Late = false;

// timer settings
int gI_Styles = 0;
stylestrings_t gS_StyleStrings[STYLE_LIMIT];

Convar gCV_SavePlaytime = null;



#include "shavit-stats/api.sp"
#include "shavit-stats/cache.sp"
#include "shavit-stats/commands.sp"

#include "shavit-stats/db/sql.sp"
#include "shavit-stats/db/setup_database.sp"
#include "shavit-stats/db/querytime.sp"
#include "shavit-stats/db/savetime.sp"

#include "shavit-stats/menu/maps.sp"
#include "shavit-stats/menu/playtime.sp"
#include "shavit-stats/menu/profile.sp"


// ======[ PLUGIN EVENTS ]======

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if(GetEngineVersion() != Engine_CSS)
	{
		SetFailState("This plugin only support for CSS!");
		return APLRes_Failure;
	}

	CreateNatives();

	RegPluginLibrary("shavit-stats");

	gB_Late = late;

	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("shavit-common.phrases");
	LoadTranslations("shavit-stats.phrases");

	CreateConVars();
	RegisterCommands();
	SQL_DBConnect();

	// modules
	gB_Rankings = LibraryExists("shavit-rankings");

	if(gB_Late)
	{
		Shavit_OnStyleConfigLoaded(Shavit_GetStyleCount());
		ForceClientInitCache();
	}

	CreateTimer(2.5 * 60.0, Timer_SavePlaytime, 0, TIMER_REPEAT);
}

public void Shavit_OnStyleConfigLoaded(int styles)
{
	for(int i = 0; i < styles; i++)
	{
		Shavit_GetStyleStringsStruct(i, gS_StyleStrings[i]);
	}

	gI_Styles = styles;
}

public void OnClientConnected(int client)
{
	OnClientConnected_InitCache(client);
}

public void OnClientPutInServer(int client)
{
	OnClientPutInServer_InitCache(client);
}

public void OnClientAuthorized(int client, const char[] auth)
{
	OnClientAuthorized_QueryPlaytime(client);
}

public void OnClientDisconnect(int client)
{
	OnClientDisconnect_SavePlayTime(client);
}

public void Shavit_OnStyleChanged(int client, int oldstyle, int newstyle, int track, bool manual)
{
	OnStyleChanged_ChangePlayTime(client, oldstyle, newstyle);
}

public void OnLibraryAdded(const char[] name)
{
	if(StrEqual(name, "shavit-rankings"))
	{
		gB_Rankings = true;
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if(StrEqual(name, "shavit-rankings"))
	{
		gB_Rankings = false;
	}
}



// ======[ PRIVATE ]======

static void CreateConVars()
{
	gCV_SavePlaytime = new Convar("shavit_stats_saveplaytime", "1", "Whether to save a player's playtime (total & per-style).", 0, true, 0.0, true, 1.0);
	Convar.AutoExecConfig();
}

static void ForceClientInitCache()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i) && IsClientInGame(i))
		{
			OnClientPutInServer(i);
		}
	}
}

static void OnStyleChanged_ChangePlayTime(int client, int oldstyle, int newstyle)
{
	if (IsFakeClient(client))
	{
		return;
	}

	gI_CurrentStyle[client] = newstyle;

	if (!IsClientConnected(client) || !IsClientInGame(client))
	{
		return;
	}

	float now = GetEngineTime();

	if (gF_PlaytimeStyleStart[client] == 0.0)
	{
		gF_PlaytimeStyleStart[client] = now;
		return;
	}

	if (oldstyle == newstyle)
	{
		return;
	}

	gF_PlaytimeStyleSum[client][oldstyle] += (now - gF_PlaytimeStyleStart[client]);
	gF_PlaytimeStyleStart[client] = now;
}