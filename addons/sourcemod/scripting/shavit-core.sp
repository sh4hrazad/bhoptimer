/*
 * shavit's Timer - Core
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
#include <sdkhooks>
#include <sdktools>
#include <geoip>
#include <clientprefs>
#include <convar_class>
#include <dhooks>
#include <shavit/colors>

#undef REQUIRE_PLUGIN
#include <shavit>

#pragma newdecls required
#pragma semicolon 1

#define CHANGE_FLAGS(%1,%2) (%1 = (%2))
#define EFL_CHECK_UNTOUCH (1<<24)

// game type (CS:GO)
bool gB_Protobuf = false;

// hook stuff
DynamicHook gH_AcceptInput; // used for hooking player_speedmod's AcceptInput
DynamicHook gH_HookTeleport; // used for hooking native game teleport function
Handle gH_PhysicsCheckForEntityUntouch;

enum struct HookingPlayer
{
	int iHookedIndex;
	int iPlayerFlags;
	bool bHooked;

	void AddHook(int client)
	{
		gH_HookTeleport.HookEntity(Hook_Pre, client, Detour_OnTeleport);
		gH_HookTeleport.HookEntity(Hook_Post, client, Detour_OnTeleport_Post);

		this.bHooked = true;
		this.iHookedIndex = client;
	}

	void RemoveHook()
	{
		this.bHooked = false;
		this.iHookedIndex = 0;
	}

	void AddFlag(int flags)
	{
		CHANGE_FLAGS(this.iPlayerFlags, this.iPlayerFlags | flags);
	}

	// Delay two frames to remove a flag, this is usually used in fastcall
	void RemoveFlag(int flagsToRemove)
	{
		DataPack dp = new DataPack();
		dp.WriteCell(flagsToRemove);
		dp.WriteCell(this.iHookedIndex);

		RequestFrame(Frame_RemoveFlag, dp);
	}

	// No delay, no handle create and delete, more save and faster
	void RemoveFlagEx(int flagsToRemove)
	{
		CHANGE_FLAGS(this.iPlayerFlags, this.iPlayerFlags & ~flagsToRemove);
	}

	int GetFlags()
	{
		return this.iPlayerFlags;
	}
}

HookingPlayer gA_HookedPlayer[MAXPLAYERS+1];

// database handle
Database2 gH_SQL = null;
bool gB_MySQL = false;
int gI_MigrationsRequired;
int gI_MigrationsFinished;

// forwards
Handle gH_Forwards_Start = null;
Handle gH_Forwards_StartPre = null;
Handle gH_Forwards_Stop = null;
Handle gH_Forwards_StopPre = null;
Handle gH_Forwards_FinishPre = null;
Handle gH_Forwards_Finish = null;
Handle gH_Forwards_OnRestartPre = null;
Handle gH_Forwards_OnRestart = null;
Handle gH_Forwards_OnEnd = null;
Handle gH_Forwards_OnPause = null;
Handle gH_Forwards_OnResume = null;
Handle gH_Forwards_OnStyleChanged = null;
Handle gH_Forwards_OnTrackChanged = null;
Handle gH_Forwards_OnStyleConfigLoaded = null;
Handle gH_Forwards_OnDatabaseLoaded = null;
Handle gH_Forwards_OnChatConfigLoaded = null;
Handle gH_Forwards_OnUserCmdPre = null;
Handle gH_Forwards_OnTimerIncrement = null;
Handle gH_Forwards_OnTimerIncrementPost = null;
Handle gH_Forwards_OnTimescaleChanged = null;
Handle gH_Forwards_OnTimeOffsetCalculated = null;
Handle gH_Forwards_OnProcessMovement = null;
Handle gH_Forwards_OnProcessMovementPost = null;
Handle gH_Forwards_OnDeleteMapData = null;
Handle gH_Forwards_OnCommandStyle = null;
Handle gH_Forwards_OnUserDeleteData = null;
Handle gH_Forwards_OnDeleteRestOfUserSuccess = null;

StringMap gSM_StyleCommands = null;

// player timer variables
timer_snapshot_t gA_Timers[MAXPLAYERS+1];

// used for offsets
float gF_SmallestDist[MAXPLAYERS + 1];
float gF_Origin[MAXPLAYERS + 1][2][3];
float gF_Fraction[MAXPLAYERS + 1];

// cookies
Handle gH_StyleCookie = null;

// late load
bool gB_Late = false;

// cvars
Convar gCV_Restart = null;
Convar gCV_Pause = null;
Convar gCV_PauseMovement = null;
Convar gCV_VelocityTeleport = null;
Convar gCV_DefaultStyle = null;
Convar gCV_NoChatSound = null;
Convar gCV_SimplerLadders = null;
Convar gCV_UseOffsets = null;
Convar gCV_TimeInMessages;

// cached cvars
int gI_DefaultStyle = 0;
bool gB_StyleCookies = true;

// table prefix
char gS_MySQLPrefix[32];

// timer settings
bool gB_Registered = false;
int gI_Styles = 0;
int gI_OrderedStyles[STYLE_LIMIT];
StringMap gSM_StyleKeys[STYLE_LIMIT];
int gI_CurrentParserIndex = 0;

// chat settings
chatstrings_t gS_ChatStrings;

// misc cache
bool gB_StopChatSound = false;
char gS_LogPath[PLATFORM_MAX_PATH];
char gS_DeleteMap[MAXPLAYERS+1][PLATFORM_MAX_PATH];
int gI_WipePlayerID[MAXPLAYERS+1];
char gS_Verification[MAXPLAYERS+1][8];
bool gB_CookiesRetrieved[MAXPLAYERS+1];

// flags
int gI_StyleFlag[STYLE_LIMIT];
char gS_StyleOverride[STYLE_LIMIT][32];

public Plugin myinfo =
{
	name = "[shavit] Core",
	author = "shavit",
	description = "The core for shavit's bhop timer.",
	version = SHAVIT_VERSION,
	url = "https://github.com/shavitush/bhoptimer"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("Shavit_CanPause", Native_CanPause);
	CreateNative("Shavit_ChangeClientStyle", Native_ChangeClientStyle);
	CreateNative("Shavit_FinishMap", Native_FinishMap);
	CreateNative("Shavit_GetBhopStyle", Native_GetBhopStyle);
	CreateNative("Shavit_GetChatStrings", Native_GetChatStrings);
	CreateNative("Shavit_GetChatStringsStruct", Native_GetChatStringsStruct);
	CreateNative("Shavit_GetClientJumps", Native_GetClientJumps);
	CreateNative("Shavit_GetClientTime", Native_GetClientTime);
	CreateNative("Shavit_GetClientTrack", Native_GetClientTrack);
	CreateNative("Shavit_GetDatabase", Native_GetDatabase);
	CreateNative("Shavit_GetOrderedStyles", Native_GetOrderedStyles);
	CreateNative("Shavit_GetStrafeCount", Native_GetStrafeCount);
	CreateNative("Shavit_GetStyleCount", Native_GetStyleCount);
	CreateNative("Shavit_GetStyleSetting", Native_GetStyleSetting);
	CreateNative("Shavit_GetStyleSettingInt", Native_GetStyleSettingInt);
	CreateNative("Shavit_GetStyleSettingBool", Native_GetStyleSettingBool);
	CreateNative("Shavit_GetStyleSettingFloat", Native_GetStyleSettingFloat);
	CreateNative("Shavit_HasStyleSetting", Native_HasStyleSetting);
	CreateNative("Shavit_GetStyleStrings", Native_GetStyleStrings);
	CreateNative("Shavit_GetStyleStringsStruct", Native_GetStyleStringsStruct);
	CreateNative("Shavit_GetSync", Native_GetSync);
	CreateNative("Shavit_GetZoneOffset", Native_GetZoneOffset);
	CreateNative("Shavit_GetDistanceOffset", Native_GetDistanceOffset);
	CreateNative("Shavit_GetTimerStatus", Native_GetTimerStatus);
	CreateNative("Shavit_HasStyleAccess", Native_HasStyleAccess);
	CreateNative("Shavit_IsPaused", Native_IsPaused);
	CreateNative("Shavit_IsPracticeMode", Native_IsPracticeMode);
	CreateNative("Shavit_LoadSnapshot", Native_LoadSnapshot);
	CreateNative("Shavit_LogMessage", Native_LogMessage);
	CreateNative("Shavit_PauseTimer", Native_PauseTimer);
	CreateNative("Shavit_PrintToChat", Native_PrintToChat);
	CreateNative("Shavit_PrintToChatAll", Native_PrintToChatAll);
	CreateNative("Shavit_RestartTimer", Native_RestartTimer);
	CreateNative("Shavit_ResumeTimer", Native_ResumeTimer);
	CreateNative("Shavit_SaveSnapshot", Native_SaveSnapshot);
	CreateNative("Shavit_SetPracticeMode", Native_SetPracticeMode);
	CreateNative("Shavit_SetStyleSetting", Native_SetStyleSetting);
	CreateNative("Shavit_SetStyleSettingFloat", Native_SetStyleSettingFloat);
	CreateNative("Shavit_SetStyleSettingBool", Native_SetStyleSettingBool);
	CreateNative("Shavit_SetStyleSettingInt", Native_SetStyleSettingInt);
	CreateNative("Shavit_StartTimer", Native_StartTimer);
	CreateNative("Shavit_StopChatSound", Native_StopChatSound);
	CreateNative("Shavit_StopTimer", Native_StopTimer);
	CreateNative("Shavit_GetClientTimescale", Native_GetClientTimescale);
	CreateNative("Shavit_SetClientTimescale", Native_SetClientTimescale);
	CreateNative("Shavit_GetAvgVelocity", Native_GetAvgVelocity);
	CreateNative("Shavit_GetMaxVelocity", Native_GetMaxVelocity);
	CreateNative("Shavit_SetAvgVelocity", Native_SetAvgVelocity);
	CreateNative("Shavit_SetMaxVelocity", Native_SetMaxVelocity);
	CreateNative("Shavit_UpdateLaggedMovement", Native_UpdateLaggedMovement);
	CreateNative("Shavit_GetCurrentStage", Native_GetCurrentStage);
	CreateNative("Shavit_GetCurrentCP", Native_GetCurrentCP);
	CreateNative("Shavit_GetLastStage", Native_GetLastStage);
	CreateNative("Shavit_GetLastCP", Native_GetLastCP);
	CreateNative("Shavit_SetCurrentStage", Native_SetCurrentStage);
	CreateNative("Shavit_SetCurrentCP", Native_SetCurrentCP);
	CreateNative("Shavit_SetLastStage", Native_SetLastStage);
	CreateNative("Shavit_SetLastCP", Native_SetLastCP);
	CreateNative("Shavit_IsStageTimer", Native_IsStageTimer);
	CreateNative("Shavit_SetStageTimer", Native_SetStageTimer);
	CreateNative("Shavit_GetLeaveStageTime", Native_GetLeaveStageTime);
	CreateNative("Shavit_SetLeaveStageTime", Native_SetLeaveStageTime);
	CreateNative("Shavit_IsTeleporting", Native_IsTeleporting);

	// registers library, check "bool LibraryExists(const char[] name)" in order to use with other plugins
	RegPluginLibrary("shavit");

	gB_Late = late;

	return APLRes_Success;
}

public void OnPluginStart()
{
	if(GetEngineVersion() != Engine_CSGO)
	{
		SetFailState("This plugin only support for csgo!");
		return;
	}

	// forwards
	gH_Forwards_Start = CreateGlobalForward("Shavit_OnStart", ET_Ignore, Param_Cell, Param_Cell);
	gH_Forwards_StartPre = CreateGlobalForward("Shavit_OnStartPre", ET_Event, Param_Cell, Param_Cell);
	gH_Forwards_Stop = CreateGlobalForward("Shavit_OnStop", ET_Event, Param_Cell, Param_Cell);
	gH_Forwards_StopPre = CreateGlobalForward("Shavit_OnStopPre", ET_Event, Param_Cell, Param_Cell);
	gH_Forwards_FinishPre = CreateGlobalForward("Shavit_OnFinishPre", ET_Hook, Param_Cell, Param_Array);
	gH_Forwards_Finish = CreateGlobalForward("Shavit_OnFinish", ET_Event, Param_Cell, Param_Cell, Param_Float, Param_Cell, Param_Cell, Param_Float, Param_Cell, Param_FloatByRef, Param_Float, Param_Float, Param_Cell);
	gH_Forwards_OnRestartPre = CreateGlobalForward("Shavit_OnRestartPre", ET_Event, Param_Cell, Param_Cell);
	gH_Forwards_OnRestart = CreateGlobalForward("Shavit_OnRestart", ET_Ignore, Param_Cell, Param_Cell);
	gH_Forwards_OnEnd = CreateGlobalForward("Shavit_OnEnd", ET_Event, Param_Cell, Param_Cell);
	gH_Forwards_OnPause = CreateGlobalForward("Shavit_OnPause", ET_Event, Param_Cell, Param_Cell);
	gH_Forwards_OnResume = CreateGlobalForward("Shavit_OnResume", ET_Event, Param_Cell, Param_Cell);
	gH_Forwards_OnStyleChanged = CreateGlobalForward("Shavit_OnStyleChanged", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	gH_Forwards_OnTrackChanged = CreateGlobalForward("Shavit_OnTrackChanged", ET_Event, Param_Cell, Param_Cell, Param_Cell);
	gH_Forwards_OnStyleConfigLoaded = CreateGlobalForward("Shavit_OnStyleConfigLoaded", ET_Event, Param_Cell);
	gH_Forwards_OnDatabaseLoaded = CreateGlobalForward("Shavit_OnDatabaseLoaded", ET_Event);
	gH_Forwards_OnChatConfigLoaded = CreateGlobalForward("Shavit_OnChatConfigLoaded", ET_Event);
	gH_Forwards_OnUserCmdPre = CreateGlobalForward("Shavit_OnUserCmdPre", ET_Event, Param_Cell, Param_CellByRef, Param_CellByRef, Param_Array, Param_Array, Param_Cell, Param_Cell, Param_Cell, Param_Array, Param_Array);
	gH_Forwards_OnTimerIncrement = CreateGlobalForward("Shavit_OnTimeIncrement", ET_Event, Param_Cell, Param_Array, Param_CellByRef, Param_Array);
	gH_Forwards_OnTimerIncrementPost = CreateGlobalForward("Shavit_OnTimeIncrementPost", ET_Event, Param_Cell, Param_Cell, Param_Array);
	gH_Forwards_OnTimescaleChanged = CreateGlobalForward("Shavit_OnTimescaleChanged", ET_Event, Param_Cell, Param_Cell, Param_Cell);
	gH_Forwards_OnTimeOffsetCalculated = CreateGlobalForward("Shavit_OnTimeOffsetCalculated", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	gH_Forwards_OnProcessMovement = CreateGlobalForward("Shavit_OnProcessMovement", ET_Event, Param_Cell);
	gH_Forwards_OnProcessMovementPost = CreateGlobalForward("Shavit_OnProcessMovementPost", ET_Event, Param_Cell);
	gH_Forwards_OnDeleteMapData = CreateGlobalForward("Shavit_OnDeleteMapData", ET_Event, Param_Cell, Param_String);
	gH_Forwards_OnCommandStyle = CreateGlobalForward("Shavit_OnCommandStyle", ET_Event, Param_Cell, Param_Cell, Param_FloatByRef);
	gH_Forwards_OnUserDeleteData = CreateGlobalForward("Shavit_OnUserDeleteData", ET_Event, Param_Cell, Param_Cell);
	gH_Forwards_OnDeleteRestOfUserSuccess = CreateGlobalForward("Shavit_OnDeleteRestOfUserSuccess", ET_Event, Param_Cell, Param_Cell);

	LoadTranslations("shavit-core.phrases");
	LoadTranslations("shavit-common.phrases");

	gB_Protobuf = (GetUserMessageType() == UM_Protobuf);

	LoadDHooks();

	// hooks
	HookEvent("player_jump", Player_Jump);
	HookEvent("player_death", Player_Death);
	HookEvent("player_team", Player_Death);
	HookEvent("player_spawn", Player_Death);

	// commands START
	// style
	RegConsoleCmd("sm_style", Command_Style, "Choose your bhop style.");
	RegConsoleCmd("sm_styles", Command_Style, "Choose your bhop style.");
	RegConsoleCmd("sm_diff", Command_Style, "Choose your bhop style.");
	RegConsoleCmd("sm_difficulty", Command_Style, "Choose your bhop style.");
	gH_StyleCookie = RegClientCookie("shavit_style", "Style cookie", CookieAccess_Protected);

	// timer start
	RegConsoleCmd("sm_start", Command_StartTimer, "Start your timer.");
	RegConsoleCmd("sm_r", Command_StartTimer, "Start your timer.");
	RegConsoleCmd("sm_restart", Command_StartTimer, "Start your timer.");
	RegConsoleCmd("sm_main", Command_StartTimer, "Start your timer on the main track.");

	RegConsoleCmd("sm_b", Command_StartTimer, "Start your timer on the bonus track.");
	RegConsoleCmd("sm_bonus", Command_StartTimer, "Start your timer on the bonus track.");

	for (int i = Track_Bonus; i <= Track_Bonus_Last; i++)
	{
		char cmd[10], helptext[50];
		FormatEx(cmd, sizeof(cmd), "sm_b%d", i);
		FormatEx(helptext, sizeof(helptext), "Start your timer on the bonus %d track.", i);
		RegConsoleCmd(cmd, Command_StartTimer, helptext);
	}

	// teleport to end
	RegConsoleCmd("sm_end", Command_TeleportEnd, "Teleport to endzone.");

	RegConsoleCmd("sm_bend", Command_TeleportEnd, "Teleport to endzone of the bonus track.");
	RegConsoleCmd("sm_bonusend", Command_TeleportEnd, "Teleport to endzone of the bonus track.");

	// timer stop
	RegConsoleCmd("sm_stop", Command_StopTimer, "Stop your timer.");

	// timer pause / resume
	RegConsoleCmd("sm_pause", Command_TogglePause, "Toggle pause.");
	RegConsoleCmd("sm_unpause", Command_TogglePause, "Toggle pause.");
	RegConsoleCmd("sm_resume", Command_TogglePause, "Toggle pause");

	// style commands
	gSM_StyleCommands = new StringMap();

	// admin
	RegAdminCmd("sm_deletemap", Command_DeleteMap, ADMFLAG_ROOT, "Deletes all map data. Usage: sm_deletemap <map>");
	RegAdminCmd("sm_wipeplayer", Command_WipePlayer, ADMFLAG_BAN, "Wipes all bhoptimer data for specified player. Usage: sm_wipeplayer <steamid3>");
	RegAdminCmd("sm_migration", Command_Migration, ADMFLAG_ROOT, "Force a database migration to run. Usage: sm_migration <migration id> or \"all\" to run all migrations.");
	// commands END

	// logs
	BuildPath(Path_SM, gS_LogPath, PLATFORM_MAX_PATH, "logs/shavit.log");

	CreateConVar("shavit_version", SHAVIT_VERSION, "Plugin version.", (FCVAR_NOTIFY | FCVAR_DONTRECORD));

	gCV_Restart = new Convar("shavit_core_restart", "1", "Allow commands that restart the timer?", 0, true, 0.0, true, 1.0);
	gCV_Pause = new Convar("shavit_core_pause", "1", "Allow pausing?", 0, true, 0.0, true, 1.0);
	gCV_PauseMovement = new Convar("shavit_core_pause_movement", "1", "Allow movement/noclip while paused?", 0, true, 0.0, true, 1.0);
	gCV_VelocityTeleport = new Convar("shavit_core_velocityteleport", "0", "Teleport the client when changing its velocity? (for special styles)", 0, true, 0.0, true, 1.0);
	gCV_DefaultStyle = new Convar("shavit_core_defaultstyle", "0", "Default style ID.\nAdd the '!' prefix to disable style cookies - i.e. \"!3\" to *force* scroll to be the default style.", 0, true, 0.0);
	gCV_NoChatSound = new Convar("shavit_core_nochatsound", "0", "Disables click sound for chat messages.", 0, true, 0.0, true, 1.0);
	gCV_SimplerLadders = new Convar("shavit_core_simplerladders", "1", "Allows using all keys on limited styles (such as sideways) after touching ladders\nTouching the ground enables the restriction again.", 0, true, 0.0, true, 1.0);
	gCV_UseOffsets = new Convar("shavit_core_useoffsets", "1", "Calculates more accurate times by subtracting/adding tick offsets from the time the server uses to register that a player has left or entered a trigger", 0, true, 0.0, true, 1.0);
	gCV_TimeInMessages = new Convar("shavit_core_timeinmessages", "0", "Whether to prefix SayText2 messages with the time.", 0, true, 0.0, true, 1.0);
	gCV_DefaultStyle.AddChangeHook(OnConVarChanged);

	Convar.AutoExecConfig();

	// database connections
	SQL_DBConnect();

	// late
	if(gB_Late)
	{
		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsValidClient(i))
			{
				OnClientPutInServer(i);
			}
		}
	}
}

void LoadDHooks()
{
	GameData gamedataConf = new GameData("shavit.games");

	if(gamedataConf == null)
	{
		SetFailState("Failed to load shavit gamedata");
		delete gamedataConf;
	}

	StartPrepSDKCall(SDKCall_Static);
	if(!PrepSDKCall_SetFromConf(gamedataConf, SDKConf_Signature, "CreateInterface"))
	{
		SetFailState("Failed to get CreateInterface");
	}
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	Handle CreateInterface = EndPrepSDKCall();

	if(CreateInterface == null)
	{
		SetFailState("Unable to prepare SDKCall for CreateInterface");
	}

	char interfaceName[64];

	// ProcessMovement
	if(!GameConfGetKeyValue(gamedataConf, "IGameMovement", interfaceName, sizeof(interfaceName)))
	{
		SetFailState("Failed to get IGameMovement interface name");
		delete gamedataConf;
	}

	Address IGameMovement = SDKCall(CreateInterface, interfaceName, 0);

	if(!IGameMovement)
	{
		SetFailState("Failed to get IGameMovement pointer");
	}

	int offset = GameConfGetOffset(gamedataConf, "ProcessMovement");
	if(offset == -1)
	{
		SetFailState("Failed to get ProcessMovement offset");
	}

	Handle processMovement = DHookCreate(offset, HookType_Raw, ReturnType_Void, ThisPointer_Ignore, DHook_ProcessMovement);
	DHookAddParam(processMovement, HookParamType_CBaseEntity);
	DHookAddParam(processMovement, HookParamType_ObjectPtr);
	DHookRaw(processMovement, false, IGameMovement);

	Handle processMovementPost = DHookCreate(offset, HookType_Raw, ReturnType_Void, ThisPointer_Ignore, DHook_ProcessMovementPost);
	DHookAddParam(processMovementPost, HookParamType_CBaseEntity);
	DHookAddParam(processMovementPost, HookParamType_ObjectPtr);
	DHookRaw(processMovementPost, true, IGameMovement);

	StartPrepSDKCall(SDKCall_Entity);
	if(!PrepSDKCall_SetFromConf(gamedataConf, SDKConf_Signature, "PhysicsCheckForEntityUntouch"))
	{
		SetFailState("Failed to get PhysicsCheckForEntityUntouch");
	}
	gH_PhysicsCheckForEntityUntouch = EndPrepSDKCall();

	delete CreateInterface;
	delete gamedataConf;

	GameData AcceptInputGameData = new GameData("sdktools.games/engine.csgo");

	// Stolen from dhooks-test.sp
	offset = AcceptInputGameData.GetOffset("AcceptInput");
	delete AcceptInputGameData;

	if(offset != -1)
	{
		gH_AcceptInput = new DynamicHook(offset, HookType_Entity, ReturnType_Bool, ThisPointer_CBaseEntity);
		gH_AcceptInput.AddParam(HookParamType_CharPtr);
		gH_AcceptInput.AddParam(HookParamType_CBaseEntity);
		gH_AcceptInput.AddParam(HookParamType_CBaseEntity);
		gH_AcceptInput.AddParam(HookParamType_Object, 20, DHookPass_ByVal|DHookPass_ODTOR|DHookPass_OCTOR|DHookPass_OASSIGNOP); //variant_t is a union of 12 (float[3]) plus two int type params 12 + 8 = 20
		gH_AcceptInput.AddParam(HookParamType_Int);
	}
	else
	{
		SetFailState("Couldn't get the offset for \"AcceptInput\" - make sure your gamedata is updated!");
	}


	GameData TeleportGameData = new GameData("sdktools.games");

	offset = TeleportGameData.GetOffset("Teleport");
	delete TeleportGameData;

	if(offset != -1)
	{
		gH_HookTeleport = new DynamicHook(offset, HookType_Entity, ReturnType_Void, ThisPointer_CBaseEntity);
		gH_HookTeleport.AddParam(HookParamType_VectorPtr);
		gH_HookTeleport.AddParam(HookParamType_ObjectPtr);
		gH_HookTeleport.AddParam(HookParamType_VectorPtr);
	}
	else
	{
		SetFailState("Couldn't get the offset for \"Teleport\" - make sure your gamedata is updated!");
	}
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	gB_StyleCookies = (newValue[0] != '!');
	gI_DefaultStyle = StringToInt(newValue[1]);
}

public void OnMapStart()
{
	// styles
	if(!LoadStyles())
	{
		SetFailState("Could not load the styles configuration file. Make sure it exists (addons/sourcemod/configs/shavit-styles.cfg) and follows the proper syntax!");
	}

	// messages
	if(!LoadMessages())
	{
		SetFailState("Could not load the chat messages configuration file. Make sure it exists (addons/sourcemod/configs/shavit-messages.cfg) and follows the proper syntax!");
	}
}

public Action Command_StartTimer(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	char sCommand[16];
	GetCmdArg(0, sCommand, 16);

	if(!gCV_Restart.BoolValue)
	{
		if(args != -1)
		{
			Shavit_PrintToChat(client, "%T", "CommandDisabled", client, sCommand);
		}

		return Plugin_Handled;
	}

	int track = Track_Main;

	if(StrContains(sCommand, "sm_b", false) == 0)
	{
		// Pull out bonus number for commands like sm_b1 and sm_b2.
		if ('1' <= sCommand[4] <= ('0' + Track_Bonus_Last))
		{
			track = view_as<int>(sCommand[4] - '0');
		}
		else if (args < 1)
		{
			track = Track_Bonus;
		}
		else
		{
			char arg[6];
			GetCmdArg(1, arg, sizeof(arg));
			track = StringToInt(arg);
		}

		if (track < Track_Bonus || track > Track_Bonus_Last)
		{
			track = Track_Bonus;
		}
	}
	else if(StrContains(sCommand, "sm_r", false) == 0)
	{
		track = Track_Main;
	}

	Action result = Plugin_Continue;
	Call_StartForward(gH_Forwards_OnRestartPre);
	Call_PushCell(client);
	Call_PushCell(track);
	Call_Finish(result);

	if(result > Plugin_Continue)
	{
		return Plugin_Handled;
	}

	Call_StartForward(gH_Forwards_OnRestart);
	Call_PushCell(client);
	Call_PushCell(track);
	Call_Finish();

	return Plugin_Handled;
}

public Action Command_TeleportEnd(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	char sCommand[16];
	GetCmdArg(0, sCommand, 16);

	int track = Track_Main;

	if(StrContains(sCommand, "sm_b", false) == 0)
	{
		if (args < 1)
		{
			track = Shavit_GetClientTrack(client);
		}
		else
		{
			char arg[6];
			GetCmdArg(1, arg, sizeof(arg));
			track = StringToInt(arg);
		}

		if (track < Track_Bonus || track > Track_Bonus_Last)
		{
			track = Track_Bonus;
		}
	}

	Call_StartForward(gH_Forwards_OnEnd);
	Call_PushCell(client);
	Call_PushCell(track);
	Call_Finish();

	return Plugin_Handled;
}

public Action Command_StopTimer(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	Shavit_StopTimer(client, false);

	return Plugin_Handled;
}

public Action Command_TogglePause(int client, int args)
{
	if(!(1 <= client <= MaxClients) || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}

	int iFlags = Shavit_CanPause(client);

	if((iFlags & CPR_NoTimer) > 0)
	{
		return Plugin_Handled;
	}

	if((iFlags & CPR_InStartZone) > 0)
	{
		Shavit_PrintToChat(client, "%T", "PauseStartZone", client);

		return Plugin_Handled;
	}

	if((iFlags & CPR_InEndZone) > 0)
	{
		Shavit_PrintToChat(client, "%T", "PauseEndZone", client);

		return Plugin_Handled;
	}

	if((iFlags & CPR_ByConVar) > 0)
	{
		char sCommand[16];
		GetCmdArg(0, sCommand, 16);

		Shavit_PrintToChat(client, "%T", "CommandDisabled", client, sCommand);

		return Plugin_Handled;
	}

	if (gA_Timers[client].bClientPaused)
	{
		if(GetEntityMoveType(client) == MOVETYPE_NOCLIP)
		{
			Shavit_PrintToChat(client, "%T", "BlockNoclipResume", client);

			return Plugin_Handled;
		}

		ResumePauseMovement(client);

		ResumeTimer(client);

		Shavit_PrintToChat(client, "%T", "MessageUnpause", client);
	}

	else
	{
		if((iFlags & CPR_NotOnGround) > 0)
		{
			Shavit_PrintToChat(client, "%T", "PauseNotOnGround", client);

			return Plugin_Handled;
		}

		if((iFlags & CPR_Moving) > 0)
		{
			Shavit_PrintToChat(client, "%T", "PauseMoving", client);

			return Plugin_Handled;
		}

		if((iFlags & CPR_Duck) > 0)
		{
			Shavit_PrintToChat(client, "%T", "PauseDuck", client);

			return Plugin_Handled;
		}

		GetPauseMovement(client);

		PauseTimer(client);

		Shavit_PrintToChat(client, "%T", "MessagePause", client);
	}

	return Plugin_Handled;
}

public Action Command_DeleteMap(int client, int args)
{
	if(args == 0)
	{
		ReplyToCommand(client, "Usage: sm_deletemap <map>\nOnce a map is chosen, \"sm_deletemap confirm\" to run the deletion.");

		return Plugin_Handled;
	}

	char sArgs[PLATFORM_MAX_PATH];
	GetCmdArgString(sArgs, sizeof(sArgs));
	LowercaseString(sArgs);

	if(StrEqual(sArgs, "confirm") && strlen(gS_DeleteMap[client]) > 0)
	{
		Call_StartForward(gH_Forwards_OnDeleteMapData);
		Call_PushCell(client);
		Call_PushString(gS_DeleteMap[client]);
		Call_Finish();

		ReplyToCommand(client, "Finished deleting data for %s.", gS_DeleteMap[client]);
		gS_DeleteMap[client] = "";
	}
	else
	{
		gS_DeleteMap[client] = sArgs;
		ReplyToCommand(client, "Map to delete is now %s.\nRun \"sm_deletemap confirm\" to delete all data regarding the map %s.", gS_DeleteMap[client], gS_DeleteMap[client]);
	}

	return Plugin_Handled;
}

public Action Command_Migration(int client, int args)
{
	if(args == 0)
	{
		ReplyToCommand(client, "Usage: sm_migration <migration id or \"all\" to run all migrationsd>.");

		return Plugin_Handled;
	}

	char sArg[16];
	GetCmdArg(1, sArg, 16);

	bool bApplyMigration[MIGRATIONS_END];

	if(StrEqual(sArg, "all"))
	{
		for(int i = 0; i < MIGRATIONS_END; i++)
		{
			bApplyMigration[i] = true;
		}
	}

	else
	{
		int iMigration = StringToInt(sArg);

		if(0 <= iMigration < MIGRATIONS_END)
		{
			bApplyMigration[iMigration] = true;
		}
	}

	for(int i = 0; i < MIGRATIONS_END; i++)
	{
		if(bApplyMigration[i])
		{
			ReplyToCommand(client, "Applying database migration %d", i);
			ApplyMigration(i);
		}
	}

	return Plugin_Handled;
}

public Action Command_WipePlayer(int client, int args)
{
	if(args == 0)
	{
		ReplyToCommand(client, "Usage: sm_wipeplayer <steamid3>\nAfter entering a SteamID, you will be prompted with a verification captcha.");

		return Plugin_Handled;
	}

	char sArgString[32];
	GetCmdArgString(sArgString, 32);

	if(strlen(gS_Verification[client]) == 0 || !StrEqual(sArgString, gS_Verification[client]))
	{
		gI_WipePlayerID[client] = SteamIDToAuth(sArgString);

		if(gI_WipePlayerID[client] <= 0)
		{
			Shavit_PrintToChat(client, "Entered SteamID (%s) is invalid. The range for valid SteamIDs is [U:1:1] to [U:1:2147483647].", sArgString);

			return Plugin_Handled;
		}

		char sAlphabet[] = "abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789!@#";
		strcopy(gS_Verification[client], 8, "");

		for(int i = 0; i < 5; i++)
		{
			gS_Verification[client][i] = sAlphabet[GetRandomInt(0, sizeof(sAlphabet) - 1)];
		}

		Shavit_PrintToChat(client, "Preparing to delete all user data for SteamID {gold}[U:1:%d]{default}. To confirm, enter {orchid}!wipeplayer %s",
			gI_WipePlayerID[client], gS_Verification[client]);
	}

	else
	{
		Shavit_PrintToChat(client, "Deleting data for SteamID {gold}[U:1:%d]{default}...", gI_WipePlayerID[client]);

		DeleteUserData(client, gI_WipePlayerID[client]);

		strcopy(gS_Verification[client], 8, "");
		gI_WipePlayerID[client] = -1;
	}

	return Plugin_Handled;
}

public void Trans_DeleteRestOfUserSuccess(Database db, DataPack hPack, int numQueries, DBResultSet[] results, any[] queryData)
{
	hPack.Reset();
	int client = hPack.ReadCell();
	int iSteamID = hPack.ReadCell();
	delete hPack;

	Call_StartForward(gH_Forwards_OnDeleteRestOfUserSuccess);
	Call_PushCell(client);
	Call_PushCell(iSteamID);
	Call_Finish();

	Shavit_LogMessage("%L - wiped user data for [U:1:%d].", client, iSteamID);
	Shavit_PrintToChat(client, "Finished wiping timer data for user {gold}[U:1:%d]{default}.", iSteamID);
}

public void Trans_DeleteRestOfUserFailed(Database db, DataPack hPack, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	hPack.Reset();
	hPack.ReadCell();
	int iSteamID = hPack.ReadCell();
	delete hPack;
	LogError("Timer error! Failed to wipe user data (wipe | delete user data/times, id [U:1:%d]). Reason: %s", iSteamID, error);
}

void DeleteRestOfUser(int iSteamID, DataPack hPack)
{
	Transaction2 hTransaction = new Transaction2();
	char sQuery[256];

	FormatEx(sQuery, 256, "DELETE FROM %splayertimes WHERE auth = %d;", gS_MySQLPrefix, iSteamID);
	hTransaction.AddQuery(sQuery);
	FormatEx(sQuery, 256, "DELETE FROM %susers WHERE auth = %d;", gS_MySQLPrefix, iSteamID);
	hTransaction.AddQuery(sQuery);

	gH_SQL.Execute(hTransaction, Trans_DeleteRestOfUserSuccess, Trans_DeleteRestOfUserFailed, hPack);
}

void DeleteUserData(int client, const int iSteamID)
{
	Call_StartForward(gH_Forwards_OnUserDeleteData);
	Call_PushCell(client);
	Call_PushCell(iSteamID);
	Call_Finish();

	DataPack hPack = new DataPack();
	hPack.WriteCell(client);
	hPack.WriteCell(iSteamID);

	DeleteRestOfUser(iSteamID, hPack);
}

public Action Command_Style(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	Menu menu = new Menu(StyleMenu_Handler);
	menu.SetTitle("%T", "StyleMenuTitle", client);

	for(int i = 0; i < gI_Styles; i++)
	{
		int iStyle = gI_OrderedStyles[i];

		// this logic will prevent the style from showing in !style menu if it's specifically inaccessible
		// or just completely disabled
		if((GetStyleSettingBool(iStyle, "inaccessible") && GetStyleSettingInt(iStyle, "enabled") == 1) ||
			GetStyleSettingInt(iStyle, "enabled") == -1)
		{
			continue;
		}

		char sInfo[8];
		IntToString(iStyle, sInfo, 8);

		char sDisplay[64];

		if(GetStyleSettingBool(iStyle, "unranked"))
		{
			char sName[64];
			gSM_StyleKeys[iStyle].GetString("name", sName, 64);
			FormatEx(sDisplay, 64, "%T %s", "StyleUnranked", client, sName);
		}

		else
		{
			float time = 0.0;

			Call_StartForward(gH_Forwards_OnCommandStyle);
			Call_PushCell(client);
			Call_PushCell(iStyle);
			Call_PushFloatRef(time);
			Call_Finish();

			if(time > 0.0)
			{
				char sTime[32];
				FormatSeconds(time, sTime, 32, false);

				char sWR[8];
				strcopy(sWR, 8, "WR");

				if (gA_Timers[client].iTimerTrack >= Track_Bonus)
				{
					strcopy(sWR, 8, "BWR");
				}

				char sName[64];
				gSM_StyleKeys[iStyle].GetString("name", sName, 64);
				FormatEx(sDisplay, 64, "%s - %s: %s", sName, sWR, sTime);
			}

			else
			{
				gSM_StyleKeys[iStyle].GetString("name", sDisplay, 64);
			}
		}

		menu.AddItem(sInfo, sDisplay, (gA_Timers[client].bsStyle == iStyle || !Shavit_HasStyleAccess(client, iStyle))? ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
	}

	// should NEVER happen
	if(menu.ItemCount == 0)
	{
		menu.AddItem("-1", "Nothing");
	}

	else if(menu.ItemCount <= 8)
	{
		menu.Pagination = MENU_NO_PAGINATION;
	}

	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}

public int StyleMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char info[16];
		menu.GetItem(param2, info, 16);

		int style = StringToInt(info);

		if(style == -1)
		{
			return 0;
		}

		ChangeClientStyle(param1, style, true);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

void CallOnTrackChanged(int client, int oldtrack, int newtrack)
{
	Call_StartForward(gH_Forwards_OnTrackChanged);
	Call_PushCell(client);
	Call_PushCell(oldtrack);
	Call_PushCell(newtrack);
	Call_Finish();

	if (oldtrack == Track_Main && oldtrack != newtrack)
	{
		Shavit_PrintToChat(client, "%T", "TrackChangeFromMain", client);
	}
}

public any Native_UpdateLaggedMovement(Handle handler, int numParams)
{
	int client = GetNativeCell(1);
	bool user_timescale = GetNativeCell(2) != 0;
	UpdateLaggedMovement(client, user_timescale);
	return 1;
}

void UpdateLaggedMovement(int client, bool user_timescale)
{
	float style_laggedmovement =
		  GetStyleSettingFloat(gA_Timers[client].bsStyle, "timescale")
		* GetStyleSettingFloat(gA_Timers[client].bsStyle, "speed");

	float laggedmovement =
		  (user_timescale ? gA_Timers[client].fTimescale : 1.0)
		* style_laggedmovement;

	SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", laggedmovement * gA_Timers[client].fplayer_speedmod);
}

void CallOnStyleChanged(int client, int oldstyle, int newstyle, bool manual, bool nofoward=false)
{
	gA_Timers[client].bsStyle = newstyle;

	if (!nofoward)
	{
		Call_StartForward(gH_Forwards_OnStyleChanged);
		Call_PushCell(client);
		Call_PushCell(oldstyle);
		Call_PushCell(newstyle);
		Call_PushCell(gA_Timers[client].iTimerTrack);
		Call_PushCell(manual);
		Call_Finish();
	}

	float fNewTimescale = GetStyleSettingFloat(newstyle, "timescale");

	if (gA_Timers[client].fTimescale != fNewTimescale && fNewTimescale > 0.0)
	{
		CallOnTimescaleChanged(client, gA_Timers[client].fTimescale, fNewTimescale);
		gA_Timers[client].fTimescale = fNewTimescale;
	}

	UpdateLaggedMovement(client, true);

	UpdateStyleSettings(client);

	SetEntityGravity(client, GetStyleSettingFloat(newstyle, "gravity"));
}

void CallOnTimescaleChanged(int client, float oldtimescale, float newtimescale)
{
	Call_StartForward(gH_Forwards_OnTimescaleChanged);
	Call_PushCell(client);
	Call_PushCell(oldtimescale);
	Call_PushCell(newtimescale);
	Call_Finish();
}

void ChangeClientStyle(int client, int style, bool manual)
{
	if(!IsValidClient(client))
	{
		return;
	}

	if(!Shavit_HasStyleAccess(client, style))
	{
		if(manual)
		{
			Shavit_PrintToChat(client, "%T", "StyleNoAccess", client);
		}

		return;
	}

	if(manual)
	{
		if(!Shavit_StopTimer(client, false))
		{
			return;
		}

		char sName[64];
		gSM_StyleKeys[style].GetString("name", sName, 64);

		Shavit_PrintToChat(client, "%T", "StyleSelection", client, sName);
	}

	if(GetStyleSettingBool(style, "unranked"))
	{
		Shavit_PrintToChat(client, "%T", "UnrankedWarning", client);
	}

	CallOnStyleChanged(client, gA_Timers[client].bsStyle, style, manual);
	Shavit_StopTimer(client, true);

	Call_StartForward(gH_Forwards_OnRestart);
	Call_PushCell(client);
	Call_PushCell(gA_Timers[client].iTimerTrack);
	Call_Finish();

	char sStyle[4];
	IntToString(style, sStyle, 4);

	SetClientCookie(client, gH_StyleCookie, sStyle);
}

public void Player_Jump(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	DoJump(client);
}

void DoJump(int client)
{
	if (gA_Timers[client].bTimerEnabled && !gA_Timers[client].bClientPaused)
	{
		gA_Timers[client].iJumps++;
		gA_Timers[client].bJumped = true;
	}

	SetEntPropFloat(client, Prop_Send, "m_flStamina", 0.0);

	RequestFrame(VelocityChanges, GetClientSerial(client));
}

void VelocityChanges(int data)
{
	int client = GetClientFromSerial(data);

	if(client == 0)
	{
		return;
	}

	int style = gA_Timers[client].bsStyle;

	if(GetStyleSettingBool(style, "force_timescale"))
	{
		float mod = gA_Timers[client].fTimescale * GetStyleSettingFloat(gA_Timers[client].bsStyle, "speed");
		SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", mod);
	}

	float fAbsVelocity[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", fAbsVelocity);

	float fSpeed = (SquareRoot(Pow(fAbsVelocity[0], 2.0) + Pow(fAbsVelocity[1], 2.0)));

	if(fSpeed != 0.0)
	{
		float fVelocityMultiplier = GetStyleSettingFloat(style, "velocity");
		float fVelocityBonus = GetStyleSettingFloat(style, "bonus_velocity");
		float fMin = GetStyleSettingFloat(style, "min_velocity");

		if(fVelocityMultiplier != 0.0)
		{
			fAbsVelocity[0] *= fVelocityMultiplier;
			fAbsVelocity[1] *= fVelocityMultiplier;
		}

		if(fVelocityBonus != 0.0)
		{
			float x = fSpeed / (fSpeed + fVelocityBonus);
			fAbsVelocity[0] /= x;
			fAbsVelocity[1] /= x;
		}

		if(fMin != 0.0 && fSpeed < fMin)
		{
			float x = (fSpeed / fMin);
			fAbsVelocity[0] /= x;
			fAbsVelocity[1] /= x;
		}
	}

	float fJumpMultiplier = GetStyleSettingFloat(style, "jump_multiplier");
	float fJumpBonus = GetStyleSettingFloat(style, "jump_bonus");

	if(fJumpMultiplier != 0.0)
	{
		fAbsVelocity[2] *= fJumpMultiplier;
	}

	if(fJumpBonus != 0.0)
	{
		fAbsVelocity[2] += fJumpBonus;
	}


	if(!gCV_VelocityTeleport.BoolValue)
	{
		SetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", fAbsVelocity);
	}

	else
	{
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, fAbsVelocity);
	}
}

public void Player_Death(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	ResumeTimer(client);
	StopTimer(client);
}

public int Native_GetOrderedStyles(Handle handler, int numParams)
{
	return SetNativeArray(1, gI_OrderedStyles, GetNativeCell(2));
}

public any Native_GetDatabase(Handle handler, int numParams)
{
	return CloneHandle(gH_SQL, handler);
}

public any Native_GetClientTime(Handle handler, int numParams)
{
	return gA_Timers[GetNativeCell(1)].fCurrentTime;
}

public int Native_GetClientTrack(Handle handler, int numParams)
{
	return gA_Timers[GetNativeCell(1)].iTimerTrack;
}

public int Native_GetClientJumps(Handle handler, int numParams)
{
	return gA_Timers[GetNativeCell(1)].iJumps;
}

public int Native_GetBhopStyle(Handle handler, int numParams)
{
	return gA_Timers[GetNativeCell(1)].bsStyle;
}

public any Native_GetTimerStatus(Handle handler, int numParams)
{
	return GetTimerStatus(GetNativeCell(1));
}

public int Native_HasStyleAccess(Handle handler, int numParams)
{
	int style = GetNativeCell(2);

	if(GetStyleSettingBool(style, "inaccessible") || GetStyleSettingInt(style, "enabled") <= 0)
	{
		return false;
	}

	return CheckCommandAccess(GetNativeCell(1), (strlen(gS_StyleOverride[style]) > 0)? gS_StyleOverride[style]:"<none>", gI_StyleFlag[style]);
}

public int Native_StartTimer(Handle handler, int numParams)
{
	StartTimer(GetNativeCell(1), GetNativeCell(2));
	return 0;
}

public int Native_StopTimer(Handle handler, int numParams)
{
	int client = GetNativeCell(1);
	bool bBypass = (numParams < 2 || view_as<bool>(GetNativeCell(2)));

	if(!bBypass)
	{
		bool bResult = true;
		Call_StartForward(gH_Forwards_StopPre);
		Call_PushCell(client);
		Call_PushCell(gA_Timers[client].iTimerTrack);
		Call_Finish(bResult);

		if(!bResult)
		{
			return false;
		}
	}

	StopTimer(client);

	Call_StartForward(gH_Forwards_Stop);
	Call_PushCell(client);
	Call_PushCell(gA_Timers[client].iTimerTrack);
	Call_Finish();

	return true;
}

public int Native_CanPause(Handle handler, int numParams)
{
	int client = GetNativeCell(1);
	int iFlags = 0;

	if(!gCV_Pause.BoolValue)
	{
		iFlags |= CPR_ByConVar;
	}

	if (!gA_Timers[client].bTimerEnabled)
	{
		iFlags |= CPR_NoTimer;
	}

	if (Shavit_InsideZone(client, Zone_Start, gA_Timers[client].iTimerTrack) && !gA_Timers[client].bClientPaused)
	{
		iFlags |= CPR_InStartZone;
	}

	if (Shavit_InsideZone(client, Zone_End, gA_Timers[client].iTimerTrack) && !gA_Timers[client].bClientPaused)
	{
		iFlags |= CPR_InEndZone;
	}

	if(GetEntPropEnt(client, Prop_Send, "m_hGroundEntity") == -1 && GetEntityMoveType(client) != MOVETYPE_LADDER)
	{
		iFlags |= CPR_NotOnGround;
	}

	float vel[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vel);
	if (vel[0] != 0.0 || vel[1] != 0.0 || vel[2] != 0.0)
	{
		iFlags |= CPR_Moving;
	}

	bool bDucked = view_as<bool>(GetEntProp(client, Prop_Send, "m_bDucked"));
	bool bDucking = view_as<bool>(GetEntProp(client, Prop_Send, "m_bDucking"));

	float fDucktime = GetEntPropFloat(client, Prop_Send, "m_flDuckAmount");

	if (bDucked || bDucking || fDucktime > 0.0 || GetClientButtons(client) & IN_DUCK)
	{
		iFlags |= CPR_Duck;
	}

	return iFlags;
}

public int Native_ChangeClientStyle(Handle handler, int numParams)
{
	int client = GetNativeCell(1);
	int style = GetNativeCell(2);
	bool force = view_as<bool>(GetNativeCell(3));
	bool manual = view_as<bool>(GetNativeCell(4));
	bool noforward = view_as<bool>(GetNativeCell(5));

	if(force || Shavit_HasStyleAccess(client, style))
	{
		CallOnStyleChanged(client, gA_Timers[client].bsStyle, style, manual, noforward);

		return true;
	}

	return false;
}

public int Native_FinishMap(Handle handler, int numParams)
{
	int client = GetNativeCell(1);
	int timestamp = GetTime();

	if(gCV_UseOffsets.BoolValue)
	{
		CalculateTickIntervalOffset(client, Zone_End);
	}

	gA_Timers[client].fCurrentTime = (gA_Timers[client].fTimescaledTicks + gA_Timers[client].fZoneOffset[Zone_Start] + gA_Timers[client].fZoneOffset[Zone_End]) * GetTickInterval();

	timer_snapshot_t snapshot;
	BuildSnapshot(client, snapshot);

	Action result = Plugin_Continue;
	Call_StartForward(gH_Forwards_FinishPre);
	Call_PushCell(client);
	Call_PushArrayEx(snapshot, sizeof(timer_snapshot_t), SM_PARAM_COPYBACK);
	Call_Finish(result);

	if(result != Plugin_Continue && result != Plugin_Changed)
	{
		return 0;
	}

	Call_StartForward(gH_Forwards_Finish);
	Call_PushCell(client);

	if(result == Plugin_Continue)
	{
		Call_PushCell(gA_Timers[client].bsStyle);
		Call_PushFloat(gA_Timers[client].fCurrentTime);
		Call_PushCell(gA_Timers[client].iJumps);
		Call_PushCell(gA_Timers[client].iStrafes);
		//gross
		Call_PushFloat((GetStyleSettingBool(gA_Timers[client].bsStyle, "sync"))? (gA_Timers[client].iGoodGains == 0)? 0.0:(gA_Timers[client].iGoodGains / float(gA_Timers[client].iTotalMeasures) * 100.0):-1.0);
		Call_PushCell(gA_Timers[client].iTimerTrack);
	}
	else
	{
		Call_PushCell(snapshot.bsStyle);
		Call_PushFloat(snapshot.fCurrentTime);
		Call_PushCell(snapshot.iJumps);
		Call_PushCell(snapshot.iStrafes);
		// gross
		Call_PushFloat((GetStyleSettingBool(snapshot.bsStyle, "sync"))? (snapshot.iGoodGains == 0)? 0.0:(snapshot.iGoodGains / float(snapshot.iTotalMeasures) * 100.0):-1.0);
		Call_PushCell(snapshot.iTimerTrack);
	}

	float oldtime = 0.0;

	Call_PushFloatRef(oldtime);

	if(result == Plugin_Continue)
	{
		Call_PushFloat(gA_Timers[client].fAvgVelocity);
		Call_PushFloat(gA_Timers[client].fMaxVelocity);
	}
	else
	{
		Call_PushFloat(snapshot.fAvgVelocity);
		Call_PushFloat(snapshot.fMaxVelocity);
	}

	Call_PushCell(timestamp);
	Call_Finish();

	StopTimer(client);

	return 0;
}

public int Native_PauseTimer(Handle handler, int numParams)
{
	int client = GetNativeCell(1);

	GetPauseMovement(client);
	PauseTimer(client);

	return 0;
}

public any Native_GetZoneOffset(Handle handler, int numParams)
{
	int client = GetNativeCell(1);
	int zonetype = GetNativeCell(2);

	if(zonetype > 1 || zonetype < 0)
	{
		return ThrowNativeError(32, "ZoneType is out of bounds");
	}

	return gA_Timers[client].fZoneOffset[zonetype];
}

public any Native_GetDistanceOffset(Handle handler, int numParams)
{
	int client = GetNativeCell(1);
	int zonetype = GetNativeCell(2);

	if(zonetype > 1 || zonetype < 0)
	{
		return ThrowNativeError(32, "ZoneType is out of bounds");
	}

	return gA_Timers[client].fDistanceOffset[zonetype];
}

public int Native_ResumeTimer(Handle handler, int numParams)
{
	int client = GetNativeCell(1);

	ResumeTimer(client);

	if(numParams >= 2 && view_as<bool>(GetNativeCell(2))) // teleport?
	{
		ResumePauseMovement(client);
	}

	return 0;
}

public int Native_StopChatSound(Handle handler, int numParams)
{
	gB_StopChatSound = true;

	return 0;
}

public int Native_PrintToChatAll(Handle plugin, int numParams)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			SetGlobalTransTarget(i);

			bool previousStopChatSound = gB_StopChatSound;
			SemiNative_PrintToChat(i, 1);
			gB_StopChatSound = previousStopChatSound;
		}
	}

	gB_StopChatSound = false;

	return 0;
}

public int Native_PrintToChat(Handle handler, int numParams)
{
	int client = GetNativeCell(1);
	return SemiNative_PrintToChat(client, 2);
}

public int SemiNative_PrintToChat(int client, int formatParam)
{
	int iWritten;
	char sBuffer[256];
	char sInput[300];
	FormatNativeString(0, formatParam, formatParam+1, sizeof(sInput), iWritten, sInput);

	char sTime[50];

	if (gCV_TimeInMessages.BoolValue)
	{
		FormatTime(sTime, sizeof(sTime), gB_Protobuf ? "%H:%M:%S " : "\x01%H:%M:%S ");
	}

	// space before message needed show colors in cs:go
	// strlen(sBuffer)>252 is when CSS stops printing the messages
	char sPrefix[sizeof(chatstrings_t::sPrefix)];
	char sText[sizeof(chatstrings_t::sText)];

	strcopy(sPrefix, sizeof(sPrefix), gS_ChatStrings.sPrefix);
	strcopy(sText, sizeof(sText), gS_ChatStrings.sText);

	ReplaceColors(sPrefix, sizeof(sPrefix));
	ReplaceColors(sText, sizeof(sText));
	ReplaceColors(sInput, 300);
	FormatEx(sBuffer, (gB_Protobuf ? sizeof(sBuffer) : 253), "%s%s%s %s%s", (gB_Protobuf ? " ":""), sTime, sPrefix, sText, sInput);

	if(client == 0)
	{
		PrintToServer("%s", sBuffer);

		return false;
	}

	if(!IsClientInGame(client))
	{
		gB_StopChatSound = false;

		return false;
	}

	Handle hSayText2 = StartMessageOne("SayText2", client, USERMSG_RELIABLE|USERMSG_BLOCKHOOKS);

	if(gB_Protobuf)
	{
		Protobuf pbmsg = UserMessageToProtobuf(hSayText2);
		pbmsg.SetInt("ent_idx", client);
		pbmsg.SetBool("chat", !(gB_StopChatSound || gCV_NoChatSound.BoolValue));
		pbmsg.SetString("msg_name", sBuffer);

		// needed to not crash
		for(int i = 1; i <= 4; i++)
		{
			pbmsg.AddString("params", "");
		}
	}
	else
	{
		BfWrite bfmsg = UserMessageToBfWrite(hSayText2);
		bfmsg.WriteByte(client);
		bfmsg.WriteByte(!(gB_StopChatSound || gCV_NoChatSound.BoolValue));
		bfmsg.WriteString(sBuffer);
	}

	EndMessage();

	gB_StopChatSound = false;

	return true;
}

public int Native_RestartTimer(Handle handler, int numParams)
{
	int client = GetNativeCell(1);
	int track = GetNativeCell(2);

	Shavit_StopTimer(client, true);

	Call_StartForward(gH_Forwards_OnRestart);
	Call_PushCell(client);
	Call_PushCell(track);
	Call_Finish();

	return 0;
}

public int Native_GetStrafeCount(Handle handler, int numParams)
{
	return gA_Timers[GetNativeCell(1)].iStrafes;
}

public any Native_GetSync(Handle handler, int numParams)
{
	int client = GetNativeCell(1);

	return (GetStyleSettingBool(gA_Timers[client].bsStyle, "sync")? (gA_Timers[client].iGoodGains == 0)? 0.0:(gA_Timers[client].iGoodGains / float(gA_Timers[client].iTotalMeasures) * 100.0):-1.0);
}

public int Native_GetStyleCount(Handle handler, int numParams)
{
	return (gI_Styles > 0)? gI_Styles:-1;
}

public int Native_GetStyleStrings(Handle handler, int numParams)
{
	int style = GetNativeCell(1);
	int type = GetNativeCell(2);
	int size = GetNativeCell(4);
	char sValue[128];

	switch(type)
	{
		case sStyleName:
		{
			gSM_StyleKeys[style].GetString("name", sValue, size);
		}
		case sShortName:
		{
			gSM_StyleKeys[style].GetString("shortname", sValue, size);
		}
		case sHTMLColor:
		{
			gSM_StyleKeys[style].GetString("htmlcolor", sValue, size);
		}
		case sChangeCommand:
		{
			gSM_StyleKeys[style].GetString("command", sValue, size);
		}
		case sClanTag:
		{
			gSM_StyleKeys[style].GetString("clantag", sValue, size);
		}
		case sSpecialString:
		{
			gSM_StyleKeys[style].GetString("specialstring", sValue, size);
		}
		case sStylePermission:
		{
			gSM_StyleKeys[style].GetString("permission", sValue, size);
		}
		default:
		{
			return -1;
		}
	}

	return SetNativeString(3, sValue, size);
}

public int Native_GetStyleStringsStruct(Handle plugin, int numParams)
{
	int style = GetNativeCell(1);

	if (GetNativeCell(3) != sizeof(stylestrings_t))
	{
		return ThrowNativeError(200, "stylestrings_t does not match latest(got %i expected %i). Please update your includes and recompile your plugins", GetNativeCell(3), sizeof(stylestrings_t));
	}

	stylestrings_t strings;
	gSM_StyleKeys[style].GetString("name", strings.sStyleName, sizeof(strings.sStyleName));
	gSM_StyleKeys[style].GetString("shortname", strings.sShortName, sizeof(strings.sShortName));
	gSM_StyleKeys[style].GetString("htmlcolor", strings.sHTMLColor, sizeof(strings.sHTMLColor));
	gSM_StyleKeys[style].GetString("command", strings.sChangeCommand, sizeof(strings.sChangeCommand));
	gSM_StyleKeys[style].GetString("clantag", strings.sClanTag, sizeof(strings.sClanTag));
	gSM_StyleKeys[style].GetString("specialstring", strings.sSpecialString, sizeof(strings.sSpecialString));
	gSM_StyleKeys[style].GetString("permission", strings.sStylePermission, sizeof(strings.sStylePermission));

	return SetNativeArray(2, strings, sizeof(stylestrings_t));
}

public int Native_GetChatStrings(Handle handler, int numParams)
{
	int type = GetNativeCell(1);
	int size = GetNativeCell(3);

	switch(type)
	{
		case sMessagePrefix: return SetNativeString(2, gS_ChatStrings.sPrefix, size);
		case sMessageText: return SetNativeString(2, gS_ChatStrings.sText, size);
		case sMessageWarning: return SetNativeString(2, gS_ChatStrings.sWarning, size);
		case sMessageTeam: return SetNativeString(2, gS_ChatStrings.sTeam, size);
		case sMessageStyle: return SetNativeString(2, gS_ChatStrings.sStyle, size);
	}

	return -1;
}

public int Native_GetChatStringsStruct(Handle plugin, int numParams)
{
	if (GetNativeCell(2) != sizeof(chatstrings_t))
	{
		return ThrowNativeError(200, "chatstrings_t does not match latest(got %i expected %i). Please update your includes and recompile your plugins", GetNativeCell(2), sizeof(chatstrings_t));
	}

	return SetNativeArray(1, gS_ChatStrings, sizeof(gS_ChatStrings));
}

public int Native_SetPracticeMode(Handle handler, int numParams)
{
	gA_Timers[GetNativeCell(1)].bPracticeMode = view_as<bool>(GetNativeCell(2));

	return 0;
}

public any Native_IsPaused(Handle handler, int numParams)
{
	return gA_Timers[GetNativeCell(1)].bClientPaused;
}

public int Native_IsPracticeMode(Handle handler, int numParams)
{
	return gA_Timers[GetNativeCell(1)].bPracticeMode;
}

public int Native_SaveSnapshot(Handle handler, int numParams)
{
	if(GetNativeCell(3) != sizeof(timer_snapshot_t))
	{
		return ThrowNativeError(200, "timer_snapshot_t does not match latest(got %i expected %i). Please update your includes and recompile your plugins",
			GetNativeCell(3), sizeof(timer_snapshot_t));
	}

	int client = GetNativeCell(1);

	timer_snapshot_t snapshot;
	BuildSnapshot(client, snapshot);
	return SetNativeArray(2, snapshot, sizeof(timer_snapshot_t));
}

public int Native_LoadSnapshot(Handle handler, int numParams)
{
	if(GetNativeCell(3) != sizeof(timer_snapshot_t))
	{
		return ThrowNativeError(200, "timer_snapshot_t does not match latest(got %i expected %i). Please update your includes and recompile your plugins",
			GetNativeCell(3), sizeof(timer_snapshot_t));
	}

	int client = GetNativeCell(1);

	timer_snapshot_t snapshot;
	GetNativeArray(2, snapshot, sizeof(timer_snapshot_t));

	if (gA_Timers[client].iTimerTrack != snapshot.iTimerTrack)
	{
		CallOnTrackChanged(client, gA_Timers[client].iTimerTrack, snapshot.iTimerTrack);
	}

	gA_Timers[client].iTimerTrack = snapshot.iTimerTrack;

	if (gA_Timers[client].bsStyle != snapshot.bsStyle && Shavit_HasStyleAccess(client, snapshot.bsStyle))
	{
		CallOnStyleChanged(client, gA_Timers[client].bsStyle, snapshot.bsStyle, false);
	}

	gA_Timers[client] = snapshot;
	gA_Timers[client].bClientPaused = snapshot.bClientPaused && snapshot.bTimerEnabled;
	gA_Timers[client].fTimescale = (snapshot.fTimescale > 0.0) ? snapshot.fTimescale : 1.0;

	return 0;
}

public int Native_LogMessage(Handle plugin, int numParams)
{
	char sPlugin[32];

	if(!GetPluginInfo(plugin, PlInfo_Name, sPlugin, 32))
	{
		GetPluginFilename(plugin, sPlugin, 32);
	}

	static int iWritten = 0;

	char sBuffer[300];
	FormatNativeString(0, 1, 2, 300, iWritten, sBuffer);

	LogToFileEx(gS_LogPath, "[%s] %s", sPlugin, sBuffer);

	return 0;
}

public any Native_GetClientTimescale(Handle handler, int numParams)
{
	int client = GetNativeCell(1);
	return gA_Timers[client].fTimescale;
}

public int Native_SetClientTimescale(Handle handler, int numParams)
{
	int client = GetNativeCell(1);
	float timescale = GetNativeCell(2);

	timescale = float(RoundFloat((timescale * 10000.0)))/10000.0;

	if (timescale != gA_Timers[client].fTimescale && timescale > 0.0)
	{
		CallOnTimescaleChanged(client, gA_Timers[client].fTimescale, timescale);
		UpdateLaggedMovement(client, true);
	}

	return 0;
}

public int Native_GetStyleSetting(Handle handler, int numParams)
{
	int style = GetNativeCell(1);

	char sKey[256];
	GetNativeString(2, sKey, 256);

	int maxlength = GetNativeCell(4);

	char sValue[256];
	bool ret = gSM_StyleKeys[style].GetString(sKey, sValue, maxlength);

	SetNativeString(3, sValue, maxlength);
	return ret;
}

public int Native_GetStyleSettingInt(Handle handler, int numParams)
{
	int style = GetNativeCell(1);

	char sKey[256];
	GetNativeString(2, sKey, 256);

	return GetStyleSettingInt(style, sKey);
}

int GetStyleSettingInt(int style, char[] key)
{
	char sValue[16];
	gSM_StyleKeys[style].GetString(key, sValue, 16);
	return StringToInt(sValue);
}

public int Native_GetStyleSettingBool(Handle handler, int numParams)
{
	int style = GetNativeCell(1);

	char sKey[256];
	GetNativeString(2, sKey, 256);

	return GetStyleSettingBool(style, sKey);
}

bool GetStyleSettingBool(int style, char[] key)
{
	return GetStyleSettingInt(style, key) != 0;
}

public any Native_GetStyleSettingFloat(Handle handler, int numParams)
{
	int style = GetNativeCell(1);

	char sKey[256];
	GetNativeString(2, sKey, 256);

	return GetStyleSettingFloat(style, sKey);
}

float GetStyleSettingFloat(int style, char[] key)
{
	char sValue[16];
	gSM_StyleKeys[style].GetString(key, sValue, 16);
	return StringToFloat(sValue);
}

public any Native_HasStyleSetting(Handle handler, int numParams)
{
	// TODO: replace with sm 1.11 StringMap.ContainsKey
	int style = GetNativeCell(1);

	char sKey[256];
	GetNativeString(2, sKey, 256);

	return HasStyleSetting(style, sKey);
}

public any Native_GetAvgVelocity(Handle plugin, int numParams)
{
	return gA_Timers[GetNativeCell(1)].fAvgVelocity;
}

public any Native_GetMaxVelocity(Handle plugin, int numParams)
{
	return gA_Timers[GetNativeCell(1)].fMaxVelocity;
}

public int Native_SetAvgVelocity(Handle plugin, int numParams)
{
	gA_Timers[GetNativeCell(1)].fAvgVelocity = GetNativeCell(2);

	return 0;
}

public int Native_SetMaxVelocity(Handle plugin, int numParams)
{
	gA_Timers[GetNativeCell(1)].fMaxVelocity = GetNativeCell(2);

	return 0;
}

bool HasStyleSetting(int style, char[] key)
{
	char sValue[1];
	return gSM_StyleKeys[style].GetString(key, sValue, 1);
}

public any Native_SetStyleSetting(Handle handler, int numParams)
{
	int style = GetNativeCell(1);

	char sKey[256];
	GetNativeString(2, sKey, 256);

	char sValue[256];
	GetNativeString(3, sValue, 256);

	bool replace = GetNativeCell(4);

	return gSM_StyleKeys[style].SetString(sKey, sValue, replace);
}

public any Native_SetStyleSettingFloat(Handle handler, int numParams)
{
	int style = GetNativeCell(1);

	char sKey[256];
	GetNativeString(2, sKey, 256);

	float fValue = GetNativeCell(3);

	char sValue[16];
	FloatToString(fValue, sValue, 16);

	bool replace = GetNativeCell(4);

	return gSM_StyleKeys[style].SetString(sKey, sValue, replace);
}

public any Native_SetStyleSettingBool(Handle handler, int numParams)
{
	int style = GetNativeCell(1);

	char sKey[256];
	GetNativeString(2, sKey, 256);

	bool value = GetNativeCell(3);

	bool replace = GetNativeCell(4);

	return gSM_StyleKeys[style].SetString(sKey, value ? "1" : "0", replace);
}

public any Native_SetStyleSettingInt(Handle handler, int numParams)
{
	int style = GetNativeCell(1);

	char sKey[256];
	GetNativeString(2, sKey, 256);

	int value = GetNativeCell(3);

	char sValue[16];
	IntToString(value, sValue, 16);

	bool replace = GetNativeCell(4);

	return gSM_StyleKeys[style].SetString(sKey, sValue, replace);
}

public int Native_GetCurrentStage(Handle handler, int numParams)
{
	return gA_Timers[GetNativeCell(1)].iCurrentStage;
}

public int Native_GetCurrentCP(Handle handler, int numParams)
{
	return gA_Timers[GetNativeCell(1)].iCurrentCP;
}

public int Native_GetLastStage(Handle handler, int numParams)
{
	return gA_Timers[GetNativeCell(1)].iLastStage;
}

public int Native_GetLastCP(Handle handler, int numParams)
{
	return gA_Timers[GetNativeCell(1)].iLastCP;
}

public int Native_SetCurrentStage(Handle handler, int numParams)
{
	gA_Timers[GetNativeCell(1)].iCurrentStage = GetNativeCell(2);

	return 0;
}

public int Native_SetCurrentCP(Handle handler, int numParams)
{
	gA_Timers[GetNativeCell(1)].iCurrentCP = GetNativeCell(2);

	return 0;
}

public int Native_SetLastStage(Handle handler, int numParams)
{
	gA_Timers[GetNativeCell(1)].iLastStage = GetNativeCell(2);

	return 0;
}

public int Native_SetLastCP(Handle handler, int numParams)
{
	gA_Timers[GetNativeCell(1)].iLastCP = GetNativeCell(2);

	return 0;
}

public any Native_IsStageTimer(Handle handler, int numParams)
{
	return gA_Timers[GetNativeCell(1)].bStageTimer;
}

public int Native_SetStageTimer(Handle handler, int numParams)
{
	gA_Timers[GetNativeCell(1)].bStageTimer = view_as<bool>(GetNativeCell(2));

	return 0;
}

public any Native_GetLeaveStageTime(Handle handler, int numParams)
{
	return gA_Timers[GetNativeCell(1)].fLeaveStageTime;
}

public int Native_SetLeaveStageTime(Handle handler, int numParams)
{
	gA_Timers[GetNativeCell(1)].fLeaveStageTime = GetNativeCell(2);

	return 0;
}

public int Native_IsTeleporting(Handle handler, int numParams)
{
	return gA_HookedPlayer[GetNativeCell(1)].GetFlags() & STATUS_ONTELEPORT;
}

public Action Shavit_OnStartPre(int client, int track)
{
	if (GetTimerStatus(client) == Timer_Paused && gCV_PauseMovement.BoolValue)
	{
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

TimerStatus GetTimerStatus(int client)
{
	if (!gA_Timers[client].bTimerEnabled)
	{
		return Timer_Stopped;
	}
	else if (gA_Timers[client].bClientPaused)
	{
		return Timer_Paused;
	}

	return Timer_Running;
}

void StartTimer(int client, int track)
{
	if(!IsValidClient(client, true) || GetClientTeam(client) < 2 || IsFakeClient(client) || !gB_CookiesRetrieved[client])
	{
		return;
	}

	float fSpeed[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", fSpeed);
	float curVel = SquareRoot(Pow(fSpeed[0], 2.0) + Pow(fSpeed[1], 2.0));

	Action result = Plugin_Continue;
	Call_StartForward(gH_Forwards_StartPre);
	Call_PushCell(client);
	Call_PushCell(track);
	Call_Finish(result);

	if(result == Plugin_Continue)
	{
		Call_StartForward(gH_Forwards_Start);
		Call_PushCell(client);
		Call_PushCell(track);
		Call_Finish(result);

		gA_Timers[client].iZoneIncrement = 0;
		gA_Timers[client].fTimescaledTicks = 0.0;
		gA_Timers[client].bClientPaused = false;
		gA_Timers[client].iStrafes = 0;
		gA_Timers[client].iJumps = 0;
		gA_Timers[client].iTotalMeasures = 0;
		gA_Timers[client].iGoodGains = 0;

		if (gA_Timers[client].iTimerTrack != track)
		{
			CallOnTrackChanged(client, gA_Timers[client].iTimerTrack, track);
		}

		gA_Timers[client].iTimerTrack = track;
		gA_Timers[client].bTimerEnabled = true;
		gA_Timers[client].iSHSWCombination = -1;
		gA_Timers[client].fCurrentTime = 0.0;
		gA_Timers[client].bPracticeMode = false;
		gA_Timers[client].bCanUseAllKeys = false;
		gA_Timers[client].fZoneOffset[Zone_Start] = 0.0;
		gA_Timers[client].fZoneOffset[Zone_End] = 0.0;
		gA_Timers[client].fDistanceOffset[Zone_Start] = 0.0;
		gA_Timers[client].fDistanceOffset[Zone_End] = 0.0;
		gA_Timers[client].fAvgVelocity = curVel;
		gA_Timers[client].fMaxVelocity = curVel;

		UpdateLaggedMovement(client, true);
		SetEntityGravity(client, GetStyleSettingFloat(gA_Timers[client].bsStyle, "gravity"));
	}
}

void StopTimer(int client)
{
	if(!IsValidClient(client) || IsFakeClient(client))
	{
		return;
	}

	gA_Timers[client].bTimerEnabled = false;
	gA_Timers[client].iJumps = 0;
	gA_Timers[client].fCurrentTime = 0.0;
	gA_Timers[client].bClientPaused = false;
	gA_Timers[client].iStrafes = 0;
	gA_Timers[client].iTotalMeasures = 0;
	gA_Timers[client].iGoodGains = 0;
}

void PauseTimer(int client)
{
	if(!IsValidClient(client) || IsFakeClient(client))
	{
		return;
	}

	Call_StartForward(gH_Forwards_OnPause);
	Call_PushCell(client);
	Call_PushCell(gA_Timers[client].iTimerTrack);
	Call_Finish();

	gA_Timers[client].bClientPaused = true;
}

void ResumeTimer(int client)
{
	if(!IsValidClient(client) || IsFakeClient(client))
	{
		return;
	}

	Call_StartForward(gH_Forwards_OnResume);
	Call_PushCell(client);
	Call_PushCell(gA_Timers[client].iTimerTrack);
	Call_Finish();

	gA_Timers[client].bClientPaused = false;
}

public void OnClientDisconnect(int client)
{
	gA_HookedPlayer[client].RemoveHook();
	RequestFrame(StopTimer, client);
}

public void OnClientCookiesCached(int client)
{
	if(IsFakeClient(client) || !IsClientInGame(client))
	{
		return;
	}

	int style = gI_DefaultStyle;

	if(gB_StyleCookies && gH_StyleCookie != null)
	{
		char sCookie[4];
		GetClientCookie(client, gH_StyleCookie, sCookie, 4);
		int newstyle = StringToInt(sCookie);

		if(0 <= newstyle < gI_Styles)
		{
			style = newstyle;
		}
	}

	if(Shavit_HasStyleAccess(client, style))
	{
		CallOnStyleChanged(client, gA_Timers[client].bsStyle, style, false);
	}

	gB_CookiesRetrieved[client] = true;
}

public void OnClientPutInServer(int client)
{
	StopTimer(client);

	if(!IsClientConnected(client) || IsFakeClient(client))
	{
		return;
	}

	if(!gA_HookedPlayer[client].bHooked)
	{
		gA_HookedPlayer[client].AddHook(client);
	}

	gA_Timers[client].fStrafeWarning = 0.0;
	gA_Timers[client].bPracticeMode = false;
	gA_Timers[client].iSHSWCombination = -1;
	gA_Timers[client].iTimerTrack = 0;
	gA_Timers[client].bsStyle = 0;
	gA_Timers[client].fTimescale = 1.0;
	gA_Timers[client].fTimescaledTicks = 0.0;
	gA_Timers[client].iZoneIncrement = 0;
	gA_Timers[client].fplayer_speedmod = 1.0;
	gS_DeleteMap[client][0] = 0;

	gB_CookiesRetrieved[client] = false;

	if(AreClientCookiesCached(client))
	{
		OnClientCookiesCached(client);
	}

	// not adding style permission check here for obvious reasons
	else
	{
		CallOnStyleChanged(client, 0, gI_DefaultStyle, false);
	}

	SDKHook(client, SDKHook_PreThinkPost, PreThinkPost);
	SDKHook(client, SDKHook_PostThinkPost, PostThinkPost);

	if(GetSteamAccountID(client) == 0)
	{
		KickClient(client, "%T", "VerificationFailed", client);

		return;
	}

	char sName[MAX_NAME_LENGTH];
	GetClientName(client, sName, MAX_NAME_LENGTH);
	ReplaceString(sName, MAX_NAME_LENGTH, "#", "?"); // to avoid this: https://user-images.githubusercontent.com/3672466/28637962-0d324952-724c-11e7-8b27-15ff021f0a59.png

	int iLength = ((strlen(sName) * 2) + 1);
	char[] sEscapedName = new char[iLength];
	gH_SQL.Escape(sName, sEscapedName, iLength);

	char sIPAddress[64];
	GetClientIP(client, sIPAddress, 64);
	int iIPAddress = IPStringToAddress(sIPAddress);

	int iTime = GetTime();

	char sQuery[512];

	if(gB_MySQL)
	{
		FormatEx(sQuery, 512,
			"INSERT INTO %susers (auth, name, ip, lastlogin) VALUES (%d, '%s', %d, %d) ON DUPLICATE KEY UPDATE name = '%s', ip = %d, lastlogin = %d;",
			gS_MySQLPrefix, GetSteamAccountID(client), sEscapedName, iIPAddress, iTime, sEscapedName, iIPAddress, iTime);
	}

	else
	{
		FormatEx(sQuery, 512,
			"REPLACE INTO %susers (auth, name, ip, lastlogin) VALUES (%d, '%s', %d, %d);",
			gS_MySQLPrefix, GetSteamAccountID(client), sEscapedName, iIPAddress, iTime);
	}

	gH_SQL.Query(SQL_InsertUser_Callback, sQuery, GetClientSerial(client));
}

public void SQL_InsertUser_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		int client = GetClientFromSerial(data);

		if(client == 0)
		{
			LogError("Timer error! Failed to insert a disconnected player's data to the table. Reason: %s", error);
		}

		else
		{
			LogError("Timer error! Failed to insert \"%N\"'s data to the table. Reason: %s", client, error);
		}

		return;
	}
}

bool LoadStyles()
{
	for(int i = 0; i < STYLE_LIMIT; i++)
	{
		delete gSM_StyleKeys[i];
	}

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, PLATFORM_MAX_PATH, "configs/shavit-styles.cfg");

	SMCParser parser = new SMCParser();
	parser.OnEnterSection = OnStyleEnterSection;
	parser.OnLeaveSection = OnStyleLeaveSection;
	parser.OnKeyValue = OnStyleKeyValue;
	parser.ParseFile(sPath);
	delete parser;

	for (int i = 0; i < gI_Styles; i++)
	{
		if (gSM_StyleKeys[i] == null)
		{
			SetFailState("Missing style index %d. Highest index is %d. Fix addons/sourcemod/configs/shavit-styles.cfg", i, gI_Styles-1);
		}
	}

	gB_Registered = true;

	SortCustom1D(gI_OrderedStyles, gI_Styles, SortAscending_StyleOrder);

	Call_StartForward(gH_Forwards_OnStyleConfigLoaded);
	Call_PushCell(gI_Styles);
	Call_Finish();

	return true;
}

public SMCResult OnStyleEnterSection(SMCParser smc, const char[] name, bool opt_quotes)
{
	// styles key
	if(!IsCharNumeric(name[0]))
	{
		return SMCParse_Continue;
	}

	gI_CurrentParserIndex = StringToInt(name);

	if (gSM_StyleKeys[gI_CurrentParserIndex] != null)
	{
		SetFailState("Style index %d (%s) already parsed. Stop using the same index for multiple styles. Fix addons/sourcemod/configs/shavit-styles.cfg", gI_CurrentParserIndex, name);
	}

	if (gI_CurrentParserIndex >= STYLE_LIMIT)
	{
		SetFailState("Style index %d (%s) too high (limit %d). Fix addons/sourcemod/configs/shavit-styles.cfg", gI_CurrentParserIndex, name, STYLE_LIMIT);
	}

	if(gI_Styles <= gI_CurrentParserIndex)
	{
		gI_Styles = gI_CurrentParserIndex + 1;
	}

	gSM_StyleKeys[gI_CurrentParserIndex] = new StringMap();

	gSM_StyleKeys[gI_CurrentParserIndex].SetString("name", "<MISSING STYLE NAME>");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("shortname", "<MISSING SHORT STYLE NAME>");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("htmlcolor", "<MISSING STYLE HTML COLOR>");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("command", "");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("clantag", "<MISSING STYLE CLAN TAG>");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("specialstring", "");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("permission", "");

	gSM_StyleKeys[gI_CurrentParserIndex].SetString("runspeed", "260.00");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("gravity", "1.0");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("speed", "1.0");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("halftime", "0");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("timescale", "1.0");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("velocity", "1.0");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("bonus_velocity", "0.0");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("min_velocity", "0.0");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("jump_multiplier", "0.0");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("jump_bonus", "0.0");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("block_w", "0");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("block_a", "0");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("block_s", "0");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("block_d", "0");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("block_use", "0");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("force_hsw", "0");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("block_pleft", "0");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("block_pright", "0");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("block_pstrafe", "0");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("unranked", "0");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("noreplay", "0");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("sync", "1");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("strafe_count_w", "0");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("strafe_count_a", "1");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("strafe_count_s", "0");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("strafe_count_d", "1");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("rankingmultiplier", "1.00");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("special", "0");

	char sOrder[4];
	IntToString(gI_CurrentParserIndex, sOrder, 4);
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("ordering", sOrder);

	gSM_StyleKeys[gI_CurrentParserIndex].SetString("inaccessible", "0");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("enabled", "1");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("force_groundkeys", "0");

	gI_OrderedStyles[gI_CurrentParserIndex] = gI_CurrentParserIndex;

	return SMCParse_Continue;
}

public SMCResult OnStyleLeaveSection(SMCParser smc)
{
	if (gI_CurrentParserIndex == -1)
	{
		// OnStyleLeaveSection can be called back to back.
		// And does for when hitting the last style!
		// So we set gI_CurrentParserIndex to -1 at the end of this function.
		return SMCParse_Halt;
	}

	// if this style is disabled, we will force certain settings
	if(GetStyleSettingInt(gI_CurrentParserIndex, "enabled") <= 0)
	{
		gSM_StyleKeys[gI_CurrentParserIndex].SetString("noreplay", "1");
		gSM_StyleKeys[gI_CurrentParserIndex].SetString("rankingmultiplier", "0");
		gSM_StyleKeys[gI_CurrentParserIndex].SetString("inaccessible", "1");
	}

	if(GetStyleSettingBool(gI_CurrentParserIndex, "halftime"))
	{
		gSM_StyleKeys[gI_CurrentParserIndex].SetString("timescale", "0.5");
	}

	if (GetStyleSettingFloat(gI_CurrentParserIndex, "timescale") <= 0.0)
	{
		gSM_StyleKeys[gI_CurrentParserIndex].SetString("timescale", "1.0");
	}

	// Setting it here so that we can reference the timescale setting.
	if(!HasStyleSetting(gI_CurrentParserIndex, "force_timescale"))
	{
		if(GetStyleSettingFloat(gI_CurrentParserIndex, "timescale") == 1.0)
		{
			gSM_StyleKeys[gI_CurrentParserIndex].SetString("force_timescale", "0");
		}

		else
		{
			gSM_StyleKeys[gI_CurrentParserIndex].SetString("force_timescale", "1");
		}
	}

	char sStyleCommand[128];
	gSM_StyleKeys[gI_CurrentParserIndex].GetString("command", sStyleCommand, 128);
	char sName[64];
	gSM_StyleKeys[gI_CurrentParserIndex].GetString("name", sName, 64);

	if(!gB_Registered && strlen(sStyleCommand) > 0 && !GetStyleSettingBool(gI_CurrentParserIndex, "inaccessible"))
	{
		char sStyleCommands[32][32];
		int iCommands = ExplodeString(sStyleCommand, ";", sStyleCommands, 32, 32, false);

		char sDescription[128];
		FormatEx(sDescription, 128, "Change style to %s.", sName);

		for(int x = 0; x < iCommands; x++)
		{
			TrimString(sStyleCommands[x]);
			StripQuotes(sStyleCommands[x]);

			char sCommand[32];
			FormatEx(sCommand, 32, "sm_%s", sStyleCommands[x]);

			gSM_StyleCommands.SetValue(sCommand, gI_CurrentParserIndex);

			RegConsoleCmd(sCommand, Command_StyleChange, sDescription);
		}
	}

	char sPermission[64];
	gSM_StyleKeys[gI_CurrentParserIndex].GetString("permission", sPermission, 64);

	if(StrContains(sPermission, ";") != -1)
	{
		char sText[2][32];
		int iCount = ExplodeString(sPermission, ";", sText, 2, 32);

		AdminFlag flag = Admin_Reservation;

		if(FindFlagByChar(sText[0][0], flag))
		{
			gI_StyleFlag[gI_CurrentParserIndex] = FlagToBit(flag);
		}

		strcopy(gS_StyleOverride[gI_CurrentParserIndex], 32, (iCount >= 2)? sText[1]:"");
	}

	else if(strlen(sPermission) > 0)
	{
		AdminFlag flag = Admin_Reservation;

		if(FindFlagByChar(sPermission[0], flag))
		{
			gI_StyleFlag[gI_CurrentParserIndex] = FlagToBit(flag);
		}
	}

	gI_CurrentParserIndex = -1;

	return SMCParse_Continue;
}

public SMCResult OnStyleKeyValue(SMCParser smc, const char[] key, const char[] value, bool key_quotes, bool value_quotes)
{
	gSM_StyleKeys[gI_CurrentParserIndex].SetString(key, value);

	return SMCParse_Continue;
}

public int SortAscending_StyleOrder(int index1, int index2, const int[] array, any hndl)
{
	int iOrder1 = GetStyleSettingInt(index1, "ordering");
	int iOrder2 = GetStyleSettingInt(index2, "ordering");

	if(iOrder1 < iOrder2)
	{
		return -1;
	}

	else if(iOrder1 == iOrder2)
	{
		return 0;
	}

	else
	{
		return 1;
	}
}

public Action Command_StyleChange(int client, int args)
{
	char sCommand[128];
	GetCmdArg(0, sCommand, 128);

	int style = 0;

	if(gSM_StyleCommands.GetValue(sCommand, style))
	{
		ChangeClientStyle(client, style, true);

		return Plugin_Handled;
	}

	return Plugin_Continue;
}

bool LoadMessages()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, PLATFORM_MAX_PATH, "configs/shavit-messages.cfg");

	KeyValues kv = new KeyValues("shavit-messages");

	if(!kv.ImportFromFile(sPath))
	{
		delete kv;

		return false;
	}

	kv.JumpToKey("CS:GO");

	kv.GetString("prefix", gS_ChatStrings.sPrefix, sizeof(chatstrings_t::sPrefix), "\x075e70d0[Timer]");
	kv.GetString("text", gS_ChatStrings.sText, sizeof(chatstrings_t::sText), "\x07ffffff");
	kv.GetString("warning", gS_ChatStrings.sWarning, sizeof(chatstrings_t::sWarning), "\x07af2a22");
	kv.GetString("team", gS_ChatStrings.sTeam, sizeof(chatstrings_t::sTeam), "\x07276f5c");
	kv.GetString("style", gS_ChatStrings.sStyle, sizeof(chatstrings_t::sStyle), "\x07db88c2");

	delete kv;

	Call_StartForward(gH_Forwards_OnChatConfigLoaded);
	Call_Finish();

	return true;
}

void SQL_DBConnect()
{
	GetTimerSQLPrefix(gS_MySQLPrefix, 32);
	gH_SQL = GetTimerDatabaseHandle2();
	gB_MySQL = IsMySQLDatabase(gH_SQL);

	CreateUsersTable();
}

public void SQL_CreateMigrationsTable_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer error! Migrations table creation failed. Reason: %s", error);

		return;
	}

	char sQuery[128];
	FormatEx(sQuery, 128, "SELECT code FROM %smigrations;", gS_MySQLPrefix);

	gH_SQL.Query(SQL_SelectMigrations_Callback, sQuery, 0, DBPrio_High);
}

public void SQL_SelectMigrations_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer error! Migrations selection failed. Reason: %s", error);

		return;
	}

	// this is ugly, i know. but it works and is more elegant than previous solutions so.. let it be =)
	bool bMigrationApplied[255] = { false, ... };

	while(results.FetchRow())
	{
		bMigrationApplied[results.FetchInt(0)] = true;
	}

	for(int i = 0; i < MIGRATIONS_END; i++)
	{
		if(!bMigrationApplied[i])
		{
			gI_MigrationsRequired++;
			PrintToServer("--- Applying database migration %d ---", i);
			ApplyMigration(i);
		}
	}

	if (!gI_MigrationsRequired)
	{
		Call_StartForward(gH_Forwards_OnDatabaseLoaded);
		Call_Finish();
	}
}

void ApplyMigration(int migration)
{
	switch(migration)
	{
		case Migration_RemoveWorkshopMaptiers, Migration_RemoveWorkshopMapzones, Migration_RemoveWorkshopPlayertimes: ApplyMigration_RemoveWorkshopPath(migration);
		case Migration_LastLoginIndex: ApplyMigration_LastLoginIndex();
		case Migration_RemoveCountry: ApplyMigration_RemoveCountry();
		case Migration_ConvertIPAddresses: ApplyMigration_ConvertIPAddresses();
		case Migration_ConvertSteamIDsUsers: ApplyMigration_ConvertSteamIDs();
		case Migration_ConvertSteamIDsPlayertimes, Migration_ConvertSteamIDsChat: return; // this is confusing, but the above case handles all of them
		case Migration_PlayertimesDateToInt: ApplyMigration_PlayertimesDateToInt();
		case Migration_AddZonesFlagsAndData: ApplyMigration_AddZonesFlagsAndData();
		case Migration_AddPlayertimesCompletions: ApplyMigration_AddPlayertimesCompletions();
		case Migration_AddCustomChatAccess: ApplyMigration_AddCustomChatAccess();
		case Migration_AddPlayertimesExactTimeInt: ApplyMigration_AddPlayertimesExactTimeInt();
		case Migration_FixOldCompletionCounts: ApplyMigration_FixOldCompletionCounts();
		case Migration_AddPlaytime: ApplyMigration_AddPlaytime();
		case Migration_Lowercase_maptiers: ApplyMigration_LowercaseMaps("maptiers", migration);
		case Migration_Lowercase_mapzones: ApplyMigration_LowercaseMaps("mapzones", migration);
		case Migration_Lowercase_playertimes: ApplyMigration_LowercaseMaps("playertimes", migration);
		case Migration_Lowercase_stagetimeswr: ApplyMigration_LowercaseMaps("stagetimewrs", migration);
		case Migration_Lowercase_startpositions: ApplyMigration_LowercaseMaps("startpositions", migration);
	}
}

void ApplyMigration_LastLoginIndex()
{
	char sQuery[128];
	FormatEx(sQuery, 128, "ALTER TABLE `%susers` ADD INDEX `lastlogin` (`lastlogin`);", gS_MySQLPrefix);
	gH_SQL.Query(SQL_TableMigrationSingleQuery_Callback, sQuery, Migration_LastLoginIndex, DBPrio_High);
}

void ApplyMigration_RemoveCountry()
{
	char sQuery[128];
	FormatEx(sQuery, 128, "ALTER TABLE `%susers` DROP COLUMN `country`;", gS_MySQLPrefix);
	gH_SQL.Query(SQL_TableMigrationSingleQuery_Callback, sQuery, Migration_RemoveCountry, DBPrio_High);
}

void ApplyMigration_PlayertimesDateToInt()
{
	char sQuery[128];
	FormatEx(sQuery, 128, "ALTER TABLE `%splayertimes` CHANGE COLUMN `date` `date` INT;", gS_MySQLPrefix);
	gH_SQL.Query(SQL_TableMigrationSingleQuery_Callback, sQuery, Migration_PlayertimesDateToInt, DBPrio_High);
}

void ApplyMigration_AddZonesFlagsAndData()
{
	char sQuery[192];
	FormatEx(sQuery, 192, "ALTER TABLE `%smapzones` ADD COLUMN `flags` INT NULL AFTER `track`, ADD COLUMN `data` INT NULL AFTER `flags`;", gS_MySQLPrefix);
	gH_SQL.Query(SQL_TableMigrationSingleQuery_Callback, sQuery, Migration_AddZonesFlagsAndData, DBPrio_High);
}

void ApplyMigration_AddPlayertimesCompletions()
{
	char sQuery[192];
	FormatEx(sQuery, 192, "ALTER TABLE `%splayertimes` ADD COLUMN `completions` SMALLINT DEFAULT 1 AFTER `perfs`;", gS_MySQLPrefix);
	gH_SQL.Query(SQL_TableMigrationSingleQuery_Callback, sQuery, Migration_AddPlayertimesCompletions, DBPrio_High);
}

void ApplyMigration_AddCustomChatAccess()
{
	char sQuery[192];
	FormatEx(sQuery, 192, "ALTER TABLE `%schat` ADD COLUMN `ccaccess` INT NOT NULL DEFAULT 0 AFTER `ccmessage`;", gS_MySQLPrefix);
	gH_SQL.Query(SQL_TableMigrationSingleQuery_Callback, sQuery, Migration_AddCustomChatAccess, DBPrio_High);
}

void ApplyMigration_AddPlayertimesExactTimeInt()
{
	char sQuery[192];
	FormatEx(sQuery, 192, "ALTER TABLE `%splayertimes` ADD COLUMN `exact_time_int` INT NOT NULL DEFAULT 0 AFTER `completions`;", gS_MySQLPrefix);
	gH_SQL.Query(SQL_TableMigrationSingleQuery_Callback, sQuery, Migration_AddPlayertimesExactTimeInt, DBPrio_High);
}

void ApplyMigration_FixOldCompletionCounts()
{
	char sQuery[192];
	FormatEx(sQuery, 192, "UPDATE `%splayertimes` SET completions = completions - 1 WHERE completions > 1;", gS_MySQLPrefix);
	gH_SQL.Query(SQL_TableMigrationSingleQuery_Callback, sQuery, Migration_FixOldCompletionCounts, DBPrio_High);
}

// double up on this migration because some people may have used shavit-playtime which uses INT but I want FLOAT
void ApplyMigration_AddPlaytime()
{
	char sQuery[192];
	FormatEx(sQuery, 192, "ALTER TABLE `%susers` MODIFY COLUMN `playtime` FLOAT NOT NULL DEFAULT 0;", gS_MySQLPrefix);
	gH_SQL.Query(SQL_Migration_AddPlaytime2222222_Callback, sQuery, Migration_AddPlaytime, DBPrio_High);
}

public void SQL_Migration_AddPlaytime2222222_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	char sQuery[192];
	FormatEx(sQuery, 192, "ALTER TABLE `%susers` ADD COLUMN `playtime` FLOAT NOT NULL DEFAULT 0 AFTER `points`;", gS_MySQLPrefix);
	gH_SQL.Query(SQL_TableMigrationSingleQuery_Callback, sQuery, Migration_AddPlaytime, DBPrio_High);
}

void ApplyMigration_LowercaseMaps(const char[] table, int migration)
{
	char sQuery[192];
	FormatEx(sQuery, 192, "UPDATE `%s%s` SET map = LOWER(map);", gS_MySQLPrefix, table);
	gH_SQL.Query(SQL_TableMigrationSingleQuery_Callback, sQuery, migration, DBPrio_High);
}

public void SQL_TableMigrationSingleQuery_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	InsertMigration(data);

	// i hate hardcoding REEEEEEEE
	if(data == Migration_ConvertSteamIDsChat)
	{
		char sQuery[256];
		// deleting rows that cause data integrity issues
		FormatEx(sQuery, 256,
			"DELETE t1 FROM %splayertimes t1 LEFT JOIN %susers t2 ON t1.auth = t2.auth WHERE t2.auth IS NULL;",
			gS_MySQLPrefix, gS_MySQLPrefix);
		gH_SQL.Query(SQL_TableMigrationIndexing_Callback, sQuery, 0, DBPrio_High);

		FormatEx(sQuery, 256,
			"ALTER TABLE `%splayertimes` ADD CONSTRAINT `%spt_auth` FOREIGN KEY (`auth`) REFERENCES `%susers` (`auth`) ON UPDATE CASCADE ON DELETE CASCADE;",
			gS_MySQLPrefix, gS_MySQLPrefix, gS_MySQLPrefix);
		gH_SQL.Query(SQL_TableMigrationIndexing_Callback, sQuery);

		FormatEx(sQuery, 256,
			"DELETE t1 FROM %schat t1 LEFT JOIN %susers t2 ON t1.auth = t2.auth WHERE t2.auth IS NULL;",
			gS_MySQLPrefix, gS_MySQLPrefix);
		gH_SQL.Query(SQL_TableMigrationIndexing_Callback, sQuery, 0, DBPrio_High);

		FormatEx(sQuery, 256,
			"ALTER TABLE `%schat` ADD CONSTRAINT `%sch_auth` FOREIGN KEY (`auth`) REFERENCES `%susers` (`auth`) ON UPDATE CASCADE ON DELETE CASCADE;",
			gS_MySQLPrefix, gS_MySQLPrefix, gS_MySQLPrefix);
		gH_SQL.Query(SQL_TableMigrationIndexing_Callback, sQuery);
	}
}

void ApplyMigration_ConvertIPAddresses(bool index = true)
{
	char sQuery[128];

	if(index)
	{
		FormatEx(sQuery, 128, "ALTER TABLE `%susers` ADD INDEX `ip` (`ip`);", gS_MySQLPrefix);
		gH_SQL.Query(SQL_TableMigrationIndexing_Callback, sQuery, 0, DBPrio_High);
	}

	FormatEx(sQuery, 128, "SELECT DISTINCT ip FROM %susers WHERE ip LIKE '%%.%%';", gS_MySQLPrefix);
	gH_SQL.Query(SQL_TableMigrationIPAddresses_Callback, sQuery);
}

public void SQL_TableMigrationIPAddresses_Callback(Database db, DBResultSet results, const char[] error, DataPack data)
{
	if(results == null || results.RowCount == 0)
	{
		InsertMigration(Migration_ConvertIPAddresses);

		return;
	}

	Transaction2 hTransaction = new Transaction2();
	int iQueries = 0;

	while(results.FetchRow())
	{
		char sIPAddress[32];
		results.FetchString(0, sIPAddress, 32);

		char sQuery[256];
		FormatEx(sQuery, 256, "UPDATE %susers SET ip = %d WHERE ip = '%s';", gS_MySQLPrefix, IPStringToAddress(sIPAddress), sIPAddress);

		hTransaction.AddQuery(sQuery);

		if(++iQueries >= 10000)
		{
			break;
		}
	}

	gH_SQL.Execute(hTransaction, Trans_IPAddressMigrationSuccess, Trans_IPAddressMigrationFailed, iQueries);
}

public void Trans_IPAddressMigrationSuccess(Database db, any data, int numQueries, DBResultSet[] results, any[] queryData)
{
	// too many queries, don't do all at once to avoid server crash due to too many queries in the transaction
	if(data >= 10000)
	{
		ApplyMigration_ConvertIPAddresses(false);

		return;
	}

	char sQuery[128];
	FormatEx(sQuery, 128, "ALTER TABLE `%susers` DROP INDEX `ip`;", gS_MySQLPrefix);
	gH_SQL.Query(SQL_TableMigrationIndexing_Callback, sQuery, 0, DBPrio_High);

	FormatEx(sQuery, 128, "ALTER TABLE `%susers` CHANGE COLUMN `ip` `ip` INT;", gS_MySQLPrefix);
	gH_SQL.Query(SQL_TableMigrationSingleQuery_Callback, sQuery, Migration_ConvertIPAddresses, DBPrio_High);
}

public void Trans_IPAddressMigrationFailed(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	LogError("Timer (core) error! IP address migration failed. Reason: %s", error);
}

void ApplyMigration_ConvertSteamIDs()
{
	char sTables[][] =
	{
		"users",
		"playertimes",
		"chat"
	};

	char sQuery[128];
	FormatEx(sQuery, 128, "ALTER TABLE `%splayertimes` DROP CONSTRAINT `%spt_auth`;", gS_MySQLPrefix, gS_MySQLPrefix);
	gH_SQL.Query(SQL_TableMigrationIndexing_Callback, sQuery, 0, DBPrio_High);

	FormatEx(sQuery, 128, "ALTER TABLE `%schat` DROP CONSTRAINT `%sch_auth`;", gS_MySQLPrefix, gS_MySQLPrefix);
	gH_SQL.Query(SQL_TableMigrationIndexing_Callback, sQuery, 0, DBPrio_High);

	for(int i = 0; i < sizeof(sTables); i++)
	{
		DataPack hPack = new DataPack();
		hPack.WriteCell(Migration_ConvertSteamIDsUsers + i);
		hPack.WriteString(sTables[i]);

		FormatEx(sQuery, 128, "UPDATE %s%s SET auth = REPLACE(REPLACE(auth, \"[U:1:\", \"\"), \"]\", \"\") WHERE auth LIKE '[%%';", sTables[i], gS_MySQLPrefix);
		gH_SQL.Query(SQL_TableMigrationSteamIDs_Callback, sQuery, hPack, DBPrio_High);
	}
}

public void SQL_TableMigrationIndexing_Callback(Database db, DBResultSet results, const char[] error, DataPack data)
{
	// nothing
}

public void SQL_TableMigrationSteamIDs_Callback(Database db, DBResultSet results, const char[] error, DataPack data)
{
	data.Reset();
	int iMigration = data.ReadCell();
	char sTable[16];
	data.ReadString(sTable, 16);
	delete data;

	char sQuery[128];
	FormatEx(sQuery, 128, "ALTER TABLE `%s%s` CHANGE COLUMN `auth` `auth` INT;", gS_MySQLPrefix, sTable);
	gH_SQL.Query(SQL_TableMigrationSingleQuery_Callback, sQuery, iMigration, DBPrio_High);
}

void ApplyMigration_RemoveWorkshopPath(int migration)
{
	char sTables[][] =
	{
		"maptiers",
		"mapzones",
		"playertimes"
	};

	DataPack hPack = new DataPack();
	hPack.WriteCell(migration);
	hPack.WriteString(sTables[migration]);

	char sQuery[192];
	FormatEx(sQuery, 192, "SELECT map FROM %s%s WHERE map LIKE 'workshop%%' GROUP BY map;", gS_MySQLPrefix, sTables[migration]);
	gH_SQL.Query(SQL_TableMigrationWorkshop_Callback, sQuery, hPack, DBPrio_High);
}

public void SQL_TableMigrationWorkshop_Callback(Database db, DBResultSet results, const char[] error, DataPack data)
{
	data.Reset();
	int iMigration = data.ReadCell();
	char sTable[16];
	data.ReadString(sTable, 16);
	delete data;

	if(results == null || results.RowCount == 0)
	{
		// no error logging here because not everyone runs the rankings/wr modules
		InsertMigration(iMigration);

		return;
	}

	Transaction2 hTransaction = new Transaction2();

	while(results.FetchRow())
	{
		char sMap[PLATFORM_MAX_PATH];
		results.FetchString(0, sMap, sizeof(sMap));

		char sDisplayMap[PLATFORM_MAX_PATH];
		GetMapDisplayName(sMap, sDisplayMap, sizeof(sDisplayMap));

		char sQuery[256];
		FormatEx(sQuery, 256, "UPDATE %s%s SET map = '%s' WHERE map = '%s';", gS_MySQLPrefix, sTable, sDisplayMap, sMap);

		hTransaction.AddQuery(sQuery);
	}

	gH_SQL.Execute(hTransaction, Trans_WorkshopMigration, INVALID_FUNCTION, iMigration);
}

public void Trans_WorkshopMigration(Database db, any data, int numQueries, DBResultSet[] results, any[] queryData)
{
	InsertMigration(data);
}

void InsertMigration(int migration)
{
	char sQuery[128];
	FormatEx(sQuery, 128, "INSERT INTO %smigrations (code) VALUES (%d);", gS_MySQLPrefix, migration);
	gH_SQL.Query(SQL_MigrationApplied_Callback, sQuery, migration);
}

public void SQL_MigrationApplied_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if (++gI_MigrationsFinished >= gI_MigrationsRequired)
	{
		gI_MigrationsRequired = gI_MigrationsFinished = 0;
		Call_StartForward(gH_Forwards_OnDatabaseLoaded);
		Call_Finish();
	}
}

void CreateUsersTable()
{
	char sQuery[512];

	if(gB_MySQL)
	{
		FormatEx(sQuery, sizeof(sQuery),
			"CREATE TABLE IF NOT EXISTS `users` (`auth` INT NOT NULL, `name` VARCHAR(32) COLLATE 'utf8mb4_general_ci', `ip` INT, `lastlogin` INT NOT NULL DEFAULT -1, `points` FLOAT NOT NULL DEFAULT 0, `playtime` FLOAT NOT NULL DEFAULT 0, PRIMARY KEY (`auth`), INDEX `points` (`points`), INDEX `lastlogin` (`lastlogin`)) ENGINE=INNODB;");
	}
	else
	{
		FormatEx(sQuery, sizeof(sQuery),
			"CREATE TABLE IF NOT EXISTS `users` (`auth` INT NOT NULL PRIMARY KEY, `name` VARCHAR(32), `ip` INT, `lastlogin` INTEGER NOT NULL DEFAULT -1, `points` FLOAT NOT NULL DEFAULT 0, `playtime` FLOAT NOT NULL DEFAULT 0);");
	}

	gH_SQL.Query(SQL_CreateUsersTable_Callback, sQuery, 0, DBPrio_High);
}

public void SQL_CreateUsersTable_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer error! Users' data table creation failed. Reason: %s", error);

		return;
	}

	// migrations will only exist for mysql. sorry sqlite users
	if(gB_MySQL)
	{
		char sQuery[128];
		FormatEx(sQuery, 128, "CREATE TABLE IF NOT EXISTS `%smigrations` (`code` TINYINT NOT NULL, UNIQUE INDEX `code` (`code`));", gS_MySQLPrefix);

		gH_SQL.Query(SQL_CreateMigrationsTable_Callback, sQuery, 0, DBPrio_High);
	}
	else
	{
		Call_StartForward(gH_Forwards_OnDatabaseLoaded);
		Call_Finish();
	}
}

public void PreThinkPost(int client)
{
	if(IsPlayerAlive(client))
	{
		MoveType mtMoveType = GetEntityMoveType(client);

		if (GetStyleSettingFloat(gA_Timers[client].bsStyle, "gravity") != 1.0 &&
			(mtMoveType == MOVETYPE_WALK || mtMoveType == MOVETYPE_ISOMETRIC) &&
			(gA_Timers[client].iLastMoveType == MOVETYPE_LADDER || GetEntityGravity(client) == 1.0))
		{
			SetEntityGravity(client, GetStyleSettingFloat(gA_Timers[client].bsStyle, "gravity"));
		}

		gA_Timers[client].iLastMoveType = mtMoveType;
	}
}

public void PostThinkPost(int client)
{
	gF_Origin[client][1] = gF_Origin[client][0];
	GetEntPropVector(client, Prop_Data, "m_vecOrigin", gF_Origin[client][0]);

	if(gA_Timers[client].iZoneIncrement == 1 && gCV_UseOffsets.BoolValue)
	{
		float fVel[3];
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", fVel);

		if(fVel[2] == 0.0)
		{
			CalculateTickIntervalOffset(client, Zone_Start);
		}
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "player_speedmod"))
	{
		gH_AcceptInput.HookEntity(Hook_Post, entity, DHook_AcceptInput_player_speedmod_Post);
	}
}

// bool CBaseEntity::AcceptInput(char  const*, CBaseEntity*, CBaseEntity*, variant_t, int)
public MRESReturn DHook_AcceptInput_player_speedmod_Post(int pThis, DHookReturn hReturn, DHookParam hParams)
{
	char buf[128];
	hParams.GetString(1, buf, sizeof(buf));

	if (!StrEqual(buf, "ModifySpeed") || hParams.IsNull(2))
	{
		return MRES_Ignored;
	}

	int activator = hParams.Get(2);

	if (!IsValidClient(activator, true))
	{
		return MRES_Ignored;
	}

	float speed;

	int variant_type = hParams.GetObjectVar(4, 16, ObjectValueType_Int);

	if (variant_type == 2 /* FIELD_STRING */)
	{
		hParams.GetObjectVarString(4, 0, ObjectValueType_String, buf, sizeof(buf));
		speed = StringToFloat(buf);
	}
	else // should be FIELD_FLOAT but don't check who cares
	{
		speed = hParams.GetObjectVar(4, 0, ObjectValueType_Float);
	}

	gA_Timers[activator].fplayer_speedmod = speed;
	UpdateLaggedMovement(activator, true);

	return MRES_Ignored;
}

