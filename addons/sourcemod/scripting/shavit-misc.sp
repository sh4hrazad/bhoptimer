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
#include <shavit>
#include <shavit/misc>
#include <shavit/wr>
#include <shavit/replay-playback>

#undef REQUIRE_EXTENSIONS
#include <SteamWorks>
#include <cstrike>



#pragma newdecls required
#pragma semicolon 1



public Plugin myinfo =
{
	name = "[shavit] Miscellaneous",
	author = "shavit",
	description = "Miscellaneous features for shavit's bhop timer.",
	version = SHAVIT_VERSION,
	url = "https://github.com/shavitush/bhoptimer"
}

bool gB_Hide[MAXPLAYERS+1];
bool gB_Late = false;
char gS_Map[PLATFORM_MAX_PATH];

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

// dhooks
DynamicHook gH_GetPlayerMaxSpeed = null;
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



#include "shavit-misc/api.sp"
#include "shavit-misc/commands.sp"
#include "shavit-misc/cookies.sp"

#include "shavit-misc/misc/advertisement.sp"
#include "shavit-misc/misc/chatcolors.sp"
#include "shavit-misc/misc/clearweapons.sp"
#include "shavit-misc/misc/dropweapon.sp"
#include "shavit-misc/misc/fixduck.sp"
#include "shavit-misc/misc/fixspawnpoint.sp"
#include "shavit-misc/misc/giveweapons.sp"
#include "shavit-misc/misc/hide.sp"
#include "shavit-misc/misc/mapfixes.sp"
#include "shavit-misc/misc/movement.sp"
#include "shavit-misc/misc/noclip.sp"
#include "shavit-misc/misc/nodmg.sp"
#include "shavit-misc/misc/radio.sp"
#include "shavit-misc/misc/ragdoll.sp"
#include "shavit-misc/misc/scoreboard.sp"
#include "shavit-misc/misc/sendwrmessage.sp"
#include "shavit-misc/misc/sounds.sp"
#include "shavit-misc/misc/spec.sp"
#include "shavit-misc/misc/teleport.sp"
#include "shavit-misc/misc/tempentity.sp"



// ======[ PLUGIN EVENTS ]======

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

	LoadTranslations("common.phrases");
	LoadTranslations("shavit-common.phrases");
	LoadTranslations("shavit-misc.phrases");

	CreateGlobalForwards();
	CreateConVars();
	RegisterCommands();
	AddCommandListeners();

	RegisterCookies();

	HookEvents();
	HookTEs();
	HookSounds();

	OnPluginStart_InitAdvs();

	// crons
	CreateTimer(10.0, Timer_Cron, 0, TIMER_REPEAT);
	CreateTimer(1.0, Timer_Scoreboard, 0, TIMER_REPEAT);

	LoadDHooks();
	UnlockMovement();

	// modules
	gB_Checkpoints = LibraryExists("shavit-checkpoints");
	gB_Rankings = LibraryExists("shavit-rankings");
	gB_Replay = LibraryExists("shavit-replay-playback");
	gB_Zones = LibraryExists("shavit-zones");
	gB_Chat = LibraryExists("shavit-chat");
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

