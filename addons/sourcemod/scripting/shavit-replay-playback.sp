/*
 * shavit's Timer - Replay Bot
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
#include <convar_class>
#include <dhooks>

#include <shavit>
#include <shavit/wr>
#include <shavit/replay-shared>
#include <shavit/replay-playback>

#undef REQUIRE_PLUGIN
#include <adminmenu>

#undef REQUIRE_EXTENSIONS
#include <cstrike>
#include <closestpos>

#pragma newdecls required
#pragma semicolon 1



public Plugin myinfo =
{
	name = "[shavit] Replay Bot",
	author = "shavit",
	description = "A replay bot for shavit's bhop timer.",
	version = SHAVIT_VERSION,
	url = "https://github.com/shavitush/bhoptimer"
}

// os type
bool gB_Linux;


char gS_ReplayFolder[PLATFORM_MAX_PATH];

// custom cvar settings
char gS_ForcedCvars[][][] =
{
	{ "bot_quota", "0" },
	{ "bot_stop", "1" },
	{ "bot_quota_mode", "normal" },
	{ "tf_bot_quota_mode", "normal" },
	{ "mp_limitteams", "0" },
	{ "bot_chatter", "off" },
	{ "bot_flipout", "1" },
	{ "bot_zombie", "1" },
	{ "mp_autoteambalance", "0" },
	{ "bot_controllable", "0" }
};

// cache
frame_cache_t gA_FrameCache[STYLE_LIMIT][TRACKS_SIZE];
frame_cache_t gA_FrameCache_Stage[STYLE_LIMIT][MAX_STAGES];

bool gB_Button[MAXPLAYERS+1];

bool gB_InReplayMenu[MAXPLAYERS+1];
float gF_LastInteraction[MAXPLAYERS+1];

float gF_TimeDifference[MAXPLAYERS+1];
int   gI_TimeDifferenceStyle[MAXPLAYERS+1];
float gF_VelocityDifference2D[MAXPLAYERS+1];
float gF_VelocityDifference3D[MAXPLAYERS+1];

bool gB_Late = false;


// server specific
float gF_Tickrate = 0.0;
char gS_Map[PLATFORM_MAX_PATH];
bool gB_CanUpdateReplayClient = false;

// replay bot stuff
int gI_CentralBot = -1;
int gI_TrackBot = -1;
int gI_StageBot = -1;
int gI_DynamicBots = 0;

bot_info_t gA_BotInfo[MAXPLAYERS+1];

// hooks and sdkcall stuff
Handle gH_BotAddCommand = INVALID_HANDLE;
Handle gH_DoAnimationEvent = INVALID_HANDLE ;
DynamicDetour gH_MaintainBotQuota = null;
DynamicDetour gH_TeamFull = null;
int gI_WEAPONTYPE_UNKNOWN = 123123123;
int gI_LatestClient = -1;
bot_info_t gA_BotInfo_Temp; // cached when creating a bot so we can use an accurate name in player_connect

// how do i call this
bool gB_HideNameChange = false;

// plugin cvars
Convar gCV_Enabled = null;
Convar gCV_ReplayDelay = null;
Convar gCV_DefaultTeam = null;
Convar gCV_CentralBot = null;
Convar gCV_DynamicBotLimit = null;
Convar gCV_BotShooting = null;
Convar gCV_BotPlusUse = null;
Convar gCV_BotWeapon = null;
Convar gCV_PlaybackCanStop = null;
Convar gCV_PlaybackCooldown = null;
Convar gCV_DynamicTimeSearch = null;
Convar gCV_DynamicTimeCheap = null;
Convar gCV_DynamicTimeTick = null;
Convar gCV_EnableDynamicTimeDifference = null;
ConVar sv_duplicate_playernames_ok = null;
ConVar bot_join_after_player = null;
ConVar mp_randomspawn = null;

// timer settings
int gI_Styles = 0;
stylestrings_t gS_StyleStrings[STYLE_LIMIT];

// replay settings
replaystrings_t gS_ReplayStrings;

// admin menu
TopMenu gH_AdminMenu = null;
TopMenuObject gH_TimerCommands = INVALID_TOPMENUOBJECT;

// database related things
Database2 gH_SQL = null;
char gS_MySQLPrefix[32];

// module
bool gB_ClosestPos;

#include "shavit-replay-shared/file.sp"
#include "shavit-replay-shared/stocks.sp"

#include "shavit-replay-playback/api.sp"
#include "shavit-replay-playback/closestpos.sp"
#include "shavit-replay-playback/commands.sp"
#include "shavit-replay-playback/control.sp"
#include "shavit-replay-playback/db.sp"
#include "shavit-replay-playback/nav.sp"
#include "shavit-replay-playback/replay_cache.sp"
#include "shavit-replay-playback/replay_menu.sp"
#include "shavit-replay-playback/playback.sp"



// =====[ PLUGIN EVENTS ]=====

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNatives();

	FileInit();

	RegPluginLibrary("shavit-replay-playback");

	gB_Late = late;

	return APLRes_Success;
}

public void OnPluginStart()
{
	if(GetEngineVersion() != Engine_CSGO)
	{
		SetFailState("This plugin only support for CSGO!");
		return;
	}

	LoadTranslations("shavit-common.phrases");
	LoadTranslations("shavit-replay.phrases");

	// game specific
	gF_Tickrate = (1.0 / GetTickInterval());

	CreateGlobalForwards();
	CreateConVars();
	HookEvents();
	RegisterCommands();
	SQL_DBConnect();
	LoadDHooks();
	CreateAllNavFiles();

	if(gB_Late)
	{
		Shavit_OnStyleConfigLoaded(Shavit_GetStyleCount());
	}

	for(int i = 1; i <= MaxClients; i++)
	{
		ClearBotInfo(gA_BotInfo[i]);

		if (gB_Late && IsValidClient(i) && !IsFakeClient(i))
		{
			OnClientPutInServer(i);
		}
	}
}

public void OnPluginEnd()
{
	KickAllReplays();
}

// Stops bot_quota from doing anything.
public MRESReturn Detour_MaintainBotQuota(int pThis)
{
	return MRES_Supercede;
}

public MRESReturn Detour_TeamFull(int pThis, DHookReturn hReturn, DHookParam hParams)
{
	hReturn.Value = false;
	return MRES_Supercede;
}

public void OnLibraryAdded(const char[] name)
{
	if (strcmp(name, "adminmenu") == 0)
	{
		if ((gH_AdminMenu = GetAdminTopMenu()) != null)
		{
			OnAdminMenuReady(gH_AdminMenu);
		}
	}
	else if (strcmp(name, "closestpos") == 0)
	{
		gB_ClosestPos = true;
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if (strcmp(name, "adminmenu") == 0)
	{
		gH_AdminMenu = null;
		gH_TimerCommands = INVALID_TOPMENUOBJECT;
	}
	else if (strcmp(name, "closestpos") == 0)
	{
		gB_ClosestPos = false;
	}
}

public void OnAllPluginsLoaded()
{
	if(!LibraryExists("shavit-wr"))
	{
		SetFailState("shavit-wr is required for the plugin to work.");
	}

	// admin menu
	if(LibraryExists("adminmenu") && ((gH_AdminMenu = GetAdminTopMenu()) != null))
	{
		OnAdminMenuReady(gH_AdminMenu);
	}

	if (LibraryExists("closestpos"))
	{
		gB_ClosestPos = true;
	}
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	OnMapStart();
}

public void OnForcedConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	char sName[32];
	convar.GetName(sName, 32);

	for(int i = 0; i < sizeof(gS_ForcedCvars); i++)
	{
		if(StrEqual(sName, gS_ForcedCvars[i][0]))
		{
			if(!StrEqual(newValue, gS_ForcedCvars[i][1]))
			{
				convar.SetString(gS_ForcedCvars[i][1]);
			}

			break;
		}
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

		gH_AdminMenu.AddItem("sm_deletereplay", AdminMenu_DeleteReplay, gH_TimerCommands, "sm_deletereplay", ADMFLAG_RCON);
	}
}

public void AdminMenu_DeleteReplay(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	if(action == TopMenuAction_DisplayOption)
	{
		FormatEx(buffer, maxlength, "%t", "DeleteReplayAdminMenu");
	}

	else if(action == TopMenuAction_SelectOption)
	{
		Command_DeleteReplay(param, 0);
	}
}

public Action Timer_Cron(Handle Timer)
{
	int valid = 0;

	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i) && !IsFakeClient(i))
		{
			valid++;
		}

		if (gA_BotInfo[i].iEnt != i)
		{
			continue;
		}

		if (1 <= gA_BotInfo[i].iEnt <= MaxClients)
		{
			RequestFrame(Frame_UpdateReplayClient, GetClientSerial(gA_BotInfo[i].iEnt));
		}
	}

	if(IsClientsNone(valid))
	{
		return Plugin_Continue;
	}

	JoinBots();

	return Plugin_Continue;
}

public void OnMapStart()
{
	if(!LoadStyling())
	{
		SetFailState("Could not load the replay bots' configuration file. Make sure it exists (addons/sourcemod/configs/shavit-replay.cfg) and follows the proper syntax!");
	}

	gB_CanUpdateReplayClient = true;

	UpdateCurrentMap();

	KickAllReplays();

	if(!gCV_Enabled.BoolValue)
	{
		return;
	}

	PrecacheModel("models/props/cs_office/vending_machine.mdl");

	Replay_CreateDirectories(gS_ReplayFolder, gI_Styles);

	DoReplayCache();

	Call_OnReplaysLoaded();

	if (gH_TeamFull != null)
	{
		gH_TeamFull.Enable(Hook_Post, Detour_TeamFull);
	}

	CreateTimer(3.0, Timer_Cron, 0, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public void OnMapEnd()
{
	gB_CanUpdateReplayClient = false;

	if (gH_TeamFull != null)
	{
		gH_TeamFull.Disable(Hook_Post, Detour_TeamFull);
	}
}

public void Shavit_OnStyleConfigLoaded(int styles)
{
	for(int i = 0; i < styles; i++)
	{
		Shavit_GetStyleStringsStruct(i, gS_StyleStrings[i]);
	}

	gI_Styles = styles;
}

public void Shavit_OnStyleChanged(int client, int oldstyle, int newstyle, int track, bool manual)
{
	gI_TimeDifferenceStyle[client] = newstyle;
}

public void OnClientPutInServer(int client)
{
	gI_LatestClient = client;

	if(IsClientSourceTV(client))
	{
		return;
	}

	if(!IsFakeClient(client))
	{
		OnClientPutInServer_ClientCache(client);
	}
	else
	{
		OnClientPutInServer_BotCache(client);
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	// trigger_once | trigger_multiple.. etc
	// func_door | func_door_rotating
	if(StrContains(classname, "trigger_") != -1 || StrContains(classname, "_door") != -1)
	{
		SDKHook(entity, SDKHook_StartTouch, HookTriggers);
		SDKHook(entity, SDKHook_EndTouch, HookTriggers);
		SDKHook(entity, SDKHook_Touch, HookTriggers);
		SDKHook(entity, SDKHook_Use, HookTriggers);
	}
}

public Action HookTriggers(int entity, int other)
{
	if(gCV_Enabled.BoolValue && 1 <= other <= MaxClients && IsFakeClient(other))
	{
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public void OnClientDisconnect(int client)
{
	if(IsClientSourceTV(client))
	{
		return;
	}

	if(!IsFakeClient(client))
	{
		OnClientDisconnect_ControlReplay(client);

		return;
	}

	OnClientDisconnect_ClearBotInfo(client);
}

public void Shavit_OnEnterStageZone_Bot(int bot, int stage)
{
	Shavit_OnEnterStageZone_Playback(bot, stage);
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	if(!gCV_Enabled.BoolValue)
	{
		return Plugin_Continue;
	}

	if(!IsPlayerAlive(client))
	{
		if((buttons & IN_USE) > 0)
		{
			if(!gB_Button[client] && GetSpectatorTarget(client) != -1)
			{
				OpenReplayMenu(client);
			}

			gB_Button[client] = true;
		}
		else
		{
			gB_Button[client] = false;
		}

		return Plugin_Continue;
	}

	if(IsFakeClient(client))
	{
		if (gA_BotInfo[client].iEnt == client)
		{
			return OnPlayerRunCmd_Playback(gA_BotInfo[client], buttons, impulse, vel);
		}
	}

	return OnPlayerRunCmd_ClosestPos(client);
}

public void Player_Event(Event event, const char[] name, bool dontBroadcast)
{
	if(!gCV_Enabled.BoolValue)
	{
		return;
	}

	int client = GetClientOfUserId(event.GetInt("userid"));

	if(IsFakeClient(client))
	{
		event.BroadcastDisabled = true;
	}
	else if (gA_BotInfo[client].iEnt > 0)
	{
		PlayerEvent_ControlReplay(client);
	}
}

public Action BotEvents(Event event, const char[] name, bool dontBroadcast)
{
	if(!gCV_Enabled.BoolValue)
	{
		return Plugin_Continue;
	}

	int client = GetClientOfUserId(event.GetInt("userid"));

	if(event.GetBool("bot") || !client || IsFakeClient(client))
	{
		event.BroadcastDisabled = true;

		if (StrEqual(name, "player_connect"))
		{
			BotEvents_Player_Connect(event);
		}

		return Plugin_Changed;
	}

	return Plugin_Continue;
}

public Action BotEventsStopLogSpam(Event event, const char[] name, bool dontBroadcast)
{
	if(!gCV_Enabled.BoolValue)
	{
		return Plugin_Continue;
	}

	if(IsFakeClient(GetClientOfUserId(event.GetInt("userid"))))
	{
		event.BroadcastDisabled = true;
		return Plugin_Handled; // Block with Plugin_Handled...
	}

	return Plugin_Continue;
}

public Action Hook_SayText2(UserMsg msg_id, any msg, const int[] players, int playersNum, bool reliable, bool init)
{
	if(!gB_HideNameChange || !gCV_Enabled.BoolValue)
	{
		return Plugin_Continue;
	}

	// caching usermessage type rather than call it every time
	static UserMessageType um = view_as<UserMessageType>(-1);

	if(um == view_as<UserMessageType>(-1))
	{
		um = GetUserMessageType();
	}

	char sMessage[24];

	if(um == UM_Protobuf)
	{
		Protobuf pbmsg = msg;
		pbmsg.ReadString("msg_name", sMessage, 24);
	}
	else
	{
		BfRead bfmsg = msg;
		bfmsg.ReadByte();
		bfmsg.ReadByte();
		bfmsg.ReadString(sMessage, 24);
	}

	if(StrEqual(sMessage, "#Cstrike_Name_Change") || StrEqual(sMessage, "#TF_Name_Change"))
	{
		gB_HideNameChange = false;

		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public void Shavit_OnReplaySaved(int client, int style, float time, int jumps, int strafes, float sync, int track, float oldtime, float avgvel, float maxvel, int timestamp, bool isbestreplay, bool istoolong, bool iscopy, const char[] replaypath, ArrayList frames, int preframes, int postframes, const char[] name)
{
	if(!Shavit_OnReplaySaved_CanBeCached(style, time, track, isbestreplay, istoolong, frames, preframes, postframes, name))
	{
		return;
	}

	Shavit_OnReplaySaved_StartReplay(style, track);
	Shavit_OnReplaySaved_ClosestPos(style, track);
}

public void Shavit_OnStageReplaySaved(int client, int stage, int style, float time, int steamid, ArrayList playerrecording, int preframes, int iSize)
{
	Shavit_OnStageReplaySaved_StartReplay(stage, style);
}

public void Shavit_OnWRDeleted(int style, int id, int track, int accountid, const char[] mapname)
{
	Shavit_OnWRDeleted_DeleteReplay(style, track, accountid, mapname);
}

public void Shavit_OnWRCPDeleted(int stage, int style, int steamid, const char[] mapname)
{
	Shavit_OnWRCPDeleted_DeleteReplay(stage, style, mapname);
}

public void Shavit_OnDeleteMapData(int client, const char[] map)
{
	DeleteAllReplays(map);
	Shavit_PrintToChat(client, "Deleted all replay data for %s.", map);
}



// =====[ PRIVATE ]=====

static void FileInit()
{
	if (!FileExists("cfg/sourcemod/plugin.shavit-replay-playback.cfg") && FileExists("cfg/sourcemod/plugin.shavit-replay.cfg"))
	{
		File source = OpenFile("cfg/sourcemod/plugin.shavit-replay.cfg", "r");
		File destination = OpenFile("cfg/sourcemod/plugin.shavit-replay-playback.cfg", "w");

		if (source && destination)
		{
			char line[512];

			while (!source.EndOfFile() && source.ReadLine(line, sizeof(line)))
			{
				destination.WriteLine("%s", line);
			}
		}

		delete destination;
		delete source;
	}
}

static void CreateConVars()
{
	ConVar bot_stop = FindConVar("bot_stop");

	if (bot_stop != null)
	{
		bot_stop.Flags &= ~FCVAR_CHEAT;
	}

	bot_join_after_player = FindConVar("bot_join_after_player");

	mp_randomspawn = FindConVar("mp_randomspawn");

	sv_duplicate_playernames_ok = FindConVar("sv_duplicate_playernames_ok");

	if (sv_duplicate_playernames_ok != null)
	{
		sv_duplicate_playernames_ok.Flags &= ~FCVAR_REPLICATED;
	}

	for(int i = 0; i < sizeof(gS_ForcedCvars); i++)
	{
		ConVar hCvar = FindConVar(gS_ForcedCvars[i][0]);

		if(hCvar != null)
		{
			hCvar.SetString(gS_ForcedCvars[i][1]);
			hCvar.AddChangeHook(OnForcedConVarChanged);
		}
	}

	// plugin convars
	gCV_Enabled = new Convar("shavit_replay_enabled", "1", "Enable replay bot functionality?", 0, true, 0.0, true, 1.0);
	gCV_ReplayDelay = new Convar("shavit_replay_delay", "0.25", "Time to wait before restarting the replay after it finishes playing.", 0, true, 0.0, true, 10.0);
	gCV_DefaultTeam = new Convar("shavit_replay_defaultteam", "3", "Default team to make the bots join, if possible.\n2 - Terrorists/RED\n3 - Counter Terrorists/BLU", 0, true, 2.0, true, 3.0);
	gCV_CentralBot = new Convar("shavit_replay_centralbot", "0", "Have one central bot instead of one bot per replay.\nTriggered with !replay.\nRestart the map for changes to take effect.\nThe disabled setting is not supported - use at your own risk.\n0 - Disabled\n1 - Enabled", 0, true, 0.0, true, 1.0);
	gCV_DynamicBotLimit = new Convar("shavit_replay_dynamicbotlimit", "5", "How many extra bots next to the central bot can be spawned with !replay.\n0 - no dynamically spawning bots.", 0, true, 0.0, true, float(MaxClients-2));
	gCV_BotShooting = new Convar("shavit_replay_botshooting", "0", "Attacking buttons to allow for bots.\n0 - none\n1 - +attack\n2 - +attack2\n3 - both", 0, true, 0.0, true, 3.0);
	gCV_BotPlusUse = new Convar("shavit_replay_botplususe", "1", "Allow bots to use +use?", 0, true, 0.0, true, 1.0);
	gCV_BotWeapon = new Convar("shavit_replay_botweapon", "none", "Choose which weapon the bot will hold.\nLeave empty to use the default.\nSet to \"none\" to have none.\nExample: weapon_usp");
	gCV_PlaybackCanStop = new Convar("shavit_replay_pbcanstop", "1", "Allow players to stop playback if they requested it?", 0, true, 0.0, true, 1.0);
	gCV_PlaybackCooldown = new Convar("shavit_replay_pbcooldown", "3.5", "Cooldown in seconds to apply for players between each playback they request/stop.\nDoes not apply to RCON admins.", 0, true, 0.0);
	gCV_DynamicTimeCheap = new Convar("shavit_replay_timedifference_cheap", "1", "0 - Disabled\n1 - only clip the search ahead to shavit_replay_timedifference_search\n2 - only clip the search behind to players current frame\n3 - clip the search to +/- shavit_replay_timedifference_search seconds to the players current frame", 0, true, 0.0, true, 3.0);
	gCV_DynamicTimeSearch = new Convar("shavit_replay_timedifference_search", "60.0", "Time in seconds to search the players current frame for dynamic time differences\n0 - Full Scan\nNote: Higher values will result in worse performance", 0, true, 0.0);
	gCV_EnableDynamicTimeDifference = new Convar("shavit_replay_timedifference", "1", "Enabled dynamic time/velocity differences for the hud", 0, true, 0.0, true, 1.0);

	char tenth[6];
	IntToString(RoundToFloor(1.0 / GetTickInterval() / 10), tenth, sizeof(tenth));
	gCV_DynamicTimeTick = new Convar("shavit_replay_timedifference_tick", tenth, "How often (in ticks) should the time difference update.\nYou should probably keep this around 0.1s worth of ticks.\nThe maximum value is your tickrate.", 0, true, 1.0, true, (1.0 / GetTickInterval()));

	Convar.AutoExecConfig();

	gCV_CentralBot.AddChangeHook(OnConVarChanged);
	gCV_DynamicBotLimit.AddChangeHook(OnConVarChanged);
}

static void HookEvents()
{
	HookEvent("player_spawn", Player_Event, EventHookMode_Pre);
	HookEvent("player_death", Player_Event, EventHookMode_Pre);
	HookEvent("player_connect", BotEvents, EventHookMode_Pre);
	HookEvent("player_disconnect", BotEvents, EventHookMode_Pre);

	// The spam from this one is really bad.: "\"%s<%i><%s><%s>\" changed name to \"%s\"\n"
	HookEvent("player_changename", BotEventsStopLogSpam, EventHookMode_Pre);
	// "\"%s<%i><%s><%s>\" joined team \"%s\"\n"
	HookEvent("player_team", BotEventsStopLogSpam, EventHookMode_Pre);
	// "\"%s<%i><%s><>\" entered the game\n"
	HookEvent("player_activate", BotEventsStopLogSpam, EventHookMode_Pre);

	// name change suppression
	HookUserMessage(GetUserMessageId("SayText2"), Hook_SayText2, true);
}

static void LoadDHooks()
{
	GameData gamedata = new GameData("shavit.games");

	if (gamedata == null)
	{
		SetFailState("Failed to load shavit gamedata");
	}

	gB_Linux = (gamedata.GetOffset("OS") == 2);

	StartPrepSDKCall(gB_Linux ? SDKCall_Raw : SDKCall_Static);

	if (!PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "CCSBotManager::BotAddCommand"))
	{
		SetFailState("Failed to get CCSBotManager::BotAddCommand");
	}

	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);  // int team
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);  // bool isFromConsole
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);  // const char *profileName
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);  // CSWeaponType weaponType
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);  // BotDifficultyType difficulty
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain); // bool

	if (!(gH_BotAddCommand = EndPrepSDKCall()))
	{
		SetFailState("Unable to prepare SDKCall for CCSBotManager::BotAddCommand");
	}

	if ((gI_WEAPONTYPE_UNKNOWN = gamedata.GetOffset("WEAPONTYPE_UNKNOWN")) == -1)
	{
		SetFailState("Failed to get WEAPONTYPE_UNKNOWN");
	}

	if (!(gH_MaintainBotQuota = DHookCreateDetour(Address_Null, CallConv_THISCALL, ReturnType_Void, ThisPointer_Address)))
	{
		SetFailState("Failed to create detour for BotManager::MaintainBotQuota");
	}

	if (!DHookSetFromConf(gH_MaintainBotQuota, gamedata, SDKConf_Signature, "BotManager::MaintainBotQuota"))
	{
		SetFailState("Failed to get address for BotManager::MaintainBotQuota");
	}

	gH_MaintainBotQuota.Enable(Hook_Pre, Detour_MaintainBotQuota);

	StartPrepSDKCall(gB_Linux ? SDKCall_Static : SDKCall_Player);

	if (PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "Player::DoAnimationEvent"))
	{
		if(gB_Linux)
		{
			PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_ByRef);
		}
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_ByValue);
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_ByValue);
	}

	gH_DoAnimationEvent = EndPrepSDKCall();

	delete gamedata;
}

static void KickAllReplays()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (gA_BotInfo[i].iEnt > 0)
		{
			KickReplay(gA_BotInfo[i]);
		}
	}

	gI_TrackBot = -1;
	gI_StageBot = -1;
}

static bool LoadStyling()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, PLATFORM_MAX_PATH, "configs/shavit-replay.cfg");

	KeyValues kv = new KeyValues("shavit-replay");
	
	if(!kv.ImportFromFile(sPath))
	{
		delete kv;

		return false;
	}

	kv.GetString("clantag", gS_ReplayStrings.sClanTag, MAX_NAME_LENGTH, "<EMPTY CLANTAG>");
	kv.GetString("namestyle", gS_ReplayStrings.sNameStyle, MAX_NAME_LENGTH, "<EMPTY NAMESTYLE>");
	kv.GetString("centralname", gS_ReplayStrings.sCentralName, MAX_NAME_LENGTH, "<EMPTY CENTRALNAME>");
	kv.GetString("unloaded", gS_ReplayStrings.sUnloaded, MAX_NAME_LENGTH, "<EMPTY UNLOADED>");

	char sFolder[PLATFORM_MAX_PATH];
	kv.GetString("replayfolder", sFolder, PLATFORM_MAX_PATH, "{SM}/data/replaybot");

	if(StrContains(sFolder, "{SM}") != -1)
	{
		ReplaceString(sFolder, PLATFORM_MAX_PATH, "{SM}/", "");
		BuildPath(Path_SM, sFolder, PLATFORM_MAX_PATH, "%s", sFolder);
	}
	
	strcopy(gS_ReplayFolder, PLATFORM_MAX_PATH, sFolder);

	delete kv;

	return true;
}

static void UpdateCurrentMap()
{
	GetCurrentMap(gS_Map, sizeof(gS_Map));
	bool bWorkshopWritten = WriteNavMesh(gS_Map); // write "maps/workshop/123123123/bhop_map.nav"
	GetMapDisplayName(gS_Map, gS_Map, sizeof(gS_Map));
	bool bDisplayWritten = WriteNavMesh(gS_Map); // write "maps/bhop_map.nav"
	LowercaseString(gS_Map);

	// Likely won't run unless this is a workshop map since CreateAllNavFiles() is ran in OnPluginStart()
	if (bWorkshopWritten || bDisplayWritten)
	{
		SetCommandFlags("nav_load", GetCommandFlags("nav_load") & ~FCVAR_CHEAT);
		ServerCommand("nav_load");
	}
}

static void DoReplayCache()
{
	for(int i = 0; i < gI_Styles; i++)
	{
		if(!ReplayEnabled(i))
		{
			continue;
		}

		for(int j = 0; j < TRACKS_SIZE; j++)
		{
			ClearFrameCache(gA_FrameCache[i][j]);
			DropClosestPos(i, j);
			DefaultLoadReplay(gA_FrameCache[i][j], i, j);
		}

		for(int j = 1; j < MAX_STAGES; j++)
		{
			ClearFrameCache(gA_FrameCache_Stage[i][j]);
			LoadStageReplay(gA_FrameCache_Stage[i][j], i, j);
		}
	}
}

static bool IsClientsNone(int valids)
{
	if(valids == 0)
	{
		KickAllReplays();
		return true;
	}

	return false;
}

static void JoinBots()
{
	if (!bot_join_after_player.BoolValue || GetClientCount() >= 1)
	{
		AddReplayBots();
	}
}