public MRESReturn Detour_OnTeleport(int pThis, DHookReturn hReturn, DHookParam hParams)
{
	gA_HookedPlayer[pThis].AddFlag(STATUS_ONTELEPORT);

	return MRES_Ignored;
}

public MRESReturn Detour_OnTeleport_Post(int pThis, DHookReturn hReturn, DHookParam hParams)
{
	gA_HookedPlayer[pThis].RemoveFlag(STATUS_ONTELEPORT);

	return MRES_Ignored;
}

bool GetCheckUntouch(int client)
{
	int flags = GetEntProp(client, Prop_Data, "m_iEFlags");
	return (flags & EFL_CHECK_UNTOUCH) != 0;
}

public MRESReturn DHook_ProcessMovement(Handle hParams)
{
	int client = DHookGetParam(hParams, 1);

	// Causes client to do zone touching in movement instead of server frames.
	// From https://github.com/rumourA/End-Touch-Fix
	if(GetCheckUntouch(client))
	{
		SDKCall(gH_PhysicsCheckForEntityUntouch, client);
	}

	Call_StartForward(gH_Forwards_OnProcessMovement);
	Call_PushCell(client);
	Call_Finish();

	if (IsFakeClient(client) || !IsPlayerAlive(client))
	{
		SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0); // otherwise you get slow spec noclip
		return MRES_Ignored;
	}

	return MRES_Ignored;
}

