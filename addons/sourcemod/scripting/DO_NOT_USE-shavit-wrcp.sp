/**
 * shavit's Timer (sfork) - WRCP
 * by: Shahrazad
 *
 * note: After finishing the plugin, I may merge these to those existing .sp files.
 *
 * This file is part of shavit's Timer (sfork).
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
#include <clientprefs>
#include <convar_class>
#include <dhooks>

#include <shavit/core>
#include <shavit/zones>
#include <shavit/wr>

#undef REQUIRE_PLUGIN
#include <shavit/rankings>

#undef REQUIRE_EXTENSIONS
#include <cstrike>

#pragma newdecls required
#pragma semicolon 1

bool gB_Late = false;
stylestrings_t gS_StyleStrings[STYLE_LIMIT];
chatstrings_t gS_ChatStrings;

public Plugin myinfo =
{
	name = "[shavit] WRCP",
	author = "Shahrazad",
	description = "",
	version = SHAVIT_VERSION ... "-sfork",
	url = "https://github.com/sh4hrazad/bhoptimer/tree/shahrazad-fork-rolling"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("shavit-wrcp");

	gB_Late = late;

	return APLRes_Success;
}

public void OnPluginStart()
{
        // TODO: cvars, translations, commands, cookies

        if (gB_Late)
	{
		Shavit_OnDatabaseLoaded();
	}
}

public void Shavit_OnChatConfigLoaded()
{
	Shavit_GetChatStringsStruct(gS_ChatStrings);
}

public void OnLibraryAdded(const char[] name)

public void OnLibraryRemoved(const char[] name)