/*
 * shavit's Timer - Miscellaneous
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
#include <clientprefs>
#include <convar_class>
#include <dhooks>

#undef REQUIRE_EXTENSIONS
#include <SteamWorks>
#include <cstrike>

#undef REQUIRE_PLUGIN
#include <shavit>

#pragma newdecls required
#pragma semicolon 1

// stolen from cs_shareddefs.cpp
const float CS_PLAYER_DUCK_SPEED_IDEAL = 8.0;

char gS_RadioCommands[][] = { "coverme", "takepoint", "holdpos", "regroup", "followme", "takingfire", "go", "fallback", "sticktog",
	"getinpos", "stormfront", "report", "roger", "enemyspot", "needbackup", "sectorclear", "inposition", "reportingin",
	"getout", "negative", "enemydown", "compliment", "thanks", "cheer", "go_a", "go_b", "sorry", "needrop", "playerradio", "playerchatwheel", "player_ping", "chatwheel_ping" };

bool gB_Hide[MAXPLAYERS+1];
bool gB_Late = false;
int gI_LastShot[MAXPLAYERS+1];
ArrayList gA_Advertisements = null;
int gI_AdvertisementsCycle = 0;
char gS_Map[PLATFORM_MAX_PATH];
int gI_LastWeaponTick[MAXPLAYERS+1];
int gI_LastNoclipTick[MAXPLAYERS+1];

// cookies
Handle gH_HideCookie = null;
Cookie gH_BlockAdvertsCookie = null;

// cvars
Convar gCV_GodMode = null;
Convar gCV_HideTeamChanges = null;
Convar gCV_RespawnOnTeam = null;
Convar gCV_RespawnOnRestart = null;
Convar gCV_StartOnSpawn = null;
Convar gCV_JointeamHook = null;
Convar gCV_HideRadar = null;
Convar gCV_TeleportCommands = null;
Convar gCV_NoWeaponDrops = null;
Convar gCV_NoBlock = null;
Convar gCV_NoBlood = null;
Convar gCV_AutoRespawn = null;
Convar gCV_CreateSpawnPoints = null;
Convar gCV_DisableRadio = null;
Convar gCV_Scoreboard = null;
Convar gCV_WeaponCommands = null;
Convar gCV_WeaponsSpawnGood = null;
Convar gCV_PlayerOpacity = null;
Convar gCV_StaticPrestrafe = null;
Convar gCV_NoclipMe = null;
Convar gCV_AdvertisementInterval = null;
Convar gCV_RemoveRagdolls = null;
Convar gCV_ClanTag = null;
Convar gCV_DropAll = null;
Convar gCV_SpectatorList = null;
Convar gCV_HideChatCommands = null;
Convar gCV_WRMessages = null;
Convar gCV_BhopSounds = null;
Convar gCV_BotFootsteps = null;
Convar gCV_SpecScoreboardOrder = null;
Convar gCV_CSGOUnlockMovement = null;
Convar gCV_CSGOFixDuckTime = null;

// external cvars
ConVar sv_cheats = null;
ConVar sv_disable_immunity_alpha = null;
ConVar mp_humanteam = null;
ConVar hostname = null;
ConVar hostport = null;
ConVar sv_disable_radar = null;

// forwards
Handle gH_Forwards_OnClanTagChangePre = null;
Handle gH_Forwards_OnClanTagChangePost = null;

// dhooks
Handle gH_GetPlayerMaxSpeed = null;
DynamicHook gH_UpdateStepSound = null;
DynamicHook gH_IsSpawnPointValid = null;

// modules
bool gB_Checkpoints = false;
bool gB_Rankings = false;
bool gB_Replay = false;
bool gB_Zones = false;
bool gB_Chat = false;

// timer settings
stylestrings_t gS_StyleStrings[STYLE_LIMIT];

// misc
bool gB_CanTouchTrigger[MAXPLAYERS+1];

// movement unlocker
Address gI_PatchAddress;
int gI_PatchRestore[100];
int gI_PatchRestoreBytes;

public Plugin myinfo =
{
	name = "[shavit] Miscellaneous",
	author = "shavit",
	description = "Miscellaneous features for shavit's bhop timer.",
	version = SHAVIT_VERSION,
	url = "https://github.com/shavitush/bhoptimer"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
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

	// forwards
	gH_Forwards_OnClanTagChangePre = CreateGlobalForward("Shavit_OnClanTagChangePre", ET_Event, Param_Cell, Param_String, Param_Cell);
	gH_Forwards_OnClanTagChangePost = CreateGlobalForward("Shavit_OnClanTagChangePost", ET_Event, Param_Cell, Param_String, Param_Cell);

	sv_cheats = FindConVar("sv_cheats");
	sv_disable_immunity_alpha = FindConVar("sv_disable_immunity_alpha");

	// avaliable colors
	RegConsoleCmd("sm_colors", Command_ValidColors, "Show a list of avaliable colors to client's chat");
	RegConsoleCmd("sm_validcolors", Command_ValidColors, "Show a list of avaliable colors to client's chat");

	// spectator list
	RegConsoleCmd("sm_specs", Command_Specs, "Show a list of spectators.");
	RegConsoleCmd("sm_spectators", Command_Specs, "Show a list of spectators.");

	// spec
	RegConsoleCmd("sm_spec", Command_Spec, "Moves you to the spectators' team. Usage: sm_spec [target]");
	RegConsoleCmd("sm_spectate", Command_Spec, "Moves you to the spectators' team. Usage: sm_spectate [target]");

	// hide
	RegConsoleCmd("sm_hide", Command_Hide, "Toggle players' hiding.");
	RegConsoleCmd("sm_unhide", Command_Hide, "Toggle players' hiding.");
	gH_HideCookie = RegClientCookie("shavit_hide", "Hide settings", CookieAccess_Protected);

	// tpto
	RegConsoleCmd("sm_tpto", Command_Teleport, "Teleport to another player. Usage: sm_tpto [target]");
	RegConsoleCmd("sm_goto", Command_Teleport, "Teleport to another player. Usage: sm_goto [target]");

	// weapons
	RegConsoleCmd("sm_usp", Command_Weapon, "Spawn a USP.");
	RegConsoleCmd("sm_glock", Command_Weapon, "Spawn a Glock.");
	RegConsoleCmd("sm_knife", Command_Weapon, "Spawn a knife.");

	// noclip
	RegConsoleCmd("sm_nc", Command_Noclip, "Toggles noclip.");
	RegConsoleCmd("sm_noclipme", Command_Noclip, "Toggles noclip.");
	RegConsoleCmd("sm_nctrigger", Command_NoclipIgnoreTrigger);
	RegConsoleCmd("sm_nctriggers", Command_NoclipIgnoreTrigger);
	AddCommandListener(CommandListener_Noclip, "+noclip");
	AddCommandListener(CommandListener_Noclip, "-noclip");
	// Hijack sourcemod's sm_noclip from funcommands to work when no args are specified.
	AddCommandListener(CommandListener_funcommands_Noclip, "sm_noclip");
	AddCommandListener(CommandListener_Real_Noclip, "noclip");

	// hook teamjoins
	AddCommandListener(Command_Jointeam, "jointeam");
	AddCommandListener(Command_Spectate, "spectate");

	// gCV_SpecScoreboardOrder stuff
	AddCommandListener(Command_SpecNextPrev, "spec_next");
	AddCommandListener(Command_SpecNextPrev, "spec_prev");

	// hook radio commands instead of a global listener
	for(int i = 0; i < sizeof(gS_RadioCommands); i++)
	{
		AddCommandListener(Command_Radio, gS_RadioCommands[i]);
	}

	// hooks
	HookEvent("player_spawn", Player_Spawn);
	HookEvent("player_team", Player_Notifications, EventHookMode_Pre);
	HookEvent("player_death", Player_Notifications, EventHookMode_Pre);
	HookEventEx("weapon_fire", Weapon_Fire);
	HookEventEx("weapon_fire_on_empty", Weapon_Fire);
	HookEventEx("weapon_reload", Weapon_Fire);
	AddCommandListener(Command_Drop, "drop");
	AddTempEntHook("EffectDispatch", EffectDispatch);
	AddTempEntHook("World Decal", WorldDecal);
	AddTempEntHook("Shotgun Shot", Shotgun_Shot);
	AddNormalSoundHook(NormalSound);

	// phrases
	LoadTranslations("common.phrases");
	LoadTranslations("shavit-common.phrases");
	LoadTranslations("shavit-misc.phrases");

	// advertisements
	gA_Advertisements = new ArrayList(600);
	hostname = FindConVar("hostname");
	hostport = FindConVar("hostport");
	RegConsoleCmd("sm_toggleadverts", Command_ToggleAdverts, "Toggles visibility of advertisements");
	gH_BlockAdvertsCookie = new Cookie("shavit-blockadverts", "whether to block shavit-misc advertisements", CookieAccess_Private);

	// cvars and stuff
	gCV_GodMode = new Convar("shavit_misc_godmode", "3", "Enable godmode for players?\n0 - Disabled\n1 - Only prevent fall/world damage.\n2 - Only prevent damage from other players.\n3 - Full godmode.", 0, true, 0.0, true, 3.0);
	gCV_HideTeamChanges = new Convar("shavit_misc_hideteamchanges", "1", "Hide team changes in chat?\n0 - Disabled\n1 - Enabled", 0, true, 0.0, true, 1.0);
	gCV_RespawnOnTeam = new Convar("shavit_misc_respawnonteam", "1", "Respawn whenever a player joins a team?\n0 - Disabled\n1 - Enabled", 0, true, 0.0, true, 1.0);
	gCV_RespawnOnRestart = new Convar("shavit_misc_respawnonrestart", "1", "Respawn a dead player if they use the timer restart command?\n0 - Disabled\n1 - Enabled", 0, true, 0.0, true, 1.0);
	gCV_StartOnSpawn = new Convar("shavit_misc_startonspawn", "1", "Restart the timer for a player after they spawn?\n0 - Disabled\n1 - Enabled", 0, true, 0.0, true, 1.0);
	gCV_JointeamHook = new Convar("shavit_misc_jointeamhook", "1", "Hook `jointeam`?\n0 - Disabled\n1 - Enabled, players can instantly change teams.", 0, true, 0.0, true, 1.0);
	gCV_HideRadar = new Convar("shavit_misc_hideradar", "1", "Should the plugin hide the in-game radar?", 0, true, 0.0, true, 1.0);
	gCV_TeleportCommands = new Convar("shavit_misc_tpcmds", "1", "Enable teleport-related commands? (sm_goto/sm_tpto)\n0 - Disabled\n1 - Enabled", 0, true, 0.0, true, 1.0);
	gCV_NoWeaponDrops = new Convar("shavit_misc_noweapondrops", "1", "Remove every dropped weapon.\n0 - Disabled\n1 - Enabled", 0, true, 0.0, true, 1.0);
	gCV_NoBlock = new Convar("shavit_misc_noblock", "1", "Disable player collision?\n0 - Disabled\n1 - Enabled", 0, true, 0.0, true, 1.0);
	gCV_NoBlood = new Convar("shavit_misc_noblood", "1", "Hide blood decals and particles?\n0 - Disabled\n1 - Enabled", 0, true, 0.0, true, 1.0);
	gCV_AutoRespawn = new Convar("shavit_misc_autorespawn", "3.0", "Seconds to wait before respawning player?\n0 - Disabled", 0, true, 0.0, true, 10.0);
	gCV_CreateSpawnPoints = new Convar("shavit_misc_createspawnpoints", "6", "Amount of spawn points to add for each team.\n0 - Disabled", 0, true, 0.0, true, 32.0);
	gCV_DisableRadio = new Convar("shavit_misc_disableradio", "1", "Block radio commands.\n0 - Disabled (radio commands work)\n1 - Enabled (radio commands are blocked)", 0, true, 0.0, true, 1.0);
	gCV_Scoreboard = new Convar("shavit_misc_scoreboard", "1", "Manipulate scoreboard so score is -{time} and deaths are {rank})?\nDeaths part requires shavit-rankings.\n0 - Disabled\n1 - Enabled", 0, true, 0.0, true, 1.0);
	gCV_WeaponCommands = new Convar("shavit_misc_weaponcommands", "2", "Enable sm_usp, sm_glock and sm_knife?\n0 - Disabled\n1 - Enabled\n2 - Also give infinite reserved ammo.\n3 - Also give infinite clip ammo.", 0, true, 0.0, true, 3.0);
	gCV_WeaponsSpawnGood = new Convar("shavit_misc_weaponsspawngood", "3", "Bitflag for making glocks spawn on burst-fire and USPs spawn with a silencer on.\n0 - Disabled\n1 - Spawn USPs with a silencer.\n2 - Spawn glocks on burst-fire mode.\n3 - Spawn both USPs and glocks GOOD.", 0, true, 0.0, true, 3.0);
	gCV_PlayerOpacity = new Convar("shavit_misc_playeropacity", "69", "Player opacity (alpha) to set on spawn.\n-1 - Disabled\nValue can go up to 255. 0 for invisibility.", 0, true, -1.0, true, 255.0);
	gCV_StaticPrestrafe = new Convar("shavit_misc_staticprestrafe", "1", "Force prestrafe for every pistol.\n250 is the default value and some styles will have 260.\n0 - Disabled\n1 - Enabled", 0, true, 0.0, true, 1.0);
	gCV_NoclipMe = new Convar("shavit_misc_noclipme", "1", "Allow +noclip, sm_p and all the noclip commands?\n0 - Disabled\n1 - Enabled\n2 - requires 'admin_noclipme' override or ADMFLAG_CHEATS flag.", 0, true, 0.0, true, 2.0);
	gCV_AdvertisementInterval = new Convar("shavit_misc_advertisementinterval", "600.0", "Interval between each chat advertisement.\nConfiguration file for those is configs/shavit-advertisements.cfg.\nSet to 0.0 to disable.\nRequires server restart for changes to take effect.", 0, true, 0.0);
	gCV_RemoveRagdolls = new Convar("shavit_misc_removeragdolls", "1", "Remove ragdolls after death?\n0 - Disabled\n1 - Only remove replay bot ragdolls.\n2 - Remove all ragdolls.", 0, true, 0.0, true, 2.0);
	gCV_ClanTag = new Convar("shavit_misc_clantag", "{tr}{styletag} :: {time}", "Custom clantag for players.\n0 - Disabled\n{styletag} - style tag.\n{style} - style name.\n{time} - formatted time.\n{tr} - first letter of track.\n{rank} - player rank.\n{cr} - player's chatrank from shavit-chat, trimmed, with no colors", 0);
	gCV_DropAll = new Convar("shavit_misc_dropall", "1", "Allow all weapons to be dropped?\n0 - Disabled\n1 - Enabled", 0, true, 0.0, true, 1.0);
	gCV_SpectatorList = new Convar("shavit_misc_speclist", "1", "Who to show in !specs?\n0 - everyone\n1 - all admins (admin_speclisthide override to bypass)\n2 - players you can target", 0, true, 0.0, true, 2.0);
	gCV_HideChatCommands = new Convar("shavit_misc_hidechatcmds", "1", "Hide commands from chat?\n0 - Disabled\n1 - Enabled", 0, true, 0.0, true, 1.0);
	gCV_WRMessages = new Convar("shavit_misc_wrmessages", "3", "How many \"NEW <style> WR!!!\" messages to print?\n0 - Disabled", 0,  true, 0.0, true, 100.0);
	gCV_BhopSounds = new Convar("shavit_misc_bhopsounds", "1", "Should bhop (landing and jumping) sounds be muted?\n0 - Disabled\n1 - Blocked while !hide is enabled\n2 - Always blocked", 0,  true, 0.0, true, 2.0);
	gCV_BotFootsteps = new Convar("shavit_misc_botfootsteps", "1", "Enable footstep sounds for replay bots. Only works if shavit_misc_bhopsounds is less than 2.", 0, true, 0.0, true, 1.0);
	gCV_SpecScoreboardOrder = new Convar("shavit_misc_spec_scoreboard_order", "1", "Use scoreboard ordering for players when changing target when spectating.", 0, true, 0.0, true, 1.0);
	gCV_CSGOUnlockMovement = new Convar("shavit_misc_csgo_unlock_movement", "1", "Removes max speed limitation from players on the ground. Feels like CS:S.", 0, true, 0.0, true, 1.0);
	gCV_CSGOFixDuckTime = new Convar("shavit_misc_csgo_fixduck", "1", "Fixing the broken duck. Feels like CS:S.", 0, true, 0.0, true, 1.0);

	gCV_HideRadar.AddChangeHook(OnConVarChanged);
	gCV_CSGOUnlockMovement.AddChangeHook(OnConVarChanged);
	Convar.AutoExecConfig();

	mp_humanteam = FindConVar("mp_humanteam");
	sv_disable_radar = FindConVar("sv_disable_radar");

	// crons
	CreateTimer(10.0, Timer_Cron, 0, TIMER_REPEAT);
	CreateTimer(1.0, Timer_Scoreboard, 0, TIMER_REPEAT);

	LoadDHooks();
	UnlockMovement();

	// modules
	gB_Checkpoints = LibraryExists("shavit-checkpoints");
	gB_Rankings = LibraryExists("shavit-rankings");
	gB_Replay = LibraryExists("shavit-replay");
	gB_Zones = LibraryExists("shavit-zones");
	gB_Chat = LibraryExists("shavit-chat");
}

void LoadDHooks()
{
	Handle hGameData = LoadGameConfigFile("shavit.games");

	if (hGameData == null)
	{
		SetFailState("Failed to load shavit gamedata");
	}

	int iOffset;

	if ((iOffset = GameConfGetOffset(hGameData, "CCSPlayer::GetPlayerMaxSpeed")) == -1)
	{
		SetFailState("Couldn't get the offset for \"CCSPlayer::GetPlayerMaxSpeed\" - make sure your gamedata is updated!");
	}

	gH_GetPlayerMaxSpeed = DHookCreate(iOffset, HookType_Entity, ReturnType_Float, ThisPointer_CBaseEntity, CCSPlayer__GetPlayerMaxSpeed);

	if ((iOffset = GameConfGetOffset(hGameData, "CBasePlayer::UpdateStepSound")) != -1)
	{
		gH_UpdateStepSound = new DynamicHook(iOffset, HookType_Entity, ReturnType_Void, ThisPointer_CBaseEntity);
		gH_UpdateStepSound.AddParam(HookParamType_ObjectPtr);
		gH_UpdateStepSound.AddParam(HookParamType_VectorPtr);
		gH_UpdateStepSound.AddParam(HookParamType_VectorPtr);
	}
	else
	{
		LogError("Couldn't get the offset for \"CBasePlayer::UpdateStepSound\" - make sure your gamedata is updated!");
	}

	if ((iOffset = GameConfGetOffset(hGameData, "CGameRules::IsSpawnPointValid")) != -1)
	{
		gH_IsSpawnPointValid = new DynamicHook(iOffset, HookType_GameRules, ReturnType_Bool, ThisPointer_Ignore);
		gH_IsSpawnPointValid.AddParam(HookParamType_CBaseEntity);
		gH_IsSpawnPointValid.AddParam(HookParamType_CBaseEntity);
	}
	else
	{
		SetFailState("Couldn't get the offset for \"CGameRules::IsSpawnPointValid\" - make sure your gamedata is updated!");
	}

	delete hGameData;
}

void UnlockMovement()
{
	if(!gCV_CSGOUnlockMovement.BoolValue)
	{
		return;
	}

	Handle hGameData = LoadGameConfigFile("shavit.games");

	if (hGameData == null)
	{
		SetFailState("Failed to load shavit gamedata");
	}

	Address iAddr = GameConfGetAddress(hGameData, "WalkMoveMaxSpeed");
	if (iAddr == Address_Null)
	{
		SetFailState("Can't find WalkMoveMaxSpeed address.");
	}

	int iOffset = GameConfGetOffset(hGameData, "CappingOffset");
	if (iOffset == -1)
	{
		SetFailState("Can't find CappingOffset in gamedata.");
	}

	iAddr += view_as<Address>(iOffset);
	gI_PatchAddress = iAddr;

	if ((gI_PatchRestoreBytes = GameConfGetOffset(hGameData, "PatchBytes")) == -1)
	{
		SetFailState("Can't find PatchBytes in gamedata.");
	}

	for (int i = 0; i < gI_PatchRestoreBytes; i++)
	{
		gI_PatchRestore[i] = LoadFromAddress(iAddr, NumberType_Int8);
		StoreToAddress(iAddr++, 0x90, NumberType_Int8);
	}

	delete hGameData;
}

void LockMovement()
{
	if(gI_PatchAddress != Address_Null)
	{
		for(int i = 0; i < gI_PatchRestoreBytes; i++)
		{
			StoreToAddress(gI_PatchAddress + view_as<Address>(i), gI_PatchRestore[i], NumberType_Int8);
		}
	}
}

public void OnPluginEnd()
{
	LockMovement();
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (convar == gCV_HideRadar && sv_disable_radar != null)
	{
		sv_disable_radar.BoolValue = gCV_HideRadar.BoolValue;
	}

	else if (convar == gCV_CSGOUnlockMovement)
	{
		if(!gCV_CSGOUnlockMovement.BoolValue)
		{
			LockMovement();
		}

		else
		{
			UnlockMovement();
		}
	}
}

public MRESReturn Hook_IsSpawnPointValid(Handle hReturn, Handle hParams)
{
	if (gCV_NoBlock.BoolValue)
	{
		DHookSetReturn(hReturn, true);
		return MRES_Supercede;
	}

	return MRES_Ignored;
}

public MRESReturn Detour_CalcPlayerScore(DHookReturn hReturn, DHookParam hParams)
{
	if (!gCV_Scoreboard.BoolValue)
	{
		return MRES_Ignored;
	}

	int client = hParams.Get(2);
	float fPB = Shavit_GetClientPB(client, 0, Track_Main);
	int iScore = (fPB != 0.0 && fPB < 2000)? -RoundToFloor(fPB):-2000;

	hReturn.Value = iScore;
	return MRES_Supercede;
}

public void OnClientCookiesCached(int client)
{
	if(IsFakeClient(client))
	{
		return;
	}

	char sSetting[8];
	GetClientCookie(client, gH_HideCookie, sSetting, 8);

	if(strlen(sSetting) == 0)
	{
		SetClientCookie(client, gH_HideCookie, "0");
		gB_Hide[client] = false;
	}

	else
	{
		gB_Hide[client] = view_as<bool>(StringToInt(sSetting));
	}
}

public void Shavit_OnStyleConfigLoaded(int styles)
{
	for(int i = 0; i < styles; i++)
	{
		Shavit_GetStyleStringsStruct(i, gS_StyleStrings[i]);
	}
}

public void Shavit_OnChatConfigLoaded()
{
	if(!LoadAdvertisementsConfig())
	{
		SetFailState("Cannot open \"configs/shavit-advertisements.cfg\". Make sure this file exists and that the server has read permissions to it.");
	}
}

void LoadMapFixes()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, PLATFORM_MAX_PATH, "configs/shavit-mapfixes.cfg");

	KeyValues kv = new KeyValues("shavit-mapfixes");

	if (kv.ImportFromFile(sPath) && kv.JumpToKey(gS_Map) && kv.GotoFirstSubKey(false))
	{
		do {
			char key[128];
			char value[128];
			kv.GetSectionName(key, sizeof(key));
			kv.GetString(NULL_STRING, value, sizeof(value));

			PrintToServer(">>>> mapfixes: %s \"%s\"", key, value);

			ConVar cvar = FindConVar(key);

			if (cvar)
			{
				cvar.SetString(value, true, true);
			}
		} while (kv.GotoNextKey(false));
	}

	delete kv;
}

void CreateSpawnPoint(int iTeam, float fOrigin[3], float fAngles[3])
{
	int iSpawnPoint = CreateEntityByName((iTeam == 2)? "info_player_terrorist":"info_player_counterterrorist");

	if (DispatchSpawn(iSpawnPoint))
	{
		TeleportEntity(iSpawnPoint, fOrigin, fAngles, NULL_VECTOR);
	}
}

public void OnMapStart()
{
	gH_IsSpawnPointValid.HookGamerules(Hook_Post, Hook_IsSpawnPointValid);

	GetLowercaseMapName(gS_Map);

	if (gB_Late)
	{
		gB_Late = false;
		Shavit_OnStyleConfigLoaded(Shavit_GetStyleCount());
		Shavit_OnChatConfigLoaded();
		OnAutoConfigsBuffered();

		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsValidClient(i))
			{
				OnClientPutInServer(i);

				if(AreClientCookiesCached(i))
				{
					OnClientCookiesCached(i);
				}
			}
		}
	}
}

public void OnAutoConfigsBuffered()
{
	LoadMapFixes();
}

public void OnConfigsExecuted()
{
	if(sv_disable_immunity_alpha != null)
	{
		sv_disable_immunity_alpha.BoolValue = true;
	}

	if (sv_disable_radar != null && gCV_HideRadar.BoolValue)
	{
		sv_disable_radar.BoolValue = true;
	}

	if(gCV_CreateSpawnPoints.IntValue > 0)
	{
		int info_player_terrorist        = FindEntityByClassname(-1, "info_player_terrorist");
		int info_player_counterterrorist = FindEntityByClassname(-1, "info_player_counterterrorist");
		int info_player_teamspawn        = FindEntityByClassname(-1, "info_player_teamspawn");
		int info_player_start            = FindEntityByClassname(-1, "info_player_start");

		int iEntity =
			((info_player_terrorist != -1)        ? info_player_terrorist :
			((info_player_counterterrorist != -1) ? info_player_counterterrorist :
			((info_player_teamspawn != -1)        ? info_player_teamspawn :
			((info_player_start != -1)            ? info_player_start : -1))));

		if (iEntity != -1)
		{
			float fOrigin[3], fAngles[3];
			GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", fOrigin);
			GetEntPropVector(iEntity, Prop_Data, "m_angAbsRotation", fAngles);

			if (info_player_terrorist == -1)
			{
				CreateSpawnPoint(2, fOrigin, fAngles);
			}

			if (info_player_counterterrorist == -1)
			{
				CreateSpawnPoint(3, fOrigin, fAngles);
			}
		}
	}

	if(gCV_AdvertisementInterval.FloatValue > 0.0)
	{
		CreateTimer(gCV_AdvertisementInterval.FloatValue, Timer_Advertisement, 0, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
}

bool LoadAdvertisementsConfig()
{
	gA_Advertisements.Clear();

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, PLATFORM_MAX_PATH, "configs/shavit-advertisements.cfg");

	KeyValues kv = new KeyValues("shavit-advertisements");
	
	if(!kv.ImportFromFile(sPath) || !kv.GotoFirstSubKey(false))
	{
		delete kv;

		return false;
	}

	do
	{
		char sTempMessage[600];
		kv.GetString(NULL_STRING, sTempMessage, 600, "<EMPTY ADVERTISEMENT>");

		gA_Advertisements.PushString(sTempMessage);
	}

	while(kv.GotoNextKey(false));

	delete kv;

	return true;
}

public void OnLibraryAdded(const char[] name)
{
	if(StrEqual(name, "shavit-checkpoints"))
	{
		gB_Checkpoints = true;
	}

	else if(StrEqual(name, "shavit-rankings"))
	{
		gB_Rankings = true;
	}

	else if(StrEqual(name, "shavit-replay"))
	{
		gB_Replay = true;
	}

	else if(StrEqual(name, "shavit-zones"))
	{
		gB_Zones = true;
	}

	else if(StrEqual(name, "shavit-chat"))
	{
		gB_Chat = true;
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if(StrEqual(name, "shavit-checkpoints"))
	{
		gB_Checkpoints = false;
	}

	else if(StrEqual(name, "shavit-rankings"))
	{
		gB_Rankings = false;
	}

	else if(StrEqual(name, "shavit-replay"))
	{
		gB_Replay = false;
	}

	else if(StrEqual(name, "shavit-zones"))
	{
		gB_Zones = false;
	}

	else if(StrEqual(name, "shavit-chat"))
	{
		gB_Chat = false;
	}
}

int GetHumanTeam()
{
	char sTeam[8];
	mp_humanteam.GetString(sTeam, 8);

	if(StrEqual(sTeam, "t", false) || StrEqual(sTeam, "red", false))
	{
		return 2;
	}

	else if(StrEqual(sTeam, "ct", false) || StrContains(sTeam, "blu", false) != -1)
	{
		return 3;
	}

	return 0;
}

public Action Command_Spectate(int client, const char[] command, int args)
{
	if(!IsValidClient(client) || !gCV_JointeamHook.BoolValue)
	{
		return Plugin_Continue;
	}

	CleanSwitchTeam(client, 1);
	return Plugin_Handled;
}

public int ScoreboardSort(int index1, int index2, Handle array, Handle hndl)
{
	int a = GetArrayCell(array, index1);
	int b = GetArrayCell(array, index2);

	int a_team = GetClientTeam(a);
	int b_team = GetClientTeam(b);

	if (a_team != b_team)
	{
		return a_team > b_team ? -1 : 1;
	}

	int a_score = CS_GetClientContributionScore(a);
	int b_score = CS_GetClientContributionScore(b);

	if (a_score != b_score)
	{
		return a_score > b_score ? -1 : 1;
	}

	int a_deaths = GetEntProp(a, Prop_Data, "m_iDeaths");
	int b_deaths = GetEntProp(b, Prop_Data, "m_iDeaths");

	if (a_deaths != b_deaths)
	{
		return a_deaths < b_deaths ? -1 : 1;
	}

	return a < b ? -1 : 1;
}

public Action Command_SpecNextPrev(int client, const char[] command, int args)
{
	if (!IsValidClient(client) || !gCV_SpecScoreboardOrder.BoolValue)
	{
		return Plugin_Continue;
	}

	int iObserverMode = GetEntProp(client, Prop_Send, "m_iObserverMode");

	if (iObserverMode <= 3 /* OBS_MODE_FIXED */)
	{
		return Plugin_Continue;
	}

	ArrayList players = new ArrayList();

	// add valid alive players
	for (int i = 1; i <= MaxClients; i++)
	{
		if (i != client && IsValidClient(i) && IsPlayerAlive(i) && GetClientTeam(i) > 1)
		{
			players.Push(i);
		}
	}

	if (players.Length < 2)
	{
		delete players;
		return Plugin_Continue;
	}

	players.SortCustom(ScoreboardSort);

	int current_target = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");

	if (!IsValidClient(current_target))
	{
		SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", players.Get(0));
		delete players;
		return Plugin_Handled;
	}

	int pos = players.FindValue(current_target);

	if (pos == -1)
	{
		pos = 0;
	}

	pos += (StrEqual(command, "spec_next", true)) ? 1 : -1;

	if (pos < 0)
	{
		pos = players.Length - 1;
	}

	if (pos >= players.Length)
	{
		pos = 0;
	}

	SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", players.Get(pos));

	delete players;

	return Plugin_Handled;
}