public MRESReturn DHook_ProcessMovementPost(Handle hParams)
{
	int client = DHookGetParam(hParams, 1);

	Call_StartForward(gH_Forwards_OnProcessMovementPost);
	Call_PushCell(client);
	Call_Finish();

	if (gA_Timers[client].bClientPaused || !gA_Timers[client].bTimerEnabled)
	{
		return MRES_Ignored;
	}

	float interval = GetTickInterval();
	float time = interval * gA_Timers[client].fTimescale;
	float timeOrig = time;

	gA_Timers[client].iZoneIncrement++;

	timer_snapshot_t snapshot;
	BuildSnapshot(client, snapshot);

	Call_StartForward(gH_Forwards_OnTimerIncrement);
	Call_PushCell(client);
	Call_PushArray(snapshot, sizeof(timer_snapshot_t));
	Call_PushCellRef(time);
	Call_Finish();

	if (time == timeOrig)
	{
		gA_Timers[client].fTimescaledTicks += gA_Timers[client].fTimescale;
	}
	else
	{
		gA_Timers[client].fTimescaledTicks += time / interval;
	}

	gA_Timers[client].fCurrentTime = interval * gA_Timers[client].fTimescaledTicks;

	Call_StartForward(gH_Forwards_OnTimerIncrementPost);
	Call_PushCell(client);
	Call_PushCell(time);
	Call_Finish();

	return MRES_Ignored;
}

