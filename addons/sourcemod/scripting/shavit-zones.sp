/*
 * shavit's Timer - Map Zones
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
#include <sdktools>
#include <sdkhooks>
#include <regex>
#include <convar_class>
#include <shavit>
#include <shavit/rankings>

#undef REQUIRE_PLUGIN
#include <adminmenu>
#include <shavit/stage>

#undef REQUIRE_EXTENSIONS
#include <cstrike>

#pragma semicolon 1
#pragma dynamic 131072
#pragma newdecls required

#define EF_NODRAW 32
#define MAX(%1,%2) (%1>%2?%1:%2)

Database2 gH_SQL = null;
bool gB_Connected = false;
bool gB_MySQL = false;

char gS_Map[160];

enum
{
	EditStep_None, // 0 - nothing
	EditStep_First, // 1 - wait for E tap to setup first coord
	EditStep_Second, // 2 - wait for E tap to setup second coord
	EditStep_Third, // 3 - wait for E tap to setup height
	EditStep_Final // 4 - confirm
};

enum struct zone_cache_t
{
	bool bZoneInitialized;
	bool bHooked;
	int iZoneType;
	int iZoneTrack; // 0 - main, 1 - bonus etc
	int iEntityID;
	int iDatabaseID;
	int iZoneFlags;
	int iZoneData;
	int iHookedHammerID;
	char sZoneHookname[128];
	float fLimitSpeed;
}

enum struct zone_settings_t
{
	bool bVisible;
	int iRed;
	int iGreen;
	int iBlue;
	int iAlpha;
	float fWidth;
	bool bFlatZone;
	bool bUseVanillaSprite;
	bool bNoHalo;
	int iBeam;
	int iHalo;
	char sBeam[PLATFORM_MAX_PATH];
}

enum
{
	ZF_ForceRender = (1 << 0)
};

int gI_ZoneType[MAXPLAYERS+1];

int gI_MapStep[MAXPLAYERS+1];

float gF_Modifier[MAXPLAYERS+1];
int gI_GridSnap[MAXPLAYERS+1];
bool gB_SnapToWall[MAXPLAYERS+1];
bool gB_CursorTracing[MAXPLAYERS+1];
int gI_ZoneFlags[MAXPLAYERS+1];
int gI_ZoneData[MAXPLAYERS+1][ZONETYPES_SIZE];
int gI_ZoneMaxData[TRACKS_SIZE];
bool gB_WaitingForDataInput[MAXPLAYERS+1];
bool gB_WaitingForLimitSpeedInput[MAXPLAYERS+1];
bool gB_HookZoneConfirm[MAXPLAYERS+1];
bool gB_ShowTriggers[MAXPLAYERS+1];

// cache
float gV_Point1[MAXPLAYERS+1][3];
float gV_Point2[MAXPLAYERS+1][3];
float gV_Teleport[MAXPLAYERS+1][3];
float gV_WallSnap[MAXPLAYERS+1][3];
bool gB_Button[MAXPLAYERS+1];
bool gB_InsideZone[MAXPLAYERS+1][ZONETYPES_SIZE][TRACKS_SIZE];
bool gB_InsideZoneID[MAXPLAYERS+1][MAX_ZONES];
int gI_InsideZoneIndex[MAXPLAYERS+1];
int gI_ZoneTrack[MAXPLAYERS+1];
int gI_ZoneDatabaseID[MAXPLAYERS+1];
int gI_ZoneID[MAXPLAYERS+1];
int gI_HookZoneHammerID[MAXPLAYERS+1];
int gI_HookZoneIndex[MAXPLAYERS+1];
int gI_LastStartZoneIndex[MAXPLAYERS+1][TRACKS_SIZE];
char gS_ZoneHookname[MAXPLAYERS+1][128];
float gF_ZoneLimitSpeed[MAXPLAYERS+1];

// zone cache
zone_settings_t gA_ZoneSettings[ZONETYPES_SIZE][TRACKS_SIZE];
zone_cache_t gA_ZoneCache[MAX_ZONES];
int gI_MapZones = 0;
float gV_MapZones[MAX_ZONES][2][3];
float gV_MapZones_Visual[MAX_ZONES][8][3];
float gV_Destinations[MAX_ZONES][3];
float gV_CustomDestinations[MAXPLAYERS+1][MAX_ZONES][3];
float gV_CustomDestinationsAngle[MAXPLAYERS+1][MAX_ZONES][3];
float gV_ZoneCenter[MAX_ZONES][3];
int gI_EntityZone[4096];
ArrayList gA_Triggers;
ArrayList gA_HookTriggers;
ArrayList gA_TeleDestination;
bool gB_ZonesCreated = false;
int gI_Bonuses;
int gI_Stages; // how many stages in a map, default 1.
int gI_Checkpoints; // how many checkpoint zones in a map, default 0.

char gS_BeamSprite[PLATFORM_MAX_PATH];
int gI_Offset_m_fEffects = -1;

// admin menu
TopMenu gH_AdminMenu = null;
TopMenuObject gH_TimerCommands = INVALID_TOPMENUOBJECT;

// cvars
Convar gCV_Interval = null;
Convar gCV_TeleportToEnd = null;
Convar gCV_UseCustomSprite = null;
Convar gCV_Offset = null;
Convar gCV_EnforceTracks = null;
Convar gCV_PreSpeed = null;
Convar gCV_EntrySpeedLimit = null;
Convar gCV_PreBuildZone = null;

// handles
Handle gH_DrawEverything = null;
Handle gH_DrawZonesToClient[MAXPLAYERS+1] = {null, ...};

// table prefix
char gS_MySQLPrefix[32];

// forwards
Handle gH_Forwards_EnterZone = null;
Handle gH_Forwards_LeaveZone = null;
Handle gH_Forwards_BotEnterStageZone = null;
Handle gH_Forwards_BotEnterCheckpointZone = null;
Handle gH_Forwards_StartTimer_Post = null;
Handle gH_Forwards_StageTimer_Post = null;
Handle gH_Forwards_OnStage = null;
Handle gH_Forwards_OnEndZone = null;
Handle gH_Forwards_OnTeleportBackStagePost = null;

bool gB_LinearMap;
bool gB_DrawEditZone[MAXPLAYERS+1];

// prespeed limit
int gI_Jumps[MAXPLAYERS+1];
bool gB_OnGround[MAXPLAYERS+1];
bool gB_InZone[MAXPLAYERS+1];

// antijump zone
int gI_LastButtons[MAXPLAYERS+1];
bool gB_AntiJump[MAXPLAYERS+1];

public Plugin myinfo =
{
	name = "[shavit] Map Zones",
	author = "shavit",
	description = "Map zones for shavit's bhop timer.",
	version = SHAVIT_VERSION,
	url = "https://github.com/shavitush/bhoptimer"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	// zone natives
	CreateNative("Shavit_GetZoneData", Native_GetZoneData);
	CreateNative("Shavit_GetZoneFlags", Native_GetZoneFlags);
	CreateNative("Shavit_GetMapBonuses", Native_GetMapBonuses);
	CreateNative("Shavit_GetMapStages", Native_GetMapStages);
	CreateNative("Shavit_GetMapCheckpoints", Native_GetMapCheckpoints);
	CreateNative("Shavit_InsideZone", Native_InsideZone);
	CreateNative("Shavit_InsideZoneGetID", Native_InsideZoneGetID);
	CreateNative("Shavit_InsideZoneGetType", Native_InsideZoneGetType);
	CreateNative("Shavit_IsLinearMap", Native_IsLinearMap);
	CreateNative("Shavit_IsClientCreatingZone", Native_IsClientCreatingZone);
	CreateNative("Shavit_ZoneExists", Native_ZoneExists);
	CreateNative("Shavit_Zones_DeleteMap", Native_Zones_DeleteMap);

	// registers library, check "bool LibraryExists(const char[] name)" in order to use with other plugins
	RegPluginLibrary("shavit-zones");

	return APLRes_Success;
}

public void OnPluginStart()
{
	if(GetEngineVersion() != Engine_CSS)
	{
		SetFailState("This plugin only support for CSS!");
		return;
	}

	LoadTranslations("shavit-common.phrases");
	LoadTranslations("shavit-zones.phrases");

	gI_Offset_m_fEffects = FindSendPropInfo("CBaseEntity", "m_fEffects");

	if(gI_Offset_m_fEffects == -1)
	{
		SetFailState("Could not find CBaseEntity:m_fEffects");
	}

	RegConsoleCmd("sm_showtrigger", Command_ShowTriggers, "Command to dynamically toggle trigger visibility");
	RegConsoleCmd("sm_showtriggers", Command_ShowTriggers, "Command to dynamically toggle trigger visibility");
	RegConsoleCmd("sm_showzones", Command_ShowTriggers, "Command to dynamically toggle shavit's zones trigger visibility");
	RegConsoleCmd("sm_findtele", Command_FindTeleDestination, "Show teleport_destination entities menu");
	RegConsoleCmd("sm_findteles", Command_FindTeleDestination, "Show teleport_destination entities menu. Alias of sm_findtele");
	RegConsoleCmd("sm_telefinder", Command_FindTeleDestination, "Show teleport_destination entities menu. Alias of sm_findtele");

	// menu
	RegAdminCmd("sm_zone", Command_Zones, ADMFLAG_RCON, "Opens the mapzones menu.");
	RegAdminCmd("sm_zones", Command_Zones, ADMFLAG_RCON, "Opens the mapzones menu.");
	RegAdminCmd("sm_addzone", Command_AddZones, ADMFLAG_RCON, "Opens the addzones menu.");
	RegAdminCmd("sm_addzones", Command_AddZones, ADMFLAG_RCON, "Opens the addzones menu.");
	RegAdminCmd("sm_mapzone", Command_AddZones, ADMFLAG_RCON, "Opens the addzones menu. Alias of sm_addzones.");
	RegAdminCmd("sm_mapzones", Command_AddZones, ADMFLAG_RCON, "Opens the addzones menu. Alias of sm_addzones.");
	RegAdminCmd("sm_hookzone", Command_HookZones, ADMFLAG_RCON, "Opens the addHookzones menu.");
	RegAdminCmd("sm_hookzones", Command_HookZones, ADMFLAG_RCON, "Opens the addHookzones menu. Alias of sm_hookzone.");

	RegAdminCmd("sm_delzone", Command_DeleteZone, ADMFLAG_RCON, "Delete a mapzone");
	RegAdminCmd("sm_delzones", Command_DeleteZone, ADMFLAG_RCON, "Delete a mapzone");
	RegAdminCmd("sm_deletezone", Command_DeleteZone, ADMFLAG_RCON, "Delete a mapzone");
	RegAdminCmd("sm_deletezones", Command_DeleteZone, ADMFLAG_RCON, "Delete a mapzone");
	RegAdminCmd("sm_deleteallzones", Command_DeleteAllZones, ADMFLAG_RCON, "Delete all mapzones");

	RegAdminCmd("sm_modifier", Command_Modifier, ADMFLAG_RCON, "Changes the axis modifier for the zone editor. Usage: sm_modifier <number>");

	RegAdminCmd("sm_editzone", Command_ZoneEdit, ADMFLAG_RCON, "Modify an existing zone.");
	RegAdminCmd("sm_editzones", Command_ZoneEdit, ADMFLAG_RCON, "Modify an existing zone.");
	RegAdminCmd("sm_zoneedit", Command_ZoneEdit, ADMFLAG_RCON, "Modify an existing zone.");

	RegAdminCmd("sm_prebuild", Command_ZonePreBuild, ADMFLAG_RCON, "Prebuild zones.");

	RegAdminCmd("sm_reloadzonesettings", Command_ReloadZoneSettings, ADMFLAG_ROOT, "Reloads the zone settings.");

	RegConsoleCmd("sm_stages", Command_Stages, "Opens the stage menu. Usage: sm_stages [stage #]");
	RegConsoleCmd("sm_stage", Command_Stages, "Opens the stage menu. Usage: sm_stage [stage #]");
	RegConsoleCmd("sm_s", Command_Stages, "Opens the stage menu. Usage: sm_stage [stage #]");

	RegConsoleCmd("sm_back", Command_Back, "Go back to the current stage zone.");
	RegConsoleCmd("sm_teleport", Command_Back, "Go back to the current stage zone. Alias of sm_back");

	RegConsoleCmd("sm_setstart", Command_Startpos, "Set track/stage startzones position.");
	RegConsoleCmd("sm_startpos", Command_Startpos, "Set track/stage startzones position. Alias of sm_setstart.");
	RegConsoleCmd("sm_ss", Command_Startpos, "Set track/stage startzones position. Alias of sm_setstart.");

	// events
	HookEvent("round_start", Round_Start);

	// forwards
	gH_Forwards_EnterZone = CreateGlobalForward("Shavit_OnEnterZone", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	gH_Forwards_LeaveZone = CreateGlobalForward("Shavit_OnLeaveZone", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	gH_Forwards_BotEnterStageZone = CreateGlobalForward("Shavit_OnEnterStageZone_Bot", ET_Event, Param_Cell, Param_Cell);
	gH_Forwards_BotEnterCheckpointZone = CreateGlobalForward("Shavit_OnEnterCheckpointZone_Bot", ET_Event, Param_Cell, Param_Cell);
	gH_Forwards_StartTimer_Post = CreateGlobalForward("Shavit_OnStartTimer_Post", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_Float);
	gH_Forwards_StageTimer_Post = CreateGlobalForward("Shavit_OnStageTimer_Post", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_Float);
	gH_Forwards_OnStage = CreateGlobalForward("Shavit_OnStage", ET_Event, Param_Cell, Param_Cell);
	gH_Forwards_OnEndZone = CreateGlobalForward("Shavit_OnEndZone", ET_Event, Param_Cell);
	gH_Forwards_OnTeleportBackStagePost = CreateGlobalForward("Shavit_OnTeleportBackStagePost", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_Cell);

	// cvars and stuff
	gCV_Interval = new Convar("shavit_zones_interval", "1.0", "Interval between each time a mapzone is being drawn to the players.", 0, true, 0.5, true, 5.0);
	gCV_TeleportToEnd = new Convar("shavit_zones_teleporttoend", "1", "Teleport players to the end zone on sm_end?\n0 - Disabled\n1 - Enabled", 0, true, 0.0, true, 1.0);
	gCV_UseCustomSprite = new Convar("shavit_zones_usecustomsprite", "0", "Use custom sprite for zone drawing?\nSee `configs/shavit-zones.cfg`.\n0 - Disabled\n1 - Enabled", 0, true, 0.0, true, 1.0);
	gCV_Offset = new Convar("shavit_zones_offset", "0", "When calculating a zone's *VISUAL* box, by how many units, should we scale it to the center?\n0.0 - no downscaling. Values above 0 will scale it inward and negative numbers will scale it outwards.\nAdjust this value if the zones clip into walls.");
	gCV_EnforceTracks = new Convar("shavit_zones_enforcetracks", "1", "Enforce zone tracks upon entry?\n0 - allow every zone to affect users on every zone.\n1 - require the user's track to match the zone's track.", 0, true, 0.0, true, 1.0);
	gCV_PreSpeed = new Convar("shavit_zones_prespeed", "1", "Stop prespeeding in the start zone?\n0 - Disabled, fully allow prespeeding.\n1 - SurfHeaven Limitspeed", 0, true, 0.0, true, 1.0);
	gCV_EntrySpeedLimit = new Convar("shavit_zones_entryzonespeedlimit", "500.0", "Maximum speed at which entry into the start/stage zone will not be slowed down.\n(***Make sure shavit_misc_prespeed set to 1***)", 0, true, 260.0);
	gCV_PreBuildZone = new Convar("shavit_zones_prebuild", "0", "Auto prebuild zones when current map have no zones.\n0 - Disabled.\n1 - Enabled", 0, true, 0.0, true, 1.0);

	gCV_Interval.AddChangeHook(OnConVarChanged);
	gCV_UseCustomSprite.AddChangeHook(OnConVarChanged);
	gCV_Offset.AddChangeHook(OnConVarChanged);

	Convar.AutoExecConfig();

	for(int i = 0; i < ZONETYPES_SIZE; i++)
	{
		for(int j = 0; j < TRACKS_SIZE; j++)
		{
			gA_ZoneSettings[i][j].bVisible = true;
			gA_ZoneSettings[i][j].iRed = 255;
			gA_ZoneSettings[i][j].iGreen = 255;
			gA_ZoneSettings[i][j].iBlue = 255;
			gA_ZoneSettings[i][j].iAlpha = 255;
			gA_ZoneSettings[i][j].fWidth = 2.0;
			gA_ZoneSettings[i][j].bFlatZone = false;
		}
	}

	SQL_DBConnect();
}

public void OnAllPluginsLoaded()
{
	// admin menu
	if(LibraryExists("adminmenu") && ((gH_AdminMenu = GetAdminTopMenu()) != null))
	{
		OnAdminMenuReady(gH_AdminMenu);
	}
}

public void OnLibraryAdded(const char[] name)
{
	if(strcmp(name, "adminmenu") == 0)
	{
		if ((gH_AdminMenu = GetAdminTopMenu()) != null)
		{
			OnAdminMenuReady(gH_AdminMenu);
		}
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if(strcmp(name, "adminmenu") == 0)
	{
		gH_AdminMenu = null;
		gH_TimerCommands = INVALID_TOPMENUOBJECT;
	}
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if(convar == gCV_Interval)
	{
		delete gH_DrawEverything;
		gH_DrawEverything = CreateTimer(gCV_Interval.FloatValue, Timer_DrawEverything, INVALID_HANDLE, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}

	else if(convar == gCV_Offset && gI_MapZones > 0)
	{
		for(int i = 0; i < gI_MapZones; i++)
		{
			if(!gA_ZoneCache[i].bZoneInitialized)
			{
				continue;
			}

			gV_MapZones_Visual[i][0][0] = gV_MapZones[i][0][0];
			gV_MapZones_Visual[i][0][1] = gV_MapZones[i][0][1];
			gV_MapZones_Visual[i][0][2] = gV_MapZones[i][0][2];
			gV_MapZones_Visual[i][7][0] = gV_MapZones[i][1][0];
			gV_MapZones_Visual[i][7][1] = gV_MapZones[i][1][1];
			gV_MapZones_Visual[i][7][2] = gV_MapZones[i][1][2];

			CreateZonePoints(gV_MapZones_Visual[i], gCV_Offset.FloatValue);
		}
	}

	else if(convar == gCV_UseCustomSprite && !StrEqual(oldValue, newValue))
	{
		LoadZoneSettings();
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

		gH_AdminMenu.AddItem("sm_zones", AdminMenu_Zones, gH_TimerCommands, "sm_zones", ADMFLAG_RCON);
		gH_AdminMenu.AddItem("sm_deletezone", AdminMenu_DeleteZone, gH_TimerCommands, "sm_deletezone", ADMFLAG_RCON);
		gH_AdminMenu.AddItem("sm_deleteallzones", AdminMenu_DeleteAllZones, gH_TimerCommands, "sm_deleteallzones", ADMFLAG_RCON);
		gH_AdminMenu.AddItem("sm_zoneedit", AdminMenu_ZoneEdit, gH_TimerCommands, "sm_zoneedit", ADMFLAG_RCON);
	}
}

public void AdminMenu_Zones(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	if(action == TopMenuAction_DisplayOption)
	{
		FormatEx(buffer, maxlength, "%T", "AddMapZone", param);
	}

	else if(action == TopMenuAction_SelectOption)
	{
		Command_AddZones(param, 0);
	}
}

public void AdminMenu_DeleteZone(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	if(action == TopMenuAction_DisplayOption)
	{
		FormatEx(buffer, maxlength, "%T", "DeleteMapZone", param);
	}

	else if(action == TopMenuAction_SelectOption)
	{
		Command_DeleteZone(param, 0);
	}
}

public void AdminMenu_DeleteAllZones(Handle topmenu,  TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	if(action == TopMenuAction_DisplayOption)
	{
		FormatEx(buffer, maxlength, "%T", "DeleteAllMapZone", param);
	}

	else if(action == TopMenuAction_SelectOption)
	{
		Command_DeleteAllZones(param, 0);
	}
}

public void AdminMenu_ZoneEdit(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	if(action == TopMenuAction_DisplayOption)
	{
		FormatEx(buffer, maxlength, "%T", "ZoneEdit", param);
	}

	else if(action == TopMenuAction_SelectOption)
	{
		Reset(param);
		OpenEditMenu(param);
	}
}

public int Native_ZoneExists(Handle handler, int numParams)
{
	return (GetZoneIndex(GetNativeCell(1), GetNativeCell(2)) != -1);
}

public int Native_GetZoneData(Handle handler, int numParams)
{
	return gA_ZoneCache[GetNativeCell(1)].iZoneData;
}

public int Native_GetZoneFlags(Handle handler, int numParams)
{
	return gA_ZoneCache[GetNativeCell(1)].iZoneFlags;
}

public int Native_InsideZone(Handle handler, int numParams)
{
	return InsideZone(GetNativeCell(1), GetNativeCell(2), GetNativeCell(3));
}

public int Native_InsideZoneGetID(Handle handler, int numParams)
{
	return InsideZoneGetID(GetNativeCell(1), GetNativeCell(2), GetNativeCell(3));
}

public int Native_InsideZoneGetType(Handle handler, int numParams)
{
	return InsideZoneGetType(GetNativeCell(1), GetNativeCell(2));
}

public int Native_IsLinearMap(Handle handler, int numParams)
{
	return gB_LinearMap;
}

public int Native_Zones_DeleteMap(Handle handler, int numParams)
{
	char sMap[160];
	GetNativeString(1, sMap, 160);

	DeleteMapAllZones(sMap);

	return 0;
}

void DeleteMapAllZones(const char[] map)
{
	char sQuery[256];
	FormatEx(sQuery, 256, "DELETE FROM %smapzones WHERE map = '%s';", gS_MySQLPrefix, map);
	gH_SQL.Query(SQL_DeleteMap_Callback, sQuery, StrEqual(gS_Map, map, false), DBPrio_High);
}

public void SQL_DeleteMap_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (zones deletemap) SQL query failed. Reason: %s", error);

		return;
	}

	if(view_as<bool>(data))
	{
		UnloadZones(0);

		Shavit_PrintToChatAll("%T", "ZoneDeleteAllSuccessful", LANG_SERVER);
	}
}

bool InsideZone(int client, int type, int track)
{
	if(track != -1)
	{
		return gB_InsideZone[client][type][track];
	}
	else
	{
		for(int i = 0; i < TRACKS_SIZE; i++)
		{
			if(gB_InsideZone[client][type][i])
			{
				return true;
			}
		}
	}

	return false;
}

int InsideZoneGetID(int client, int type, int track)
{
	for(int i = 0; i < MAX_ZONES; i++)
	{
		if(gB_InsideZoneID[client][i] &&
			gA_ZoneCache[i].iZoneType == type &&
			(gA_ZoneCache[i].iZoneTrack == track || track == -1))
		{
			return i;
		}
	}

	return -1;
}

int InsideZoneGetType(int client, int track)
{
	for(int i = 0; i < ZONETYPES_SIZE; i++)
	{
		if(track != -1)
		{
			if(gB_InsideZone[client][i][track])
			{
				return i;
			}
		}
		else
		{
			for(int j = 0; i < TRACKS_SIZE; j++)
			{
				if(gB_InsideZone[client][i][j])
				{
					return i;
				}
			}
		}
	}

	return -1;
}

public int Native_IsClientCreatingZone(Handle handler, int numParams)
{
	return (gI_MapStep[GetNativeCell(1)] != EditStep_None);
}

public int Native_GetMapBonuses(Handle handler, int numParams)
{
	return gI_Bonuses;
}

public int Native_GetMapStages(Handle handler, int numParams)
{
	return gI_Stages;
}

public int Native_GetMapCheckpoints(Handle handler, int numParams)
{
	return gI_Checkpoints;
}

bool LoadZonesConfig()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, PLATFORM_MAX_PATH, "configs/shavit-zones.cfg");

	KeyValues kv = new KeyValues("shavit-zones");
	
	if(!kv.ImportFromFile(sPath))
	{
		delete kv;

		return false;
	}

	kv.JumpToKey("Sprites");
	kv.GetString("beam", gS_BeamSprite, PLATFORM_MAX_PATH);

	char sDownloads[PLATFORM_MAX_PATH * 8];
	kv.GetString("downloads", sDownloads, (PLATFORM_MAX_PATH * 8));

	char sDownloadsExploded[PLATFORM_MAX_PATH][PLATFORM_MAX_PATH];
	int iDownloads = ExplodeString(sDownloads, ";", sDownloadsExploded, PLATFORM_MAX_PATH, PLATFORM_MAX_PATH, false);

	for(int i = 0; i < iDownloads; i++)
	{
		if(strlen(sDownloadsExploded[i]) > 0)
		{
			TrimString(sDownloadsExploded[i]);
			AddFileToDownloadsTable(sDownloadsExploded[i]);
		}
	}

	kv.GoBack();
	kv.JumpToKey("Colors");
	kv.JumpToKey("Start"); // A stupid and hacky way to achieve what I want. It works though.

	int i = 0;
	int track;

	do
	{
		// retroactively don't respect custom spawn settings
		char sSection[32];
		kv.GetSectionName(sSection, 32);

		if(StrContains(sSection, "SPAWN POINT", false) != -1)
		{
			continue;
		}

		track = (i / ZONETYPES_SIZE);

		if(track >= TRACKS_SIZE)
		{
			break;
		}

		int index = (i % ZONETYPES_SIZE);

		gA_ZoneSettings[index][track].bVisible = view_as<bool>(kv.GetNum("visible", 1));
		gA_ZoneSettings[index][track].iRed = kv.GetNum("red", 255);
		gA_ZoneSettings[index][track].iGreen = kv.GetNum("green", 255);
		gA_ZoneSettings[index][track].iBlue = kv.GetNum("blue", 255);
		gA_ZoneSettings[index][track].iAlpha = kv.GetNum("alpha", 255);
		gA_ZoneSettings[index][track].fWidth = kv.GetFloat("width", 2.0);
		gA_ZoneSettings[index][track].bFlatZone = view_as<bool>(kv.GetNum("flat", false));
		gA_ZoneSettings[index][track].bUseVanillaSprite = view_as<bool>(kv.GetNum("vanilla_sprite", false));
		gA_ZoneSettings[index][track].bNoHalo = view_as<bool>(kv.GetNum("no_halo", false));
		kv.GetString("beam", gA_ZoneSettings[index][track].sBeam, sizeof(zone_settings_t::sBeam), "");

		i++;
	}

	while(kv.GotoNextKey(false));

	delete kv;

	// copy bonus#1 settings to the rest of the bonuses
	for (++track; track < TRACKS_SIZE; track++)
	{
		for (int type = 0; type < ZONETYPES_SIZE; type++)
		{
			gA_ZoneSettings[type][track] = gA_ZoneSettings[type][Track_Bonus];
		}
	}

	return true;
}

void LoadZoneSettings()
{
	if(!LoadZonesConfig())
	{
		SetFailState("Cannot open \"configs/shavit-zones.cfg\". Make sure this file exists and that the server has read permissions to it.");
	}

	int defaultBeam = PrecacheModel("sprites/laser.vmt", true);
	int defaultHalo = PrecacheModel("sprites/halo01.vmt", true);

	int customBeam;

	if(gCV_UseCustomSprite.BoolValue)
	{
		customBeam = PrecacheModel(gS_BeamSprite, true);
	}
	else
	{
		customBeam = defaultBeam;
	}

	for (int i = 0; i < ZONETYPES_SIZE; i++)
	{
		for (int j = 0; j < TRACKS_SIZE; j++)
		{
			if (gA_ZoneSettings[i][j].bUseVanillaSprite)
			{
				gA_ZoneSettings[i][j].iBeam = defaultBeam;
			}
			else
			{
				gA_ZoneSettings[i][j].iBeam = (gA_ZoneSettings[i][j].sBeam[0] != 0)
					? PrecacheModel(gA_ZoneSettings[i][j].sBeam, true)
					: customBeam;
			}

			gA_ZoneSettings[i][j].iHalo = (gA_ZoneSettings[i][j].bNoHalo) ? 0 : defaultHalo;
		}
	}
}

void FindTriggers()
{
	delete gA_Triggers;
	gA_Triggers = new ArrayList();

	int iEnt = -1;
	int iCount = 1;

	while((iEnt = FindEntityByClassname(iEnt, "trigger_multiple")) != -1)
	{
		char sBuffer[128];
		GetEntPropString(iEnt, Prop_Data, "m_iName", sBuffer, 128, 0);

		if(strlen(sBuffer) == 0)
		{
			char sTargetname[64];
			FormatEx(sTargetname, 64, "trigger_multiple_#%d", iCount);
			DispatchKeyValue(iEnt, "targetname", sTargetname);
		}

		iCount++;
		gA_Triggers.Push(iEnt);
	}

	iCount = 1;

	while((iEnt = FindEntityByClassname(iEnt, "trigger_teleport")) != -1)
	{
		char sBuffer[128];
		GetEntPropString(iEnt, Prop_Data, "m_iName", sBuffer, 128, 0);

		if(strlen(sBuffer) == 0)
		{
			char sTargetname[64];
			FormatEx(sTargetname, 64, "trigger_teleport_#%d", iCount);
			DispatchKeyValue(iEnt, "targetname", sTargetname);
		}

		iCount++;
		gA_Triggers.Push(iEnt);
	}

	iCount = 1;

	while((iEnt = FindEntityByClassname(iEnt, "trigger_push")) != -1)
	{
		char sBuffer[128];
		GetEntPropString(iEnt, Prop_Data, "m_iName", sBuffer, 128, 0);

		if(strlen(sBuffer) == 0)
		{
			char sTargetname[64];
			FormatEx(sTargetname, 64, "trigger_push_#%d", iCount);
			DispatchKeyValue(iEnt, "targetname", sTargetname);
		}

		iCount++;
		gA_Triggers.Push(iEnt);
	}
}

void FindTeles()
{
	int iEnt = -1;

	delete gA_TeleDestination;
	gA_TeleDestination = new ArrayList();

	while ((iEnt = FindEntityByClassname(iEnt, "info_teleport_destination")) != -1)
	{
		gA_TeleDestination.Push(iEnt);
	}

	iEnt = -1;

	while ((iEnt = FindEntityByClassname(iEnt, "info_target")) != -1)
	{
		gA_TeleDestination.Push(iEnt);
	}
}

public void OnMapStart()
{
	if(!gB_Connected)
	{
		return;
	}

	GetCurrentMap(gS_Map, 160);
	GetMapDisplayName(gS_Map, gS_Map, 160);

	PrecacheModel("models/props/cs_office/vending_machine.mdl");

	gB_LinearMap = false;
	gI_MapZones = 0;

	UnloadZones(0);
	FindTriggers();
	FindTeles();
	RefreshZones();
	LoadBonusZones();
	LoadStageZones();
	LoadCheckpointZones();
	LoadZoneSettings();

	// draw
	// start drawing mapzones here
	if(gH_DrawEverything == null)
	{
		gH_DrawEverything = CreateTimer(gCV_Interval.FloatValue, Timer_DrawEverything, INVALID_HANDLE, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}

	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i) && IsClientInGame(i))
		{
			OnClientPutInServer(i);
		}
	}
}

void LoadBonusZones()
{
	gI_Bonuses = 0;

	char sQuery[256];
	FormatEx(sQuery, 256, "SELECT track FROM mapzones WHERE map = '%s' ORDER BY track DESC LIMIT 1;", gS_Map);
	gH_SQL.Query(SQL_GetBonusZone_Callback, sQuery, 0, DBPrio_High);
}

public void SQL_GetBonusZone_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (zones GetBonusZones) SQL query failed. Reason: %s", error);
		return;
	}

	if(results.FetchRow())
	{
		gI_Bonuses = results.FetchInt(0);
	}
}

void LoadStageZones()
{
	gI_Stages = 1;

	char sQuery[256];
	FormatEx(sQuery, 256, "SELECT data FROM mapzones WHERE type = %d and map = '%s' ORDER BY data DESC LIMIT 1;", Zone_Stage, gS_Map);
	gH_SQL.Query(SQL_GetStageZone_Callback, sQuery, 0, DBPrio_High);
}

public void SQL_GetStageZone_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (zones GetStageZone) SQL query failed. Reason: %s", error);
		return;
	}

	while(results.FetchRow())
	{
		gI_Stages = results.FetchInt(0);
	}

	gB_LinearMap = (gI_Stages == 1);
}

void LoadCheckpointZones()
{
	gI_Checkpoints = 0;

	char sQuery[256];
	FormatEx(sQuery, 256, "SELECT data FROM mapzones WHERE type = %d AND map = '%s' ORDER BY data DESC LIMIT 1;", Zone_Checkpoint, gS_Map);
	gH_SQL.Query(SQL_GetCheckpointZone_Callback, sQuery, 0, DBPrio_High);
}

public void SQL_GetCheckpointZone_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (zones GetCheckpointZone) SQL query failed. Reason: %s", error);
		return;
	}

	if(results.FetchRow())
	{
		gI_Checkpoints = results.FetchInt(0);
	}
}

public void OnMapEnd()
{
	UnloadZones(0);
	delete gH_DrawEverything;

	for(int i = 1; i <= MaxClients; i++)
	{
		if(gH_DrawZonesToClient[i] != null)
		{
			delete gH_DrawZonesToClient[i];
		}
	}
}

void ClearZone(int index)
{
	for(int i = 0; i < 3; i++)
	{
		gV_MapZones[index][0][i] = 0.0;
		gV_MapZones[index][1][i] = 0.0;
		gV_Destinations[index][i] = 0.0;
		gV_ZoneCenter[index][i] = 0.0;
	}

	gA_ZoneCache[index].bZoneInitialized = false;
	gA_ZoneCache[index].bHooked = false;
	gA_ZoneCache[index].iZoneType = -1;
	gA_ZoneCache[index].iZoneTrack = -1;
	gA_ZoneCache[index].iEntityID = -1;
	gA_ZoneCache[index].iDatabaseID = -1;
	gA_ZoneCache[index].iZoneFlags = 0;
	gA_ZoneCache[index].iZoneData = 0;
	gA_ZoneCache[index].iHookedHammerID = -1;
	strcopy(gA_ZoneCache[index].sZoneHookname, sizeof(zone_cache_t::sZoneHookname), "NONE");
	gA_ZoneCache[index].fLimitSpeed = gCV_EntrySpeedLimit.FloatValue;
}

void UnhookEntity(int entity)
{
	SDKUnhook(entity, SDKHook_StartTouchPost, StartTouchPost);
	SDKUnhook(entity, SDKHook_EndTouchPost, EndTouchPost);
	SDKUnhook(entity, SDKHook_TouchPost, TouchPost);
}

void KillZoneEntity(int index)
{
	int entity = gA_ZoneCache[index].iEntityID;

	if(entity > MaxClients && IsValidEntity(entity))
	{
		for(int i = 1; i <= MaxClients; i++)
		{
			for(int j = 0; j < TRACKS_SIZE; j++)
			{
				gB_InsideZone[i][gA_ZoneCache[index].iZoneType][j] = false;
			}

			gB_InsideZoneID[i][index] = false;
		}

		UnhookEntity(entity);

		char sTargetname[32];
		GetEntPropString(entity, Prop_Data, "m_iName", sTargetname, 32);
		if(StrContains(sTargetname, "shavit_zones_") != -1)
		{
			AcceptEntityInput(entity, "Kill");
		}
	}
}

// 0 - all zones
void UnloadZones(int zone)
{
	for(int i = 0; i < ZONETYPES_SIZE; i++)
	{
		gI_ZoneMaxData[i] = 0;
	}

	for(int i = 0; i < MAX_ZONES; i++)
	{
		if((zone == 0 || gA_ZoneCache[i].iZoneType == zone) && gA_ZoneCache[i].bZoneInitialized)
		{
			KillZoneEntity(i);
			ClearZone(i);
		}
	}

	if(zone == 0)
	{
		gB_ZonesCreated = false;

		char sTargetname[32];
		int iEntity = INVALID_ENT_REFERENCE;

		while((iEntity = FindEntityByClassname(iEntity, "trigger_multiple")) != INVALID_ENT_REFERENCE)
		{
			GetEntPropString(iEntity, Prop_Data, "m_iName", sTargetname, 32);

			if(StrContains(sTargetname, "shavit_") != -1)
			{
				AcceptEntityInput(iEntity, "Kill");
			}
		}
	}
}

void RefreshZones()
{
	char sQuery[512];
	FormatEx(sQuery, 512,
		"SELECT type, corner1_x, corner1_y, corner1_z, corner2_x, corner2_y, corner2_z, destination_x, destination_y, destination_z, track, id, flags, data, hammerid, hookname, limitspeed FROM `%smapzones` WHERE map = '%s';",
		gS_MySQLPrefix, gS_Map);

	gH_SQL.Query(SQL_RefreshZones_Callback, sQuery, 0, DBPrio_High);
}

public void SQL_RefreshZones_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (zone refresh) SQL query failed. Reason: %s", error);

		return;
	}

	gI_MapZones = 0;

	bool mainHasStart = false;
	bool mainHasEnd = false;

	while(results.FetchRow())
	{
		int type = results.FetchInt(0);
		// how you got type == -1?
		if(type < 0)
		{
			LogError("Timer (zone refresh) SQL query got zone_type < 0, type -> %d, map -> %s", type, gS_Map);
			continue;
		}

		gV_MapZones[gI_MapZones][0][0] = gV_MapZones_Visual[gI_MapZones][0][0] = results.FetchFloat(1);
		gV_MapZones[gI_MapZones][0][1] = gV_MapZones_Visual[gI_MapZones][0][1] = results.FetchFloat(2);
		gV_MapZones[gI_MapZones][0][2] = gV_MapZones_Visual[gI_MapZones][0][2] = results.FetchFloat(3);
		gV_MapZones[gI_MapZones][1][0] = gV_MapZones_Visual[gI_MapZones][7][0] = results.FetchFloat(4);
		gV_MapZones[gI_MapZones][1][1] = gV_MapZones_Visual[gI_MapZones][7][1] = results.FetchFloat(5);
		gV_MapZones[gI_MapZones][1][2] = gV_MapZones_Visual[gI_MapZones][7][2] = results.FetchFloat(6);

		CreateZonePoints(gV_MapZones_Visual[gI_MapZones], gCV_Offset.FloatValue);

		gV_ZoneCenter[gI_MapZones][0] = (gV_MapZones[gI_MapZones][0][0] + gV_MapZones[gI_MapZones][1][0]) / 2.0;
		gV_ZoneCenter[gI_MapZones][1] = (gV_MapZones[gI_MapZones][0][1] + gV_MapZones[gI_MapZones][1][1]) / 2.0;
		gV_ZoneCenter[gI_MapZones][2] = (gV_MapZones[gI_MapZones][0][2] + gV_MapZones[gI_MapZones][1][2]) / 2.0;

		gV_Destinations[gI_MapZones][0] = results.FetchFloat(7);
		gV_Destinations[gI_MapZones][1] = results.FetchFloat(8);
		gV_Destinations[gI_MapZones][2] = results.FetchFloat(9);

		gA_ZoneCache[gI_MapZones].bZoneInitialized = true;
		gA_ZoneCache[gI_MapZones].iZoneType = type;
		gA_ZoneCache[gI_MapZones].iZoneTrack = results.FetchInt(10);
		gA_ZoneCache[gI_MapZones].iDatabaseID = results.FetchInt(11);
		gA_ZoneCache[gI_MapZones].iZoneFlags = results.FetchInt(12);
		gA_ZoneCache[gI_MapZones].iZoneData = results.FetchInt(13);
		gI_ZoneMaxData[type] = MAX(gI_ZoneMaxData[type], results.FetchInt(13));
		gA_ZoneCache[gI_MapZones].iHookedHammerID = results.FetchInt(14);
		results.FetchString(15, gA_ZoneCache[gI_MapZones].sZoneHookname, 128);
		gA_ZoneCache[gI_MapZones].fLimitSpeed = results.FetchFloat(16);
		gA_ZoneCache[gI_MapZones].bHooked = !StrEqual(gA_ZoneCache[gI_MapZones].sZoneHookname, "NONE");

		gA_ZoneCache[gI_MapZones].iEntityID = -1;

		if(gA_ZoneCache[gI_MapZones].iZoneTrack == Track_Main)
		{
			if(type == Zone_Start)
			{
				mainHasStart = true;
			}
			else if(type == Zone_End)
			{
				mainHasEnd = true;
			}
		}

		gI_MapZones++;
	}

	if(!mainHasStart)
	{
		Shavit_PrintToChatAll("主线缺少{lightgreen}起点{default}区域，请联系管理员添加.");
	}

	if(!mainHasEnd)
	{
		Shavit_PrintToChatAll("主线缺少{darkred}终点{default}区域，请联系管理员添加.");
	}

	CreateZoneEntities();
}

bool PreBuildZones()
{
	Shavit_PrintToChatAll("该地图没有区域，系统将自动设置区域中...");

	bool bHaveZones = false;

	for(int i = 0; i < gA_Triggers.Length; i++)
	{
		int iEnt = gA_Triggers.Get(i);

		char sTriggerName[128];
		GetEntPropString(iEnt, Prop_Data, "m_iName", sTriggerName, 128);
		// block weird trigger
		if(StrContains(sTriggerName, "tele", false) != -1 ||
			StrContains(sTriggerName, "tp", false) != -1 ||
			StrContains(sTriggerName, "to", false) != -1 ||
			StrContains(sTriggerName, "jail", false) != -1)
		{
			continue;
		}

		int iHammerID = GetEntProp(iEnt, Prop_Data, "m_iHammerID");

		int iData = 0;
		int iType = Zone_Start;
		int iTrack = Track_Main;

		if(!PreBuildMainTrack(sTriggerName, iData, iType) && 
			!PreBuildBonusTrack(sTriggerName, iTrack, iType) && 
			!PreBuildStages(sTriggerName, iTrack, iData, iType) && 
			!PreBuildCheckpoints(sTriggerName, iTrack, iData, iType))
		{
			continue;
		}

		bHaveZones = true;

		float origin[3];
		GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", origin);

		float fMins[3], fMaxs[3];
		GetEntPropVector(iEnt, Prop_Send, "m_vecMins", fMins);
		GetEntPropVector(iEnt, Prop_Send, "m_vecMaxs", fMaxs);

		for(int j = 0; j < 3; j++)
		{
			fMins[j] += origin[j];
		}

		for(int j = 0; j < 3; j++)
		{
			fMaxs[j] += origin[j];
		}

		char sQuery[512];
		FormatEx(sQuery, 512,
				"INSERT INTO `%smapzones` (map, type, corner1_x, corner1_y, corner1_z, corner2_x, corner2_y, corner2_z, destination_x, destination_y, destination_z, track, flags, data, hookname, hammerid) VALUES ('%s', %d, '%.03f', '%.03f', '%.03f', '%.03f', '%.03f', '%.03f', '%.03f', '%.03f', '%.03f', %d, %d, %d, '%s', %d);",
				gS_MySQLPrefix, gS_Map, iType, fMins[0], fMins[1], fMins[2], fMaxs[0], fMaxs[1], fMaxs[2], 0.0, 0.0, 0.0, iTrack, 0, iData, sTriggerName, iHammerID);

		DataPack dp = new DataPack();
		dp.WriteCell(iTrack);
		dp.WriteCell(iType);

		gH_SQL.Query(SQL_InsertPrebuildZone_Callback, sQuery, dp);
	}

	if(bHaveZones)
	{
		CreateTimer(5.0, Timer_PrebuildZoneDone);

		return true;
	}

	Shavit_PrintToChatAll("无法预设地图，请管理员手动添加区域...");

	return false;
}

bool PreBuild_FindMainStart(const char[] str)
{
	if(StrContains(str, "end", false) != -1 || 
		StrContains(str, "b", false) != -1 ||
		FindNumberInString(str) >= 10) // found stage 10 above, wtf
	{
		return false;
	}

	if(StrEqual(str, "zone_start", false) || 
		StrEqual(str, "zonestart", false) || 
		StrEqual(str, "start_zone", false) ||
		StrEqual(str, "startzone", false) ||
		StrEqual(str, "start", false) || 
		StrEqual(str, "stage01", false) || 
		StrEqual(str, "stage1", false) || 
		StrEqual(str, "s1", false) ||
		StrEqual(str, "1", false))
	{
		return true;
	}

	if(StrContains(str, "main", false) != -1 ||
		StrContains(str, "map", false) != -1 ||
		StrContains(str, "stage01", false) != -1 ||
		StrContains(str, "stage1", false) != -1 ||
		StrContains(str, "s1", false) != -1)
	{
		// do start detecting
		if(StrContains(str, "start", false) != -1 ||
			StrContains(str, "begin", false) != -1)
		{
			return true;
		}
	}

	// double check 's1'
	if(StrContains(str, "stage01", false) != -1 ||
		StrContains(str, "stage1", false) != -1 ||
		StrContains(str, "s1", false) != -1)
	{
		return true;
	}

	return false;
}

bool PreBuild_FindMainEnd(const char[] str)
{
	if(StrContains(str, "b", false) != -1)
	{
		return false;
	}

	if(StrEqual(str, "end_zone", false) ||
		StrEqual(str, "endzone", false) ||
		StrEqual(str, "zone_end", false) ||
		StrEqual(str, "end", false))
	{
		return true;
	}

	if(StrContains(str, "map", false) != -1 ||
		StrContains(str, "main", false) != -1)
	{
		// do end detecting
		if(StrContains(str, "end", false) != -1)
		{
			return true;
		}
	}

	// TODO:
	// do last stage end detecting, but it's a hard thing
	// fuck those stupid mapper

	return false;
}

bool PreBuildMainTrack(const char[] sTemp, int& data, int& type)
{
	char sTriggerName[128];
	strcopy(sTriggerName, 128, sTemp);
	LowercaseString(sTriggerName);

	if(PreBuild_FindMainStart(sTriggerName))
	{
		if(StrContains(sTriggerName, "right", false) != -1)
		{
			data = 1;
		}

		type = Zone_Start;

		return true;
	}

	else if(PreBuild_FindMainEnd(sTriggerName))
	{
		if(StrContains(sTriggerName, "right", false) != -1)
		{
			data = 1;
		}

		type = Zone_End;

		return true;
	}

	return false;
}

bool PreBuildBonusTrack(const char[] sTemp, int& track, int& type)
{
	char sTriggerName[128];
	strcopy(sTriggerName, 128, sTemp);
	LowercaseString(sTriggerName);

	if(StrContains(sTriggerName, "b", false) == -1) // bonus not found.
	{
		return false;
	}

	int num = FindNumberInString(sTriggerName);
	if(num != 0)
	{
		track = num;
	}
	else
	{
		track = Track_Bonus;
	}

	if(StrContains(sTriggerName, "end", false) != -1)
	{
		type = Zone_End;
	}
	else
	{
		type = Zone_Start;
	}

	return true;
}

int PreBuild_FindStage(const char[] str)
{
	// prevent some stupid authors making a end zone for stage.
	if(StrContains(str, "end", false) != -1)
	{
		return -1;
	}

	Regex sRegex = new Regex("^([s][0-9]{1,})|([s][_0-9]{1,})$");
	int stage = -1;

	if(sRegex.Match(str) > 0 || StrContains(str, "stage") != -1 || StrContains(str, "zone_s") != -1 || StrContains(str, "zone_stage") != -1)
	{
		delete sRegex;

		stage = FindNumberInString(str);

		return (stage >= 2) ? stage : -1;
	}

	delete sRegex;

	stage = StringToInt(str);

	return (stage >= 2) ? stage : -1;
}

bool PreBuildStages(const char[] sTemp, int& track, int& data, int& type)
{
	char sTriggerName[128];
	strcopy(sTriggerName, 128, sTemp);
	LowercaseString(sTriggerName);

	int stage = PreBuild_FindStage(sTriggerName);
	if(stage == -1)
	{
		return false;
	}

	track = Track_Main;
	data = stage;
	type = Zone_Stage;

	return true;
}

bool PreBuildCheckpoints(const char[] sTemp, int& track, int& data, int& type)
{
	char sTriggerName[128];
	strcopy(sTriggerName, 128, sTemp);
	LowercaseString(sTriggerName);

	if(StrContains(sTriggerName, "cp") == -1 && StrContains(sTriggerName, "checkpoint") == -1)
	{
		return false;
	}

	int cp = FindNumberInString(sTriggerName);
	if(cp == 0)
	{
		return false;
	}

	track = Track_Main;
	data = cp;
	type = Zone_Checkpoint;

	return true;
}

public void SQL_InsertPrebuildZone_Callback(Database db, DBResultSet results, const char[] error, DataPack dp)
{
	dp.Reset();
	int track = dp.ReadCell();
	int type = dp.ReadCell();

	delete dp;

	if(results == null)
	{
		LogError("Insert prebuild zones error! Reason: %s", error);

		return;
	}

	char sTrack[32];
	GetTrackName(LANG_SERVER, track, sTrack, sizeof(sTrack));

	if(type == Zone_Start)
	{
		Shavit_PrintToChatAll("{blue}%s{lightgreen}起点{default}区域预设成功", sTrack);
	}
	else if(type == Zone_End)
	{
		Shavit_PrintToChatAll("{blue}%s{darkred}终点{default}区域预设成功", sTrack);
	}
	else if(type == Zone_Stage)
	{
		Shavit_PrintToChatAll("{yellow}关卡{default}区域预设成功");
	}
	else if(type == Zone_Checkpoint)
	{
		Shavit_PrintToChatAll("{gold}检查点{default}区域预设成功");
	}
}

public Action Timer_PrebuildZoneDone(Handle timer)
{
	Shavit_PrintToChatAll("预设地图区域成功，可能会漏设区域，如发现请及时联系OP...");

	OnMapStart();

	return Plugin_Stop;
}

public void OnClientPutInServer(int client)
{
	for(int i = 0; i < TRACKS_SIZE; i++)
	{
		for(int j = 0; j < ZONETYPES_SIZE; j++)
		{
			gB_InsideZone[client][j][i] = false;
		}
	}

	for(int i = 0; i < MAX_ZONES; i++)
	{
		gB_InsideZoneID[client][i] = false;
		gV_CustomDestinations[client][i][0] = 0.0;
		gV_CustomDestinations[client][i][1] = 0.0;
		gV_CustomDestinations[client][i][2] = 0.0;
		gV_CustomDestinationsAngle[client][i][0] = 0.0;
		gV_CustomDestinationsAngle[client][i][1] = 0.0;
		gV_CustomDestinationsAngle[client][i][2] = 0.0;
	}

	Reset(client);
}

public void OnClientDisconnect_Post(int client)
{
	gB_ShowTriggers[client] = false;
	TransmitTriggers(client, false);
}

public Action Command_Modifier(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	if(args == 0)
	{
		Shavit_PrintToChat(client, "%T", "ModifierCommandNoArgs", client);

		return Plugin_Handled;
	}

	char sArg1[16];
	GetCmdArg(1, sArg1, 16);

	float fArg1 = StringToFloat(sArg1);

	if(fArg1 <= 0.0)
	{
		Shavit_PrintToChat(client, "%T", "ModifierTooLow", client);

		return Plugin_Handled;
	}

	gF_Modifier[client] = fArg1;

	Shavit_PrintToChat(client, "%T %.01f.", "ModifierSet", client, fArg1);

	return Plugin_Handled;
}

public Action Command_ZoneEdit(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	Reset(client);

	OpenEditMenu(client);

	return Plugin_Handled;
}

public Action Command_ZonePreBuild(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	if(gB_ZonesCreated)
	{
		Shavit_PrintToChat(client, "已经有区域了, 不能预设.");
		return Plugin_Handled;
	}

	PreBuildZones();

	return Plugin_Handled;
}

public Action Command_ReloadZoneSettings(int client, int args)
{
	LoadZoneSettings();

	ReplyToCommand(client, "Reloaded zone settings.");

	return Plugin_Handled;
}

public Action Command_Startpos(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(client))
	{
		Shavit_PrintToChat(client, "%T", "SetStartCommandAlive", client);

		return Plugin_Handled;
	}

	if(Shavit_GetTimerStatus(client) != Timer_Running)
	{
		Shavit_PrintToChat(client, "%T", "SetStartRestartTimer", client);

		return Plugin_Handled;
	}

	if(!(GetEntityFlags(client) & FL_ONGROUND))
	{
		Shavit_PrintToChat(client, "%T", "SetStartOnGround", client);

		return Plugin_Handled;
	}

	if(!Shavit_InsideZone(client, Zone_Start, -1) && !Shavit_InsideZone(client, Zone_Stage, -1))
	{
		Shavit_PrintToChat(client, "%T", "SetStartNotInStartZone", client);

		return Plugin_Handled;
	}

	GetClientAbsOrigin(client, gV_CustomDestinations[client][gI_InsideZoneIndex[client]]);
	GetClientEyeAngles(client, gV_CustomDestinationsAngle[client][gI_InsideZoneIndex[client]]);

	if(Shavit_InsideZone(client, Zone_Start, -1))
	{
		Shavit_PrintToChat(client, "%T", "SetStart", client);
	}

	else if(Shavit_InsideZone(client, Zone_Stage, -1))
	{
		Shavit_PrintToChat(client, "%T", "SetStageStart", client);
	}

	return Plugin_Handled;
}

public Action Command_Back(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(client))
	{
		Shavit_PrintToChat(client, "%T", "StageCommandAlive", client);

		return Plugin_Handled;
	}

	int index = gI_InsideZoneIndex[client];

	DoTeleport(client, index);

	if(gA_ZoneCache[index].iZoneType == Zone_Stage)
	{
		Call_StartForward(gH_Forwards_OnTeleportBackStagePost);
		Call_PushCell(client);
		Call_PushCell(gA_ZoneCache[index].iZoneData);
		Call_PushCell(Shavit_GetBhopStyle(client));
		Call_PushCell(Shavit_IsStageTimer(client));
		Call_Finish();
	}

	return Plugin_Handled;
}

public Action Command_Stages(int client, int args)
{
	if(!IsValidClient(client, true))
	{
		Shavit_PrintToChat(client, "%T", "StageCommandAlive", client);

		return Plugin_Handled;
	}

	int iStage = -1;
	char sCommand[16];
	GetCmdArg(0, sCommand, 16);

	if ('0' <= sCommand[4] <= '9')
	{
		iStage = view_as<int>(sCommand[4] - '0');
	}
	else if (args > 0)
	{
		char arg1[8];
		GetCmdArg(1, arg1, 8);
		iStage = StringToInt(arg1);
		if(iStage > gI_Stages || iStage < 1)
		{
			Shavit_PrintToChat(client, "%T", "InvalidStage", client);
		}
	}

	if (iStage > -1)
	{
		if(iStage == 1)
		{
			FakeClientCommand(client, "sm_r");
			return Plugin_Handled;
		}

		for(int i = 0; i < gI_MapZones; i++)
		{
			if(gA_ZoneCache[i].bZoneInitialized && gA_ZoneCache[i].iZoneType == Zone_Stage && gA_ZoneCache[i].iZoneData == iStage)
			{
				Shavit_StopTimer(client);
				Shavit_SetPracticeMode(client, false);
				Shavit_StartTimer(client, Track_Main);
				Shavit_StopTimer(client);
				Shavit_SetStageTimer(client, true);

				DoTeleport(client, i);

				break;
			}
		}
	}
	else
	{
		Menu menu = new Menu(MenuHandler_SelectStage);
		menu.SetTitle("%T\n", "ZoneMenuStage", client);

		char sDisplay[64];

		for(int i = 0; i < gI_MapZones; i++)
		{
			if(gA_ZoneCache[i].bZoneInitialized)
			{
				// stage 1 (main start)
				if(gA_ZoneCache[i].iZoneType == Zone_Start && gA_ZoneCache[i].iZoneTrack == 0)
					menu.AddItem("1", "Stage 1");

				if(gA_ZoneCache[i].iZoneType == Zone_Stage)
				{
					FormatEx(sDisplay, 64, "Stage %d", (i + 1), gA_ZoneCache[i].iZoneData);

					char sInfo[8];
					IntToString(i, sInfo, 8);

					menu.AddItem(sInfo, sDisplay);
				}
			}
		}

		menu.Display(client, MENU_TIME_FOREVER);
	}

	return Plugin_Handled;
}

public int MenuHandler_SelectStage(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		if(param2 == 0)
		{
			FakeClientCommand(param1, "sm_r");
		}
		else
		{
			Shavit_StopTimer(param1);
			Shavit_StartTimer(param1, Track_Main);
			Shavit_StopTimer(param1);
			Shavit_SetStageTimer(param1, true);

			DoTeleport(param1, param2);
		}
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}
	
	return 0;
}

public Action Command_ShowTriggers(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	gB_ShowTriggers[client] = !gB_ShowTriggers[client];

	if(gB_ShowTriggers[client])
	{
		Shavit_PrintToChat(client, "[显示区域] {green}已打开{default}.");
	}
	else
	{
		Shavit_PrintToChat(client, "[显示区域] {darkred}已关闭{default}.");
	}

	char sArgs[32];
	GetCmdArg(0, sArgs, sizeof(sArgs));

	if(StrContains(sArgs, "trigger", false) != -1)
	{
		TransmitTriggers(client, gB_ShowTriggers[client], true);
	}
	else
	{
		TransmitTriggers(client, gB_ShowTriggers[client], false);
	}

	return Plugin_Handled;
}

public Action Command_FindTeleDestination(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	if (gA_TeleDestination.Length == 0)
	{
		Shavit_PrintToChat(client, "No Map Teleports Found");
		return Plugin_Handled;
	}

	OpenFindTeleMenu(client);

	return Plugin_Handled;
}

void OpenFindTeleMenu(int client)
{
	Menu menu = new Menu(FindTeleDestination_MenuHandler);
	menu.SetTitle("Warning: This will stop your timer");

	for(int i = 0; i < gA_TeleDestination.Length; i++)
	{
		int iEnt = gA_TeleDestination.Get(i);

		char sName[64];
		GetEntPropString(iEnt, Prop_Data, "m_iName", sName, 64);
		menu.AddItem(sName, sName);
	}

	menu.Display(client, -1);
}

public int FindTeleDestination_MenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[64];
		menu.GetItem(param2, sInfo, 64);

		int iEnt = gA_TeleDestination.Get(param2);

		float position[3];
		float angles[3];
		GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", position);
		GetEntPropVector(iEnt, Prop_Send, "m_angRotation", angles);

		Shavit_StopTimer(param1);
		TeleportEntity(param1, position, angles, view_as<float>({0.0, 0.0, 0.0}));
		Shavit_PrintToChat(param1, "Teleported to '%s', position: %.2f | %.2f | %.2f", sInfo, position[0], position[1], position[2]);

		FakeClientCommand(param1, "sm_findtele");
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

public Action Command_HookZones(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	OpenHookZonesMenu_SelectMethod(client);

	return Plugin_Handled;
}

void OpenHookZonesMenu_SelectMethod(int client)
{
	Reset(client);

	Menu menu = new Menu(HookZoneMenuHandler_SelectMethod);
	menu.SetTitle("%T", "HookZoneSelectMethod", client);

	menu.AddItem("", "Name");
	menu.AddItem("", "Origin");

	menu.Display(client, -1);
}

public int HookZoneMenuHandler_SelectMethod(Menu a, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		Menu menu = new Menu(MenuHandler_BeforeSelectHookZone);
		menu.SetTitle("%T", "HookZoneMenuTrigger", param1);

		switch(param2)
		{
			case 0:
			{
				for(int i = 0; i < gA_Triggers.Length; i++)
				{
					int iEnt = gA_Triggers.Get(i);

					if(!IsValidEntity(iEnt))
					{
						continue;
					}

					char sTriggerName[128];
					GetEntPropString(iEnt, Prop_Data, "m_iName", sTriggerName, 128, 0);
					menu.AddItem(sTriggerName, sTriggerName);
				}
			}

			case 1:
			{
				for(int i = 0; i < gA_Triggers.Length; i++)
				{
					int iEnt = gA_Triggers.Get(i);

					if(!IsValidEntity(iEnt))
					{
						continue;
					}

					float origin[3];
					GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", origin);

					char sBuffer[128];
					FormatEx(sBuffer, 128, "%.2f %.2f %.2f", origin[0], origin[1], origin[2]);
					menu.AddItem("", sBuffer);
				}
			}
		}

		menu.ExitBackButton = true;
		menu.Display(param1, -1);
	}

	else if(action == MenuAction_End)
	{
		delete a;
	}

	return 0;
}

public int MenuHandler_BeforeSelectHookZone(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		gI_HookZoneIndex[param1] = gA_Triggers.Get(param2);

		Menu submenu = new Menu(MenuHandler_SelectHookZone);
		submenu.SetTitle("%T", "HookZoneMenuBefore", param1);

		submenu.AddItem("", "Teleport To This Zone");
		submenu.AddItem("", "Hook This Zone");

		submenu.ExitBackButton = true;
		submenu.Display(param1, -1);
	}

	else if(action == MenuAction_Cancel)
	{
		OpenHookZonesMenu_SelectMethod(param1);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

public int MenuHandler_SelectHookZone(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		int entity = gI_HookZoneIndex[param1];
		char sHookname[128];
		GetEntPropString(entity, Prop_Data, "m_iName", sHookname, 128, 0);

		float origin[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", origin);

		switch(param2)
		{
			case 0:
			{
				TeleportEntity(param1, origin, NULL_VECTOR, NULL_VECTOR);
				Shavit_PrintToChat(param1, "%T", "HookTeleportZonesItem", param1, sHookname);
				menu.Display(param1, -1);
			}

			case 1:
			{
				gI_HookZoneHammerID[param1] = GetEntProp(entity, Prop_Data, "m_iHammerID");
				strcopy(gS_ZoneHookname[param1], 128, sHookname);
				Shavit_PrintToChat(param1, "%T", "HookZonesItem", param1, sHookname);


				float fMins[3], fMaxs[3];
				GetEntPropVector(entity, Prop_Send, "m_vecMins", fMins);
				GetEntPropVector(entity, Prop_Send, "m_vecMaxs", fMaxs);

				for(int j = 0; j < 3; j++)
				{
					fMins[j] += origin[j];
				}

				for(int j = 0; j < 3; j++)
				{
					fMaxs[j] += origin[j];
				}

				gV_Point1[param1][0] = fMins[0];
				gV_Point1[param1][1] = fMins[1];
				gV_Point1[param1][2] = fMins[2];
				gV_Point2[param1][0] = fMaxs[0];
				gV_Point2[param1][1] = fMaxs[1];
				gV_Point2[param1][2] = fMaxs[2];

				OpenHookZonesMenu_Track(param1);
			}
		}
	}
	else if(action == MenuAction_Cancel)
	{
		OpenHookZonesMenu_SelectMethod(param1);
	}

	return 0;
}

void OpenHookZonesMenu_Track(int client)
{
	Menu menu = new Menu(MenuHandler_SelectHookZone_Track);
	menu.SetTitle("%T", "ZoneMenuTrack", client);

	for(int i = 0; i < TRACKS_SIZE; i++)
	{
		char sInfo[8];
		IntToString(i, sInfo, 8);

		char sDisplay[16];
		GetTrackName(client, i, sDisplay, 16);

		menu.AddItem(sInfo, sDisplay);
	}

	menu.ExitBackButton = true;
	menu.Display(client, 300);
}

public int MenuHandler_SelectHookZone_Track(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[8];
		menu.GetItem(param2, sInfo, 8);
		gI_ZoneTrack[param1] = StringToInt(sInfo);

		char sTrack[16];
		GetTrackName(param1, gI_ZoneTrack[param1], sTrack, 16);

		Menu submenu = new Menu(MenuHandler_SelectHookZone_Type);
		submenu.SetTitle("%T\n ", "ZoneMenuTitle", param1, sTrack);

		for(int i = 0; i < ZONETYPES_SIZE; i++)
		{
			char sZoneName[64];
			GetZoneName(param1, i, sZoneName, 64);

			if(i == Zone_Stage && gI_Checkpoints > 0)
			{
				continue;
			}

			else if(i == Zone_Checkpoint && gI_Stages > 1)
			{
				continue;
			}

			IntToString(i, sInfo, 8);
			submenu.AddItem(sInfo, sZoneName);
		}

		submenu.Display(param1, 300);
	}

	else if(action == MenuAction_Cancel)
	{
		OpenHookZonesMenu_SelectMethod(param1);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}
	
	return 0;
}

public int MenuHandler_SelectHookZone_Type(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char info[8];
		menu.GetItem(param2, info, 8);

		gI_ZoneType[param1] = StringToInt(info);
		gI_ZoneData[param1][gI_ZoneType[param1]] = FindNumberInString(gS_ZoneHookname[param1]);

		HookZoneConfirmMenu(param1);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

void HookZoneConfirmMenu(int client)
{
	char sTrack[32];
	GetTrackName(client, gI_ZoneTrack[client], sTrack, 32);

	Menu menu = new Menu(HookZoneConfirm_Handler);
	menu.SetTitle("%T\n%T\n ", "ZoneEditConfirm", client, "ZoneEditTrack", client, sTrack);

	char sMenuItem[64];

	FormatEx(sMenuItem, 64, "%T", "ZoneSetYes", client);
	menu.AddItem("yes", sMenuItem);

	FormatEx(sMenuItem, 64, "%T", "ZoneSetNo", client);
	menu.AddItem("no", sMenuItem);

	FormatEx(sMenuItem, 64, "%T", "ZoneSetData", client, gI_ZoneData[client][gI_ZoneType[client]]);
	menu.AddItem("datafromchat", sMenuItem);

	menu.ExitButton = false;
	menu.Display(client, -1);
}

public int HookZoneConfirm_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[16];
		menu.GetItem(param2, sInfo, 16);

		if(StrEqual(sInfo, "yes"))
		{
			InsertZone(param1);
		}

		else if(StrEqual(sInfo, "no"))
		{
			OpenHookZonesMenu_SelectMethod(param1);
		}

		else if(StrEqual(sInfo, "datafromchat"))
		{
			gB_HookZoneConfirm[param1] = true;

			Shavit_PrintToChat(param1, "%T", "ZoneEnterDataChat", param1);

			return 0;
		}
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

public Action Command_Zones(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	OpenZonesMenu(client);

	return Plugin_Handled;
}

void OpenZonesMenu(int client)
{
	Menu menu = new Menu(MenuHandler_OpenZonesMenu);
	menu.SetTitle("Zones");

	char sFormatItem[64];
	FormatEx(sFormatItem, 64, "%T", "AddMapZone", client);
	menu.AddItem("Create", sFormatItem);

	FormatEx(sFormatItem, 64, "%T", "ZoneEdit", client);
	menu.AddItem("Edit", sFormatItem);

	FormatEx(sFormatItem, 64, "%T", "DeleteMapZone", client);
	menu.AddItem("Delete", sFormatItem);

	FormatEx(sFormatItem, 64, "%T", "DeleteAllMapZone", client);
	menu.AddItem("DeleteAll", sFormatItem);

	menu.Display(client, -1);
}

public int MenuHandler_OpenZonesMenu(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[16];
		menu.GetItem(param2, sInfo, 16);

		if(StrEqual(sInfo, "Create"))
		{
			FakeClientCommand(param1, "sm_addzones");
		}

		else if(StrEqual(sInfo, "Edit"))
		{
			FakeClientCommand(param1, "sm_editzones");
		}

		else if(StrEqual(sInfo, "Delete"))
		{
			FakeClientCommand(param1, "sm_delzones");
		}

		else
		{
			FakeClientCommand(param1, "sm_deleteallzones");
		}
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

public Action Command_AddZones(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(client))
	{
		Shavit_PrintToChat(client, "%T", "ZonesCommand", client);

		return Plugin_Handled;
	}

	OpenAddZonesMenu(client);

	return Plugin_Handled;
}

void OpenAddZonesMenu(int client)
{
	Reset(client);

	Menu menu = new Menu(MenuHandler_SelectZoneTrack);
	menu.SetTitle("%T", "ZoneMenuTrack", client);

	for(int i = 0; i < TRACKS_SIZE; i++)
	{
		char sInfo[8];
		IntToString(i, sInfo, 8);

		char sDisplay[16];
		GetTrackName(client, i, sDisplay, 16);

		menu.AddItem(sInfo, sDisplay);
	}

	menu.Display(client, 300);
}

public int MenuHandler_SelectZoneTrack(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[8];
		menu.GetItem(param2, sInfo, 8);
		gI_ZoneTrack[param1] = StringToInt(sInfo);

		char sTrack[16];
		GetTrackName(param1, gI_ZoneTrack[param1], sTrack, 16);

		Menu submenu = new Menu(MenuHandler_SelectZoneType);
		submenu.SetTitle("%T\n ", "ZoneMenuTitle", param1, sTrack);

		for(int i = 0; i < ZONETYPES_SIZE; i++)
		{
			char sZoneName[64];
			GetZoneName(param1, i, sZoneName, 64);

			if(i == Zone_Stage && (gI_Checkpoints > 0 || gI_ZoneTrack[param1] != Track_Main))
			{
				continue;
			}

			else if(i == Zone_Checkpoint && (gI_Stages > 1 || gI_ZoneTrack[param1] != Track_Main))
			{
				continue;
			}

			IntToString(i, sInfo, 8);
			submenu.AddItem(sInfo, sZoneName);
		}

		submenu.Display(param1, 300);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}
	
	return 0;
}

public int MenuHandler_SelectZoneType(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char info[8];
		menu.GetItem(param2, info, 8);

		int type = StringToInt(info);

		gI_ZoneType[param1] = type;

		gI_ZoneData[param1][type] = gI_ZoneMaxData[type] + 1;

		if(gI_Stages == 1)
		{
			gI_ZoneData[param1][Zone_Stage] = 2; // hack fix for creating first stage zone
		}

		if(gI_Checkpoints == 0)
		{
			gI_ZoneData[param1][Zone_Checkpoint] = 1; // hack fix for creating first checkpoint zone
		}

		ShowPanel(param1, EditStep_First);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

void OpenEditMenu(int client)
{
	Reset(client);

	Menu menu = new Menu(MenuHandler_ZoneEdit);
	menu.SetTitle("%T\n ", "ZoneEditTitle", client);

	char sDisplay[64];
	FormatEx(sDisplay, 64, "%T", "ZoneEditRefresh", client);
	menu.AddItem("-2", sDisplay);

	for(int i = 0; i < gI_MapZones; i++)
	{
		if(!gA_ZoneCache[i].bZoneInitialized)
		{
			continue;
		}

		char sInfo[8];
		IntToString(i, sInfo, 8);

		char sTrack[32];
		GetTrackName(client, gA_ZoneCache[i].iZoneTrack, sTrack, 32);

		char sZoneName[32];
		GetZoneName(client, gA_ZoneCache[i].iZoneType, sZoneName, 32);

		FormatEx(sDisplay, 64, "#%d - %s #%d (%s)", (i + 1), sZoneName, gA_ZoneCache[i].iZoneData, sTrack);

		if(gB_InsideZoneID[client][i])
		{
			Format(sDisplay, 64, "%s %T", sDisplay, "ZoneInside", client);
		}

		menu.AddItem(sInfo, sDisplay);
	}

	if(menu.ItemCount == 0)
	{
		FormatEx(sDisplay, 64, "%T", "ZonesMenuNoneFound", client);
		menu.AddItem("-1", sDisplay);
	}

	menu.Display(client, 300);
}

public int MenuHandler_ZoneEdit(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char info[8];
		menu.GetItem(param2, info, 8);

		int id = StringToInt(info);

		switch(id)
		{
			case -2:
			{
				OpenEditMenu(param1);
			}

			case -1:
			{
				Shavit_PrintToChat(param1, "%T", "ZonesMenuNoneFound", param1);
			}

			default:
			{
				// a hack to place the player in the last step of zone editing
				gI_MapStep[param1] = EditStep_Final;

				gI_ZoneID[param1] = id;
				gV_Point1[param1] = gV_MapZones[id][0];
				gV_Point2[param1] = gV_MapZones[id][1];
				gI_ZoneType[param1] = gA_ZoneCache[id].iZoneType;
				gI_ZoneTrack[param1] = gA_ZoneCache[id].iZoneTrack;
				gV_Teleport[param1] = gV_Destinations[id];
				gI_ZoneDatabaseID[param1] = gA_ZoneCache[id].iDatabaseID;
				gI_ZoneFlags[param1] = gA_ZoneCache[id].iZoneFlags;
				gI_ZoneData[param1][gI_ZoneType[param1]] = gA_ZoneCache[id].iZoneData;
				strcopy(gS_ZoneHookname[param1], 128, gA_ZoneCache[id].sZoneHookname);
				gI_HookZoneHammerID[param1] = gA_ZoneCache[id].iHookedHammerID;
				gF_ZoneLimitSpeed[param1] = gA_ZoneCache[id].fLimitSpeed;

				// draw the zone edit
				gB_DrawEditZone[param1] = true;

				CreateEditMenu(param1);
			}
		}
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

public Action Command_DeleteZone(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	return OpenDeleteMenu(client);
}

Action OpenDeleteMenu(int client)
{
	Menu menu = new Menu(MenuHandler_DeleteZone);
	menu.SetTitle("%T\n ", "ZoneMenuDeleteTitle", client);

	char sDisplay[64];
	FormatEx(sDisplay, 64, "%T", "ZoneEditRefresh", client);
	menu.AddItem("-2", sDisplay);

	for(int i = 0; i < gI_MapZones; i++)
	{
		if(gA_ZoneCache[i].bZoneInitialized)
		{
			char sTrack[32];
			GetTrackName(client, gA_ZoneCache[i].iZoneTrack, sTrack, 32);

			char sZoneName[32];
			GetZoneName(client, gA_ZoneCache[i].iZoneType, sZoneName, 32);

			FormatEx(sDisplay, 64, "#%d - %s #%d (%s)", (i + 1), sZoneName, gA_ZoneCache[i].iZoneData, sTrack);

			char sInfo[8];
			IntToString(i, sInfo, 8);
			
			if(gB_InsideZoneID[client][i])
			{
				Format(sDisplay, 64, "%s %T", sDisplay, "ZoneInside", client);
			}

			menu.AddItem(sInfo, sDisplay);
		}
	}

	if(menu.ItemCount == 0)
	{
		char sMenuItem[64];
		FormatEx(sMenuItem, 64, "%T", "ZonesMenuNoneFound", client);
		menu.AddItem("-1", sMenuItem);
	}

	menu.Display(client, -1);

	return Plugin_Handled;
}

public int MenuHandler_DeleteZone(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char info[8];
		menu.GetItem(param2, info, 8);

		int id = StringToInt(info);
	
		switch(id)
		{
			case -2:
			{
				OpenDeleteMenu(param1);
			}

			case -1:
			{
				Shavit_PrintToChat(param1, "%T", "ZonesMenuNoneFound", param1);
			}

			default:
			{
				char sZoneName[32];
				GetZoneName(param1, gA_ZoneCache[id].iZoneType, sZoneName, 32);

				Shavit_LogMessage("%L - deleted %s (id %d) from map `%s`.", param1, sZoneName, gA_ZoneCache[id].iDatabaseID, gS_Map);
				
				char sQuery[256];
				FormatEx(sQuery, 256, "DELETE FROM `mapzones` WHERE %s = %d;", (gB_MySQL)? "id":"rowid", gA_ZoneCache[id].iDatabaseID);

				DataPack hDatapack = new DataPack();
				hDatapack.WriteCell(GetClientSerial(param1));
				hDatapack.WriteCell(gA_ZoneCache[id].iZoneType);

				gH_SQL.Query(SQL_DeleteZone_Callback, sQuery, hDatapack);
			}
		}
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

public void SQL_DeleteZone_Callback(Database db, DBResultSet results, const char[] error, DataPack data)
{
	data.Reset();
	int client = GetClientFromSerial(data.ReadCell());
	int type = data.ReadCell();

	delete data;

	if(results == null)
	{
		LogError("Timer (single zone delete) SQL query failed. Reason: %s", error);

		return;
	}

	if(client == 0)
	{
		return;
	}

	UnloadZones(type);
	RefreshZones();
	LoadBonusZones();
	LoadStageZones();
	LoadCheckpointZones();

	char sZoneName[32];
	GetZoneName(client, type, sZoneName, 32);

	Shavit_PrintToChat(client, "%T", "ZoneDeleteSuccessful", client, sZoneName);
	CreateTimer(0.05, Timer_OpenDeleteMenu, client);
}

public Action Timer_OpenDeleteMenu(Handle timer, int client)
{
	OpenDeleteMenu(client);

	return Plugin_Handled;
}

public Action Command_DeleteAllZones(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	Menu menu = new Menu(MenuHandler_DeleteAllZones);
	menu.SetTitle("%T", "ZoneMenuDeleteALLTitle", client);

	char sMenuItem[64];

	for(int i = 1; i <= GetRandomInt(1, 4); i++)
	{
		FormatEx(sMenuItem, 64, "%T", "ZoneMenuNo", client);
		menu.AddItem("-1", sMenuItem);
	}

	FormatEx(sMenuItem, 64, "%T", "ZoneMenuYes", client);
	menu.AddItem("yes", sMenuItem);

	for(int i = 1; i <= GetRandomInt(1, 3); i++)
	{
		FormatEx(sMenuItem, 64, "%T", "ZoneMenuNo", client);
		menu.AddItem("-1", sMenuItem);
	}

	menu.Display(client, 300);

	return Plugin_Handled;
}

public int MenuHandler_DeleteAllZones(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char info[8];
		menu.GetItem(param2, info, 8);

		int iInfo = StringToInt(info);

		if(iInfo == -1)
		{
			return 0;
		}

		Shavit_LogMessage("%L - deleted all zones from map `%s`.", param1, gS_Map);

		DeleteMapAllZones(gS_Map);
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

void Reset(int client)
{
	gI_ZoneTrack[client] = Track_Main;
	gF_Modifier[client] = 16.0;
	gI_MapStep[client] = EditStep_None;
	gI_GridSnap[client] = 16;
	gB_SnapToWall[client] = false;
	gB_CursorTracing[client] = true;

	gB_WaitingForDataInput[client] = false;
	gB_WaitingForLimitSpeedInput[client] = false;
	gB_HookZoneConfirm[client] = false;

	gI_ZoneFlags[client] = 0;
	gI_ZoneDatabaseID[client] = -1;
	strcopy(gS_ZoneHookname[client], 128, "NONE");
	gI_HookZoneHammerID[client] = -1;
	gF_ZoneLimitSpeed[client] = gCV_EntrySpeedLimit.FloatValue;
	gI_ZoneID[client] = -1;

	gB_ShowTriggers[client] = false;
	gH_DrawZonesToClient[client] = null;
	gB_DrawEditZone[client] = false;

	for(int i = 0; i < 3; i++)
	{
		gV_Point1[client][i] = 0.0;
		gV_Point2[client][i] = 0.0;
		gV_Teleport[client][i] = 0.0;
		gV_WallSnap[client][i] = 0.0;
	}

	for(int i = 0; i < ZONETYPES_SIZE; i++)
	{
		gI_ZoneData[client][i] = 0;
	}

	for(int i = 0; i < TRACKS_SIZE; i++)
	{
		gI_LastStartZoneIndex[client][i] = -1;
	}
}

void ShowPanel(int client, int step)
{
	gI_MapStep[client] = step;

	if(step == EditStep_First || step == EditStep_Second)
	{
		gB_DrawEditZone[client] = true;
	}

	Panel pPanel = new Panel();

	char sPanelText[128];

	switch(step)
	{
		case EditStep_First:
		{
			char sFirst[64];
			FormatEx(sFirst, 64, "%T", "ZoneFirst", client);
			FormatEx(sPanelText, 128, "%T", "ZonePlaceText", client, sFirst);
		}

		case EditStep_Second:
		{
			char sSecond[64];
			FormatEx(sSecond, 64, "%T", "ZoneSecond", client);
			FormatEx(sPanelText, 128, "%T", "ZonePlaceText", client, sSecond);
		}

		case EditStep_Third:
		{
			char sHeight[64];
			FormatEx(sHeight, 64, "%T", "ZoneHeight", client);
			FormatEx(sPanelText, 128, "%T", "ZonePlaceText", client, sHeight);
		}
	}

	pPanel.DrawItem(sPanelText, ITEMDRAW_RAWLINE);
	char sPanelItem[64];
	FormatEx(sPanelItem, 64, "%T", "AbortZoneCreation", client);
	pPanel.DrawItem(sPanelItem);

	char sDisplay[64];
	FormatEx(sDisplay, 64, "%T", "GridSnapPlus", client, gI_GridSnap[client]);
	pPanel.DrawItem(sDisplay);

	FormatEx(sDisplay, 64, "%T", "GridSnapMinus", client);
	pPanel.DrawItem(sDisplay);

	FormatEx(sDisplay, 64, "%T", "WallSnap", client, (gB_SnapToWall[client])? "ZoneSetYes":"ZoneSetNo", client);
	pPanel.DrawItem(sDisplay);

	FormatEx(sDisplay, 64, "%T", "CursorZone", client, (gB_CursorTracing[client])? "ZoneSetYes":"ZoneSetNo", client);
	pPanel.DrawItem(sDisplay);

	pPanel.Send(client, ZoneCreation_Handler, 600);

	delete pPanel;
}

public int ZoneCreation_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		switch(param2)
		{
			case 1:
			{
				Reset(param1);

				return 0;
			}

			case 2:
			{
				gI_GridSnap[param1] *= 2;

				if(gI_GridSnap[param1] > 64)
				{
					gI_GridSnap[param1] = 1;
				}
			}

			case 3:
			{
				gI_GridSnap[param1] /= 2;

				if(gI_GridSnap[param1] < 1)
				{
					gI_GridSnap[param1] = 64;
				}
			}

			case 4:
			{
				gB_SnapToWall[param1] = !gB_SnapToWall[param1];

				if(gB_SnapToWall[param1])
				{
					gB_CursorTracing[param1] = false;

					if(gI_GridSnap[param1] < 32)
					{
						gI_GridSnap[param1] = 32;
					}
				}
			}

			case 5:
			{
				gB_CursorTracing[param1] = !gB_CursorTracing[param1];

				if(gB_CursorTracing[param1])
				{
					gB_SnapToWall[param1] = false;
				}
			}
		}

		ShowPanel(param1, gI_MapStep[param1]);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

float[] SnapToGrid(float pos[3], int grid, bool third)
{
	float origin[3];
	origin = pos;

	origin[0] = float(RoundToNearest(pos[0] / grid) * grid);
	origin[1] = float(RoundToNearest(pos[1] / grid) * grid);
	
	if(third)
	{
		origin[2] = float(RoundToNearest(pos[2] / grid) * grid);
	}

	return origin;
}

bool SnapToWall(float pos[3], int client, float final[3])
{
	bool hit = false;

	float end[3];
	float temp[3];

	float prefinal[3];
	prefinal = pos;

	for(int i = 0; i < 4; i++)
	{
		end = pos;

		int axis = (i / 2);
		end[axis] += (((i % 2) == 1)? -gI_GridSnap[client]:gI_GridSnap[client]);

		TR_TraceRayFilter(pos, end, MASK_PLAYERSOLID, RayType_EndPoint, TraceFilter_NoClients, client);

		if(TR_DidHit())
		{
			TR_GetEndPosition(temp);
			prefinal[axis] = temp[axis];
			hit = true;
		}
	}

	if(hit && GetVectorDistance(prefinal, pos) <= gI_GridSnap[client])
	{
		final = SnapToGrid(prefinal, gI_GridSnap[client], false);

		return true;
	}

	return false;
}

public bool TraceFilter_NoClients(int entity, int contentsMask, any data)
{
	return (entity != data && !IsValidClient(data));
}

float[] GetAimPosition(int client)
{
	float pos[3];
	GetClientEyePosition(client, pos);

	float angles[3];
	GetClientEyeAngles(client, angles);

	TR_TraceRayFilter(pos, angles, MASK_PLAYERSOLID, RayType_Infinite, TraceFilter_NoClients, client);

	if(TR_DidHit())
	{
		float end[3];
		TR_GetEndPosition(end);

		return SnapToGrid(end, gI_GridSnap[client], true);
	}

	return pos;
}

public bool TraceFilter_World(int entity, int contentsMask)
{
	return (entity == 0);
}

public Action Shavit_OnUserCmdPre(int client, int &buttons, int &impulse, float vel[3], float angles[3], TimerStatus status, int track, int style)
{
	if(gB_DrawEditZone[client])
	{
		DrawEditZone(client);
	}

	if(gI_MapStep[client] > EditStep_None && gI_MapStep[client] != EditStep_Final)
	{
		int button = IN_USE;

		if((buttons & button) > 0)
		{
			if(!gB_Button[client])
			{
				float vPlayerOrigin[3];
				GetClientAbsOrigin(client, vPlayerOrigin);

				float origin[3];

				if(gB_CursorTracing[client])
				{
					origin = GetAimPosition(client);
				}
				else if(!(gB_SnapToWall[client] && SnapToWall(vPlayerOrigin, client, origin)))
				{
					origin = SnapToGrid(vPlayerOrigin, gI_GridSnap[client], false);
				}
				else
				{
					gV_WallSnap[client] = origin;
				}

				switch(gI_MapStep[client])
				{
					case EditStep_First:
					{
						gV_Point1[client] = origin;

						ShowPanel(client, EditStep_Second);
					}

					case EditStep_Second:
					{
						gV_Point2[client][0] = origin[0];
						gV_Point2[client][1] = origin[1];
						gV_Point2[client][2] = vPlayerOrigin[2];

						ShowPanel(client, EditStep_Third);
					}

					case EditStep_Third:
					{
						gV_Point2[client][2] = origin[2];

						gI_MapStep[client] = EditStep_Final;

						CreateEditMenu(client);
					}
				}
			}

			gB_Button[client] = true;
		}

		else
		{
			gB_Button[client] = false;
		}
	}

	if (buttons & IN_JUMP && gB_AntiJump[client])
		if (!(gI_LastButtons[client] & IN_JUMP))
			Shavit_PrintToChat(client, "%T", "JumpInAntiJumpZone", client);

	gI_LastButtons[client] = buttons;

	if (buttons & IN_JUMP && gB_AntiJump[client])
		buttons &= ~IN_JUMP;

	if (!gB_AntiJump[client])
		gB_OnGround[client] = view_as<bool>(GetEntityFlags(client) & FL_ONGROUND);

	return Plugin_Continue;
}

public int CreateZoneConfirm_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[16];
		menu.GetItem(param2, sInfo, 16);

		if(StrEqual(sInfo, "yes"))
		{
			InsertZone(param1);
			gI_MapStep[param1] = EditStep_None;

			return 0;
		}

		else if(StrEqual(sInfo, "no"))
		{
			Reset(param1);

			return 0;
		}

		else if(StrEqual(sInfo, "zonedes"))
		{
			CreateUpdateTeleportZoneMenu(param1, 0);

			return 0;
		}

		else if(StrEqual(sInfo, "tpzone"))
		{
			Shavit_StopTimer(param1);
			TeleportEntity(param1, gV_ZoneCenter[gI_ZoneID[param1]], NULL_VECTOR, view_as<float>({0.0, 0.0, 0.0}));
		}

		else if(StrEqual(sInfo, "datafromchat"))
		{
			gB_WaitingForDataInput[param1] = true;

			Shavit_PrintToChat(param1, "%T", "ZoneEnterDataChat", param1);

			return 0;
		}

		else if(StrEqual(sInfo, "adjust"))
		{
			CreateAdjustMenu(param1, 0);

			return 0;
		}

		else if(StrEqual(sInfo, "forcerender"))
		{
			gI_ZoneFlags[param1] ^= ZF_ForceRender;
		}

		else if(StrEqual(sInfo, "limitspeed"))
		{
			gB_WaitingForLimitSpeedInput[param1] = true;

			Shavit_PrintToChat(param1, "%T", "ZoneEnterLimitSpeedChat", param1);

			return 0;
		}

		CreateEditMenu(param1);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

void CreateUpdateTeleportZoneMenu(int client, int page)
{
	char sInfo[128];

	Menu menu = new Menu(UpdateTeleportZoneMenu_Handler);
	
	FormatEx(sInfo, sizeof(sInfo), "%T\n%T", "ZoneSetTPZone", client, "ZoneTelefinder", client);
	menu.SetTitle(sInfo);

	FormatEx(sInfo, sizeof(sInfo), "%T\n ", "ZoneCurrentPosition", client);
	menu.AddItem("tpzone", sInfo);

	int iEntity;
	while ((iEntity = FindEntityByClassname(iEntity, "info_teleport_destination")) != -1)
	{
		char target_name[32];
		GetEntPropString(iEntity, Prop_Data, "m_iName", target_name, sizeof(target_name));

		char sEntity[8];
		IntToString(iEntity, sEntity, sizeof(sEntity));

		menu.AddItem(sEntity, target_name);
	}

	menu.ExitButton = false;
	menu.DisplayAt(client, page, MENU_TIME_FOREVER);
}

public int UpdateTeleportZoneMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char sInfo[16];
		menu.GetItem(param2, sInfo, 16);

		if(StrEqual(sInfo, "tpzone"))
		{
			UpdateTeleportZone(param1);
		}
		else
		{
			float position[3];

			GetEntPropVector(StringToInt(sInfo), Prop_Send, "m_vecOrigin", position);

			UpdateTeleportZone(param1, position);
		}

		CreateEditMenu(param1);
	}
	else if (action == MenuAction_Cancel)
	{
		if (gI_ZoneID[param1] != -1)
		{
			// reenable original zone
			gA_ZoneCache[gI_ZoneID[param1]].bZoneInitialized = true;
		}

		Reset(param1);
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
	if(gB_HookZoneConfirm[client])
	{
		gI_ZoneData[client][gI_ZoneType[client]] = StringToInt(sArgs);

		HookZoneConfirmMenu(client);

		return Plugin_Handled;
	}
	else if(gB_WaitingForDataInput[client])
	{
		gI_ZoneData[client][gI_ZoneType[client]] = StringToInt(sArgs);

		CreateEditMenu(client);

		return Plugin_Handled;
	}
	else if(gB_WaitingForLimitSpeedInput[client])
	{
		gF_ZoneLimitSpeed[client] = StringToFloat(sArgs);

		CreateEditMenu(client);

		return Plugin_Handled;
	}

	return Plugin_Continue;
}

void UpdateTeleportZone(int client, float position[3] = {-1.0, -1.0, -1.0})
{
	float vTeleport[3];
	if(position[0] == -1.0 && position[1] == -1.0 && position[2] == -1.0)
	{
		GetClientAbsOrigin(client, vTeleport);
		vTeleport[2] += 2.0;
	}
	else
	{
		vTeleport = position;
	}

	gV_Teleport[client] = vTeleport;

	Shavit_PrintToChat(client, "%T", "ZoneTeleportUpdated", client);
}

void CreateEditMenu(int client)
{
	char sTrack[32];
	GetTrackName(client, gI_ZoneTrack[client], sTrack, 32);

	Menu menu = new Menu(CreateZoneConfirm_Handler);
	menu.SetTitle("%T\n%T\n ", "ZoneEditConfirm", client, "ZoneEditTrack", client, sTrack);

	char sMenuItem[64];

	if(gI_ZoneType[client] == Zone_Teleport)
	{
		if(EmptyVector(gV_Teleport[client]))
		{
			FormatEx(sMenuItem, 64, "%T", "ZoneSetTP", client);
			menu.AddItem("-1", sMenuItem, ITEMDRAW_DISABLED);
		}
	}

	FormatEx(sMenuItem, 64, "%T", "ZoneSetYes", client);
	menu.AddItem("yes", sMenuItem);

	FormatEx(sMenuItem, 64, "%T", "ZoneSetNo", client);
	menu.AddItem("no", sMenuItem);

	FormatEx(sMenuItem, 64, "%T", "ZoneSetTPZone", client);
	menu.AddItem("zonedes", sMenuItem);

	FormatEx(sMenuItem, 64, "%T", "TPToZone", client);
	menu.AddItem("tpzone", sMenuItem);

	FormatEx(sMenuItem, 64, "%T", "ZoneSetData", client, gI_ZoneData[client][gI_ZoneType[client]]);
	menu.AddItem("datafromchat", sMenuItem);

	FormatEx(sMenuItem, 64, "%T", "ZoneSetAdjust", client);
	menu.AddItem("adjust", sMenuItem);

	FormatEx(sMenuItem, 64, "%T", "ZoneForceRender", client, ((gI_ZoneFlags[client] & ZF_ForceRender) > 0)? "＋":"－");
	menu.AddItem("forcerender", sMenuItem);

	FormatEx(sMenuItem, 64, "hookname: %s", gS_ZoneHookname[client]);
	menu.AddItem("null", sMenuItem, ITEMDRAW_DISABLED);

	FormatEx(sMenuItem, 64, "hammerid: %d", gI_HookZoneHammerID[client]);
	menu.AddItem("null", sMenuItem, ITEMDRAW_DISABLED);

	FormatEx(sMenuItem, 64, "%T", "ZoneSetLimitSpeed", client, gF_ZoneLimitSpeed[client]);
	menu.AddItem("limitspeed", sMenuItem);

	menu.ExitButton = false;
	menu.Display(client, -1);
}

void CreateAdjustMenu(int client, int page)
{
	Menu hMenu = new Menu(ZoneAdjuster_Handler);
	char sMenuItem[64];
	hMenu.SetTitle("%T", "ZoneAdjustPosition", client);

	FormatEx(sMenuItem, 64, "%T", "ZoneAdjustDone", client);
	hMenu.AddItem("done", sMenuItem);
	FormatEx(sMenuItem, 64, "%T", "ZoneAdjustCancel", client);
	hMenu.AddItem("cancel", sMenuItem);

	char sAxis[4];
	strcopy(sAxis, 4, "XYZ");

	char sDisplay[32];
	char sInfo[16];

	for(int iPoint = 1; iPoint <= 2; iPoint++)
	{
		for(int iAxis = 0; iAxis < 3; iAxis++)
		{
			for(int iState = 1; iState <= 2; iState++)
			{
				FormatEx(sDisplay, 32, "%T %c%.01f", "ZonePoint", client, iPoint, sAxis[iAxis], (iState == 1)? '+':'-', gF_Modifier[client]);
				FormatEx(sInfo, 16, "%d;%d;%d", iPoint, iAxis, iState);
				hMenu.AddItem(sInfo, sDisplay);
			}
		}
	}

	hMenu.ExitButton = false;
	hMenu.DisplayAt(client, page, MENU_TIME_FOREVER);
}

public int ZoneAdjuster_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[16];
		menu.GetItem(param2, sInfo, 16);

		if(StrEqual(sInfo, "done"))
		{
			CreateEditMenu(param1);
		}

		else if(StrEqual(sInfo, "cancel"))
		{
			if (gI_ZoneID[param1] != -1)
			{
				// reenable original zone
				gA_ZoneCache[gI_ZoneID[param1]].bZoneInitialized = true;
			}

			Reset(param1);
		}

		else
		{
			char sAxis[4];
			strcopy(sAxis, 4, "XYZ");

			char sExploded[3][8];
			ExplodeString(sInfo, ";", sExploded, 3, 8);

			int iPoint = StringToInt(sExploded[0]);
			int iAxis = StringToInt(sExploded[1]);
			bool bIncrease = view_as<bool>(StringToInt(sExploded[2]) == 1);

			((iPoint == 1)? gV_Point1:gV_Point2)[param1][iAxis] += ((bIncrease)? gF_Modifier[param1]:-gF_Modifier[param1]);
			Shavit_PrintToChat(param1, "%T", (bIncrease)? "ZoneSizeIncrease":"ZoneSizeDecrease", param1, sAxis[iAxis], iPoint, gF_Modifier[param1]);

			CreateAdjustMenu(param1, GetMenuSelectionPosition());
		}
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

void InsertZone(int client)
{
	int iType = gI_ZoneType[client];
	int iIndex = GetZoneIndex(iType, gI_ZoneTrack[client]);
	bool bInsert = (gI_ZoneDatabaseID[client] == -1 && (iIndex == -1 || iType >= Zone_Start));

	char sQuery[512];
	char sZoneName[32];
	GetZoneName(client, iType, sZoneName, 32);

	if(bInsert) // insert
	{
		Shavit_LogMessage("%L - added %s to map `%s`.", client, sZoneName, gS_Map);

		FormatEx(sQuery, 512,
			"INSERT INTO %smapzones (map, type, corner1_x, corner1_y, corner1_z, corner2_x, corner2_y, corner2_z, destination_x, destination_y, destination_z, track, flags, data, hammerid, hookname, limitspeed) VALUES ('%s', %d, '%.03f', '%.03f', '%.03f', '%.03f', '%.03f', '%.03f', '%.03f', '%.03f', '%.03f', %d, %d, %d, %d, '%s', '%.2f');",
			gS_MySQLPrefix, gS_Map, iType, gV_Point1[client][0], gV_Point1[client][1], gV_Point1[client][2], gV_Point2[client][0], gV_Point2[client][1], gV_Point2[client][2], gV_Teleport[client][0], gV_Teleport[client][1], gV_Teleport[client][2], gI_ZoneTrack[client], gI_ZoneFlags[client], gI_ZoneData[client][iType], gI_HookZoneHammerID[client], gS_ZoneHookname[client], gF_ZoneLimitSpeed[client]);
	}

	else // update
	{
		Shavit_LogMessage("%L - updated %s in map `%s`.", client, sZoneName, gS_Map);

		if(gI_ZoneDatabaseID[client] == -1)
		{
			for(int i = 0; i < gI_MapZones; i++)
			{
				if(gA_ZoneCache[i].bZoneInitialized && gA_ZoneCache[i].iZoneType == iType && gA_ZoneCache[i].iZoneTrack == gI_ZoneTrack[client])
				{
					gI_ZoneDatabaseID[client] = gA_ZoneCache[i].iDatabaseID;
				}
			}
		}

		FormatEx(sQuery, 512,
			"UPDATE %smapzones SET corner1_x = '%.03f', corner1_y = '%.03f', corner1_z = '%.03f', corner2_x = '%.03f', corner2_y = '%.03f', corner2_z = '%.03f', destination_x = '%.03f', destination_y = '%.03f', destination_z = '%.03f', track = %d, flags = %d, data = %d, limitspeed = '%.2f' WHERE id = %d;",
			gS_MySQLPrefix, gV_Point1[client][0], gV_Point1[client][1], gV_Point1[client][2], gV_Point2[client][0], gV_Point2[client][1], gV_Point2[client][2], gV_Teleport[client][0], gV_Teleport[client][1], gV_Teleport[client][2], gI_ZoneTrack[client], gI_ZoneFlags[client], gI_ZoneData[client][iType], gF_ZoneLimitSpeed[client], gI_ZoneDatabaseID[client]);
	}

	gH_SQL.Query(SQL_InsertZone_Callback, sQuery, GetClientSerial(client));
}

public void SQL_InsertZone_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (zone insert) SQL query failed. Reason: %s", error);

		return;
	}

	int client = GetClientFromSerial(data);

	if(client == 0)
	{
		return;
	}

	UnloadZones(0);
	RefreshZones();
	LoadBonusZones();
	LoadStageZones();
	LoadCheckpointZones();
	Reset(client);
}

public Action Timer_DrawEverything(Handle Timer)
{
	if(gI_MapZones == 0)
	{
		return Plugin_Continue;
	}

	static int iCycle = 0;

	if(iCycle >= gI_MapZones)
	{
		iCycle = 0;
	}

	for(int i = iCycle; i < gI_MapZones; i++, iCycle++)
	{
		if(gA_ZoneCache[i].bZoneInitialized)
		{
			int type = gA_ZoneCache[i].iZoneType;
			int track = gA_ZoneCache[i].iZoneTrack;

			if(gA_ZoneSettings[type][track].bVisible || (gA_ZoneCache[i].iZoneFlags & ZF_ForceRender) > 0)
			{
				DrawZone(gV_MapZones_Visual[i],
						GetZoneColors(type, track),
						gCV_Interval.FloatValue,
						gA_ZoneSettings[type][track].fWidth,
						gA_ZoneSettings[type][track].bFlatZone,
						gA_ZoneSettings[type][track].iBeam,
						gA_ZoneSettings[type][track].iHalo);
			}
		}
	}

	iCycle = 0;

	return Plugin_Continue;
}

int[] GetZoneColors(int type, int track, int customalpha = 0)
{
	int colors[4];
	colors[0] = gA_ZoneSettings[type][track].iRed;
	colors[1] = gA_ZoneSettings[type][track].iGreen;
	colors[2] = gA_ZoneSettings[type][track].iBlue;
	colors[3] = (customalpha > 0)? customalpha:gA_ZoneSettings[type][track].iAlpha;

	return colors;
}

void DrawEditZone(int client)
{
	if(gI_MapStep[client] == EditStep_None)
	{
		Reset(client);

		return;
	}

	float vPlayerOrigin[3];
	GetClientAbsOrigin(client, vPlayerOrigin);

	float origin[3];

	if(gB_CursorTracing[client])
	{
		origin = GetAimPosition(client);
	}
	else if(!(gB_SnapToWall[client] && SnapToWall(vPlayerOrigin, client, origin)))
	{
		origin = SnapToGrid(vPlayerOrigin, gI_GridSnap[client], false);
	}
	else
	{
		gV_WallSnap[client] = origin;
	}

	switch(gI_MapStep[client])
	{
		case EditStep_Second:
		{
			origin[2] = vPlayerOrigin[2];
		}
		case EditStep_Third:
		{
			origin[0] = gV_Point2[client][0];
			origin[1] = gV_Point2[client][1];
		}
		case EditStep_Final:
		{
			origin = gV_Point2[client];
		}
	}

	int type = gI_ZoneType[client];
	int track = gI_ZoneTrack[client];

	if(!EmptyVector(gV_Point1[client]) || !EmptyVector(gV_Point2[client]))
	{
		float points[8][3];
		points[0] = gV_Point1[client];
		points[7] = origin;
		CreateZonePoints(points, gCV_Offset.FloatValue);

		// This is here to make the zone setup grid snapping be 1:1 to how it looks when done with the setup.
		origin = points[7];

		DrawZone(points, GetZoneColors(type, track, 125), 0.1, gA_ZoneSettings[type][track].fWidth, false, gA_ZoneSettings[type][track].iBeam, gA_ZoneSettings[type][track].iHalo);

		if(gI_ZoneType[client] == Zone_Teleport && !EmptyVector(gV_Teleport[client]))
		{
			TE_SetupEnergySplash(gV_Teleport[client], NULL_VECTOR, false);
			TE_SendToClient(client);
		}
	}

	if(gI_MapStep[client] != EditStep_Final && !EmptyVector(origin))
	{
		TE_SetupBeamPoints(vPlayerOrigin, origin, gA_ZoneSettings[type][track].iBeam, gA_ZoneSettings[type][track].iHalo, 0, 0, 0.1, 1.0, 1.0, 0, 0.0, {255, 255, 255, 75}, 0);
		TE_SendToClient(client);

		// visualize grid snap
		float snap1[3];
		float snap2[3];

		for(int i = 0; i < 3; i++)
		{
			snap1 = origin;
			snap1[i] -= (gI_GridSnap[client] / 2);

			snap2 = origin;
			snap2[i] += (gI_GridSnap[client] / 2);

			TE_SetupBeamPoints(snap1, snap2, gA_ZoneSettings[type][track].iBeam, gA_ZoneSettings[type][track].iHalo, 0, 0, 0.1, 1.0, 1.0, 0, 0.0, {255, 255, 255, 75}, 0);
			TE_SendToClient(client);
		}
	}
}

void DrawZone(float points[8][3], int color[4], float life, float width, bool flat, int beam, int halo)
{
	static int pairs[][] =
	{
		{ 0, 2 },
		{ 2, 6 },
		{ 6, 4 },
		{ 4, 0 },
		{ 0, 1 },
		{ 3, 1 },
		{ 3, 2 },
		{ 3, 7 },
		{ 5, 1 },
		{ 5, 4 },
		{ 6, 7 },
		{ 7, 5 }
	};

	for(int i = 0; i < ((flat)? 4:12); i++)
	{
		TE_SetupBeamPoints(points[pairs[i][0]], points[pairs[i][1]], beam, halo, 0, 0, life, width, width, 0, 0.0, color, 0);
		TE_SendToAll(0.0);
	}
}

// original by blacky
// creates 3d box from 2 points
void CreateZonePoints(float point[8][3], float offset = 0.0)
{
	// calculate all zone edges
	for(int i = 1; i < 7; i++)
	{
		for(int j = 0; j < 3; j++)
		{
			point[i][j] = point[((i >> (2 - j)) & 1) * 7][j];
		}
	}

	// apply beam offset
	if(offset != 0.0)
	{
		float center[2];
		center[0] = ((point[0][0] + point[7][0]) / 2);
		center[1] = ((point[0][1] + point[7][1]) / 2);

		for(int i = 0; i < 8; i++)
		{
			for(int j = 0; j < 2; j++)
			{
				if(point[i][j] < center[j])
				{
					point[i][j] += offset;
				}

				else if(point[i][j] > center[j])
				{
					point[i][j] -= offset;
				}
			}
		}
	}
}

void SQL_DBConnect()
{
	GetTimerSQLPrefix(gS_MySQLPrefix, 32);
	gH_SQL = GetTimerDatabaseHandle2(false);
	gB_MySQL = IsMySQLDatabase(gH_SQL);

	char sQuery[1024];
	if(gB_MySQL)
	{
		FormatEx(sQuery, 1024,
			"CREATE TABLE IF NOT EXISTS `mapzones` (`id` INT AUTO_INCREMENT, `map` VARCHAR(128), `type` INT, `corner1_x` FLOAT, `corner1_y` FLOAT, `corner1_z` FLOAT, `corner2_x` FLOAT, `corner2_y` FLOAT, `corner2_z` FLOAT, `destination_x` FLOAT NOT NULL DEFAULT 0, `destination_y` FLOAT NOT NULL DEFAULT 0, `destination_z` FLOAT NOT NULL DEFAULT 0, `track` INT NOT NULL DEFAULT 0, `flags` INT NOT NULL DEFAULT 0, `data` INT NOT NULL DEFAULT 0, `hammerid` INT NOT NULL DEFAULT -1, `hookname` VARCHAR(128) NOT NULL DEFAULT 'NONE', `limitspeed` FLOAT NOT NULL DEFAULT %f, PRIMARY KEY (`id`)) ENGINE=INNODB;", gCV_EntrySpeedLimit.FloatValue);
	}
	else
	{
		FormatEx(sQuery, 1024,
			"CREATE TABLE IF NOT EXISTS `mapzones` (`id` INT AUTO_INCREMENT, `map` VARCHAR(128), `type` INT, `corner1_x` FLOAT, `corner1_y` FLOAT, `corner1_z` FLOAT, `corner2_x` FLOAT, `corner2_y` FLOAT, `corner2_z` FLOAT, `destination_x` FLOAT NOT NULL DEFAULT 0, `destination_y` FLOAT NOT NULL DEFAULT 0, `destination_z` FLOAT NOT NULL DEFAULT 0, `track` INT NOT NULL DEFAULT 0, `flags` INT NOT NULL DEFAULT 0, `data` INT NOT NULL DEFAULT 0, `hammerid` INT NOT NULL DEFAULT -1, `hookname` VARCHAR(128) NOT NULL DEFAULT 'NONE', `limitspeed` FLOAT NOT NULL DEFAULT %f, PRIMARY KEY (`id`));", gCV_EntrySpeedLimit.FloatValue);
	}

	gH_SQL.Query(SQL_CreateTable_Callback, sQuery);
}

public void SQL_CreateTable_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (zones module) error! Map zones' table creation failed. Reason: %s", error);

		return;
	}

	gB_Connected = true;

	OnMapStart();
}

public Action Shavit_OnRestartPre(int client, int track)
{
	char sArg[16];
	GetCmdArg(0, sArg, sizeof(sArg));

	if((StrEqual(sArg, "sm_b", false) || StrEqual(sArg, "sm_bonus", false)) && GetCmdArgs() == 0)
	{
		OpenBonusMenu(client);
		return Plugin_Handled;
	}

	Shavit_SetStageTimer(client, false);
	DoRestart(client, track);

	return Plugin_Handled;
}

void DoRestart(int client, int track)
{
	int iIndex = GetZoneIndex(Zone_Start, track);

	// standard zoning
	if(iIndex != -1)
	{
		if(!Shavit_StopTimer(client, false))
		{
			return;
		}

		Shavit_StartTimer(client, track);

		if(gI_LastStartZoneIndex[client][track] != -1)
		{
			iIndex = gI_LastStartZoneIndex[client][track];
		}

		DoTeleport(client, iIndex);
	}
	else
	{
		char sTrack[32];
		GetTrackName(client, track, sTrack, 32);

		Shavit_PrintToChat(client, "%T", "StartZoneUndefined", client, sTrack);

		Shavit_StopTimer(client);
	}
}

void OpenBonusMenu(int client)
{
	Menu menu = new Menu(OpenBonusMenu_Handler);
	menu.SetTitle("Select a bonus\n ");

	int lastbonus = Track_Bonus;

	for(int i = Track_Bonus; i <= Track_Bonus_Last; i++)
	{
		if(GetZoneIndex(Zone_Start, i) != -1)
		{
			char sItem[4];
			IntToString(i, sItem, 4);

			char sDisplay[16];
			FormatEx(sDisplay, 16, "Bonus %d", i);
			menu.AddItem(sItem, sDisplay);

			lastbonus = i;
		}
	}

	if(menu.ItemCount <= 1)
	{
		delete menu;
		DoRestart(client, lastbonus);
	}
	else
	{
		menu.Display(client, -1);
	}
}

public int OpenBonusMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[4];
		menu.GetItem(param2, sInfo, 4);

		DoRestart(param1, StringToInt(sInfo));
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

public void Shavit_OnEnd(int client, int track)
{
	int iIndex = GetZoneIndex(Zone_End, track);

	if(iIndex != -1)
	{
		if(!Shavit_StopTimer(client, false))
		{
			return;
		}

		if(gCV_TeleportToEnd.BoolValue)
		{
			DoTeleport(client, iIndex);
		}
	}
	else
	{
		Shavit_PrintToChat(client, "%T", "EndZoneUndefined", client);
	}
}

public void Shavit_OnDeleteMapData(int client, const char[] map)
{
	DeleteMapAllZones(map);
	Shavit_PrintToChat(client, "Deleted all zones for %s.", map);
}

bool EmptyVector(float vec[3])
{
	return (IsNullVector(vec) || (vec[0] == 0.0 && vec[1] == 0.0 && vec[2] == 0.0));
}

// returns -1 if there's no zone
int GetZoneIndex(int type, int track, int start = 0)
{
	if(gI_MapZones == 0)
	{
		return -1;
	}

	for(int i = start; i < gI_MapZones; i++)
	{
		if(gA_ZoneCache[i].bZoneInitialized && gA_ZoneCache[i].iZoneType == type && (gA_ZoneCache[i].iZoneTrack == track || track == -1))
		{
			return i;
		}
	}

	return -1;
}

public void Round_Start(Event event, const char[] name, bool dontBroadcast)
{
	gB_ZonesCreated = false;

	RequestFrame(Frame_InitZones);
}

public void Frame_InitZones(any data)
{
	OnMapStart();
}

void CreateZoneEntities()
{
	if(gB_ZonesCreated)
	{
		return;
	}

	delete gA_HookTriggers;
	gA_HookTriggers = new ArrayList();

	for(int i = 0; i < gI_MapZones; i++)
	{
		for(int j = 1; j <= MaxClients; j++)
		{
			for(int k = 0; k < TRACKS_SIZE; k++)
			{
				gB_InsideZone[j][gA_ZoneCache[i].iZoneType][k] = false;
			}

			gB_InsideZoneID[j][i] = false;
		}

		if(gA_ZoneCache[i].iEntityID != -1)
		{
			KillZoneEntity(i);

			gA_ZoneCache[i].iEntityID = -1;
		}

		if(!gA_ZoneCache[i].bZoneInitialized || gA_ZoneCache[i].iZoneType == Zone_Mark)
		{
			continue;
		}

		if(!gA_ZoneCache[i].bHooked)
		{
			if(!CreateNormalZone(i))
			{
				continue;
			}
		}
		else
		{
			if(!CreateHookZone(i))
			{
				char sTrack[32];
				GetTrackName(LANG_SERVER, gA_ZoneCache[i].iZoneTrack, sTrack, sizeof(sTrack));

				char sType[32];
				GetZoneName(LANG_SERVER, gA_ZoneCache[i].iZoneType, sType, sizeof(sType));

				char sLogs[256];
				FormatEx(sLogs, sizeof(sLogs), "该hook区域丢失hammerid, 请联系OP重新设置hook区域. Hookzone的名字是: \"%s\", Track: \"%s\", 类别为: \"%s\".", 
					gA_ZoneCache[i].sZoneHookname, sTrack, sType);
				Shavit_PrintToChatAll(sLogs);

				Format(sLogs, sizeof(sLogs), "%s ***Map: %s***", sLogs, gS_Map);
				Shavit_LogMessage(sLogs);

				continue;
			}
		}

		SetCenterByDestination(i);

		gB_ZonesCreated = true;
	}

	if(!gB_ZonesCreated && gCV_PreBuildZone.BoolValue)
	{
		CreateTimer(5.0, Timer_DelayPreBuildZones);
	}
}

bool CreateNormalZone(int zone)
{
	int entity = CreateEntityByName("trigger_multiple");

	if(entity == -1)
	{
		LogError("\"trigger_multiple\" creation failed, map %s.", gS_Map);

		return false;
	}

	DispatchKeyValue(entity, "wait", "0");
	DispatchKeyValue(entity, "spawnflags", "4097");
	
	if(!DispatchSpawn(entity))
	{
		LogError("\"trigger_multiple\" spawning failed, map %s.", gS_Map);

		return false;
	}

	ActivateEntity(entity);
	SetEntityModel(entity, "models/props/cs_office/vending_machine.mdl");
	SetEntProp(entity, Prop_Send, "m_fEffects", 32);

	TeleportEntity(entity, gV_ZoneCenter[zone], NULL_VECTOR, NULL_VECTOR);

	float distance_x = FloatAbs(gV_MapZones[zone][0][0] - gV_MapZones[zone][1][0]) / 2;
	float distance_y = FloatAbs(gV_MapZones[zone][0][1] - gV_MapZones[zone][1][1]) / 2;
	float distance_z = FloatAbs(gV_MapZones[zone][0][2] - gV_MapZones[zone][1][2]) / 2;

	float height = 36.0;

	float min[3];
	min[0] = -distance_x;
	min[1] = -distance_y;
	min[2] = -distance_z + height;
	SetEntPropVector(entity, Prop_Send, "m_vecMins", min);

	float max[3];
	max[0] = distance_x;
	max[1] = distance_y;
	max[2] = distance_z - height;
	SetEntPropVector(entity, Prop_Send, "m_vecMaxs", max);

	SetEntProp(entity, Prop_Send, "m_nSolidType", 2);

	SDKHook(entity, SDKHook_StartTouchPost, StartTouchPost);
	SDKHook(entity, SDKHook_EndTouchPost, EndTouchPost);
	SDKHook(entity, SDKHook_TouchPost, TouchPost);

	gI_EntityZone[entity] = zone;
	gA_ZoneCache[zone].iEntityID = entity;

	char sTargetname[32];
	FormatEx(sTargetname, 32, "shavit_zones_%d_%d", gA_ZoneCache[zone].iZoneTrack, gA_ZoneCache[zone].iZoneType);
	DispatchKeyValue(entity, "targetname", sTargetname);

	return true;
}

bool CreateHookZone(int zone)
{
	for(int i = 0; i < gA_Triggers.Length; i++)
	{
		int entity = gA_Triggers.Get(i);

		if(gA_ZoneCache[zone].iHookedHammerID == GetEntProp(entity, Prop_Data, "m_iHammerID"))
		{
			for(int j = 0; j < 8; j++)
			{
				for(int k = 0; k < 3; k++)
				{
					gV_MapZones_Visual[zone][j][k] = 0.0; // do not set their visual point, use trigger material instead
				}
			}

			gA_HookTriggers.Push(entity);

			SDKHook(entity, SDKHook_StartTouchPost, StartTouchPost);
			SDKHook(entity, SDKHook_EndTouchPost, EndTouchPost);
			SDKHook(entity, SDKHook_TouchPost, TouchPost);

			gI_EntityZone[entity] = zone;
			gA_ZoneCache[zone].iEntityID = entity;

			return true;
		}
	}

	return false;
}

void SetCenterByDestination(int zone)
{
	for(int i = 0; i < gA_TeleDestination.Length; i++)
	{
		int entity = gA_TeleDestination.Get(i);
		float origin[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", origin);

		float bmin[3], bmax[3];
		FillBoxMinMax(gV_MapZones[zone][0], gV_MapZones[zone][1], bmin, bmax);

		if(PointInBox(origin, bmin, bmax))
		{
			gV_ZoneCenter[zone][0] = origin[0];
			gV_ZoneCenter[zone][1] = origin[1];
			gV_ZoneCenter[zone][2] = origin[2];
			break; // maybe we should make a 'stuck' check
		}
	}
}

public Action Timer_DelayPreBuildZones(Handle timer)
{
	PreBuildZones();

	return Plugin_Stop;
}

public void StartTouchPost(int entity, int other)
{
	if(other < 1 || other > MaxClients || gI_EntityZone[entity] == -1 || !gA_ZoneCache[gI_EntityZone[entity]].bZoneInitialized)
	{
		return;
	}

	int entityzone = gI_EntityZone[entity];
	int type = gA_ZoneCache[entityzone].iZoneType;
	int track = gA_ZoneCache[entityzone].iZoneTrack;
	int data = gA_ZoneCache[entityzone].iZoneData;

	if(!IsFakeClient(other))
	{
		gB_InsideZone[other][type][track] = true;
		gB_InsideZoneID[other][entityzone] = true;

		if(!IsCurrentTrack(other, track))
		{
			return;
		}

		TimerStatus status = Shavit_GetTimerStatus(other);

		if(status == Timer_Paused)
		{
			return;
		}

		Action result = Plugin_Continue;
		Call_StartForward(gH_Forwards_EnterZone);
		Call_PushCell(other);
		Call_PushCell(type);
		Call_PushCell(track);
		Call_PushCell(entityzone);
		Call_PushCell(entity);
		Call_PushCell(data);
		Call_Finish(result);

		if(result != Plugin_Continue)
		{
			return;
		}

		switch(type)
		{
			case Zone_Start:
			{
				Shavit_SetCurrentStage(other, 1);
				Shavit_SetCurrentCP(other, 0);
				Shavit_SetLastStage(other, 1);
				Shavit_SetLastCP(other, (gB_LinearMap) ? 0 : 1);

				gI_InsideZoneIndex[other] = entityzone;
				gI_LastStartZoneIndex[other][track] = entityzone;
			}

			case Zone_End:
			{
				if(!gB_LinearMap) // prevent no stages.
				{
					Shavit_SetCurrentStage(other, gI_Stages + 1); // a hack that record the last stage's time
					Shavit_SetLastStage(other, gI_Stages + 1);
					Shavit_FinishStage(other);
				}

				int nextcp = (gB_LinearMap) ? gI_Checkpoints + 1 : gI_Stages + 1;

				Shavit_SetCurrentCP(other, nextcp);
				Shavit_SetLastCP(other, nextcp);

				if(Shavit_IsStageTimer(other))
				{
					Shavit_StopTimer(other);
				}
				else if(status != Timer_Stopped && !Shavit_IsPaused(other) && Shavit_GetClientTrack(other) == track)
				{
					Shavit_FinishCheckpoint(other);
					Shavit_FinishMap(other, track);
				}
			}

			case Zone_Stage:
			{
				gI_InsideZoneIndex[other] = entityzone;
				Shavit_SetCurrentStage(other, data);
				Shavit_SetCurrentCP(other, data);

				if(Shavit_GetCurrentStage(other) > Shavit_GetLastStage(other))
				{
					Shavit_FinishStage(other);

					if(!Shavit_IsStageTimer(other))
					{
						Shavit_FinishCheckpoint(other);
					}
				}

				Shavit_SetLastStage(other, data);
				Shavit_SetLastCP(other, data);
			}

			case Zone_Checkpoint:
			{
				Shavit_SetCurrentCP(other, data);

				if(Shavit_GetCurrentCP(other) > Shavit_GetLastCP(other))
				{
					Shavit_FinishCheckpoint(other);
				}

				Shavit_SetLastCP(other, data);
			}

			case Zone_Stop:
			{
				if(status != Timer_Stopped)
				{
					Shavit_StopTimer(other);
					Shavit_PrintToChat(other, "%T", "ZoneStopEnter", other);
				}
			}

			case Zone_Teleport:
			{
				if(EmptyVector(gV_Destinations[entityzone]))
				{
					Shavit_RestartTimer(other, Shavit_GetClientTrack(other));
				}
				else
				{
					TeleportEntity(other, gV_Destinations[entityzone], NULL_VECTOR, NULL_VECTOR);
				}
			}

			case Zone_AntiJump:
			{
				gB_AntiJump[other] = true;
			}
		}
	}

	else
	{
		switch(type)
		{
			case Zone_Stage:
			{
				Call_StartForward(gH_Forwards_BotEnterStageZone);
				Call_PushCell(other);
				Call_PushCell(data);
				Call_Finish();
			}

			case Zone_Checkpoint:
			{
				Call_StartForward(gH_Forwards_BotEnterCheckpointZone);
				Call_PushCell(other);
				Call_PushCell(data);
				Call_Finish();
			}
		}
	}
}

public void EndTouchPost(int entity, int other)
{
	if(other < 1 || other > MaxClients || Shavit_GetTimerStatus(other) == Timer_Paused || gI_EntityZone[entity] == -1)
	{
		return;
	}

	int entityzone = gI_EntityZone[entity];
	int type = gA_ZoneCache[entityzone].iZoneType;
	int track = gA_ZoneCache[entityzone].iZoneTrack;
	int data = gA_ZoneCache[entityzone].iZoneData;

	float fSpeed[3];
	GetEntPropVector(other, Prop_Data, "m_vecAbsVelocity", fSpeed);
	float fSpeed3D = (SquareRoot(Pow(fSpeed[0], 2.0) + Pow(fSpeed[1], 2.0) + Pow(fSpeed[2], 2.0)));

	if(!IsFakeClient(other))
	{
		gB_InsideZone[other][type][track] = false;
		gB_InsideZoneID[other][entityzone] = false;
		gB_AntiJump[other] = false;

		ClearShittyLimitPrestrafe(other);

		Action result = Plugin_Continue;
		Call_StartForward(gH_Forwards_LeaveZone);
		Call_PushCell(other);
		Call_PushCell(type);
		Call_PushCell(track);
		Call_PushCell(entityzone);
		Call_PushCell(entity);
		Call_PushCell(data);
		Call_Finish(result);

		if(result != Plugin_Continue)
		{
			return;
		}

		float fTime = Shavit_GetClientTime(other);

		if(fTime > 0.0 && fTime <= 0.5)
		{
			if(type == Zone_Start)
			{
				Call_StartForward(gH_Forwards_StartTimer_Post);
				Call_PushCell(other);
				Call_PushCell(Shavit_GetBhopStyle(other));
				Call_PushCell(track);
				Call_PushFloat(fSpeed3D);
				Call_Finish();
			}

			else if(type == Zone_Stage && Shavit_IsStageTimer(other))
			{
				Call_StartForward(gH_Forwards_StageTimer_Post);
				Call_PushCell(other);
				Call_PushCell(Shavit_GetBhopStyle(other));
				Call_PushCell(data);
				Call_PushFloat(fSpeed3D);
				Call_Finish();
			}
		}
	}
}

public void TouchPost(int entity, int other)
{
	if(other < 1 || other > MaxClients || gI_EntityZone[entity] == -1 || IsFakeClient(other) || Shavit_GetTimerStatus(other) == Timer_Paused || Shavit_IsPracticeMode(other))
	{
		return;
	}

	// do precise stuff here, this will be called *A LOT*
	int entityzone = gI_EntityZone[entity];
	int type = gA_ZoneCache[entityzone].iZoneType;
	int track = gA_ZoneCache[entityzone].iZoneTrack;
	int data = gA_ZoneCache[entityzone].iZoneData;

	gB_InsideZone[other][type][track] = true;
	gB_InsideZoneID[other][entityzone] = true;

	if(!IsCurrentTrack(other, track))
	{
		return;
	}

	switch(type)
	{
		case Zone_Start:
		{
			// start timer instantly for main track, but require bonuses to have the current timer stopped
			// so you don't accidentally step on those while running
			Shavit_SetStageTimer(other, false);
			Shavit_StartTimer(other, track);

			if(ShittyLimitPrestrafe(other, entityzone, false, true))
			{
				SendLimitMessage(other);
			}
		}

		case Zone_End:
		{
			Action result = Plugin_Continue;
			Call_StartForward(gH_Forwards_OnEndZone);
			Call_PushCell(other);
			Call_Finish(result);

			if(result != Plugin_Continue)
			{
				return;
			}
		}

		case Zone_Stage:
		{
			if(Shavit_GetClientTrack(other) == Track_Main)
			{
				Action result = Plugin_Continue;
				Call_StartForward(gH_Forwards_OnStage);
				Call_PushCell(other);
				Call_PushCell(data);
				Call_Finish(result);

				if(result != Plugin_Continue)
				{
					return;
				}

				if(ShittyLimitPrestrafe(other, entityzone, true, true))
				{
					SendLimitMessage(other);
				}

				if(Shavit_IsStageTimer(other))
				{
					Shavit_StartTimer(other, Track_Main);
				}
			}
		}

		case Zone_Stop:
		{
			if(Shavit_GetTimerStatus(other) != Timer_Stopped)
			{
				Shavit_StopTimer(other);
				Shavit_PrintToChat(other, "%T", "ZoneStopEnter", other);
			}
		}
	}
}

void FillBoxMinMax(float point1[3], float point2[3], float boxmin[3], float boxmax[3])
{
	for (int i = 0; i < 3; i++)
	{
		boxmin[i] = (point1[i] < point2[i]) ? point1[i] : point2[i];
		boxmax[i] = (point1[i] < point2[i]) ? point2[i] : point1[i];
	}
}

bool PointInBox(float point[3], float bmin[3], float bmax[3])
{
	return (bmin[0] <= point[0] <= bmax[0]) &&
	       (bmin[1] <= point[1] <= bmax[1]) &&
	       (bmin[2] <= point[2] <= bmax[2]);
}

void TransmitTriggers(int client, bool btransmit, bool all = false)
{
	if(!IsValidClient(client))
	{
		return;
	}

	ArrayList trigger = view_as<ArrayList>(CloneHandle(all ? gA_Triggers : gA_HookTriggers));

	for(int i = 0; i < trigger.Length; i++)
	{
		int entity = trigger.Get(i);
		int effectFlags = GetEntData(entity, gI_Offset_m_fEffects);
		int edictFlags = GetEdictFlags(entity);

		if(btransmit)
		{
			effectFlags &= ~EF_NODRAW;
			edictFlags &= ~FL_EDICT_DONTSEND;
		}

		else
		{
			effectFlags |= EF_NODRAW;
			edictFlags |= FL_EDICT_DONTSEND;
		}

		SetEntData(entity, gI_Offset_m_fEffects, effectFlags);
		ChangeEdictState(entity, gI_Offset_m_fEffects);
		SetEdictFlags(entity, edictFlags);

		if(btransmit)
		{
			SDKHook(entity, SDKHook_SetTransmit, Hook_SetTransmit);
		}

		else
		{
			SDKUnhook(entity, SDKHook_SetTransmit, Hook_SetTransmit);
		}
	}

	delete trigger;

	if(btransmit)
	{
		if(gH_DrawZonesToClient[client] == null)
		{
			gH_DrawZonesToClient[client] = CreateTimer(gCV_Interval.FloatValue, Timer_DrawZonesToClient, GetClientSerial(client), TIMER_REPEAT);
		}
	}

	else
	{
		delete gH_DrawZonesToClient[client];
	}
}

public Action Hook_SetTransmit(int entity, int other)
{
	if(!gB_ShowTriggers[other])
	{
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public Action Timer_DrawZonesToClient(Handle Timer, any data)
{
	if(gI_MapZones == 0)
	{
		return Plugin_Continue;
	}

	int client = GetClientFromSerial(data);

	if(client == 0 || !gB_ShowTriggers[client])
	{
		return Plugin_Handled;
	}

	static int iCycle = 0;

	if(iCycle >= gI_MapZones)
	{
		iCycle = 0;
	}

	for(int i = iCycle; i < gI_MapZones; i++, iCycle++)
	{
		if(gA_ZoneCache[i].bZoneInitialized)
		{
			int type = gA_ZoneCache[i].iZoneType;
			int track = gA_ZoneCache[i].iZoneTrack;

			if(gA_ZoneSettings[type][track].bVisible || (gA_ZoneCache[i].iZoneFlags & ZF_ForceRender) > 0)
			{
				continue; // already drew to everyone, find next undrawn
			}

			DrawZoneToSingleClient(client, 
								gV_MapZones_Visual[i], 
								GetZoneColors(type, track), 
								gCV_Interval.FloatValue, 
								gA_ZoneSettings[type][track].fWidth, 
								gA_ZoneSettings[type][track].bFlatZone, 
								gA_ZoneSettings[type][track].iBeam, 
								gA_ZoneSettings[type][track].iHalo);
		}
	}

	iCycle = 0;

	return Plugin_Continue;
}

void DrawZoneToSingleClient(int client, float points[8][3], int color[4], float life, float width, bool flat, int beam, int halo)
{
	static int pairs[][] =
	{
		{ 0, 2 },
		{ 2, 6 },
		{ 6, 4 },
		{ 4, 0 },
		{ 0, 1 },
		{ 3, 1 },
		{ 3, 2 },
		{ 3, 7 },
		{ 5, 1 },
		{ 5, 4 },
		{ 6, 7 },
		{ 7, 5 }
	};

	for(int i = 0; i < ((flat)? 4:12); i++)
	{
		TE_SetupBeamPoints(points[pairs[i][0]], points[pairs[i][1]], beam, halo, 0, 0, life, width, width, 0, 0.0, color, 0);
		TE_SendToClient(client, 0.0);
	}
}

void DoTeleport(int client, int zone)
{
	if(!EmptyVector(gV_CustomDestinations[client][zone]) && 
		(Shavit_IsStageTimer(client) || gA_ZoneCache[zone].iZoneType == Zone_Start))
	{
		TeleportEntity(client, gV_CustomDestinations[client][zone], gV_CustomDestinationsAngle[client][zone], view_as<float>({0.0, 0.0, 0.0}));
	}
	else if(!EmptyVector(gV_Destinations[zone]))
	{
		TeleportEntity(client, gV_Destinations[zone], NULL_VECTOR, view_as<float>({0.0, 0.0, 0.0}));
	}
	else
	{
		TeleportEntity(client, gV_ZoneCenter[zone], NULL_VECTOR, view_as<float>({0.0, 0.0, 0.0}));
	}
}

int FindNumberInString(const char[] str)
{
	Regex sRegex = new Regex("[0-9]{1,}");

	char sNum[4];

	if(sRegex.Match(str) > 0)
	{
		sRegex.GetSubString(0, sNum, 4);
	}

	delete sRegex;

	return StringToInt(sNum);
}

// This is used instead of `TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, fSpeed)`.
// Why: TeleportEntity somehow triggers the zone EndTouch which fucks with `InsideZone`.
void DumbSetVelocity(int client, float fSpeed[3])
{
	// Someone please let me know if any of these are unnecessary.
	SetEntPropVector(client, Prop_Data, "m_vecBaseVelocity", NULL_VECTOR);
	SetEntPropVector(client, Prop_Data, "m_vecVelocity", fSpeed);
	SetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", fSpeed); // m_vecBaseVelocity+m_vecVelocity
}

bool ShittyLimitPrestrafe(int client, int id, bool inStage, bool inZone)
{
	if(Shavit_IsTeleporting(client) || !IsValidClient(client, true))
	{
		return false;
	}

	bool onGround = view_as<bool>(GetEntityFlags(client) & FL_ONGROUND);
	bool bLimited = false;

	if(GetEntityMoveType(client) != MOVETYPE_NOCLIP)
	{
		if(gCV_PreSpeed.IntValue >= 1)
		{
			// surfheaven prespeed
			// limit speed since 2 jumps
			// int iGroundEntity = GetEntPropEnt(client, Prop_Send, "m_hGroundEntity");
			// iGroundEntity == 0 ---> onGround
			// iGroundEntity == -1 ---> onAir

			if(inStage && !Shavit_GetMapLimitspeed()) // do not limit all stages' speed
			{
				return false;
			}

			float fSpeed[3];
			GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", fSpeed);
			float fSpeedXY = SquareRoot(Pow(fSpeed[0], 2.0) + Pow(fSpeed[1], 2.0));

			if(!gB_InZone[client]) // limit those one that enter zone by outsiding zone
			{
				if(gA_ZoneCache[id].fLimitSpeed <= 0.0)
				{
					return false;
				}

				if(fSpeedXY > gA_ZoneCache[id].fLimitSpeed)
				{
					fSpeed[0] *= 0.1;
					fSpeed[1] *= 0.1;
					DumbSetVelocity(client, fSpeed);

					bLimited = true;
				}
			}

			if(GetEntityFlags(client) & FL_BASEVELOCITY) // they are on booster, dont limit them
			{
				return false;
			}

			if(gB_OnGround[client] && !onGround) // 起跳 starts jump
			{
				if(++gI_Jumps[client] >= 2)
				{
					float fScale = 260.0 / fSpeedXY;

					if(fScale < 1.0)
					{
						fSpeed[0] *= fScale;
						fSpeed[1] *= fScale;
						DumbSetVelocity(client, fSpeed);

						bLimited = true;
					}
				}
			}
			else if(gB_OnGround[client] && onGround) // 不跳 not jumping
			{
				gI_Jumps[client] = 0;
			}
		}
	}

	gB_InZone[client] = inZone;

	return bLimited;
}

// clear them when leave zone
void ClearShittyLimitPrestrafe(int client)
{
	gB_InZone[client] = false;

	switch(gI_Jumps[client])
	{
		case 1:
		{
			return;
		}

		default:
		{
			gI_Jumps[client] = 0;
		}
	}
}

bool IsCurrentTrack(int client, int track)
{
	return gCV_EnforceTracks.BoolValue && track == Shavit_GetClientTrack(client);
}

void SendLimitMessage(int client)
{
	Shavit_PrintToChat(client, "%T", "ZoneExceededLimit", client);
	SendMessageToSpectator(client, "%t", "ZoneExceededLimit", client, true);
}

stock void SendMessageToSpectator(int client, const char[] message, any ..., bool translate = false)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(i != client && (IsValidClient(i) && GetSpectatorTarget(i, i) == client))
		{
			if(!translate)
			{
				Shavit_PrintToChat(i, message);
			}
			else
			{
				SetGlobalTransTarget(i);

				char sBuffer[256];
				VFormat(sBuffer, sizeof(sBuffer), message, 3);
				Shavit_PrintToChat(i, sBuffer);
			}
		}
	}
}