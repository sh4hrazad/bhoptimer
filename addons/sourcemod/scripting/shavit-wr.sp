/*
 * shavit's Timer - World Records
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
#include <convar_class>
#include <dhooks>

#include <shavit/core>
#include <shavit/wr>

#undef REQUIRE_PLUGIN
#include <shavit/rankings>
#include <shavit/stats>

#undef REQUIRE_PLUGIN
#include <adminmenu>

#pragma newdecls required
#pragma semicolon 1



public Plugin myinfo =
{
	name = "[shavit] World Records",
	author = "shavit",
	description = "World records for shavit's bhop timer.",
	version = SHAVIT_VERSION,
	url = "https://github.com/shavitush/bhoptimer"
}



bool gB_Late = false;

// modules
bool gB_Rankings = false;
bool gB_Stats = false;


// database handle
Database2 gH_SQL = null;
bool gB_Connected = false;

// cache
wrcache_t gA_WRCache[MAXPLAYERS+1];
StringMap gSM_StyleCommands = null;

char gS_Map[PLATFORM_MAX_PATH];
ArrayList gA_ValidMaps = null;

// current wr stats
float gF_WRTime[STYLE_LIMIT][TRACKS_SIZE];
int gI_WRRecordID[STYLE_LIMIT][TRACKS_SIZE];
int gI_WRSteamID[STYLE_LIMIT][TRACKS_SIZE];
StringMap gSM_WRNames = null;
ArrayList gA_Leaderboard[STYLE_LIMIT][TRACKS_SIZE];
bool gB_LoadedCache[MAXPLAYERS+1];
float gF_PlayerRecord[MAXPLAYERS+1][STYLE_LIMIT][TRACKS_SIZE];
int gI_PlayerCompletion[MAXPLAYERS+1][STYLE_LIMIT][TRACKS_SIZE];
float gF_PlayerPrestrafe[MAXPLAYERS+1][STYLE_LIMIT][TRACKS_SIZE];
float gF_CurrentPrestrafe[MAXPLAYERS+1];

// admin menu
TopMenu gH_AdminMenu = null;
TopMenuObject gH_TimerCommands = INVALID_TOPMENUOBJECT;

// cvars
Convar gCV_RecordsLimit = null;
Convar gCV_RecentLimit = null;

// timer settings
int gI_Styles = 0;
stylestrings_t gS_StyleStrings[STYLE_LIMIT];

// chat settings
chatstrings_t gS_ChatStrings;



#include "shavit-wr/db/sql.sp"
#include "shavit-wr/db/create_tables.sp"
#include "shavit-wr/db/delete.sp"
#include "shavit-wr/db/setup_database.sp"
#include "shavit-wr/db/cache_leaderboards.sp"
#include "shavit-wr/db/cache_maplist.sp"
#include "shavit-wr/db/cache_pbs.sp"
#include "shavit-wr/db/cache_wrs.sp"
#include "shavit-wr/db/process_onfinish.sp"

#include "shavit-wr/api.sp"
#include "shavit-wr/cache.sp"
#include "shavit-wr/commands.sp"
#include "shavit-wr/menu.sp"



// ======[ PLUGIN EVENTS ]======

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNatives();

	RegPluginLibrary("shavit-wr");

	gB_Late = late;

	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("shavit-common.phrases");
	LoadTranslations("shavit-wr.phrases");

	CreateGlobalForwards();
	CreateConVars();
	RegisterCommands();
	InitCaches();

	// modules
	gB_Rankings = LibraryExists("shavit-rankings");
	gB_Stats = LibraryExists("shavit-stats");

	if(gB_Late)
	{
		Shavit_OnStyleConfigLoaded(Shavit_GetStyleCount());
		Shavit_OnChatConfigLoaded();
	}

	SQL_DBConnect();

	CreateTimer(2.5, Timer_Dominating, 0, TIMER_REPEAT);
}

public void OnAllPluginsLoaded()
{
	// admin menu
	if(LibraryExists("adminmenu") && ((gH_AdminMenu = GetAdminTopMenu()) != null))
	{
		OnAdminMenuReady(gH_AdminMenu);
	}
}

public void OnAdminMenuCreated(Handle topmenu)
{
	if(gH_AdminMenu == null || (topmenu == gH_AdminMenu && gH_TimerCommands != INVALID_TOPMENUOBJECT))
	{
		return;
	}

	gH_TimerCommands = gH_AdminMenu.AddCategory("Timer Commands", CategoryHandler, "shavit_admin", ADMFLAG_RCON);
}

public void CategoryHandler(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	if(action == TopMenuAction_DisplayTitle)
	{
		FormatEx(buffer, maxlength, "%T:", "TimerCommands", param);
	}

	else if(action == TopMenuAction_DisplayOption)
	{
		FormatEx(buffer, maxlength, "%T", "TimerCommands", param);
	}
}

public void OnAdminMenuReady(Handle topmenu)
{
	if((gH_AdminMenu = GetAdminTopMenu()) != null)
	{
		if(gH_TimerCommands == INVALID_TOPMENUOBJECT)
		{
			gH_TimerCommands = gH_AdminMenu.FindCategory("Timer Commands");

			if(gH_TimerCommands == INVALID_TOPMENUOBJECT)
			{
				OnAdminMenuCreated(topmenu);
			}
		}

		gH_AdminMenu.AddItem("sm_deleteall", AdminMenu_DeleteAll, gH_TimerCommands, "sm_deleteall", ADMFLAG_RCON);
		gH_AdminMenu.AddItem("sm_delete", AdminMenu_Delete, gH_TimerCommands, "sm_delete", ADMFLAG_RCON);
	}
}

public void AdminMenu_Delete(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	if(action == TopMenuAction_DisplayOption)
	{
		FormatEx(buffer, maxlength, "%t", "DeleteSingleRecord");
	}

	else if(action == TopMenuAction_SelectOption)
	{
		Command_Delete(param, 0);
	}
}

public void AdminMenu_DeleteAll(Handle topmenu,  TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	if(action == TopMenuAction_DisplayOption)
	{
		FormatEx(buffer, maxlength, "%t", "DeleteAllRecords");
	}

	else if(action == TopMenuAction_SelectOption)
	{
		Command_DeleteAll(param, 0);
	}
}

public void OnLibraryAdded(const char[] name)
{
	if(StrEqual(name, "shavit-rankings"))
	{
		gB_Rankings = true;
	}
	else if(StrEqual(name, "shavit-stats"))
	{
		gB_Stats = true;
	}
	else if (StrEqual(name, "adminmenu"))
	{
		if ((gH_AdminMenu = GetAdminTopMenu()) != null)
		{
			OnAdminMenuReady(gH_AdminMenu);
		}
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if(StrEqual(name, "shavit-rankings"))
	{
		gB_Rankings = false;
	}
	else if(StrEqual(name, "shavit-stats"))
	{
		gB_Stats = false;
	}
	else if (StrEqual(name, "adminmenu"))
	{
		gH_AdminMenu = null;
		gH_TimerCommands = INVALID_TOPMENUOBJECT;
	}
}

public Action Timer_Dominating(Handle timer)
{
	bool bHasWR[MAXPLAYERS+1];

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			char sSteamID[20];
			IntToString(GetSteamAccountID(i), sSteamID, sizeof(sSteamID));
			bHasWR[i] = gSM_WRNames.GetString(sSteamID, sSteamID, sizeof(sSteamID));
		}
	}

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i))
		{
			continue;
		}

		for (int x = 1; x <= MaxClients; x++)
		{
			SetEntProp(i, Prop_Send, "m_bPlayerDominatingMe", bHasWR[x], 1, x);
		}
	}

	return Plugin_Continue;
}

public void OnMapStart()
{
	if(!gB_Connected)
	{
		return;
	}

	OnMapStart_ClearMapCache();
	UpdateWRCache();
	UpdateMaps();
	ForceInitClientCache();
}

public void OnMapEnd()
{
	ResetWRs();
}

public void Shavit_OnStyleConfigLoaded(int styles)
{
	OnStyleConfigLoaded_InitCaches(styles);

	gI_Styles = styles;
}

public void Shavit_OnChatConfigLoaded()
{
	Shavit_GetChatStringsStruct(gS_ChatStrings);
}

public void OnClientConnected(int client)
{
	OnClientConnected_InitCache(client);
}

public void OnClientPutInServer(int client)
{
	if (gB_Connected && !IsFakeClient(client))
	{
		UpdateClientCache(client);
	}
}

public void Shavit_OnDeleteMapData(int client, const char[] map)
{
	DB_DeleteMapAllRecords(map);
	Shavit_PrintToChat(client, "Deleted all records for %s.", map);
}

public void Shavit_OnCommandStyle(int client, int style, float& wrtime)
{
	wrtime = gF_WRTime[style][Shavit_GetClientTrack(client)];
}

public void Shavit_OnUserDeleteData(int client, int steamid)
{
	DB_DeleteUserData(steamid);
}

public void Shavit_OnDeleteRestOfUserSuccess(int client, int steamid)
{
	UpdateWRCache();
}

public void Shavit_OnStartTimer_Post(int client, int style, int track, float speed)
{
	gF_CurrentPrestrafe[client] = speed;
}

public void Shavit_OnFinish(int client, int style, float time, int jumps, int strafes, float sync, int track, float& oldtime, float avgvel, float maxvel, int timestamp)
{
	DB_OnFinish(client, style, time, jumps, strafes, sync, track, oldtime, avgvel, maxvel, timestamp);
}



// ======[ PUBLIC ]======

int GetRecordAmount(int style, int track)
{
	if(gA_Leaderboard[style][track] == null)
	{
		return 0;
	}

	return gA_Leaderboard[style][track].Length;
}

int GetRankForTime(int style, float time, int track)
{
	int iRecords = GetRecordAmount(style, track);

	if(time == 0.0)
	{
		return 0;
	}
	else if(time <= gF_WRTime[style][track] || iRecords <= 0) /* should be the first record */
	{
		return 1;
	}

	int i = 0;

	if (iRecords > 100)
	{
		int middle = iRecords/2;

		if (gA_Leaderboard[style][track].Get(middle) < time)
		{
			i = middle;
		}
		else
		{
			iRecords = middle;
		}
	}

	for (; i < iRecords; i++)
	{
		if (time <= gA_Leaderboard[style][track].Get(i))
		{
			return i+1;
		}
	}

	return (iRecords + 1);
}

