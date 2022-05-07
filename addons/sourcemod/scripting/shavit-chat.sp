/*
 * shavit's Timer - Chat
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

// Note: For donator perks, give donators a custom flag and then override it to have "shavit_chat".

#include <sourcemod>
#include <clientprefs>
#include <convar_class>
#include <dhooks>
#include <shavit/core>
#include <shavit/colors>
#include <shavit/chat>
#include <shavit/surftimer>

#undef REQUIRE_PLUGIN
#include <shavit/rankings>

#undef REQUIRE_EXTENSIONS
#include <cstrike>



#pragma newdecls required
#pragma semicolon 1
#pragma dynamic 131072

public Plugin myinfo =
{
	name = "[shavit] Chat Processor",
	author = "shavit",
	description = "Custom chat privileges (custom name/message colors), chat processor, and rankings integration.",
	version = SHAVIT_VERSION,
	url = "https://github.com/shavitush/bhoptimer"
}


char gS_ControlCharacters[][] = {"\x01", "\x02", "\x03", "\x04", "\x05", "\x06", "\x07", "\x08", "\x09",
	"\x0A", "\x0B", "\x0C", "\x0D", "\x0E", "\x0F", "\x10" };

// database
Database gH_SQL = null;

// modules
bool gB_Rankings = false;
bool gB_Stats = false;

// cvars
Convar gCV_RankingsIntegration = null;
Convar gCV_CustomChat = null;
Convar gCV_Colon = null;
ConVar gCV_TimeInMessages = null;

Cookie gH_ChatCookie = null;

// -2: auto-assign - user will fallback to this if they're on an index that they don't have access to.
// -1: custom ccname/ccmsg
int gI_ChatSelection[MAXPLAYERS+1];
ArrayList gA_ChatRanks = null;

bool gB_ChangedSinceLogin[MAXPLAYERS+1];

bool gB_CCAccess[MAXPLAYERS+1];

bool gB_NameEnabled[MAXPLAYERS+1];
char gS_CustomName[MAXPLAYERS+1][128];

bool gB_MessageEnabled[MAXPLAYERS+1];
char gS_CustomMessage[MAXPLAYERS+1][16];

// chat procesor
bool gB_Protobuf = false;
bool gB_NewMessage[MAXPLAYERS+1];
StringMap gSM_Messages = null;


#include "shavit-chat/db/sql.sp"
#include "shavit-chat/db/setup_database.sp"
#include "shavit-chat/db/create_tables.sp"
#include "shavit-chat/db/cache_chat.sp"

#include "shavit-chat/menu/chatranks.sp"
#include "shavit-chat/menu/ranks.sp"


#include "shavit-chat/api.sp"
#include "shavit-chat/cache.sp"
#include "shavit-chat/commands.sp"
#include "shavit-chat/cookie.sp"



// ======[ PLUGIN EVENTS ]======

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if(GetEngineVersion() != Engine_CSS)
	{
		SetFailState("This plugin only support for CSS!");
		return APLRes_Failure;
	}

	CreateNatives();

	RegPluginLibrary("shavit-chat");

	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("shavit-common.phrases");
	LoadTranslations("shavit-chat.phrases");

	CreateConVars();
	HookEvents();
	RegisterCommands();
	InitCaches();
	InitCookies();
	SQL_DBConnect();
	ForceAllClientsCached();

	gB_Protobuf = (GetUserMessageType() == UM_Protobuf);
}

public void OnLibraryAdded(const char[] name)
{
	if(StrEqual(name, "shavit-rankings"))
	{
		gB_Rankings = true;
	}

	else if(StrEqual(name, "shavit-stats"))
	{
		gB_Stats = true;
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if(StrEqual(name, "shavit-rankings"))
	{
		gB_Rankings = false;
	}

	else if(StrEqual(name, "shavit-stats"))
	{
		gB_Stats = false;
	}
}

public void OnAllPluginsLoaded()
{
	gCV_TimeInMessages = FindConVar("shavit_core_timeinmessages");
}

public void OnMapStart()
{
	if(!LoadChatConfig())
	{
		SetFailState("Could not load the chat configuration file. Make sure it exists (addons/sourcemod/configs/shavit-chat.cfg) and follows the proper syntax!");
	}

	if(!LoadEngineChatSettings())
	{
		SetFailState("Could not load the chat settings file. Make sure it exists (addons/sourcemod/configs/shavit-chatsettings.cfg) and follows the proper syntax!");
	}
}

public void OnClientCookiesCached(int client)
{
	char sChatSettings[8];
	gH_ChatCookie.Get(client, sChatSettings, sizeof(sChatSettings));

	if(strlen(sChatSettings) == 0)
	{
		gH_ChatCookie.Set(client, "-2");
		gI_ChatSelection[client] = -2;
	}
	else
	{
		gI_ChatSelection[client] = StringToInt(sChatSettings);
	}
}

public void OnClientPutInServer(int client)
{
	gB_CCAccess[client] = false;

	gB_NameEnabled[client] = true;
	strcopy(gS_CustomName[client], 128, "{team}{name}");

	gB_MessageEnabled[client] = true;
	strcopy(gS_CustomMessage[client], 128, "{default}");
}

public void OnClientDisconnect(int client)
{
	if(HasCustomChat(client))
	{
		DB_SaveChatSettings(client);
	}
}

public void OnClientPostAdminCheck(int client)
{
	if (gH_SQL)
	{
		DB_LoadChatSettings(client);
	}
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
	if(1 <= client <= MaxClients)
	{
		gB_NewMessage[client] = true;
	}

	return Plugin_Continue;
}

public Action Hook_SayText2(UserMsg msg_id, any msg, const int[] players, int playersNum, bool reliable, bool init)
{
	int client = 0;
	char sMessage[32];
	char sOriginalName[MAXLENGTH_NAME];
	char sOriginalText[MAXLENGTH_TEXT];

	if(gB_Protobuf)
	{
		Protobuf pbmsg = UserMessageToProtobuf(msg);
		client = pbmsg.ReadInt("ent_idx");
		pbmsg.ReadString("msg_name", sMessage, 32);
		pbmsg.ReadString("params", sOriginalName, MAXLENGTH_NAME, 0);
		pbmsg.ReadString("params", sOriginalText, MAXLENGTH_TEXT, 1);
	}

	else
	{
		BfRead bfmsg = UserMessageToBfRead(msg);
		client = bfmsg.ReadByte();
		bfmsg.ReadByte(); // chat parameter
		bfmsg.ReadString(sMessage, 32);
		bfmsg.ReadString(sOriginalName, MAXLENGTH_NAME);
		bfmsg.ReadString(sOriginalText, MAXLENGTH_TEXT);
	}

	if(client == 0)
	{
		return Plugin_Continue;
	}

	if(!gB_NewMessage[client])
	{
		return Plugin_Stop;
	}

	gB_NewMessage[client] = false;

	char sTextFormatting[MAXLENGTH_BUFFER];

	// not a hooked message
	if(!gSM_Messages.GetString(sMessage, sTextFormatting, MAXLENGTH_BUFFER))
	{
		return Plugin_Continue;
	}

	char sTime[50];

	if (gCV_TimeInMessages.BoolValue)
	{
		FormatTime(sTime, sizeof(sTime), "%H:%M:%S ");
	}

	Format(sTextFormatting, MAXLENGTH_BUFFER, "\x01%s%s", sTime, sTextFormatting);

	// remove control characters
	for(int i = 0; i < sizeof(gS_ControlCharacters); i++)
	{
		ReplaceString(sOriginalName, MAXLENGTH_NAME, gS_ControlCharacters[i], "");
		ReplaceString(sOriginalText, MAXLENGTH_TEXT, gS_ControlCharacters[i], "");
	}

	// fix an exploit that breaks chat colors in cs:s
	while(ReplaceString(sOriginalText, MAXLENGTH_TEXT, "   ", " ") > 0) { }

	char sName[MAXLENGTH_NAME];
	char sCMessage[MAXLENGTH_CMESSAGE];

	if(HasCustomChat(client) && gI_ChatSelection[client] == -1)
	{
		if(gB_NameEnabled[client])
		{
			strcopy(sName, MAXLENGTH_NAME, gS_CustomName[client]);
		}

		if(gB_MessageEnabled[client])
		{
			strcopy(sCMessage, MAXLENGTH_CMESSAGE, gS_CustomMessage[client]);
		}
	}

	else
	{
		GetPlayerChatSettings(client, sName, sCMessage);
	}

	if(strlen(sName) > 0)
	{
		FormatChat(client, sName, MAXLENGTH_NAME);
		strcopy(sOriginalName, MAXLENGTH_NAME, sName);
	}

	if(strlen(sMessage) > 0)
	{
		FormatChat(client, sCMessage, MAXLENGTH_CMESSAGE);

		Format(sOriginalText, MAXLENGTH_MESSAGE, "%s%s", sCMessage, sOriginalText);
	}

	char sColon[MAXLENGTH_CMESSAGE];
	gCV_Colon.GetString(sColon, MAXLENGTH_CMESSAGE);

	ReplaceFormats(sTextFormatting, MAXLENGTH_BUFFER, sName, sColon, sOriginalText);

	DataPack pack = new DataPack();
	pack.WriteCell(GetClientSerial(client)); // client serial
	pack.WriteCell(StrContains(sMessage, "_All") != -1); // all chat
	pack.WriteString(sTextFormatting); // text
	RequestFrame(Frame_SendText, pack);

	return Plugin_Stop;
}

public void Frame_SendText(DataPack pack)
{
	pack.Reset();
	int serial = pack.ReadCell();
	bool allchat = pack.ReadCell();
	char sText[MAXLENGTH_BUFFER];
	pack.ReadString(sText, MAXLENGTH_BUFFER);
	delete pack;

	int client = GetClientFromSerial(serial);

	if(client == 0)
	{
		return;
	}

	int team = GetClientTeam(client);
	int clients[MAXPLAYERS+1];
	int count = 0;

	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsClientConnected(i))
		{
			continue;
		}

		if(IsClientSourceTV(i) || IsClientReplay(i) || // sourcetv?
			(IsClientInGame(i) && (allchat || GetClientTeam(i) == team)))
		{
			clients[count++] = i;
		}
	}

	// should never happen
	if(count == 0)
	{
		return;
	}

	Handle hSayText2 = StartMessage("SayText2", clients, count, USERMSG_RELIABLE|USERMSG_BLOCKHOOKS);

	if(hSayText2 == null)
	{
		return;
	}

	if(gB_Protobuf)
	{
		// show colors in cs:go
		Format(sText, MAXLENGTH_BUFFER, " %s", sText);

		Protobuf pbmsg = UserMessageToProtobuf(hSayText2);
		pbmsg.SetInt("ent_idx", client);
		pbmsg.SetBool("chat", true);
		pbmsg.SetString("msg_name", sText);

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
		bfmsg.WriteByte(true);
		bfmsg.WriteString(sText);
	}

	EndMessage();
}



// ======[ PUBLIC ]======

stock bool LoadChatConfig()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, PLATFORM_MAX_PATH, "configs/shavit-chat.cfg");

	KeyValues kv = new KeyValues("shavit-chat");

	if(!kv.ImportFromFile(sPath) || !kv.GotoFirstSubKey())
	{
		delete kv;

		return false;
	}

	gA_ChatRanks.Clear();

	do
	{
		chatranks_cache_t chat_title;
		char sRanks[32];
		kv.GetString("ranks", sRanks, 32, "0");

		if(sRanks[0] == 'p')
		{	
			chat_title.iRequire = Require_Points;
		}
		else if(sRanks[0] == 'w')
		{
			chat_title.iRequire = Require_WR_Count;
		}
		else if(sRanks[0] == 'W')
		{
			chat_title.iRequire = Require_WR_Rank;
		}
		else
		{
			chat_title.iRequire = Require_Rank;
		}

		chat_title.bPercent = (StrContains(sRanks, "%") != -1);

		ReplaceString(sRanks, 32, "w", "");
		ReplaceString(sRanks, 32, "W", "");
		ReplaceString(sRanks, 32, "p", "");
		ReplaceString(sRanks, 32, "%%", "");

		if(StrContains(sRanks, "-") != -1)
		{
			char sExplodedString[2][16];
			ExplodeString(sRanks, "-", sExplodedString, 2, 64);
			chat_title.fFrom = StringToFloat(sExplodedString[0]);
			chat_title.fTo = StringToFloat(sExplodedString[1]);
			chat_title.bRanged = true;
		}
		else
		{
			float fRank = StringToFloat(sRanks);

			chat_title.fFrom = fRank;

			if (chat_title.iRequire == Require_WR_Count || chat_title.iRequire == Require_Points)
			{
				chat_title.fTo = MAGIC_NUMBER;
			}
			else
			{
				chat_title.fTo = fRank;
			}
		}

		if(chat_title.bPercent)
		{
			if(chat_title.iRequire == Require_WR_Count)
			{
				LogError("shavit chatranks can't use WR count & percentage in the same tag");
				continue;
			}
			else if(chat_title.iRequire == Require_Points)
			{
				LogError("shavit chatranks can't use points & percentage in the same tag");
				continue;
			}
		}

		chat_title.bFree = view_as<bool>(kv.GetNum("free", false));
		chat_title.bEasterEgg = view_as<bool>(kv.GetNum("easteregg", false));

		kv.GetString("name", chat_title.sName, MAXLENGTH_NAME, "{name}");
		kv.GetString("message", chat_title.sMessage, MAXLENGTH_MESSAGE, "");
		kv.GetString("display", chat_title.sDisplay, MAXLENGTH_DISPLAY, "");
		kv.GetString("flag", chat_title.sAdminFlag, 32, "");

		if(strlen(chat_title.sDisplay) > 0)
		{
			gA_ChatRanks.PushArray(chat_title);
		}
	}
	while(kv.GotoNextKey());

	delete kv;

	return true;
}

stock bool LoadEngineChatSettings()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, PLATFORM_MAX_PATH, "configs/shavit-chatsettings.cfg");

	KeyValues kv = new KeyValues("shavit-chat");

	if(!kv.ImportFromFile(sPath))
	{
		delete kv;

		return false;
	}

	gSM_Messages.Clear();

	bool failed = !kv.JumpToKey("CS:S");

	if(failed || !kv.GotoFirstSubKey(false))
	{
		SetFailState("Invalid \"configs/shavit-chatsettings.cfg\" file, or the game section is missing");
	}

	do
	{
		char sSection[32];
		kv.GetSectionName(sSection, 32);

		char sText[MAXLENGTH_BUFFER];
		kv.GetString(NULL_STRING, sText, MAXLENGTH_BUFFER);

		gSM_Messages.SetString(sSection, sText);
	}

	while(kv.GotoNextKey(false));

	delete kv;

	return true;
}

// ======[ PRIVATE ]======

static void CreateConVars()
{
	gCV_RankingsIntegration = new Convar("shavit_chat_rankings", "1", "Integrate with rankings?\n0 - Disabled\n1 - Enabled", 0, true, 0.0, true, 1.0);
	gCV_CustomChat = new Convar("shavit_chat_customchat", "1", "Allow custom chat names or message colors?\n0 - Disabled\n1 - Enabled (requires chat flag/'shavit_chat' override or granted access with sm_ccadd)\n2 - Allow use by everyone", 0, true, 0.0, true, 2.0);
	gCV_Colon = new Convar("shavit_chat_colon", ":", "String to use as the colon when messaging.");

	Convar.AutoExecConfig();
}

static void HookEvents()
{
	HookUserMessage(GetUserMessageId("SayText2"), Hook_SayText2, true);
}

static void ForceAllClientsCached()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i))
		{
			if(AreClientCookiesCached(i))
			{
				OnClientCookiesCached(i);
			}
		}
	}
}