// reference: https://github.com/momentum-mod/game/blob/5e2d1995ca7c599907980ee5b5da04d7b5474c61/mp/src/game/server/momentum/mom_timer.cpp#L388
void CalculateTickIntervalOffset(int client, int zonetype)
{
	float localOrigin[3];
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", localOrigin);
	float maxs[3];
	float mins[3];
	float vel[3];
	GetEntPropVector(client, Prop_Send, "m_vecMins", mins);
	GetEntPropVector(client, Prop_Send, "m_vecMaxs", maxs);
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vel);

	gF_SmallestDist[client] = 0.0;

	if (zonetype == Zone_Start)
	{
		TR_EnumerateEntitiesHull(localOrigin, gF_Origin[client][1], mins, maxs, PARTITION_TRIGGER_EDICTS, TREnumTrigger, client);
	}
	else
	{
		TR_EnumerateEntitiesHull(gF_Origin[client][0], localOrigin, mins, maxs, PARTITION_TRIGGER_EDICTS, TREnumTrigger, client);
	}

	float offset = gF_Fraction[client] * GetTickInterval();

	gA_Timers[client].fZoneOffset[zonetype] = gF_Fraction[client];
	gA_Timers[client].fDistanceOffset[zonetype] = gF_SmallestDist[client];

	Call_StartForward(gH_Forwards_OnTimeOffsetCalculated);
	Call_PushCell(client);
	Call_PushCell(zonetype);
	Call_PushCell(offset);
	Call_PushCell(gF_SmallestDist[client]);
	Call_Finish();

	gF_SmallestDist[client] = 0.0;
}