int GetRankForSteamid(int style, int steamid, int track)
{
	int iRecords = GetRecordAmount(style, track);

	if(iRecords <= 0)
	{
		return 0;
	}

	if(gA_Leaderboard[style][track] != null && gA_Leaderboard[style][track].Length > 0)
	{
		for(int i = 0; i < iRecords; i++)
		{
			prcache_t pr;
			gA_Leaderboard[style][track].GetArray(i, pr, sizeof(pr));

			if(steamid == pr.iSteamid)
			{
				return ++i;
			}
		}
	}

	return 0;
}

float ExactTimeMaybe(float time, int exact_time)
{
	return (exact_time != 0) ? view_as<float>(exact_time) : time;
}



// ======[ PRIVATE ]======

static void CreateConVars()
{
	gCV_RecordsLimit = new Convar("shavit_wr_recordlimit", "50", "Limit of records shown in the WR menu.\nAdvised to not set above 1,000 because scrolling through so many pages is useless.\n(And can also cause the command to take long time to run)", 0, true, 1.0);
	gCV_RecentLimit = new Convar("shavit_wr_recentlimit", "50", "Limit of records shown in the RR menu.", 0, true, 1.0);

	Convar.AutoExecConfig();
}

static void ForceInitClientCache()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i) && IsClientInGame(i))
		{
			OnClientPutInServer(i);
		}
	}
}