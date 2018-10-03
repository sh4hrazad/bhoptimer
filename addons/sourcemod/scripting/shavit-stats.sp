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

#undef REQUIRE_PLUGIN
#include <shavit>

#undef REQUIRE_EXTENSIONS
#include <cstrike>

#pragma newdecls required
#pragma semicolon 1

// macros
#define MAPSDONE 0
#define MAPSLEFT 1

// modules
bool gB_Rankings = false;

// database handle
Database gH_SQL = null;

// table prefix
char gS_MySQLPrefix[32];

// cache
bool gB_AllowStats[MAXPLAYERS+1];
int gI_MapType[MAXPLAYERS+1];
int gBS_Style[MAXPLAYERS+1];
int gI_Track[MAXPLAYERS+1];
char gS_TargetAuth[MAXPLAYERS+1][32];
char gS_TargetName[MAXPLAYERS+1][MAX_NAME_LENGTH];
int gI_WRAmount[MAXPLAYERS+1];
EngineVersion gEV_Type = Engine_Unknown;

bool gB_Late = false;

// cvars
ConVar gCV_MVPRankOnes = null;
ConVar gCV_MVPRankOnes_Main = null;

// cached cvars
int gI_MVPRankOnes = 2;
bool gB_MVPRankOnes_Main = true;

// timer settings
int gI_Styles = 0;
char gS_StyleStrings[STYLE_LIMIT][STYLESTRINGS_SIZE][128];
any gA_StyleSettings[STYLE_LIMIT][STYLESETTINGS_SIZE];

// chat settings
char gS_ChatStrings[CHATSETTINGS_SIZE][128];

public Plugin myinfo =
{
	name = "[shavit] Player Stats",
	author = "shavit",
	description = "Player stats for shavit's bhop timer.",
	version = SHAVIT_VERSION,
	url = "https://github.com/shavitush/bhoptimer"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	// natives
	CreateNative("Shavit_OpenStatsMenu", Native_OpenStatsMenu);
	CreateNative("Shavit_GetWRCount", Native_GetWRCount);

	RegPluginLibrary("shavit-stats");

	gB_Late = late;

	return APLRes_Success;
}

public void OnAllPluginsLoaded()
{
	if(!LibraryExists("shavit-wr"))
	{
		SetFailState("shavit-wr is required for the plugin to work.");
	}

	if(gH_SQL == null)
	{
		Shavit_OnDatabaseLoaded();
	}
}

public void OnPluginStart()
{
	gEV_Type = GetEngineVersion();

	// player commands
	RegConsoleCmd("sm_profile", Command_Profile, "Show the player's profile. Usage: sm_profile [target]");
	RegConsoleCmd("sm_stats", Command_Profile, "Show the player's profile. Usage: sm_profile [target]");

	// translations
	LoadTranslations("common.phrases");
	LoadTranslations("shavit-common.phrases");
	LoadTranslations("shavit-stats.phrases");

	// hooks
	HookEvent("player_spawn", Player_Event);
	HookEvent("player_team", Player_Event);

	// cvars
	gCV_MVPRankOnes = CreateConVar("shavit_stats_mvprankones", "2", "Set the players' amount of MVPs to the amount of #1 times they have.\n0 - Disabled\n1 - Enabled, for all styles.\n2 - Enabled, for default style only.\n(CS:S/CS:GO only)", 0, true, 0.0, true, 2.0);
	gCV_MVPRankOnes_Main = CreateConVar("shavit_stats_mvprankones_maintrack", "1", "If set to 0, all tracks will be counted for the MVP stars.\nOtherwise, only the main track will be checked.\n\nRequires \"shavit_stats_mvprankones\" set to 1 or above.\n(CS:S/CS:GO only)", 0, true, 0.0, true, 1.0);

	gCV_MVPRankOnes.AddChangeHook(OnConVarChanged);
	gCV_MVPRankOnes_Main.AddChangeHook(OnConVarChanged);

	AutoExecConfig();

	gB_Rankings = LibraryExists("shavit-rankings");

	SQL_SetPrefix();

	if(gB_Late)
	{
		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsClientConnected(i) && IsClientInGame(i))
			{
				OnClientPutInServer(i);
			}
		}
	}
}