bool TREnumTrigger(int entity, int client)
{
	if(entity <= MaxClients)
	{
		return true;
	}

	char classname[32];
	GetEntityClassname(entity, classname, sizeof(classname));

	//the entity is a zone
	if(StrContains(classname, "trigger_multiple") > -1)
	{
		TR_ClipCurrentRayToEntity(MASK_ALL, entity);

		float start[3];
		TR_GetStartPosition(INVALID_HANDLE, start);

		float end[3];
		TR_GetEndPosition(end);

		float distance = GetVectorDistance(start, end);
		gF_SmallestDist[client] = distance;
		gF_Fraction[client] = TR_GetFraction();

		return false;
	}

	return true;
}

void BuildSnapshot(int client, timer_snapshot_t snapshot)
{
	snapshot = gA_Timers[client];
	snapshot.fServerTime = GetEngineTime();
	snapshot.fTimescale = (gA_Timers[client].fTimescale > 0.0) ? gA_Timers[client].fTimescale : 1.0;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if(IsFakeClient(client))
	{
		return Plugin_Continue;
	}

	int flags = GetEntityFlags(client);

	SetEntityFlags(client, (flags & ~FL_ATCONTROLS));

	// Wait till now to return so spectators can free-cam while paused...
	if(!IsPlayerAlive(client))
	{
		return Plugin_Changed;
	}

	Action result = Plugin_Continue;
	Call_StartForward(gH_Forwards_OnUserCmdPre);
	Call_PushCell(client);
	Call_PushCellRef(buttons);
	Call_PushCellRef(impulse);
	Call_PushArrayEx(vel, 3, SM_PARAM_COPYBACK);
	Call_PushArrayEx(angles, 3, SM_PARAM_COPYBACK);
	Call_PushCell(GetTimerStatus(client));
	Call_PushCell(gA_Timers[client].iTimerTrack);
	Call_PushCell(gA_Timers[client].bsStyle);
	Call_PushArrayEx(mouse, 2, SM_PARAM_COPYBACK);
	Call_Finish(result);

	if(result != Plugin_Continue && result != Plugin_Changed)
	{
		return result;
	}

	int iGroundEntity = GetEntPropEnt(client, Prop_Send, "m_hGroundEntity");
	bool bInStart = Shavit_InsideZone(client, Zone_Start, gA_Timers[client].iTimerTrack);

	if (gA_Timers[client].bTimerEnabled && !gA_Timers[client].bClientPaused)
	{
		// +strafe block
		if (GetStyleSettingInt(gA_Timers[client].bsStyle, "block_pstrafe") > 0 &&
			((vel[0] > 0.0 && (buttons & IN_FORWARD) == 0) || (vel[0] < 0.0 && (buttons & IN_BACK) == 0) ||
			(vel[1] > 0.0 && (buttons & IN_MOVERIGHT) == 0) || (vel[1] < 0.0 && (buttons & IN_MOVELEFT) == 0)))
		{
			if (gA_Timers[client].fStrafeWarning < gA_Timers[client].fCurrentTime)
			{
				if (GetStyleSettingInt(gA_Timers[client].bsStyle, "block_pstrafe") >= 2)
				{
					char sCheatDetected[64];
					FormatEx(sCheatDetected, 64, "%T", "Inconsistencies", client);
					StopTimer_Cheat(client, sCheatDetected);
				}

				vel[0] = 0.0;
				vel[1] = 0.0;

				return Plugin_Changed;
			}

			gA_Timers[client].fStrafeWarning = gA_Timers[client].fCurrentTime + 0.3;
		}
	}


	MoveType mtMoveType = GetEntityMoveType(client);

	if(mtMoveType == MOVETYPE_LADDER && gCV_SimplerLadders.BoolValue)
	{
		gA_Timers[client].bCanUseAllKeys = true;
	}

	else if(iGroundEntity != -1)
	{
		gA_Timers[client].bCanUseAllKeys = false;
	}

	// key blocking
	if(!gA_Timers[client].bCanUseAllKeys && mtMoveType != MOVETYPE_NOCLIP && mtMoveType != MOVETYPE_LADDER)
	{
		// block E
		if (GetStyleSettingBool(gA_Timers[client].bsStyle, "block_use") && (buttons & IN_USE) > 0)
		{
			buttons &= ~IN_USE;
		}

		if (iGroundEntity == -1 || GetStyleSettingBool(gA_Timers[client].bsStyle, "force_groundkeys"))
		{
			if (GetStyleSettingBool(gA_Timers[client].bsStyle, "block_w") && ((buttons & IN_FORWARD) > 0 || vel[0] > 0.0))
			{
				vel[0] = 0.0;
				buttons &= ~IN_FORWARD;
			}

			if (GetStyleSettingBool(gA_Timers[client].bsStyle, "block_a") && ((buttons & IN_MOVELEFT) > 0 || vel[1] < 0.0))
			{
				vel[1] = 0.0;
				buttons &= ~IN_MOVELEFT;
			}

			if (GetStyleSettingBool(gA_Timers[client].bsStyle, "block_s") && ((buttons & IN_BACK) > 0 || vel[0] < 0.0))
			{
				vel[0] = 0.0;
				buttons &= ~IN_BACK;
			}

			if (GetStyleSettingBool(gA_Timers[client].bsStyle, "block_d") && ((buttons & IN_MOVERIGHT) > 0 || vel[1] > 0.0))
			{
				vel[1] = 0.0;
				buttons &= ~IN_MOVERIGHT;
			}

			// HSW
			// Theory about blocking non-HSW strafes while playing HSW:
			// Block S and W without A or D.
			// Block A and D without S or W.
			if (GetStyleSettingInt(gA_Timers[client].bsStyle, "force_hsw") > 0)
			{
				bool bSHSW = (GetStyleSettingInt(gA_Timers[client].bsStyle, "force_hsw") == 2) && !bInStart; // don't decide on the first valid input until out of start zone!
				int iCombination = -1;

				bool bForward = ((buttons & IN_FORWARD) > 0 && vel[0] > 0.0);
				bool bMoveLeft = ((buttons & IN_MOVELEFT) > 0 && vel[1] < 0.0);
				bool bBack = ((buttons & IN_BACK) > 0 && vel[0] < 0.0);
				bool bMoveRight = ((buttons & IN_MOVERIGHT) > 0 && vel[1] > 0.0);

				if(bSHSW)
				{
					if((bForward && bMoveLeft) || (bBack && bMoveRight))
					{
						iCombination = 0;
					}
					else if((bForward && bMoveRight || bBack && bMoveLeft))
					{
						iCombination = 1;
					}

					// int gI_SHSW_FirstCombination[MAXPLAYERS+1]; // 0 - W/A S/D | 1 - W/D S/A
					if(gA_Timers[client].iSHSWCombination == -1 && iCombination != -1)
					{
						Shavit_PrintToChat(client, "%T", (iCombination == 0)? "SHSWCombination0":"SHSWCombination1", client);
						gA_Timers[client].iSHSWCombination = iCombination;
					}

					// W/A S/D
					if((gA_Timers[client].iSHSWCombination == 0 && iCombination != 0) ||
					// W/D S/A
						(gA_Timers[client].iSHSWCombination == 1 && iCombination != 1) ||
					// no valid combination & no valid input
						(gA_Timers[client].iSHSWCombination == -1 && iCombination == -1))
					{
						vel[0] = 0.0;
						vel[1] = 0.0;

						buttons &= ~IN_FORWARD;
						buttons &= ~IN_MOVELEFT;
						buttons &= ~IN_MOVERIGHT;
						buttons &= ~IN_BACK;
					}
				}
				else
				{
					if(bBack && (bMoveLeft || bMoveRight))
					{
						vel[0] = 0.0;

						buttons &= ~IN_FORWARD;
						buttons &= ~IN_BACK;
					}

					if(bForward && !(bMoveLeft || bMoveRight))
					{
						vel[0] = 0.0;

						buttons &= ~IN_FORWARD;
						buttons &= ~IN_BACK;
					}

					if((bMoveLeft || bMoveRight) && !bForward)
					{
						vel[1] = 0.0;

						buttons &= ~IN_MOVELEFT;
						buttons &= ~IN_MOVERIGHT;
					}
				}
			}
		}
	}

	bool bInWater = (GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2);
	bool bOnGround = (!bInWater && mtMoveType == MOVETYPE_WALK && iGroundEntity != -1);

	// css old auto jump code 
	/*if (GetStyleSettingBool(gA_Timers[client].bsStyle, "autobhop") && gB_Auto[client] && (buttons & IN_JUMP) > 0 && mtMoveType == MOVETYPE_WALK && !bInWater)
	{
		int iOldButtons = GetEntProp(client, Prop_Data, "m_nOldButtons");
		SetEntProp(client, Prop_Data, "m_nOldButtons", (iOldButtons & ~IN_JUMP));
	}*/

	// no jump zone implementation
	/*if (buttons & IN_JUMP) > 0)
	{
		vel[2] = 0.0;
		buttons &= ~IN_JUMP;
	}*/

	gA_Timers[client].bJumped = false;
	gA_Timers[client].bOnGround = bOnGround;

	return Plugin_Continue;
}