public Action Command_Jointeam(int client, const char[] command, int args)
{
	if(!IsValidClient(client) || !gCV_JointeamHook.BoolValue)
	{
		return Plugin_Continue;
	}

	char arg1[8];
	GetCmdArg(1, arg1, 8);

	int iTeam = StringToInt(arg1);
	int iHumanTeam = GetHumanTeam();

	if (iHumanTeam != 0)
	{
		iTeam = iHumanTeam;
	}

	if (iTeam < 1 || iTeam > 3)
	{
		iTeam = GetRandomInt(2, 3);
	}

	CleanSwitchTeam(client, iTeam);

	if(gCV_RespawnOnTeam.BoolValue && iTeam != 1)
	{
		RemoveAllWeapons(client); // so weapons are removed and we don't hit the edict limit
		CS_RespawnPlayer(client);

		return Plugin_Handled;
	}

	return Plugin_Continue;
}

void CleanSwitchTeam(int client, int team)
{
	if (GetClientTeam(client) == team)
	{
		// Close the team menu when selecting your own team...
		Event event = CreateEvent("player_team");
		event.SetInt("userid", GetClientUserId(client));
		event.SetInt("team", team);
		event.SetBool("silent", true);
		event.FireToClient(client);
		event.Cancel();
	}

	if(team != 1)
	{
		CS_SwitchTeam(client, team);
	}
	else
	{
		ChangeClientTeam(client, team);
	}
}

