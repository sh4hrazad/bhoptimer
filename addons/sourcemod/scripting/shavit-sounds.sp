/*
 * shavit's Timer - Sounds
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
#include <convar_class>
#include <dhooks>
#include <shavit>
#include <shavit/sounds>
#include <shavit/wr>



#pragma newdecls required
#pragma semicolon 1



public Plugin myinfo =
{
	name = "[shavit] Sounds",
	author = "shavit",
	description = "Play custom sounds when timer-related events happen.",
	version = SHAVIT_VERSION,
	url = "https://github.com/shavitush/bhoptimer"
}

// cvars
Convar gCV_MinimumWorst = null;
Convar gCV_Enabled = null;

// module
bool gB_HUD = false;



#include "shavit-sounds/api.sp"
#include "shavit-sounds/sounds.sp"



// ======[ PLUGIN EVENTS ]======

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("shavit-sounds");

	return APLRes_Success;
}

public void OnAllPluginsLoaded()
{
	if(!LibraryExists("shavit-wr"))
	{
		SetFailState("shavit-wr is required for the plugin to work.");
	}
}

public void OnPluginStart()
{
	OnPluginStart_InitSoundsCache();
	CreateGlobalForwards();
	CreateConVars();

	// modules
	gB_HUD = LibraryExists("shavit-hud");
}

public void OnLibraryAdded(const char[] name)
{
	if(StrEqual(name, "shavit-hud"))
	{
		gB_HUD = true;
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if(StrEqual(name, "shavit-hud"))
	{
		gB_HUD = false;
	}
}

public void OnMapStart()
{
	OnMapStart_ClearSoundsCache();
	OnMapStart_LoadSounds();
}

public void Shavit_OnFinish(int client, int style, float time, int jumps, int strafes, float sync, int track, float& oldtime)
{
	if(!gCV_Enabled.BoolValue)
	{
		return;
	}

	Shavit_OnFinish_PlaySounds(client, time, track, oldtime);
}

public void Shavit_OnFinish_Post(int client, int style, float time, int jumps, int strafes, float sync, int rank, int overwrite, int track)
{
	if(!gCV_Enabled.BoolValue || track != Track_Main)
	{
		return;
	}

	Shavit_OnFinish_Post_PlaySounds(client, style, time, rank, overwrite, track);
}

public void Shavit_OnWorstRecord(int client, int style, float time, int jumps, int strafes, float sync, int track)
{
	if(!gCV_Enabled.BoolValue)
	{
		return;
	}

	Shavit_OnWorstRecord_PlaySounds(client, style, track);
}

public void Shavit_OnWRCP(int client, int stage, int style, int steamid, int records, float oldtime, float time, float leavespeed, const char[] mapname)
{
	if(!gCV_Enabled.BoolValue)
	{
		return;
	}

	Shavit_OnWRCP_PlaySounds(client);
}



// ======[ PRIVATE ]======
static void CreateConVars()
{
	gCV_MinimumWorst = new Convar("shavit_sounds_minimumworst", "10", "Minimum amount of records to be saved for a \"worst\" sound to play.", 0, true, 1.0);
	gCV_Enabled = new Convar("shavit_sounds_enabled", "1", "Enables/Disables functionality of the plugin", 0, true, 0.0, true, 1.0);

	Convar.AutoExecConfig();
}