public void OnPlayerRunCmdPost(int client, int buttons, int impulse, const float vel[3], const float angles[3], int weapon, int subtype, int cmdnum, int tickcount, int seed, const int mouse[2])
{
	if (IsFakeClient(client))
	{
		return;
	}

	if (!IsPlayerAlive(client) || GetTimerStatus(client) != Timer_Running)
	{
		return;
	}

	if (GetStyleSettingBool(gA_Timers[client].bsStyle, "strafe_count_w")
	&& !GetStyleSettingBool(gA_Timers[client].bsStyle, "block_w")
	&& (gA_Timers[client].fLastInputVel[0] <= 0.0) && (vel[0] > 0.0)
	&& GetStyleSettingInt(gA_Timers[client].bsStyle, "force_hsw") != 1
	)
	{
		gA_Timers[client].iStrafes++;
	}

	if (GetStyleSettingBool(gA_Timers[client].bsStyle, "strafe_count_s")
	&& !GetStyleSettingBool(gA_Timers[client].bsStyle, "block_s")
	&& (gA_Timers[client].fLastInputVel[0] >= 0.0) && (vel[0] < 0.0)
	)
	{
		gA_Timers[client].iStrafes++;
	}

	if (GetStyleSettingBool(gA_Timers[client].bsStyle, "strafe_count_a")
	&& !GetStyleSettingBool(gA_Timers[client].bsStyle, "block_a")
	&& (gA_Timers[client].fLastInputVel[1] >= 0.0) && (vel[1] < 0.0)
	&& (GetStyleSettingInt(gA_Timers[client].bsStyle, "force_hsw") > 0 || vel[0] == 0.0)
	)
	{
		gA_Timers[client].iStrafes++;
	}

	if (GetStyleSettingBool(gA_Timers[client].bsStyle, "strafe_count_d")
	&& !GetStyleSettingBool(gA_Timers[client].bsStyle, "block_d")
	&& (gA_Timers[client].fLastInputVel[1] <= 0.0) && (vel[1] > 0.0)
	&& (GetStyleSettingInt(gA_Timers[client].bsStyle, "force_hsw") > 0 || vel[0] == 0.0)
	)
	{
		gA_Timers[client].iStrafes++;
	}

	int iGroundEntity = GetEntPropEnt(client, Prop_Send, "m_hGroundEntity");
	float fAngle = GetAngleDiff(angles[1], gA_Timers[client].fLastAngle);

	if (iGroundEntity == -1 && (GetEntityFlags(client) & FL_INWATER) == 0 && fAngle != 0.0)
	{
		float fAbsVelocity[3];
		GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", fAbsVelocity);

		if (SquareRoot(Pow(fAbsVelocity[0], 2.0) + Pow(fAbsVelocity[1], 2.0)) > 0.0)
		{
			float fTempAngle = angles[1];

			float fAngles[3];
			GetVectorAngles(fAbsVelocity, fAngles);

			if (fTempAngle < 0.0)
			{
				fTempAngle += 360.0;
			}

			TestAngles(client, (fTempAngle - fAngles[1]), fAngle, vel);
		}
	}

	if (gA_Timers[client].fCurrentTime != 0.0)
	{
		float frameCount = float(gA_Timers[client].iZoneIncrement);
		float fAbsVelocity[3];
		GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", fAbsVelocity);
		float curVel = SquareRoot(Pow(fAbsVelocity[0], 2.0) + Pow(fAbsVelocity[1], 2.0));
		float maxVel = gA_Timers[client].fMaxVelocity;
		gA_Timers[client].fMaxVelocity = (curVel > maxVel) ? curVel : maxVel;
		// STOLEN from Epic/Disrevoid. Thx :)
		gA_Timers[client].fAvgVelocity += (curVel - gA_Timers[client].fAvgVelocity) / frameCount;
	}

	gA_Timers[client].iLastButtons = buttons;
	gA_Timers[client].fLastAngle = angles[1];
	gA_Timers[client].fLastInputVel[0] = vel[0];
	gA_Timers[client].fLastInputVel[1] = vel[1];
}