public void OnMapStart()
{
	if(gB_Late)
	{
		Shavit_OnStyleConfigLoaded(-1);
		Shavit_OnChatConfigLoaded();
	}
}

public void Shavit_OnStyleConfigLoaded(int styles)
{
	if(styles == -1)
	{
		styles = Shavit_GetStyleCount();
	}

	for(int i = 0; i < styles; i++)
	{
		Shavit_GetStyleSettings(i, gA_StyleSettings[i]);
		Shavit_GetStyleStrings(i, sStyleName, gS_StyleStrings[i][sStyleName], 128);
		Shavit_GetStyleStrings(i, sShortName, gS_StyleStrings[i][sShortName], 128);
	}

	gI_Styles = styles;
}

public void Shavit_OnChatConfigLoaded()
{
	for(int i = 0; i < CHATSETTINGS_SIZE; i++)
	{
		Shavit_GetChatStrings(i, gS_ChatStrings[i], 128);
	}
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	gI_MVPRankOnes = gCV_MVPRankOnes.IntValue;
	gB_MVPRankOnes_Main = gCV_MVPRankOnes_Main.BoolValue;
}

public void OnClientPutInServer(int client)
{
	if(IsFakeClient(client))
	{
		return;
	}

	gB_AllowStats[client] = true;
	gI_WRAmount[client] = 0;
	UpdateWRs(client);
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

public void Shavit_OnDatabaseLoaded()
{
	gH_SQL = Shavit_GetDatabase();
	SetSQLInfo();
}

public Action CheckForSQLInfo(Handle Timer)
{
	return SetSQLInfo();
}

Action SetSQLInfo()
{
	if(gH_SQL == null)
	{
		gH_SQL = Shavit_GetDatabase();

		CreateTimer(0.5, CheckForSQLInfo);
	}

	else
	{
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

void SQL_SetPrefix()
{
	char sFile[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sFile, PLATFORM_MAX_PATH, "configs/shavit-prefix.txt");

	File fFile = OpenFile(sFile, "r");

	if(fFile == null)
	{
		SetFailState("Cannot open \"configs/shavit-prefix.txt\". Make sure this file exists and that the server has read permissions to it.");
	}
	
	char sLine[PLATFORM_MAX_PATH*2];

	while(fFile.ReadLine(sLine, PLATFORM_MAX_PATH*2))
	{
		TrimString(sLine);
		strcopy(gS_MySQLPrefix, 32, sLine);

		break;
	}

	delete fFile;
}

public void Player_Event(Event event, const char[] name, bool dontBroadcast)
{
	if(gI_MVPRankOnes == 0)
	{
		return;
	}

	int client = GetClientOfUserId(event.GetInt("userid"));

	if(IsValidClient(client) && !IsFakeClient(client) && gEV_Type != Engine_TF2)
	{
		CS_SetMVPCount(client, gI_WRAmount[client]);
	}
}

void UpdateWRs(int client)
{
	if(gH_SQL == null)
	{
		return;
	}

	char sAuthID[32];

	if(GetClientAuthId(client, AuthId_Steam3, sAuthID, 32))
	{
		char sQuery[256];

		if(gI_MVPRankOnes == 2)
		{
			FormatEx(sQuery, 256, "SELECT COUNT(*) FROM %splayertimes a JOIN (SELECT MIN(time) time FROM %splayertimes WHERE style = 0 %sGROUP by map) b ON a.time = b.time WHERE auth = '%s';", gS_MySQLPrefix, gS_MySQLPrefix, (gB_MVPRankOnes_Main)? "AND track = 0 ":"", sAuthID);
		}

		else
		{
			FormatEx(sQuery, 256, "SELECT COUNT(*) FROM %splayertimes a JOIN (SELECT MIN(time) time FROM %splayertimes %sGROUP by map) b ON a.time = b.time WHERE auth = '%s';", gS_MySQLPrefix, gS_MySQLPrefix, (gB_MVPRankOnes_Main)? "WHERE track = 0 ":"", sAuthID);
		}

		gH_SQL.Query(SQL_GetWRs_Callback, sQuery, GetClientSerial(client));
	}
}

public void SQL_GetWRs_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (get WR amount) SQL query failed. Reason: %s", error);

		return;
	}

	int client = GetClientFromSerial(data);

	if(client == 0 || !results.FetchRow())
	{
		return;
	}

	int iWRs = results.FetchInt(0);

	if(gI_MVPRankOnes > 0 && gEV_Type != Engine_TF2)
	{
		CS_SetMVPCount(client, iWRs);
	}

	gI_WRAmount[client] = iWRs;
}

public Action Command_Profile(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	int target = client;

	if(args > 0)
	{
		char sArgs[64];
		GetCmdArgString(sArgs, 64);

		target = FindTarget(client, sArgs, true, false);

		if(target == -1)
		{
			return Plugin_Handled;
		}
	}

	GetClientAuthId(target, AuthId_Steam3, gS_TargetAuth[client], 32);

	return OpenStatsMenu(client, gS_TargetAuth[client]);
}

Action OpenStatsMenu(int client, const char[] authid)
{
	// no spam please
	if(!gB_AllowStats[client])
	{
		return Plugin_Handled;
	}

	// big ass query, looking for optimizations
	char sQuery[2048];

	if(gB_Rankings)
	{
		FormatEx(sQuery, 2048, "SELECT a.clears, b.maps, c.wrs, d.name, d.country, d.lastlogin, d.points, e.rank FROM " ...
				"(SELECT COUNT(*) clears FROM (SELECT id FROM %splayertimes WHERE auth = '%s' AND track = 0 GROUP BY map) s) a " ...
				"JOIN (SELECT COUNT(*) maps FROM (SELECT id FROM %smapzones WHERE track = 0 GROUP BY map) s) b " ...
				"JOIN (SELECT COUNT(*) wrs FROM %splayertimes a JOIN (SELECT MIN(time) time FROM %splayertimes WHERE style = 0 AND track = 0 GROUP by map) b ON a.time = b.time WHERE auth = '%s') c " ...
				"JOIN (SELECT name, country, lastlogin, FORMAT(points, 2) points FROM %susers WHERE auth = '%s' LIMIT 1) d " ...
				"JOIN (SELECT FORMAT(COUNT(*), 0) rank FROM %susers WHERE points >= (SELECT points FROM %susers WHERE auth = '%s' LIMIT 1) ORDER BY points DESC LIMIT 1) e " ...
			"LIMIT 1;", gS_MySQLPrefix, authid, gS_MySQLPrefix, gS_MySQLPrefix, gS_MySQLPrefix, authid, gS_MySQLPrefix, authid, gS_MySQLPrefix, gS_MySQLPrefix, authid);
	}

	else
	{
		FormatEx(sQuery, 2048, "SELECT a.clears, b.maps, c.wrs, d.name, d.country, d.lastlogin FROM " ...
				"(SELECT COUNT(*) clears FROM (SELECT id FROM %splayertimes WHERE auth = '%s' AND track = 0 GROUP BY map) s) a " ...
				"JOIN (SELECT COUNT(*) maps FROM (SELECT id FROM %smapzones WHERE track = 0 GROUP BY map) s) b " ...
				"JOIN (SELECT COUNT(*) wrs FROM %splayertimes a JOIN (SELECT MIN(time) time FROM %splayertimes WHERE style = 0 AND track = 0 GROUP by map) b ON a.time = b.time WHERE auth = '%s') c " ...
				"JOIN (SELECT name, country, lastlogin FROM %susers WHERE auth = '%s' LIMIT 1) d " ...
			"LIMIT 1;", gS_MySQLPrefix, authid, gS_MySQLPrefix, gS_MySQLPrefix, gS_MySQLPrefix, authid, gS_MySQLPrefix, authid);
	}

	gB_AllowStats[client] = false;
	gH_SQL.Query(OpenStatsMenuCallback, sQuery, GetClientSerial(client), DBPrio_Low);

	return Plugin_Handled;
}

public void OpenStatsMenuCallback(Database db, DBResultSet results, const char[] error, any data)
{
	int client = GetClientFromSerial(data);
	gB_AllowStats[client] = true;

	if(results == null)
	{
		LogError("Timer (statsmenu) SQL query failed. Reason: %s", error);

		return;
	}

	if(client == 0)
	{
		return;
	}

	if(results.FetchRow())
	{
		// create variables
		int iClears = results.FetchInt(0);
		int iTotalMaps = results.FetchInt(1);
		int iWRs = results.FetchInt(2);
		results.FetchString(3, gS_TargetName[client], MAX_NAME_LENGTH);
		ReplaceString(gS_TargetName[client], MAX_NAME_LENGTH, "#", "?");

		char sCountry[64];
		results.FetchString(4, sCountry, 64);

		int iLastLogin = results.FetchInt(5);
		char sLastLogin[32];
		FormatTime(sLastLogin, 32, "%Y-%m-%d %H:%M:%S", iLastLogin);
		Format(sLastLogin, 32, "%T: %s", "LastLogin", client, (iLastLogin != -1)? sLastLogin:"N/A");

		char sPoints[16];
		char sRank[16];

		if(gB_Rankings)
		{
			results.FetchString(6, sPoints, 16);
			results.FetchString(7, sRank, 16);
		}

		char sRankingString[64];

		if(gB_Rankings)
		{
			if(StringToInt(sRank) > 0 && StringToInt(sPoints) > 0)
			{
				FormatEx(sRankingString, 64, "\n%T: #%s/%d\n%T: %s", "Rank", client, sRank, Shavit_GetRankedPlayers(), "Points", client, sPoints);
			}

			else
			{
				FormatEx(sRankingString, 64, "\n%T: %T", "Rank", client, "PointsUnranked", client);
			}
		}

		if(iClears > iTotalMaps)
		{
			iClears = iTotalMaps;
		}

		char sClearString[128];
		FormatEx(sClearString, 128, "%T: %d/%d (%.01f%%)", "MapCompletions", client, iClears, iTotalMaps, ((float(iClears) / iTotalMaps) * 100.0));

		Menu menu = new Menu(MenuHandler_ProfileHandler);
		menu.SetTitle("%s's %T. %s\n%T: %s\n%s\n%s\n[%s] %T: %d%s\n", gS_TargetName[client], "Profile", client, gS_TargetAuth[client], "Country", client, sCountry, sLastLogin, sClearString, gS_StyleStrings[0][sStyleName], "WorldRecords", client, iWRs, sRankingString);

		for(int i = 0; i < gI_Styles; i++)
		{
			if(gA_StyleSettings[i][bUnranked])
			{
				continue;
			}

			char sInfo[4];
			IntToString(i, sInfo, 4);

			menu.AddItem(sInfo, gS_StyleStrings[i][sStyleName]);
		}

		// should NEVER happen
		if(menu.ItemCount == 0)
		{
			char sMenuItem[64];
			FormatEx(sMenuItem, 64, "%T", "NoRecords", client);
			menu.AddItem("-1", sMenuItem);
		}

		menu.ExitButton = true;
		menu.Display(client, 20);
	}

	else
	{
		Shavit_PrintToChat(client, "%T", "StatsMenuFailure", client, gS_ChatStrings[sMessageWarning], gS_ChatStrings[sMessageText]);
	}
}

public int MenuHandler_ProfileHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[32];

		menu.GetItem(param2, sInfo, 32);
		gBS_Style[param1] = StringToInt(sInfo);

		Menu submenu = new Menu(MenuHandler_TypeHandler);
		submenu.SetTitle("%T", "MapsMenu", param1, gS_StyleStrings[gBS_Style[param1]][sShortName]);

		for(int j = 0; j < TRACKS_SIZE; j++)
		{
			char sTrack[32];
			GetTrackName(param1, j, sTrack, 32);

			char sMenuItem[64];
			FormatEx(sMenuItem, 64, "%T (%s)", "MapsDone", param1, sTrack);

			char sNewInfo[32];
			FormatEx(sNewInfo, 32, "%d;0", j);
			submenu.AddItem(sNewInfo, sMenuItem);

			FormatEx(sMenuItem, 64, "%T (%s)", "MapsLeft", param1, sTrack);
			FormatEx(sNewInfo, 32, "%d;1", j);
			submenu.AddItem(sNewInfo, sMenuItem);
		}

		submenu.ExitBackButton = true;
		submenu.Display(param1, 20);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

public int MenuHandler_TypeHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[32];
		menu.GetItem(param2, sInfo, 32);

		char sExploded[2][4];
		ExplodeString(sInfo, ";", sExploded, 2, 4);

		gI_Track[param1] = StringToInt(sExploded[0]);
		gI_MapType[param1] = StringToInt(sExploded[1]);

		ShowMaps(param1);
	}

	else if(action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		OpenStatsMenu(param1, gS_TargetAuth[param1]);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

public Action Timer_DBFailure(Handle timer, any data)
{
	int client = GetClientFromSerial(data);

	if(client == 0)
	{
		return Plugin_Stop;
	}

	ShowMaps(client);

	return Plugin_Stop;
}

void ShowMaps(int client)
{
	// database not found, display with a 3 seconds delay
	if(gH_SQL == null)
	{
		CreateTimer(3.0, Timer_DBFailure, GetClientSerial(client));

		return;
	}

	char sQuery[512];

	if(gI_MapType[client] == MAPSDONE)
	{
		FormatEx(sQuery, 512, "SELECT a.map, a.time, a.jumps, a.id, COUNT(b.map) + 1 rank, a.points FROM %splayertimes a LEFT JOIN %splayertimes b ON a.time > b.time AND a.map = b.map AND a.style = b.style AND a.track = b.track WHERE a.auth = '%s' AND a.style = %d AND a.track = %d GROUP BY a.map ORDER BY a.%s;", gS_MySQLPrefix, gS_MySQLPrefix, gS_TargetAuth[client], gBS_Style[client], gI_Track[client], (gB_Rankings)? "points DESC":"map");
	}

	else
	{
		FormatEx(sQuery, 512, "SELECT DISTINCT m.map FROM %smapzones m LEFT JOIN %splayertimes r ON r.map = m.map AND r.auth = '%s' AND r.style = %d AND m.track = %d WHERE r.map IS NULL AND m.track = %d ORDER BY m.map;", gS_MySQLPrefix, gS_MySQLPrefix, gS_TargetAuth[client], gBS_Style[client], gI_Track[client], gI_Track[client]);
	}

	gH_SQL.Query(ShowMapsCallback, sQuery, GetClientSerial(client), DBPrio_High);
}

public void ShowMapsCallback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (ShowMaps SELECT) SQL query failed. Reason: %s", error);

		return;
	}

	int client = GetClientFromSerial(data);

	if(client == 0)
	{
		return;
	}

	int rows = results.RowCount;

	char sTrack[32];
	GetTrackName(client, gI_Track[client], sTrack, 32);

	Menu menu = new Menu(MenuHandler_ShowMaps);

	if(gI_MapType[client] == MAPSDONE)
	{
		menu.SetTitle("%T (%s)", "MapsDoneFor", client, gS_StyleStrings[gBS_Style[client]][sShortName], gS_TargetName[client], rows, sTrack);
	}

	else
	{
		menu.SetTitle("%T (%s)", "MapsLeftFor", client, gS_StyleStrings[gBS_Style[client]][sShortName], gS_TargetName[client], rows, sTrack);
	}

	while(results.FetchRow())
	{
		char sMap[192];
		results.FetchString(0, sMap, 192);

		char sRecordID[16];
		char sDisplay[256];

		if(gI_MapType[client] == MAPSDONE)
		{
			float time = results.FetchFloat(1);
			int jumps = results.FetchInt(2);
			int rank = results.FetchInt(4);

			char sTime[32];
			FormatSeconds(time, sTime, 32);

			float points = results.FetchFloat(5);

			if(gB_Rankings && points > 0.0)
			{
				FormatEx(sDisplay, 192, "[#%d] %s - %s (%.03f %T)", rank, sMap, sTime, points, "MapsPoints", client);
			}

			else
			{
				FormatEx(sDisplay, 192, "[#%d] %s - %s (%d %T)", rank, sMap, sTime, jumps, "MapsJumps", client);
			}

			int iRecordID = results.FetchInt(3);
			IntToString(iRecordID, sRecordID, 16);
		}

		else
		{
			strcopy(sDisplay, 192, sMap);
			strcopy(sRecordID, 16, "nope");
		}

		menu.AddItem(sRecordID, sDisplay);
	}

	if(menu.ItemCount == 0)
	{
		char sMenuItem[64];
		FormatEx(sMenuItem, 64, "%T", "NoResults", client);
		menu.AddItem("nope", sMenuItem);
	}

	menu.ExitBackButton = true;
	menu.Display(client, 60);
}