public MRESReturn Hook_IsSpawnPointValid(DHookReturn hReturn, DHookParam hParams)
{
	if (gCV_NoBlock.BoolValue)
	{
		hReturn.Value = true;
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

public void Shavit_OnStyleConfigLoaded(int styles)
{
	for(int i = 0; i < styles; i++)
	{
		Shavit_GetStyleStringsStruct(i, gS_StyleStrings[i]);
	}
}

public void Shavit_OnChatConfigLoaded()
{
	Shavit_OnChatConfigLoaded_LoadAdvs();
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
		OnMapStart_CacheCookies();
	}
}

public void OnAutoConfigsBuffered()
{
	OnAutoConfigsBuffered_LoadMapFixes();
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

	OnConfigsExecuted_FixSpawnPoints();
	OnConfigsExecuted_ShowAdvs();
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
	else if(StrEqual(name, "shavit-replay-playback"))
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
	else if(StrEqual(name, "shavit-replay-playback"))
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
	Timer_ClearWeapons();

	return Plugin_Continue;
}

public Action Shavit_OnUserCmdPre(int client, int &buttons, int &impulse, float vel[3], float angles[3], TimerStatus status, int track, int style)
{
	Shavit_OnUserCmdPre_FixDuck(client, buttons);

	if(GetEntityMoveType(client) == MOVETYPE_NOCLIP && status == Timer_Running)
	{
		Shavit_StopTimer(client);
	}

	return Plugin_Continue;
}

public void OnClientPutInServer(int client)
{
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
		gH_GetPlayerMaxSpeed.HookEntity(Hook_Post, client, CCSPlayer__GetPlayerMaxSpeed);
	}

	OnClientPutInServer_HookWeaponDrop(client);
	OnClientPutInServer_HookDamage(client);
	OnClientPutInServer_Hide(client);

	OnClientPutInServer_InitWeapon(client);
	OnClientPutInServer_InitNoclip(client);
}

public void OnClientDisconnect(int client)
{
	OnClientDisconnect_ClearWeapons(client);
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
	OnEntityCreated_HookTrigger(entity, classname);
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
	Shavit_OnWorldRecord_SendWRMessage(client, style, track);
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

public void Player_Spawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if(!IsFakeClient(client))
	{
		OnPlayerSpawn_UpdateScoreBoard(client);

		if (gCV_StartOnSpawn.BoolValue && !(gB_Checkpoints && Shavit_HasSavestate(client)))
		{
			Shavit_RestartTimer(client, Shavit_GetClientTrack(client));
		}
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

	RemoveRagdoll(client);

	return Plugin_Continue;
}

public void Shavit_OnFinish(int client)
{
	Shavit_OnFinish_UpdateScoreboard(client);
}



// ======[ PRIVATE ]======

static void CreateConVars()
{
	sv_cheats = FindConVar("sv_cheats");
	sv_disable_immunity_alpha = FindConVar("sv_disable_immunity_alpha");
	sv_disable_radar = FindConVar("sv_disable_radar");
	mp_humanteam = FindConVar("mp_humanteam");

	// advertisements
	hostname = FindConVar("hostname");
	hostport = FindConVar("hostport");

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
}

static void HookEvents()
{
	HookEvent("player_spawn", Player_Spawn);
	HookEvent("player_team", Player_Notifications, EventHookMode_Pre);
	HookEvent("player_death", Player_Notifications, EventHookMode_Pre);
	HookEventEx("weapon_fire", Weapon_Fire);
	HookEventEx("weapon_fire_on_empty", Weapon_Fire);
	HookEventEx("weapon_reload", Weapon_Fire);
}

static void LoadDHooks()
{
	GameData hGameData = new GameData("shavit.games");

	if (hGameData == null)
	{
		SetFailState("Failed to load shavit gamedata");
		delete hGameData;
	}

	int iOffset;

	if ((iOffset = hGameData.GetOffset("CCSPlayer::GetPlayerMaxSpeed")) != -1)
	{
		gH_GetPlayerMaxSpeed = new DynamicHook(iOffset, HookType_Entity, ReturnType_Float, ThisPointer_CBaseEntity);
	}
	else
	{
		SetFailState("Couldn't get the offset for \"CCSPlayer::GetPlayerMaxSpeed\" - make sure your gamedata is updated!");
	}

	if ((iOffset = hGameData.GetOffset("CBasePlayer::UpdateStepSound")) != -1)
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

	if ((iOffset = hGameData.GetOffset("CGameRules::IsSpawnPointValid")) != -1)
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

static void RestartTimer(int client, int track)
{
	if(gB_Zones && Shavit_ZoneExists(Zone_Start, track))
	{
		Shavit_RestartTimer(client, track);
	}
}