public Action Command_Radio(int client, const char[] command, int args)
{
	if(gCV_DisableRadio.BoolValue)
	{
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public MRESReturn CCSPlayer__GetPlayerMaxSpeed(int pThis, DHookReturn hReturn)
{
	if(!gCV_StaticPrestrafe.BoolValue || !IsValidClient(pThis, true))
	{
		return MRES_Ignored;
	}

	hReturn.Value = Shavit_GetStyleSettingFloat(Shavit_GetBhopStyle(pThis), "runspeed");

	return MRES_Override;
}

// Remove flags from replay bots that cause CBasePlayer::UpdateStepSound to return without playing a footstep.
public MRESReturn Hook_UpdateStepSound_Pre(int pThis, DHookParam hParams)
{
	if (GetEntityMoveType(pThis) == MOVETYPE_NOCLIP)
	{
		SetEntityMoveType(pThis, MOVETYPE_WALK);
	}

	SetEntityFlags(pThis, GetEntityFlags(pThis) & ~FL_ATCONTROLS);

	return MRES_Ignored;
}

// Readd flags to replay bots now that CBasePlayer::UpdateStepSound is done.
public MRESReturn Hook_UpdateStepSound_Post(int pThis, DHookParam hParams)
{
	if (GetEntityMoveType(pThis) == MOVETYPE_WALK)
	{
		SetEntityMoveType(pThis, MOVETYPE_NOCLIP);
	}

	SetEntityFlags(pThis, GetEntityFlags(pThis) | FL_ATCONTROLS);

	return MRES_Ignored;
}

public Action Timer_Cron(Handle timer)
{
	if (gCV_NoWeaponDrops.BoolValue)
	{
		int ent = -1;

		while ((ent = FindEntityByClassname(ent, "weapon_*")) != -1)
		{
			if (GetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity") == -1)
			{
				AcceptEntityInput(ent, "Kill");
			}
		}
	}

	return Plugin_Continue;
}

public Action Timer_Scoreboard(Handle timer)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsValidClient(i) || IsFakeClient(i))
		{
			continue;
		}

		if(gCV_Scoreboard.BoolValue)
		{
			UpdateScoreboard(i);
		}

		UpdateClanTag(i);
	}

	return Plugin_Continue;
}