public int MenuHandler_ShowMaps(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[16];
		menu.GetItem(param2, sInfo, 16);

		if(StrEqual(sInfo, "nope"))
		{
			OpenStatsMenu(param1, gS_TargetAuth[param1]);

			return 0;
		}

		char sQuery[512];
		FormatEx(sQuery, 512, "SELECT u.name, p.time, p.jumps, p.style, u.auth, p.date, p.map, p.strafes, p.sync, p.points FROM %splayertimes p JOIN %susers u ON p.auth = u.auth WHERE p.id = '%s' LIMIT 1;", gS_MySQLPrefix, gS_MySQLPrefix, sInfo);

		gH_SQL.Query(SQL_SubMenu_Callback, sQuery, GetClientSerial(param1));
	}

	else if(action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		OpenStatsMenu(param1, gS_TargetAuth[param1]);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

public void SQL_SubMenu_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (STATS SUBMENU) SQL query failed. Reason: %s", error);

		return;
	}

	int client = GetClientFromSerial(data);

	if(client == 0)
	{
		return;
	}

	Menu menu = new Menu(SubMenu_Handler);

	char sName[MAX_NAME_LENGTH];
	char sAuthID[32];
	char sMap[192];

	if(results.FetchRow())
	{
		// 0 - name
		results.FetchString(0, sName, MAX_NAME_LENGTH);

		// 1 - time
		float time = results.FetchFloat(1);
		char sTime[16];
		FormatSeconds(time, sTime, 16);

		char sDisplay[128];
		FormatEx(sDisplay, 128, "%T: %s", "Time", client, sTime);
		menu.AddItem("-1", sDisplay);

		// 2 - jumps
		int jumps = results.FetchInt(2);
		FormatEx(sDisplay, 128, "%T: %d", "Jumps", client, jumps);
		menu.AddItem("-1", sDisplay);

		// 3 - style
		int style = results.FetchInt(3);
		FormatEx(sDisplay, 128, "%T: %s", "Style", client, gS_StyleStrings[style][sStyleName]);
		menu.AddItem("-1", sDisplay);

		// 4 - steamid3
		results.FetchString(4, sAuthID, 32);

		// 6 - map
		results.FetchString(6, sMap, 192);

		float points = results.FetchFloat(9);

		if(gB_Rankings && points > 0.0)
		{
			FormatEx(sDisplay, 192, "%T: %.03f", "Points", client, points);
			menu.AddItem("-1", sDisplay);
		}

		// 5 - date
		char sDate[32];
		results.FetchString(5, sDate, 32);

		if(sDate[4] != '-')
		{
			FormatTime(sDate, 32, "%Y-%m-%d %H:%M:%S", StringToInt(sDate));
		}

		FormatEx(sDisplay, 128, "%T: %s", "Date", client, sDate);
		menu.AddItem("-1", sDisplay);

		int strafes = results.FetchInt(7);
		float sync = results.FetchFloat(8);

		if(jumps > 0 || strafes > 0)
		{
			FormatEx(sDisplay, 128, (sync > 0.0)? "%T: %d (%.02f%%)":"%T: %d", "Strafes", client, strafes, sync, "Strafes", client, strafes);
			menu.AddItem("-1", sDisplay);
		}
	}

	char sFormattedTitle[256];
	FormatEx(sFormattedTitle, 256, "%s %s\n--- %s:", sName, sAuthID, sMap);

	menu.SetTitle(sFormattedTitle);
	menu.ExitBackButton = true;
	menu.Display(client, 20);
}

public int SubMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		ShowMaps(param1);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

public int Native_OpenStatsMenu(Handle handler, int numParams)
{
	int client = GetNativeCell(1);
	GetNativeString(2, gS_TargetAuth[client], 32);

	OpenStatsMenu(client, gS_TargetAuth[client]);
}

public int Native_GetWRCount(Handle handler, int numParams)
{
	return gI_WRAmount[GetNativeCell(1)];
}

void GetTrackName(int client, int track, char[] output, int size)
{
	if(track < 0 || track >= TRACKS_SIZE)
	{
		FormatEx(output, size, "%T", "Track_Unknown", client);

		return;
	}

	static char sTrack[16];
	FormatEx(sTrack, 16, "Track_%d", track);
	FormatEx(output, size, "%T", sTrack, client);
}
