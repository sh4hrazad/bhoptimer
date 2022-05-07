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
#include <shavit/core>
#include <shavit/zones>
#include <shavit/colors>
#include <shavit/surftimer>

#undef REQUIRE_PLUGIN
#include <shavit/rankings>

#pragma newdecls required
#pragma semicolon 1

#define CHANGE_FLAGS(%1,%2) (%1 = (%2))
#define EFL_CHECK_UNTOUCH (1<<24)

public Plugin myinfo =
{
	name = "[shavit] Core",
	author = "shavit",
	description = "The core for shavit's bhop timer.",
	version = SHAVIT_VERSION,
	url = "https://github.com/shavitush/bhoptimer"
}

// game type (CS:GO)
bool gB_Protobuf = false;

// player timer variables
timer_snapshot_t gA_Timers[MAXPLAYERS+1];
bool gB_Auto[MAXPLAYERS+1];

// used for offsets
float gF_SmallestDist[MAXPLAYERS + 1];
float gF_Origin[MAXPLAYERS + 1][2][3];
float gF_Fraction[MAXPLAYERS + 1];

// cookies
Handle gH_StyleCookie = null;
Handle gH_AutoBhopCookie = null;

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

// timer settings
bool gB_Registered = false;
int gI_Styles = 0;
int gI_OrderedStyles[STYLE_LIMIT];
StringMap gSM_StyleKeys[STYLE_LIMIT];
int gI_CurrentParserIndex = 0;

// chat settings
chatstrings_t gS_ChatStrings;

// misc cache
char gS_LogPath[PLATFORM_MAX_PATH];
char gS_DeleteMap[MAXPLAYERS+1][PLATFORM_MAX_PATH];
int gI_WipePlayerID[MAXPLAYERS+1];
char gS_Verification[MAXPLAYERS+1][8];
bool gB_CookiesRetrieved[MAXPLAYERS+1];

#include "shavit-core/timer.sp"
#include "shavit-core/player.sp"
#include "shavit-core/styles.sp"
#include "shavit-core/database.sp"
#include "shavit-core/commands.sp"
#include "shavit-core/dhook.sp"
#include "shavit-core/menus.sp"

#include "shavit-core/api/forwards.sp"
#include "shavit-core/api/natives.sp"

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNatives();

	// registers library, check "bool LibraryExists(const char[] name)" in order to use with other plugins
	RegPluginLibrary("shavit");

	gB_Late = late;

	return APLRes_Success;
}

public void OnPluginStart()
{
	if(GetEngineVersion() != Engine_CSS)
	{
		SetFailState("This plugin only support for CSS!");
		return;
	}

	CreateForwards();

	LoadTranslations("shavit-core.phrases");
	LoadTranslations("shavit-common.phrases");

	gB_Protobuf = (GetUserMessageType() == UM_Protobuf);

	LoadDHooks();

	HookPlayerEvents();

	RegisterCommands();

	gH_StyleCookie = RegClientCookie("shavit_style", "Style cookie", CookieAccess_Protected);
	gH_AutoBhopCookie = RegClientCookie("shavit_autobhop", "Autobhop cookie", CookieAccess_Protected);

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

public Action Shavit_OnStartPre(int client, int track)
{
	if (GetTimerStatus(client) == Timer_Paused && gCV_PauseMovement.BoolValue)
	{
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

public void OnClientDisconnect(int client)
{
	gA_HookedPlayer[client].Remove();
	RequestFrame(StopTimer, client);
}

public void OnClientCookiesCached(int client)
{
	if(IsFakeClient(client) || !IsClientInGame(client))
	{
		return;
	}

	char sCookie[4];

	if(gH_AutoBhopCookie != null)
	{
		GetClientCookie(client, gH_AutoBhopCookie, sCookie, 4);
	}

	gB_Auto[client] = (strlen(sCookie) > 0)? view_as<bool>(StringToInt(sCookie)):true;

	int style = gI_DefaultStyle;

	if(gB_StyleCookies && gH_StyleCookie != null)
	{
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
		gA_HookedPlayer[client].Add(client);
	}

	gB_Auto[client] = true;
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

	OnClientPutInServer_UpdateClientData(client);
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

	kv.JumpToKey("CS:S");

	kv.GetString("prefix", gS_ChatStrings.sPrefix, sizeof(chatstrings_t::sPrefix), "\x07ff6a6a[Timer]");
	kv.GetString("text", gS_ChatStrings.sText, sizeof(chatstrings_t::sText), "\x07ffffff");
	kv.GetString("warning", gS_ChatStrings.sWarning, sizeof(chatstrings_t::sWarning), "\x07af2a22");
	kv.GetString("team", gS_ChatStrings.sTeam, sizeof(chatstrings_t::sTeam), "\x07276f5c");
	kv.GetString("style", gS_ChatStrings.sStyle, sizeof(chatstrings_t::sStyle), "\x07db88c2");
	kv.GetString("good", gS_ChatStrings.sGood, sizeof(chatstrings_t::sGood), "\x0799ff99");
	kv.GetString("bad", gS_ChatStrings.sBad, sizeof(chatstrings_t::sBad), "\x07ff4040");

	delete kv;

	ReplaceColors(gS_ChatStrings.sPrefix, sizeof(chatstrings_t::sPrefix));
	ReplaceColors(gS_ChatStrings.sText, sizeof(chatstrings_t::sText));
	ReplaceColors(gS_ChatStrings.sWarning, sizeof(chatstrings_t::sWarning));
	ReplaceColors(gS_ChatStrings.sTeam, sizeof(chatstrings_t::sTeam));
	ReplaceColors(gS_ChatStrings.sStyle, sizeof(chatstrings_t::sStyle));
	ReplaceColors(gS_ChatStrings.sGood, sizeof(chatstrings_t::sGood));
	ReplaceColors(gS_ChatStrings.sBad, sizeof(chatstrings_t::sBad));

	Call_OnChatConfigLoaded();

	return true;
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

	Call_OnTimeOffsetCalculated(client, zonetype, offset, gF_SmallestDist[client]);

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