public Action Timer_Advertisement(Handle timer)
{
	char sHostname[128];
	hostname.GetString(sHostname, 128);

	char sTimeLeft[32];
	int iTimeLeft = 0;
	GetMapTimeLeft(iTimeLeft);
	FormatSeconds(float(iTimeLeft), sTimeLeft, 32, false, true);

	char sTimeLeftRaw[8];
	IntToString(iTimeLeft, sTimeLeftRaw, 8);

	char sIPAddress[64];

	if(GetFeatureStatus(FeatureType_Native, "SteamWorks_GetPublicIP") == FeatureStatus_Available)
	{
		int iAddress[4];
		SteamWorks_GetPublicIP(iAddress);

		FormatEx(sIPAddress, 64, "%d.%d.%d.%d:%d", iAddress[0], iAddress[1], iAddress[2], iAddress[3], hostport.IntValue);
	}

	bool bLinear = Shavit_IsLinearMap();

	char sMapType[16];
	strcopy(sMapType, 16, bLinear? "竞速图":"关卡图");

	char sMapCPType[16];
	strcopy(sMapCPType, 16, bLinear? "检查点数":"关卡数");

	char sMapCPs[4];
	IntToString(bLinear? Shavit_GetMapCheckpoints():Shavit_GetMapStages(), sMapCPs, 4);

	char sMapTier[4];
	IntToString(Shavit_GetMapTier(gS_Map), sMapTier, 4);

	char sMapBonuses[4];
	IntToString(Shavit_GetMapBonuses(), sMapBonuses, 4);

	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i) && IsClientInGame(i))
		{
			if(AreClientCookiesCached(i))
			{
				char sCookie[2];
				gH_BlockAdvertsCookie.Get(i, sCookie, sizeof(sCookie));

				if (sCookie[0] == '1')
				{
					continue;
				}
			}

			char sTempMessage[600];
			gA_Advertisements.GetString(gI_AdvertisementsCycle, sTempMessage, 600);

			char sName[MAX_NAME_LENGTH];
			GetClientName(i, sName, MAX_NAME_LENGTH);
			ReplaceString(sTempMessage, 600, "{name}", sName);
			ReplaceString(sTempMessage, 600, "{timeleft}", sTimeLeft);
			ReplaceString(sTempMessage, 600, "{timeleftraw}", sTimeLeftRaw);
			ReplaceString(sTempMessage, 600, "{hostname}", sHostname);
			ReplaceString(sTempMessage, 600, "{serverip}", sIPAddress);
			ReplaceString(sTempMessage, 600, "{map}", gS_Map);
			ReplaceString(sTempMessage, 600, "{maptype}", sMapType);
			ReplaceString(sTempMessage, 600, "{mapcptype}", sMapCPType);
			ReplaceString(sTempMessage, 600, "{mapcps}", sMapCPs);
			ReplaceString(sTempMessage, 600, "{maptier}", sMapTier);
			ReplaceString(sTempMessage, 600, "{mapbonuses}", sMapBonuses);

			Shavit_PrintToChat(i, "%s", sTempMessage);
		}
	}

	if(++gI_AdvertisementsCycle >= gA_Advertisements.Length)
	{
		gI_AdvertisementsCycle = 0;
	}

	return Plugin_Continue;
}