void TestAngles(int client, float dirangle, float yawdelta, const float vel[3])
{
	if(dirangle < 0.0)
	{
		dirangle = -dirangle;
	}

	// normal
	if(dirangle < 22.5 || dirangle > 337.5)
	{
		gA_Timers[client].iTotalMeasures++;

		if((yawdelta > 0.0 && vel[1] <= -100.0) || (yawdelta < 0.0 && vel[1] >= 100.0))
		{
			gA_Timers[client].iGoodGains++;
		}
	}

	// hsw (thanks nairda!)
	else if((dirangle > 22.5 && dirangle < 67.5))
	{
		gA_Timers[client].iTotalMeasures++;

		if((yawdelta != 0.0) && (vel[0] >= 100.0 || vel[1] >= 100.0) && (vel[0] >= -100.0 || vel[1] >= -100.0))
		{
			gA_Timers[client].iGoodGains++;
		}
	}

	// sw
	else if((dirangle > 67.5 && dirangle < 112.5) || (dirangle > 247.5 && dirangle < 292.5))
	{
		gA_Timers[client].iTotalMeasures++;

		if(vel[0] <= -100.0 || vel[0] >= 100.0)
		{
			gA_Timers[client].iGoodGains++;
		}
	}
}

void StopTimer_Cheat(int client, const char[] message)
{
	Shavit_StopTimer(client);
	Shavit_PrintToChat(client, "%T", "CheatTimerStop", client, message);
}

void UpdateStyleSettings(int client)
{
	SetEntityGravity(client, GetStyleSettingFloat(gA_Timers[client].bsStyle, "gravity"));
}

void GetPauseMovement(int client)
{
	GetClientAbsOrigin(client, gA_Timers[client].fPauseOrigin);
	GetClientEyeAngles(client, gA_Timers[client].fPauseAngles);
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", gA_Timers[client].fPauseVelocity);
}

void ResumePauseMovement(int client)
{
	TeleportEntity(client, gA_Timers[client].fPauseOrigin, gA_Timers[client].fPauseAngles, gA_Timers[client].fPauseVelocity);
}

public void Frame_RemoveFlag(DataPack dp)
{
	RequestFrame(Frame2_RemoveFlag, dp);
}

public void Frame2_RemoveFlag(DataPack dp)
{
	dp.Reset();

	int flagsToRemove = dp.ReadCell();
	int client = dp.ReadCell();

	delete dp;

	CHANGE_FLAGS(gA_HookedPlayer[client].iPlayerFlags, gA_HookedPlayer[client].iPlayerFlags & ~flagsToRemove);
}