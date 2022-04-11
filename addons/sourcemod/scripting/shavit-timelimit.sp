/*
 * shavit's Timer - Dynamic Timelimits
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

// original idea from ckSurf.

#include <sourcemod>
#include <convar_class>
#include <dhooks>
#include <shavit>
#include <shavit/timelimit>
#include <shavit/wr>



#undef REQUIRE_EXTENSIONS
#include <cstrike>

#pragma newdecls required
#pragma semicolon 1



public Plugin myinfo =
{
	name = "[shavit] Dynamic Timelimits",
	author = "shavit",
	description = "Sets a dynamic value of mp_timelimit and mp_roundtime, based on average map times on the server.",
	version = SHAVIT_VERSION,
	url = "https://github.com/shavitush/bhoptimer"
}



// database handle
Database2 gH_SQL = null;

// base cvars
ConVar mp_do_warmup_period = null;
ConVar mp_freezetime = null;
ConVar mp_ignore_round_win_conditions = null;
ConVar mp_timelimit = null;
ConVar mp_roundtime = null;

// cvars
Convar gCV_Config = null;
Convar gCV_DefaultLimit = null;
Convar gCV_DynamicTimelimits = null;
Convar gCV_MinimumLimit = null;
Convar gCV_MaximumLimit = null;
Convar gCV_ForceMapEnd = null;
Convar gCV_MinimumTimes = null;
Convar gCV_PlayerAmount = null;
Convar gCV_Style = null;
Convar gCV_GameStartFix = null;
Convar gCV_InstantMapChange = null;
Convar gCV_Enabled = null;
Convar gCV_HideCvarChanges = null;
Convar gCV_Hide321CountDown = null;

// misc cache
bool gB_BlockRoundEndEvent = false;
bool gB_AlternateZeroPrint = false;
Handle gH_Timer = null;



#include "shavit-timelimit/api.sp"
#include "shavit-timelimit/timelimit.sp"
#include "shavit-timelimit/sql.sp"



// ======[ PLUGIN EVETNS ]======

public void OnPluginStart()
{
	if(GetEngineVersion() != Engine_CSS)
	{
		SetFailState("This plugin only support for CSS!");
		return;
	}

	LoadTranslations("shavit-common.phrases");

	CreateGlobalForwards();
	CreateConVars();
	HookEvents();
	SQL_DBConnect();
}

public void OnMapStart()
{
	gB_BlockRoundEndEvent = false;
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if(view_as<bool>(StringToInt(newValue)))
	{
		delete gH_Timer;
		gH_Timer = CreateTimer(1.0, Timer_PrintToChat, 0, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}

	else
	{
		delete gH_Timer;
	}
}

public Action Hook_ServerCvar(Event event, const char[] name, bool dontBroadcast)
{
	if (gCV_HideCvarChanges.BoolValue)
	{
		char cvarname[32];
		GetEventString(event, "cvarname", cvarname, sizeof(cvarname));

		if (StrEqual(cvarname, "mp_timelimit", true) || StrEqual(cvarname, "mp_roundtime", true))
		{
			event.BroadcastDisabled = true;
			return Plugin_Changed;
		}
	}

	return Plugin_Continue;
}

public void OnConfigsExecuted()
{
	OnConfigsExecuted_Timelimit();
}

public Action Timer_PrintToChat(Handle timer)
{
	return Timer_PrintToChat_Timelimit();
}

public Action Timer_ChangeMap(Handle timer, any data)
{
	char map[PLATFORM_MAX_PATH];

	if (GetNextMap(map, sizeof(map)))
	{
		ForceChangeLevel(map, "bhoptimer instant map change after timelimit");
	}

	return Plugin_Stop;
}

public Action CS_OnTerminateRound(float &fDelay, CSRoundEndReason &iReason)
{
	if(gCV_Enabled.BoolValue && gCV_GameStartFix.BoolValue && iReason == CSRoundEnd_GameStart)
	{
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public Action round_end(Event event, const char[] name, bool dontBroadcast)
{
	if (gB_BlockRoundEndEvent)
	{
		event.BroadcastDisabled = true; // stop the "Event.RoundDraw" sound from playing client-side
		return Plugin_Changed;
	}

	return Plugin_Continue;
}



// ======[ PUBLIC ]======

void SetLimit(int time)
{
	mp_timelimit.IntValue = time;

	if(mp_roundtime != null)
	{
		mp_roundtime.IntValue = time;
	}
}



// ======[ PRIVATE ]======

static void CreateConVars()
{
	mp_do_warmup_period = FindConVar("mp_do_warmup_period");
	mp_freezetime = FindConVar("mp_freezetime");
	mp_ignore_round_win_conditions = FindConVar("mp_ignore_round_win_conditions");
	mp_timelimit = FindConVar("mp_timelimit");
	mp_roundtime = FindConVar("mp_roundtime");

	if(mp_roundtime != null)
	{
		mp_roundtime.SetBounds(ConVarBound_Upper, false);
	}

	gCV_Config = new Convar("shavit_timelimit_config", "1", "Enables the following game settings:\n\"mp_do_warmup_period\" \"0\"\n\"mp_freezetime\" \"0\"\n\"mp_ignore_round_win_conditions\" \"1\"", 0, true, 0.0, true, 1.0);
	gCV_DefaultLimit = new Convar("shavit_timelimit_default", "60.0", "Default timelimit to use in case there isn't an average.", 0);
	gCV_DynamicTimelimits = new Convar("shavit_timelimit_dynamic", "0", "Use dynamic timelimits.\n0 - Disabled\n1 - Enabled", 0, true, 0.0, true, 1.0);
	gCV_MinimumLimit = new Convar("shavit_timelimit_minimum", "20.0", "Minimum timelimit to use.\nREQUIRES \"shavit_timelimit_dynamic\" TO BE ENABLED!", 0);
	gCV_MaximumLimit = new Convar("shavit_timelimit_maximum", "120.0", "Maximum timelimit to use.\nREQUIRES \"shavit_timelimit_dynamic\" TO BE ENABLED!\n0 - No maximum", 0);
	gCV_ForceMapEnd = new Convar("shavit_timelimit_forcemapend", "1", "Force the map to end after the timelimit.\n0 - Disabled\n1 - Enabled", 0, true, 0.0, true, 1.0);
	gCV_MinimumTimes = new Convar("shavit_timelimit_minimumtimes", "5", "Minimum amount of times required to calculate an average.\nREQUIRES \"shavit_timelimit_dynamic\" TO BE ENABLED!", 0, true, 1.0);
	gCV_PlayerAmount = new Convar("shavit_timelimit_playertime", "25", "Limited amount of times to grab from the database to calculate an average.\nREQUIRES \"shavit_timelimit_dynamic\" TO BE ENABLED!\nSet to 0 to have it \"unlimited\".", 0);
	gCV_Style = new Convar("shavit_timelimit_style", "1", "If set to 1, calculate an average only from times that the first (default: forwards) style was used to set.\nREQUIRES \"shavit_timelimit_dynamic\" TO BE ENABLED!", 0, true, 0.0, true, 1.0);
	gCV_GameStartFix = new Convar("shavit_timelimit_gamestartfix", "1", "If set to 1, will block the round from ending because another player joined. Useful for single round servers.", 0, true, 0.0, true, 1.0);
	gCV_Enabled = new Convar("shavit_timelimit_enabled", "1", "Enables/Disables functionality of the plugin.", 0, true, 0.0, true, 1.0);
	gCV_InstantMapChange = new Convar("shavit_timelimit_instantmapchange", "1", "If set to 1 then it will changelevel to the next map after the countdown. Requires the 'nextmap' to be set.", 0, true, 0.0, true, 1.0);
	gCV_HideCvarChanges = new Convar("shavit_timelimit_hidecvarchange", "0", "Whether to hide changes to mp_timelimit & mp_roundtime from chat.", 0, true, 0.0, true, 1.0);
	gCV_Hide321CountDown = new Convar("shavit_timelimt_hide321countdown", "0", "Whether to hide 3.. 2.. 1.. countdown messages.", 0, true, 0.0, true, 1.0);

	gCV_ForceMapEnd.AddChangeHook(OnConVarChanged);
	gCV_Enabled.AddChangeHook(OnConVarChanged);

	Convar.AutoExecConfig();
}

static void HookEvents()
{
	HookEventEx("server_cvar", Hook_ServerCvar, EventHookMode_Pre);
	HookEvent("round_end", round_end, EventHookMode_Pre);
}