void UpdateScoreboard(int client)
{
	float fPB = Shavit_GetClientPB(client, 0, Track_Main);

	int iScore = (fPB != 0.0 && fPB < 2000)? -RoundToFloor(fPB):-2000;

	CS_SetClientContributionScore(client, iScore);

	if(gB_Rankings)
	{
		SetEntProp(client, Prop_Data, "m_iDeaths", Shavit_GetRank(client));
	}
}

void UpdateClanTag(int client)
{
	// no clan tags in tf2
	char sCustomTag[32];
	gCV_ClanTag.GetString(sCustomTag, 32);

	if(StrEqual(sCustomTag, "0"))
	{
		return;
	}

	char sTime[16];

	float fTime = Shavit_GetClientTime(client);

	if(Shavit_GetTimerStatus(client) == Timer_Stopped || fTime < 1.0)
	{
		strcopy(sTime, 16, "N/A");
	}
	else
	{
		FormatSeconds(fTime, sTime, sizeof(sTime), false, true);
	}

	int track = Shavit_GetClientTrack(client);
	char sTrack[4];

	if(track != Track_Main)
	{
		sTrack[0] = 'B';
		if (track > Track_Bonus)
		{
			sTrack[1] = '0' + track;
		}
	}

	char sRank[8];

	if(gB_Rankings)
	{
		IntToString(Shavit_GetRank(client), sRank, 8);
	}

	ReplaceString(sCustomTag, 32, "{style}", gS_StyleStrings[Shavit_GetBhopStyle(client)].sStyleName);
	ReplaceString(sCustomTag, 32, "{styletag}", gS_StyleStrings[Shavit_GetBhopStyle(client)].sClanTag);
	ReplaceString(sCustomTag, 32, "{time}", sTime);
	ReplaceString(sCustomTag, 32, "{tr}", sTrack);
	ReplaceString(sCustomTag, 32, "{rank}", sRank);

	if(gB_Chat)
	{
		char sChatrank[32];
		Shavit_GetPlainChatrank(client, sChatrank, sizeof(sChatrank), false);
		ReplaceString(sCustomTag, 32, "{cr}", sChatrank);
	}

	Action result = Plugin_Continue;
	Call_StartForward(gH_Forwards_OnClanTagChangePre);
	Call_PushCell(client);
	Call_PushStringEx(sCustomTag, 32, SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushCell(32);
	Call_Finish(result);
	
	if(result != Plugin_Continue && result != Plugin_Changed)
	{
		return;
	}

	CS_SetClientClanTag(client, sCustomTag);

	Call_StartForward(gH_Forwards_OnClanTagChangePost);
	Call_PushCell(client);
	Call_PushStringEx(sCustomTag, 32, SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushCell(32);
	Call_Finish();
}

void RemoveRagdoll(int client)
{
	int iEntity = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");

	if(iEntity != INVALID_ENT_REFERENCE)
	{
		AcceptEntityInput(iEntity, "Kill");
	}
}

public Action Shavit_OnUserCmdPre(int client, int &buttons, int &impulse, float vel[3], float angles[3], TimerStatus status, int track, int style)
{
	if (gCV_CSGOFixDuckTime.BoolValue && (buttons & IN_DUCK))
	{
		SetEntPropFloat(client, Prop_Send, "m_flDuckSpeed", CS_PLAYER_DUCK_SPEED_IDEAL);
	}

	if(GetEntityMoveType(client) == MOVETYPE_NOCLIP && status == Timer_Running)
	{
		Shavit_StopTimer(client);
	}

	return Plugin_Continue;
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_SetTransmit, OnSetTransmit);
	SDKHook(client, SDKHook_WeaponDrop, OnWeaponDrop);
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);

	gI_LastWeaponTick[client] = 0;
	gI_LastNoclipTick[client] = 0;

	if(IsFakeClient(client))
	{
		if (gCV_BotFootsteps.BoolValue && gH_UpdateStepSound != null)
		{
			gH_UpdateStepSound.HookEntity(Hook_Pre,  client, Hook_UpdateStepSound_Pre);
			gH_UpdateStepSound.HookEntity(Hook_Post, client, Hook_UpdateStepSound_Post);
		}
		return;
	}

	if(gH_GetPlayerMaxSpeed != null)
	{
		DHookEntity(gH_GetPlayerMaxSpeed, true, client);
	}

	if(!AreClientCookiesCached(client))
	{
		gB_Hide[client] = false;
	}

	gB_CanTouchTrigger[client] = false;
}

void RemoveAllWeapons(int client)
{
	int weapon = -1;
	int max = GetEntPropArraySize(client, Prop_Send, "m_hMyWeapons");
	for (int i = 0; i < max; i++)
	{
		if ((weapon = GetEntPropEnt(client, Prop_Send, "m_hMyWeapons", i)) == -1)
		{
			continue;
		}

		if (RemovePlayerItem(client, weapon))
		{
			AcceptEntityInput(weapon, "Kill");
		}
	}
}

public void OnClientDisconnect(int client)
{
	if(gCV_NoWeaponDrops.BoolValue)
	{
		if (IsClientInGame(client))
		{
			RemoveAllWeapons(client);
		}
	}
}

void ClearViewPunch(int victim)
{
	if (1 <= victim <= MaxClients)
	{
		SetEntPropVector(victim, Prop_Send, "m_viewPunchAngle", NULL_VECTOR);
		SetEntPropVector(victim, Prop_Send, "m_aimPunchAngle", NULL_VECTOR);
		SetEntPropVector(victim, Prop_Send, "m_aimPunchAngleVel", NULL_VECTOR);
	}
}

public Action OnTakeDamage(int victim, int& attacker)
{
	bool bBlockDamage;

	switch(gCV_GodMode.IntValue)
	{
		case 0:
		{
			bBlockDamage = false;
		}
		case 1:
		{
			// 0 - world/fall damage
			if(attacker == 0)
			{
				bBlockDamage = true;
			}
		}
		case 2:
		{
			if(IsValidClient(attacker))
			{
				bBlockDamage = true;
			}
		}
		default:
		{
			bBlockDamage = true;
		}
	}

	if (gB_Hide[victim] || bBlockDamage || IsFakeClient(victim))
	{
		ClearViewPunch(victim);

		for (int i = 1; i <= MaxClients; i++)
		{
			if (i != victim && IsValidClient(i) && GetSpectatorTarget(i) == victim)
			{
				ClearViewPunch(i);
			}
		}
	}

	return bBlockDamage ? Plugin_Handled : Plugin_Continue;
}

public void OnWeaponDrop(int client, int entity)
{
	if(gCV_NoWeaponDrops.BoolValue && IsValidEntity(entity))
	{
		AcceptEntityInput(entity, "Kill");
	}
}

// hide
public Action OnSetTransmit(int entity, int client)
{
	if(gB_Hide[client] && client != entity && (!IsClientObserver(client) || (GetEntProp(client, Prop_Send, "m_iObserverMode") != 6 &&
		GetEntPropEnt(client, Prop_Send, "m_hObserverTarget") != entity)))
	{
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
	if (!IsValidClient(client))
	{
		return Plugin_Continue;
	}

	if(IsChatTrigger() && gCV_HideChatCommands.BoolValue)
	{
		// hide commands
		return Plugin_Handled;
	}

	if(sArgs[0] == '!' || sArgs[0] == '/')
	{
		bool bUpper = false;
		char buf[200];
		int size = strcopy(buf, sizeof(buf), sArgs[1]);

		for(int i = 0; i < size; i++)
		{
			if (buf[i] == ' ' || buf[i] == '\n' || buf[i] == '\t')
			{
				break;
			}

			if (IsCharUpper(buf[i]))
			{
				buf[i] = CharToLower(buf[i]);
				bUpper = true;
			}
		}

		if(bUpper)
		{
			FakeClientCommandEx(client, "sm_%s", buf);
			return Plugin_Stop;
		}
	}

	return Plugin_Continue;
}

public Action Command_Hide(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	gB_Hide[client] = !gB_Hide[client];
	SetClientCookie(client, gH_HideCookie, gB_Hide[client] ? "1" : "0");

	if(gB_Hide[client])
	{
		Shavit_PrintToChat(client, "%T", "HideEnabled", client);
	}
	else
	{
		Shavit_PrintToChat(client, "%T", "HideDisabled", client);
	}

	return Plugin_Handled;
}

public Action Command_Spec(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	CleanSwitchTeam(client, 1);

	int target = -1;

	if(args > 0)
	{
		char sArgs[MAX_TARGET_LENGTH];
		GetCmdArgString(sArgs, MAX_TARGET_LENGTH);

		target = FindTarget(client, sArgs, false, false);

		if(target == -1)
		{
			return Plugin_Handled;
		}
	}
	else if(gB_Replay)
	{
		target = Shavit_GetReplayBotIndex(0, -1); // try to find normal bot

		if (target < 1)
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsValidClient(i, true) && IsFakeClient(i))
				{
					target = i;
					break;
				}
			}
		}
	}

	if(IsValidClient(target, true))
	{
		SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", target);
	}

	return Plugin_Handled;
}

public Action Command_ToggleAdverts(int client, int args)
{
	if (IsValidClient(client))
	{
		char sCookie[4];
		gH_BlockAdvertsCookie.Get(client, sCookie, sizeof(sCookie));
		gH_BlockAdvertsCookie.Set(client, (sCookie[0] == '1') ? "0" : "1");
		Shavit_PrintToChat(client, "%T", (sCookie[0] == '1') ? "AdvertisementsEnabled" : "AdvertisementsDisabled", client);
	}

	return Plugin_Handled;
}

public Action Command_Teleport(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	if(!gCV_TeleportCommands.BoolValue)
	{
		Shavit_PrintToChat(client, "%T", "CommandDisabled", client);

		return Plugin_Handled;
	}

	if(args > 0)
	{
		char sArgs[MAX_TARGET_LENGTH];
		GetCmdArgString(sArgs, MAX_TARGET_LENGTH);

		int iTarget = FindTarget(client, sArgs, false, false);

		if(iTarget == -1)
		{
			return Plugin_Handled;
		}

		Teleport(client, GetClientSerial(iTarget));
	}

	else
	{
		Menu menu = new Menu(MenuHandler_Teleport);
		menu.SetTitle("%T", "TeleportMenuTitle", client);

		for(int i = 1; i <= MaxClients; i++)
		{
			if(!IsValidClient(i, true) || i == client)
			{
				continue;
			}

			char serial[16];
			IntToString(GetClientSerial(i), serial, 16);

			char sName[MAX_NAME_LENGTH];
			GetClientName(i, sName, MAX_NAME_LENGTH);

			menu.AddItem(serial, sName);
		}

		menu.ExitButton = true;
		menu.Display(client, MENU_TIME_FOREVER);
	}

	return Plugin_Handled;
}

public int MenuHandler_Teleport(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[16];
		menu.GetItem(param2, sInfo, 16);

		if(!Teleport(param1, StringToInt(sInfo)))
		{
			Command_Teleport(param1, 0);
		}
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

bool Teleport(int client, int targetserial)
{
	if(!IsPlayerAlive(client))
	{
		Shavit_PrintToChat(client, "%T", "TeleportAlive", client);

		return false;
	}

	int iTarget = GetClientFromSerial(targetserial);

	if(iTarget == 0)
	{
		Shavit_PrintToChat(client, "%T", "TeleportInvalidTarget", client);

		return false;
	}

	float vecPosition[3];
	GetClientAbsOrigin(iTarget, vecPosition);

	Shavit_StopTimer(client);

	TeleportEntity(client, vecPosition, NULL_VECTOR, NULL_VECTOR);

	return true;
}

public Action Hook_GunTouch(int entity, int client)
{
	if (1 <= client <= MaxClients)
	{
		char classname[64];
		GetEntityClassname(entity, classname, sizeof(classname));

		if (StrEqual(classname, "weapon_glock"))
		{
			if (!IsValidClient(client) || !IsFakeClient(client))
			{
				SetEntProp(entity, Prop_Send, "m_bBurstMode", 1);
			}
		}
	}

	return Plugin_Continue;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (((gCV_WeaponsSpawnGood.IntValue & 2) && StrEqual(classname, "weapon_glock")))
	{
		SDKHook(entity, SDKHook_Touch, Hook_GunTouch);
	}

	if(StrEqual(classname, "trigger_multiple") || StrEqual(classname, "trigger_once") || StrEqual(classname, "trigger_push") || StrEqual(classname, "trigger_teleport") || StrEqual(classname, "trigger_gravity"))
	{
		SDKHook(entity, SDKHook_StartTouch, HookTrigger);
		SDKHook(entity, SDKHook_EndTouch, HookTrigger);
		SDKHook(entity, SDKHook_Touch, HookTrigger);
	}
}

public Action HookTrigger(int entity, int other)
{
    if(IsValidClient(other))
    {
		if(!gB_CanTouchTrigger[other] && GetEntityMoveType(other) & MOVETYPE_NOCLIP)
		{
			return Plugin_Handled;
		}
    }

    return Plugin_Continue;
}

public Action Command_Weapon(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	if(gCV_WeaponCommands.IntValue == 0)
	{
		Shavit_PrintToChat(client, "%T", "CommandDisabled", client);

		return Plugin_Handled;
	}

	if(!IsPlayerAlive(client))
	{
		Shavit_PrintToChat(client, "%T", "WeaponAlive", client);

		return Plugin_Handled;
	}

	if (GetGameTickCount() - gI_LastWeaponTick[client] < 10)
	{
		return Plugin_Handled;
	}

	gI_LastWeaponTick[client] = GetGameTickCount();

	char sCommand[16];
	GetCmdArg(0, sCommand, 16);

	int iSlot = CS_SLOT_SECONDARY;
	char sWeapon[32];

	if(StrContains(sCommand, "usp", false) != -1)
	{
		strcopy(sWeapon, 32, "weapon_usp_silencer");
	}
	else if(StrContains(sCommand, "glock", false) != -1)
	{
		strcopy(sWeapon, 32, "weapon_glock");
	}
	else
	{
		strcopy(sWeapon, 32, "weapon_knife");
		iSlot = CS_SLOT_KNIFE;
	}

	int iWeapon = GetPlayerWeaponSlot(client, iSlot);

	if(iWeapon != -1)
	{
		RemovePlayerItem(client, iWeapon);
		AcceptEntityInput(iWeapon, "Kill");
	}

	iWeapon = GivePlayerItem(client, sWeapon);
	FakeClientCommand(client, "use %s", sWeapon);

	if(iSlot != CS_SLOT_KNIFE)
	{
		SetWeaponAmmo(client, iWeapon, false);
	}

	return Plugin_Handled;
}

void SetWeaponAmmo(int client, int weapon, bool setClip1)
{
	int iAmmo = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
	SetEntProp(client, Prop_Send, "m_iAmmo", 255, 4, iAmmo);

	SetEntProp(weapon, Prop_Send, "m_iPrimaryReserveAmmoCount", 255);

	if (gCV_WeaponCommands.IntValue >= 3 && setClip1)
	{
		int amount = GetEntProp(weapon, Prop_Send, "m_iClip1") + 1;

		if (HasEntProp(weapon, Prop_Send, "m_bBurstMode") && GetEntProp(weapon, Prop_Send, "m_bBurstMode"))
		{
			amount += 2;
		}

		SetEntProp(weapon, Prop_Data, "m_iClip1", amount);
	}
}

public Action Command_Noclip(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	if (gI_LastNoclipTick[client] == GetGameTickCount())
	{
		return Plugin_Handled;
	}

	gI_LastNoclipTick[client] = GetGameTickCount();

	if(gCV_NoclipMe.IntValue == 0)
	{
		Shavit_PrintToChat(client, "%T", "FeatureDisabled", client);

		return Plugin_Handled;
	}
	else if(gCV_NoclipMe.IntValue == 2 && !CheckCommandAccess(client, "admin_noclipme", ADMFLAG_CHEATS))
	{
		Shavit_PrintToChat(client, "%T", "LackingAccess", client);

		return Plugin_Handled;
	}

	if(!IsPlayerAlive(client))
	{
		Shavit_PrintToChat(client, "%T", "CommandAlive", client);

		return Plugin_Handled;
	}

	UpdateByNoclipStatus(client, GetEntityMoveType(client) == MOVETYPE_WALK);

	return Plugin_Handled;
}

public Action CommandListener_Noclip(int client, const char[] command, int args)
{
	if(!IsValidClient(client, true))
	{
		return Plugin_Handled;
	}

	gI_LastNoclipTick[client] = GetGameTickCount();

	UpdateByNoclipStatus(client, command[0] == '+');

	return Plugin_Handled;
}

void UpdateByNoclipStatus(int client, bool walking)
{
	if(walking)
	{
		if(Shavit_GetTimerStatus(client) != Timer_Paused && !Shavit_IsPracticeMode(client))
		{
			Shavit_PauseTimer(client);
		}

		Shavit_PrintToChat(client, "%T", (gB_CanTouchTrigger[client])?"NoclipCanTrigger":"NoclipCannotTrigger", client);
		SetEntityMoveType(client, MOVETYPE_NOCLIP);
	}
	else
	{
		if(Shavit_GetTimerStatus(client) == Timer_Paused)
		{
			Shavit_PrintToChat(client, "输入{palered}%s{default}恢复计时器", Shavit_GetClientTime(client) != 0.0 ? "!pause" : "!r");
		}

		SetEntityMoveType(client, MOVETYPE_WALK);
	}
}

public Action Command_NoclipIgnoreTrigger(int client, int args)
{
	gB_CanTouchTrigger[client] = !gB_CanTouchTrigger[client];
	Shavit_PrintToChat(client, "%T", (gB_CanTouchTrigger[client])?"NoclipCanTrigger":"NoclipCannotTrigger", client);

	return Plugin_Handled;
}

public Action CommandListener_funcommands_Noclip(int client, const char[] command, int args)
{
	if (IsValidClient(client, true) && args < 1)
	{
		Command_Noclip(client, 0);
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

public Action CommandListener_Real_Noclip(int client, const char[] command, int args)
{
	if (sv_cheats.BoolValue)
	{
		if (gI_LastNoclipTick[client] == GetGameTickCount())
		{
			return Plugin_Stop;
		}

		gI_LastNoclipTick[client] = GetGameTickCount();
	}

	return Plugin_Continue;
}

public Action Command_ValidColors(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	static char sGlobalColorNames[][] =
	{
		"{default}", "{team}", "{green}"
	};

	static char sGlobalColorNamesDemo[][] =
	{
		"default", "team", "green"
	};

	static char sCSGOColorNames[][] =
	{
		"{blue}", "{bluegrey}", "{darkblue}", "{darkred}", "{gold}", "{grey}", "{grey2}", "{lightgreen}", "{lightred}", "{lime}", "{orchid}", "{yellow}", "{palered}"
	};

	static char sCSGOColorNamesDemo[][] =
	{
		"blue", "bluegrey", "darkblue", "darkred", "gold", "grey", "grey2", "lightgreen", "lightred", "lime", "orchid", "yellow", "palered"
	};

	for(int i = 0; i < sizeof(sGlobalColorNames); i++)
	{
		Shavit_PrintToChat(client, "%s%s", sGlobalColorNames[i], sGlobalColorNamesDemo[i]);
	}

	for(int i = 0; i < sizeof(sCSGOColorNames); i++)
	{
		Shavit_PrintToChat(client, "%s%s", sCSGOColorNames[i], sCSGOColorNamesDemo[i]);
	}

	return Plugin_Handled;
}

public Action Command_Specs(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	int iObserverTarget = GetSpectatorTarget(client, client);

	if(args > 0)
	{
		char sTarget[MAX_TARGET_LENGTH];
		GetCmdArgString(sTarget, MAX_TARGET_LENGTH);

		int iNewTarget = FindTarget(client, sTarget, false, false);

		if(iNewTarget == -1)
		{
			return Plugin_Handled;
		}

		if(!IsPlayerAlive(iNewTarget))
		{
			Shavit_PrintToChat(client, "%T", "SpectateDead", client);

			return Plugin_Handled;
		}

		iObserverTarget = iNewTarget;
	}

	int iCount = 0;
	bool bIsAdmin = CheckCommandAccess(client, "admin_speclisthide", ADMFLAG_KICK);
	char sSpecs[192];

	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsValidClient(i) || IsFakeClient(i) || !IsClientObserver(i) || GetClientTeam(i) < 1)
		{
			continue;
		}

		if((gCV_SpectatorList.IntValue == 1 && !bIsAdmin && CheckCommandAccess(i, "admin_speclisthide", ADMFLAG_KICK)) ||
			(gCV_SpectatorList.IntValue == 2 && !CanUserTarget(client, i)))
		{
			continue;
		}

		if(GetEntPropEnt(i, Prop_Send, "m_hObserverTarget") == iObserverTarget)
		{
			iCount++;

			if(iCount == 1)
			{
				FormatEx(sSpecs, 192, "{orchid}%N", i);
			}

			else
			{
				Format(sSpecs, 192, "%s{default}, {orchid}%N", sSpecs, i);
			}
		}
	}

	if(iCount > 0)
	{
		Shavit_PrintToChat(client, "%T", "SpectatorCount", client, iObserverTarget, iCount, sSpecs);
	}

	else
	{
		Shavit_PrintToChat(client, "%T", "SpectatorCountZero", client, iObserverTarget);
	}

	return Plugin_Handled;
}

public Action Shavit_OnStart(int client)
{
	if(GetEntityMoveType(client) == MOVETYPE_NOCLIP)
	{
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

public void Shavit_OnWorldRecord(int client, int style, float time, int jumps, int strafes, float sync, int track)
{
	char sUpperCase[64];
	strcopy(sUpperCase, 64, gS_StyleStrings[style].sStyleName);

	for(int i = 0; i < strlen(sUpperCase); i++)
	{
		if(!IsCharUpper(sUpperCase[i]))
		{
			sUpperCase[i] = CharToUpper(sUpperCase[i]);
		}
	}

	char sTrack[32];
	GetTrackName(client, track, sTrack, 32);

	for(int i = 1; i <= gCV_WRMessages.IntValue; i++)
	{
		if(track == Track_Main)
		{
			Shavit_PrintToChatAll("%t", "WRNotice", sTrack, sUpperCase);
		}
	}
}

public void Shavit_OnRestart(int client, int track)
{
	SetEntPropFloat(client, Prop_Send, "m_flStamina", 0.0);
}

public Action Shavit_OnRestartPre(int client, int track)
{
	if(gCV_RespawnOnRestart.BoolValue && !IsPlayerAlive(client))
	{
		CS_SwitchTeam(client, GetRandomInt(2, 3));

		CS_RespawnPlayer(client);

		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public Action Respawn(Handle timer, any data)
{
	int client = GetClientFromSerial(data);

	if(IsValidClient(client) && !IsPlayerAlive(client) && GetClientTeam(client) >= 2)
	{
		CS_RespawnPlayer(client);

		if(gCV_RespawnOnRestart.BoolValue)
		{
			RestartTimer(client, Track_Main);
		}
	}

	return Plugin_Handled;
}

void RestartTimer(int client, int track)
{
	if(gB_Zones && Shavit_ZoneExists(Zone_Start, track))
	{
		Shavit_RestartTimer(client, track);
	}
}

public void Player_Spawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if(!IsFakeClient(client))
	{
		if(gCV_Scoreboard.BoolValue)
		{
			UpdateScoreboard(client);
		}

		if (gCV_StartOnSpawn.BoolValue && !(gB_Checkpoints && Shavit_HasSavestate(client)))
		{
			Shavit_RestartTimer(client, Shavit_GetClientTrack(client));
		}

		UpdateClanTag(client);
	}

	if(gCV_NoBlock.BoolValue)
	{
		SetEntProp(client, Prop_Data, "m_CollisionGroup", 2);
	}

	if(gCV_PlayerOpacity.IntValue != -1)
	{
		SetEntityRenderMode(client, RENDER_TRANSCOLOR);
		SetEntityRenderColor(client, 255, 255, 255, gCV_PlayerOpacity.IntValue);
	}
}

public Action Player_Notifications(Event event, const char[] name, bool dontBroadcast)
{
	if(gCV_HideTeamChanges.BoolValue)
	{
		if (StrEqual(name, "player_team"))
		{
			event.SetBool("silent", true);
		}
		else
		{
			event.BroadcastDisabled = true;
		}
	}

	int client = GetClientOfUserId(event.GetInt("userid"));

	if(!IsFakeClient(client))
	{
		if(gCV_AutoRespawn.FloatValue > 0.0 && StrEqual(name, "player_death"))
		{
			CreateTimer(gCV_AutoRespawn.FloatValue, Respawn, GetClientSerial(client), TIMER_FLAG_NO_MAPCHANGE);
		}
	}

	if ((gCV_RemoveRagdolls.IntValue == 1 && IsFakeClient(client)) || gCV_RemoveRagdolls.IntValue == 2)
	{
		RemoveRagdoll(client);
	}

	return Plugin_Continue;
}

public void Weapon_Fire(Event event, const char[] name, bool dB)
{
	if(gCV_WeaponCommands.IntValue < 2)
	{
		return;
	}

	char sWeapon[16];
	event.GetString("weapon", sWeapon, 16);

	if(StrContains(sWeapon, "usp") != -1 || StrContains(sWeapon, "hpk") != -1 || StrContains(sWeapon, "glock") != -1)
	{
		int client = GetClientOfUserId(event.GetInt("userid"));
		SetWeaponAmmo(client, GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon"), true);
	}
}

public Action Shotgun_Shot(const char[] te_name, const int[] Players, int numClients, float delay)
{
	int client = (TE_ReadNum("m_iPlayer") + 1);

	if(!(1 <= client <= MaxClients) || !IsClientInGame(client))
	{
		return Plugin_Continue;
	}

	int ticks = GetGameTickCount();

	if(gI_LastShot[client] == ticks)
	{
		return Plugin_Continue;
	}

	gI_LastShot[client] = ticks;

	int clients[MAXPLAYERS+1];
	int count = 0;

	for(int i = 0; i < numClients; i++)
	{
		int x = Players[i];

		if (!IsClientInGame(x) || x == client)
		{
			continue;
		}

		if (!gB_Hide[x] || GetSpectatorTarget(x) == client)
		{
			clients[count++] = x;
		}
	}

	if(numClients == count)
	{
		return Plugin_Continue;
	}

	TE_Start(te_name);

	float temp[3];
	TE_ReadVector("m_vecOrigin", temp);
	TE_WriteVector("m_vecOrigin", temp);

	TE_WriteFloat("m_vecAngles[0]", TE_ReadFloat("m_vecAngles[0]"));
	TE_WriteFloat("m_vecAngles[1]", TE_ReadFloat("m_vecAngles[1]"));
	TE_WriteNum("m_iMode", TE_ReadNum("m_iMode"));
	TE_WriteNum("m_iSeed", TE_ReadNum("m_iSeed"));
	TE_WriteNum("m_iPlayer", (client - 1));

	TE_WriteNum("m_weapon", TE_ReadNum("m_weapon"));
	TE_WriteFloat("m_fInaccuracy", TE_ReadFloat("m_fInaccuracy"));
	TE_WriteFloat("m_flRecoilIndex", TE_ReadFloat("m_flRecoilIndex"));
	TE_WriteFloat("m_fSpread", TE_ReadFloat("m_fSpread"));
	TE_WriteNum("m_nItemDefIndex", TE_ReadNum("m_nItemDefIndex"));
	TE_WriteNum("m_iSoundType", TE_ReadNum("m_iSoundType"));

	TE_Send(clients, count, delay);

	return Plugin_Stop;
}

public Action EffectDispatch(const char[] te_name, const int[] Players, int numClients, float delay)
{
	if(!gCV_NoBlood.BoolValue)
	{
		return Plugin_Continue;
	}

	int iEffectIndex = TE_ReadNum("m_iEffectName");
	int nHitBox = TE_ReadNum("m_nHitBox");

	char sEffectName[32];
	GetEffectName(iEffectIndex, sEffectName, 32);

	if(StrEqual(sEffectName, "csblood"))
	{
		return Plugin_Handled;
	}

	if(StrEqual(sEffectName, "ParticleEffect"))
	{
		char sParticleEffectName[32];
		GetParticleEffectName(nHitBox, sParticleEffectName, 32);

		if(StrEqual(sParticleEffectName, "impact_helmet_headshot") || StrEqual(sParticleEffectName, "impact_physics_dust"))
		{
			return Plugin_Handled;
		}
	}

	return Plugin_Continue;
}

public Action WorldDecal(const char[] te_name, const int[] Players, int numClients, float delay)
{
	if(!gCV_NoBlood.BoolValue)
	{
		return Plugin_Continue;
	}

	float vecOrigin[3];
	TE_ReadVector("m_vecOrigin", vecOrigin);

	int nIndex = TE_ReadNum("m_nIndex");

	char sDecalName[32];
	GetDecalName(nIndex, sDecalName, 32);

	if(StrContains(sDecalName, "decals/blood") == 0 && StrContains(sDecalName, "_subrect") != -1)
	{
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public Action NormalSound(int clients[MAXPLAYERS], int &numClients, char sample[PLATFORM_MAX_PATH], int &entity, int &channel, float &volume, int &level, int &pitch, int &flags, char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
	if(!gCV_BhopSounds.BoolValue)
	{
		return Plugin_Continue;
	}

	if(StrContains(sample, "physics/") != -1 || StrContains(sample, "weapons/") != -1 || StrContains(sample, "player/") != -1 || StrContains(sample, "items/") != -1)
	{
		if(gCV_BhopSounds.IntValue == 2)
		{
			numClients = 0;
		}
		else
		{
			for(int i = 0; i < numClients; ++i)
			{
				if(!IsValidClient(clients[i]) || (clients[i] != entity && gB_Hide[clients[i]] && GetSpectatorTarget(clients[i]) != entity))
				{
					for (int j = i; j < numClients-1; j++)
					{
						clients[j] = clients[j+1];
					}
					
					numClients--;
					i--;
				}
			}
		}

		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

int GetParticleEffectName(int index, char[] sEffectName, int maxlen)
{
	static int table = INVALID_STRING_TABLE;

	if(table == INVALID_STRING_TABLE)
	{
		table = FindStringTable("ParticleEffectNames");
	}

	return ReadStringTable(table, index, sEffectName, maxlen);
}

int GetEffectName(int index, char[] sEffectName, int maxlen)
{
	static int table = INVALID_STRING_TABLE;

	if(table == INVALID_STRING_TABLE)
	{
		table = FindStringTable("EffectDispatch");
	}

	return ReadStringTable(table, index, sEffectName, maxlen);
}

int GetDecalName(int index, char[] sDecalName, int maxlen)
{
	static int table = INVALID_STRING_TABLE;

	if(table == INVALID_STRING_TABLE)
	{
		table = FindStringTable("decalprecache");
	}

	return ReadStringTable(table, index, sDecalName, maxlen);
}

public void Shavit_OnFinish(int client)
{
	if(!gCV_Scoreboard.BoolValue)
	{
		return;
	}

	UpdateScoreboard(client);
	UpdateClanTag(client);
}

public Action Command_Drop(int client, const char[] command, int argc)
{
	if(!gCV_DropAll.BoolValue || !IsValidClient(client))
	{
		return Plugin_Continue;
	}

	int iWeapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");

	if(iWeapon != -1 && IsValidEntity(iWeapon) && GetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity") == client)
	{
		CS_DropWeapon(client, iWeapon, true);
	}

	return Plugin_Handled;
}
