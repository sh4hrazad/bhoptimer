#include <sourcemod>
#include <convar_class>
#include <sdktools>

#undef REQUIRE_PLUGIN
#include <shavit>
#include <shavit/rankings>
#include <mapchooser> // for MapChange type

#undef REQUIRE_EXTENSIONS
#include <cstrike>

#pragma semicolon 1
#pragma newdecls required

bool gB_Late = false;

char gS_SQLPrefix[32];
Database2 gH_SQL = null;

float gF_LastRtvTime[MAXPLAYERS+1];
float gF_LastNominateTime[MAXPLAYERS+1];

int gI_ExcludePrefixesCount;
char gS_ExcludePrefixesBuffers[128][12];

int gI_AutocompletePrefixesCount;
char gS_AutocompletePrefixesBuffers[128][12];

// Map arrays
ArrayList gA_MapList;
ArrayList gA_NominateList;
ArrayList gA_AllMapsList;
ArrayList gA_OldMaps;

StringMap gSM_MapList;

// Map Data
char gS_MapName[PLATFORM_MAX_PATH];

MapChange g_ChangeTime;

bool gB_MapVoteStarted;
bool gB_MapVoteFinished;
float gF_MapStartTime;
float gF_LastMapvoteTime = 0.0;

int gI_ExtendCount;
int gI_MapFileSerial = -1;

Menu gH_NominateMenu;
Menu gH_EnhancedMenu;

Menu gH_TierMenus[10+1];
bool gB_WaitingForTiers = false;
bool gB_TiersAssigned = false;

Menu gH_VoteMenu;

// Player Data
bool gB_RockTheVote[MAXPLAYERS + 1];
char gS_NominatedMap[MAXPLAYERS + 1][PLATFORM_MAX_PATH];
float gF_SpecTimerStart[MAXPLAYERS+1];

float gF_VoteDelayTime = 1.75;
bool gB_VoteDelayed[MAXPLAYERS+1];

// ConVars
Convar gCV_RTVRequiredPercentage;
Convar gCV_RTVAllowSpectators;
Convar gCV_RTVSpectatorCooldown;
Convar gCV_RTVMinimumPoints;
Convar gCV_RTVDelayTime;
Convar gCV_NominateDelayTime;
Convar gCV_HideRTVChat;
Convar gCV_MapListType;
Convar gCV_MatchFuzzyMap;
Convar gCV_HijackMap;
Convar gCV_ExcludePrefixes;
Convar gCV_AutocompletePrefixes;
Convar gCV_MapVoteStartTime;
Convar gCV_MapVoteDuration;
Convar gCV_MapVoteBlockMapInterval;
Convar gCV_MapVoteExtendLimit;
Convar gCV_MapVoteEnableNoVote;
Convar gCV_MapVoteExtendTime;
Convar gCV_MapVoteShowTier;
Convar gCV_MapVoteRunOff;
Convar gCV_MapVoteRunOffPerc;
Convar gCV_MapVoteRevoteTime;
Convar gCV_DoNominateMatches;
Convar gCV_EnhancedMenu;
Convar gCV_AntiSpam;

// custom cvars
ConVar gCV_MinTier;
ConVar gCV_MaxTier;

// Timer
Handle gH_RetryTimer = null;

// Forwards
Handle gH_Forward_OnRTV = null;
Handle gH_Forward_OnUnRTV = null;
Handle gH_Forward_OnSuccesfulRTV = null;

// Modules
bool gB_Rankings = false;

enum
{
	MapListZoned,
	MapListFile,
	MapListFolder,
	MapListMixed,
	MapListZonedMixedWithFolder,
}

public Plugin myinfo =
{
	name = "[shavit] MapChooser",
	author = "SlidyBat, kidfearless, mbhound, lilac, rtldg",
	description = "Automated Map Voting and nominating with Shavit's bhoptimer integration",
	version = SHAVIT_VERSION,
	url = "https://github.com/shavitush/bhoptimer"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	gH_Forward_OnRTV = CreateGlobalForward("Shavit_OnRTV", ET_Event, Param_Cell);
	gH_Forward_OnUnRTV = CreateGlobalForward("Shavit_OnUnRTV", ET_Event, Param_Cell);
	gH_Forward_OnSuccesfulRTV = CreateGlobalForward("Shavit_OnSuccesfulRTV", ET_Event);

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

	LoadTranslations("shavit-mapchooser.phrases");

	gA_MapList = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
	gA_AllMapsList = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
	gA_NominateList = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
	gA_OldMaps = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));

	gSM_MapList = new StringMap();

	gCV_MapListType = new Convar("shavit_mapchooser_maplist_type", "2", "Where the plugin should get the map list from.\n0 - zoned maps from database\n1 - from maplist file (mapcycle.txt)\n2 - from maps folder\n3 - from zoned maps and confirmed by maplist file\n4 - from zoned maps and confirmed by maps folder", _, true, 0.0, true, 4.0);
	gCV_MatchFuzzyMap = new Convar("shavit_mapchooser_match_fuzzy", "1", "If set to 1, the plugin will accept partial map matches from the database. Useful for workshop maps, bad for duplicate map names", _, true, 0.0, true, 1.0);
	gCV_HijackMap = new Convar("shavit_mapchooser_hijack_sm_map_so_its_faster", "1", "Hijacks sourcemod's built-in sm_map command so it's faster.", 0, true, 0.0, true, 1.0);
	gCV_ExcludePrefixes = new Convar("shavit_mapchooser_exclude_prefixes", "de_,cs_,as_,ar_,dz_,gd_,lobby_,training1,mg_,gg_,jb_,coop_,aim_,awp_,cp_,ctf_,fy_,dm_,hg_,rp_,ze_,zm_,arena_,pl_,plr_,mvm_,db_,trade_,ba_,mge_,ttt_,ph_,hns_,", "Exclude maps based on these prefixes.\nA good reference: https://developer.valvesoftware.com/wiki/Map_prefixes");
	gCV_AutocompletePrefixes = new Convar("shavit_mapchooser_autocomplete_prefixes", "bhop_,surf_,kz_,kz_bhop_,bhop_kz_,xc_,trikz_,jump_,rj_", "Some prefixes that are attempted when using !map");

	gCV_MapVoteBlockMapInterval = new Convar("shavit_mapchooser_mapvote_blockmap_interval", "1", "How many maps should be played before a map can be nominated again", _, true, 0.0, false);
	gCV_MapVoteEnableNoVote = new Convar("shavit_mapchooser_mapvote_enable_novote", "1", "Whether players are able to choose 'No Vote' in map vote", _, true, 0.0, true, 1.0);
	gCV_MapVoteExtendLimit = new Convar("shavit_mapchooser_mapvote_extend_limit", "3", "How many times players can choose to extend a single map (0 = block extending, -1 = infinite extending)", _, true, -1.0, false);
	gCV_MapVoteExtendTime = new Convar("shavit_mapchooser_mapvote_extend_time", "10", "How many minutes should the map be extended by if the map is extended through a mapvote", _, true, 1.0, false);
	gCV_MapVoteShowTier = new Convar("shavit_mapchooser_mapvote_show_tier", "1", "Whether the map tier should be displayed in the map vote", _, true, 0.0, true, 1.0);
	gCV_MapVoteDuration = new Convar("shavit_mapchooser_mapvote_duration", "1", "Duration of time in minutes that map vote menu should be displayed for", _, true, 0.1, false);
	gCV_MapVoteStartTime = new Convar("shavit_mapchooser_mapvote_start_time", "5", "Time in minutes before map end that map vote starts", _, true, 1.0, false);

	gCV_RTVAllowSpectators = new Convar("shavit_mapchooser_rtv_allow_spectators", "1", "Whether spectators should be allowed to RTV", _, true, 0.0, true, 1.0);
	gCV_RTVSpectatorCooldown = new Convar("shavit_mapchooser_rtv_spectator_cooldown", "60", "When `shavit_mapchooser_rtv_allow_spectators` is `0`, wait this many seconds before removing a spectator's RTV", 0, true, 0.0);
	gCV_RTVMinimumPoints = new Convar("shavit_mapchooser_rtv_minimum_points", "-1", "Minimum number of points a player must have before being able to RTV, or -1 to allow everyone", _, true, -1.0, false);
	gCV_RTVDelayTime = new Convar("shavit_mapchooser_rtv_delay", "0", "Time in minutes after map start before players should be allowed to RTV", _, true, 0.0, false);
	gCV_NominateDelayTime = new Convar("shavit_mapchooser_nominate_delay", "0", "Time in minutes after map start before players should be allowed to nominate", _, true, 0.0, false);
	gCV_RTVRequiredPercentage = new Convar("shavit_mapchooser_rtv_required_percentage", "50", "Percentage of players who have RTVed before a map vote is initiated", _, true, 1.0, true, 100.0);
	gCV_HideRTVChat = new Convar("shavit_mapchooser_hide_rtv_chat", "1", "Whether to hide 'rtv', 'rockthevote', 'unrtv', 'nextmap', and 'nominate' from chat.");

	gCV_MapVoteRunOff = new Convar("shavit_mapchooser_mapvote_runoff", "1", "Hold run of votes if winning choice is less than a certain margin", _, true, 0.0, true, 1.0);
	gCV_MapVoteRunOffPerc = new Convar("shavit_mapchooser_mapvote_runoffpercent", "50", "If winning choice has less than this percent of votes, hold a runoff", _, true, 0.0, true, 100.0);
	gCV_MapVoteRevoteTime = new Convar("shavit_mapchooser_mapvote_revotetime", "0", "How many minutes after a failed mapvote before rtv is enabled again", _, true, 0.0);

	gCV_DoNominateMatches = new Convar("shavit_mapchooser_nominate_matches", "1", "Prompts a menu which shows all maps which match argument",  _, true, 0.0, true, 1.0);
	gCV_EnhancedMenu = new Convar("shavit_mapchooser_enhanced_menu", "1", "Nominate menu can show maps by alphabetic order and tiers",  _, true, 0.0, true, 1.0);

	gCV_AntiSpam = new Convar("shavit_mapchooser_anti_spam", "15.0", "The number of seconds a player needs to wait before rtv/unrtv/nominate/unnominate.", 0, true, 0.0, true, 300.0);

	Convar.AutoExecConfig();

	gCV_MinTier = CreateConVar("shavit_mapchooser_min_tier", "0", "The minimum tier to show on the enhanced menu",  _, true, 0.0, true, 10.0);
	gCV_MaxTier = CreateConVar("shavit_mapchooser_max_tier", "10", "The maximum tier to show on the enhanced menu",  _, true, 0.0, true, 10.0);


	RegAdminCmd("sm_extend", Command_Extend, ADMFLAG_CHANGEMAP, "Admin command for extending map");
	RegAdminCmd("sm_extendmap", Command_Extend, ADMFLAG_CHANGEMAP, "Admin command for extending map");
	RegAdminCmd("sm_forcemapvote", Command_ForceMapVote, ADMFLAG_CHANGEMAP, "Admin command for forcing the end of map vote");
	RegAdminCmd("sm_reloadmaplist", Command_ReloadMaplist, ADMFLAG_CHANGEMAP, "Admin command for forcing maplist to be reloaded");
	RegAdminCmd("sm_reloadmap", Command_ReloadMap, ADMFLAG_CHANGEMAP, "Admin command for reloading current map");
	RegAdminCmd("sm_restartmap", Command_ReloadMap, ADMFLAG_CHANGEMAP, "Admin command for reloading current map");

	RegAdminCmd("sm_loadunzonedmap", Command_LoadUnzonedMap, ADMFLAG_ROOT, "Loads the next map from the maps folder that is unzoned.");

	RegConsoleCmd("sm_nominate", Command_Nominate, "Lets players nominate maps to be on the end of map vote");
	RegConsoleCmd("sm_unnominate", Command_UnNominate, "Removes nominations");
	RegConsoleCmd("sm_rtv", Command_RockTheVote, "Lets players Rock The Vote");
	RegConsoleCmd("sm_unrtv", Command_UnRockTheVote, "Lets players un-Rock The Vote");
	RegConsoleCmd("sm_nomlist", Command_NomList, "Shows currently nominated maps");

	AddCommandListener(Command_MapButFaster, "sm_map");

	gB_Rankings = LibraryExists("shavit-rankings");

	SQL_DBConnect();

	if (gB_Late)
	{
		if (gB_Rankings)
		{
			gB_TiersAssigned = true;
		}
	}
}

public void OnLibraryAdded(const char[] name)
{
	if(StrEqual(name, "shavit-rankings"))
	{
		gB_Rankings = true;
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if(StrEqual(name, "shavit-rankings"))
	{
		gB_Rankings = false;
	}
}

public void OnMapStart()
{
	GetCurrentMap(gS_MapName, sizeof(gS_MapName));

	SetNextMap(gS_MapName);

	// disable rtv if delay time is > 0
	gF_MapStartTime = GetEngineTime();
	gF_LastMapvoteTime = 0.0;

	gI_ExtendCount = 0;

	gB_MapVoteFinished = false;
	gB_MapVoteStarted = false;

	gA_NominateList.Clear();

	for(int i = 1; i <= MaxClients; ++i)
	{
		gS_NominatedMap[i][0] = '\0';
	}

	ClearRTV();

	CreateTimer(0.5, Timer_SpecCooldown, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(2.0, Timer_OnMapTimeLeftChanged, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

void ResetMaplistByTiers()
{
	if(gB_Rankings)
	{
		int min = gCV_MinTier.IntValue;
		int max = gCV_MaxTier.IntValue;

		if (max < min)
		{
			int temp = max;
			max = min;
			min = temp;
			gCV_MinTier.IntValue = min;
			gCV_MaxTier.IntValue = max;
		}

		StringMap tiersMap = Shavit_GetMapTiers();

		for(int i = 0; i < gA_MapList.Length; i++)
		{
			char mapname[PLATFORM_MAX_PATH];
			gA_MapList.GetString(i, mapname, sizeof(mapname));

			int tier = 0;
			tiersMap.GetValue(mapname, tier);

			if(tier == 0)
			{
				// continue
			}

			else if(tier < min || tier > max)
			{
				gA_MapList.Erase(i);
				i--;
			}
		}

		delete tiersMap;
	}
}

public void OnConfigsExecuted()
{
	// reload maplist array
	// cache the nominate menu so that it isn't being built every time player opens it
	LoadMapList();

	// reset the maplist for tiers distinguishing server
	ResetMaplistByTiers();
}

public void OnAllPluginsLoaded()
{
	// reset the maplist for tiers distinguishing server
	ResetMaplistByTiers();
}

public void OnMapEnd()
{
	if(gCV_MapVoteBlockMapInterval.IntValue > 0)
	{
		gA_OldMaps.PushString(gS_MapName);
		if(gA_OldMaps.Length > gCV_MapVoteBlockMapInterval.IntValue)
		{
			gA_OldMaps.Erase(0);
		}
	}

	gI_ExtendCount = 0;
	gB_WaitingForTiers = false;
	gB_TiersAssigned = false;

	gB_MapVoteFinished = false;
	gB_MapVoteStarted = false;

	gA_NominateList.Clear();
	for(int i = 1; i <= MaxClients; i++)
	{
		gS_NominatedMap[i][0] = '\0';
	}

	ClearRTV();
}

public void Shavit_OnTierAssigned(const char[] map, int tier)
{
	gB_TiersAssigned = true;

	if (gB_WaitingForTiers)
	{
		gB_WaitingForTiers = false;
		RequestFrame(CreateNominateMenu);
	}
}

int ExplodeCvar(ConVar cvar, char[][] buffers, int maxStrings, int maxStringLength)
{
	char cvarstring[2048];
	cvar.GetString(cvarstring, sizeof(cvarstring));
	LowercaseString(cvarstring);

	while (ReplaceString(cvarstring, sizeof(cvarstring), ",,", ",", true)) {}

	int count = ExplodeString(cvarstring, ",", buffers, maxStrings, maxStringLength);

	for (int i = 0; i < count; i++)
	{
		TrimString(buffers[i]);

		if (buffers[i][0] == 0)
		{
			strcopy(buffers[i], maxStringLength, buffers[--count]);
		}
	}

	return count;
}

public Action Timer_SpecCooldown(Handle timer)
{
	if (gCV_RTVAllowSpectators.BoolValue)
	{
		return Plugin_Continue;
	}

	float cooldown = gCV_RTVSpectatorCooldown.FloatValue;
	float now = GetEngineTime();

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientConnected(i) || !IsClientInGame(i) || GetClientTeam(i) > CS_TEAM_SPECTATOR)
		{
			gF_SpecTimerStart[i] = 0.0;
			continue;
		}

		if (!gF_SpecTimerStart[i])
		{
			gF_SpecTimerStart[i] = now;
		}

		if (gB_RockTheVote[i] && (now - gF_SpecTimerStart[i]) >= cooldown)
		{
			UnRTVClient(i);
			int needed = CheckRTV();

			if(needed > 0)
			{
				Shavit_PrintToChatAll("%t", "UnRTVNeeds", i, needed);
			}
		}
	}

	return Plugin_Continue;
}

public Action Timer_OnMapTimeLeftChanged(Handle Timer)
{
	int timeleft;
	if(GetMapTimeLeft(timeleft))
	{
		if(!gB_MapVoteStarted && !gB_MapVoteFinished)
		{
			int mapvoteTime = timeleft - RoundFloat(gCV_MapVoteStartTime.FloatValue * 60.0) + 3;
			switch(mapvoteTime)
			{
				case (10 * 60), (5 * 60):
				{
					Shavit_PrintToChatAll("%t", "Minutes Until Map Vote", mapvoteTime/60);
				}
				case (10 * 60) - 3:
				{
					Shavit_PrintToChatAll("%t", "Minutes Until Map Vote", 10);
				}
				case 60, 30, 5:
				{
					Shavit_PrintToChatAll("%t", "Seconds Until Map Vote", mapvoteTime);
				}
			}
		}
	}

	if(gA_MapList.Length && !gB_MapVoteStarted && !gB_MapVoteFinished)
	{
		CheckTimeLeft();
	}

	return Plugin_Continue;
}

void CheckTimeLeft()
{
	int timeleft;
	if(GetMapTimeLeft(timeleft) && timeleft > 0)
	{
		int startTime = RoundFloat(gCV_MapVoteStartTime.FloatValue * 60.0);

		if(timeleft - startTime <= 0)
		{
			InitiateMapVote(MapChange_MapEnd);
		}
	}
}

public void OnClientConnected(int client)
{
	gF_LastRtvTime[client] = 0.0;
	gF_LastNominateTime[client] = 0.0;
	gF_SpecTimerStart[client] = 0.0;
	gB_VoteDelayed[client] = false;
}

public void OnClientDisconnect(int client)
{
	// clear player data
	gB_RockTheVote[client] = false;
	gS_NominatedMap[client][0] = '\0';

	CheckRTV();
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
	if (!gCV_HideRTVChat.BoolValue)
	{
		return Plugin_Continue;
	}

	if (StrEqual(sArgs, "rtv", false) || StrEqual(sArgs, "rockthevote", false) || StrEqual(sArgs, "unrtv", false) || StrEqual(sArgs, "unnominate", false) || StrContains(sArgs, "nominate", false) == 0 || StrEqual(sArgs, "nextmap", false) || StrEqual(sArgs, "timeleft", false))
	{
		return Plugin_Handled; // block chat but still do _Post
	}

	return Plugin_Continue;
}

public void OnClientSayCommand_Post(int client, const char[] command, const char[] sArgs)
{
	if(StrEqual(sArgs, "rtv", false) || StrEqual(sArgs, "rockthevote", false))
	{
		ReplySource old = SetCmdReplySource(SM_REPLY_TO_CHAT);

		Command_RockTheVote(client, 0);

		SetCmdReplySource(old);
	}
	else if (StrEqual(sArgs, "unnominate", false))
	{
		ReplySource old = SetCmdReplySource(SM_REPLY_TO_CHAT);

		Command_UnNominate(client, 0);

		SetCmdReplySource(old);
	}
	else if (StrContains(sArgs, "nominate", false) == 0)
	{
		ReplySource old = SetCmdReplySource(SM_REPLY_TO_CHAT);

		char mapname[PLATFORM_MAX_PATH];
		BreakString(sArgs[strlen("nominate")], mapname, sizeof(mapname));
		TrimString(mapname);

		if (mapname[0] != 0)
		{
			Command_Nominate_Internal(client, mapname);
		}
		else
		{
			Command_Nominate(client, 0);
		}

		SetCmdReplySource(old);
	}
	else if (StrEqual(sArgs, "unrtv", false))
	{
		ReplySource old = SetCmdReplySource(SM_REPLY_TO_CHAT);

		Command_UnRockTheVote(client, 0);

		SetCmdReplySource(old);
	}
}

void InitiateMapVote(MapChange when)
{
	g_ChangeTime = when;
	gB_MapVoteStarted = true;

	if (IsVoteInProgress())
	{
		// Can't start a vote, try again in 5 seconds.
		//g_RetryTimer = CreateTimer(5.0, Timer_StartMapVote, _, TIMER_FLAG_NO_MAPCHANGE);

		DataPack data;
		gH_RetryTimer = CreateDataTimer(5.0, Timer_StartMapVote, data, TIMER_FLAG_NO_MAPCHANGE);
		data.WriteCell(when);
		data.Reset();
		return;
	}

	// create menu
	Menu menu = new Menu(Handler_MapVoteMenu, MENU_ACTIONS_ALL);
	menu.VoteResultCallback = Handler_MapVoteFinished;
	menu.Pagination = MENU_NO_PAGINATION;
	menu.SetTitle("Vote Nextmap");

	int maxPageItems = 8;
	int mapsToAdd = maxPageItems;
	int mapsAdded = 0;

	bool add_extend = (gCV_MapVoteExtendLimit.IntValue == -1) || (gCV_MapVoteExtendLimit.IntValue > 0 && gI_ExtendCount < gCV_MapVoteExtendLimit.IntValue);

	if (add_extend)
	{
		mapsToAdd--;
	}

	if(gCV_MapVoteEnableNoVote.BoolValue)
	{
		mapsToAdd--;
		maxPageItems--;
	}

	char map[PLATFORM_MAX_PATH];
	char mapdisplay[PLATFORM_MAX_PATH + 32];

	StringMap tiersMap = gB_Rankings ? Shavit_GetMapTiers() : new StringMap();

	int nominateMapsToAdd = (mapsToAdd > gA_NominateList.Length) ? gA_NominateList.Length : mapsToAdd;
	for(int i = 0; i < nominateMapsToAdd; i++)
	{
		gA_NominateList.GetString(i, map, sizeof(map));
		GetMapDisplayName(map, mapdisplay, sizeof(mapdisplay));

		if(gCV_MapVoteShowTier.BoolValue)
		{
			int tier = 0;
			tiersMap.GetValue(mapdisplay, tier);
			Format(mapdisplay, sizeof(mapdisplay), "[T%i] %s", tier, mapdisplay);
		}
		else
		{
			strcopy(mapdisplay, sizeof(mapdisplay), map);
		}

		menu.AddItem(map, mapdisplay);
		mapsAdded += 1;
		mapsToAdd--;
	}

	if (gA_MapList.Length < mapsToAdd)
	{
		mapsToAdd = gA_MapList.Length;
	}

	ArrayList used_indices = new ArrayList();

	for(int i = 0; i < mapsToAdd; i++)
	{
		int rand;
		bool duplicate = true;

		for (int x = 0; x < 10; x++) // let's not infinite loop
		{
			rand = GetRandomInt(0, gA_MapList.Length - 1);

			if (used_indices.FindValue(rand) == -1)
			{
				duplicate = false;
				break;
			}
		}

		if (duplicate)
		{
			continue; // unlucky or out of maps
		}

		used_indices.Push(rand);

		gA_MapList.GetString(rand, map, sizeof(map));
		LessStupidGetMapDisplayName(map, mapdisplay, sizeof(mapdisplay));

		if (StrEqual(map, gS_MapName) || gA_OldMaps.FindString(map) != -1)
		{
			// don't add current map or recently played
			i--;
			continue;
		}

		if(gCV_MapVoteShowTier.BoolValue)
		{
			int tier = 0;
			tiersMap.GetValue(mapdisplay, tier);

			Format(mapdisplay, sizeof(mapdisplay), "[T%i] %s", tier, mapdisplay);
		}

		mapsAdded += 1;
		menu.AddItem(map, mapdisplay);
	}

	delete used_indices;
	delete tiersMap;

	if ((when == MapChange_MapEnd && add_extend) || (when == MapChange_Instant))
	{
		for (int i = 0; i < (maxPageItems-mapsAdded-1); i++)
		{
			menu.AddItem("", "");
		}
	}

	if ((when == MapChange_MapEnd && add_extend))
	{
		menu.AddItem("extend", "Extend Current Map");
	}
	else if (when == MapChange_Instant)
	{
		menu.AddItem("dontchange", "Don't Change");
	}

	Shavit_PrintToChatAll("%t", "Nextmap Voting Started");

	for (int i = 1; i <= MaxClients; i++)
	{
		gB_VoteDelayed[i] = (IsClientInGame(i) && !IsFakeClient(i) && GetClientMenu(i) != MenuSource_None);

		if (gB_VoteDelayed[i])
		{
			Shavit_PrintToChat(i, "%T", "VoteDelay", i, gF_VoteDelayTime);
		}
	}

	CreateTimer(gF_VoteDelayTime+0.1, Timer_VoteDelay, 0, TIMER_FLAG_NO_MAPCHANGE);

	menu.NoVoteButton = gCV_MapVoteEnableNoVote.BoolValue;
	menu.ExitButton = false;
	menu.DisplayVoteToAll(RoundFloat(gCV_MapVoteDuration.FloatValue * 60.0));
}

public Action Timer_VoteDelay(Handle timer, any data)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (gB_VoteDelayed[i])
		{
			gB_VoteDelayed[i] = false;

			if (IsClientInGame(i))
			{
				RedrawClientVoteMenu(i);
			}
		}
	}

	return Plugin_Stop;
}

public void Handler_MapVoteFinished(Menu menu, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	if (gCV_MapVoteRunOff.BoolValue && num_items > 1)
	{
		float winningvotes = float(item_info[0][VOTEINFO_ITEM_VOTES]);
		float required = num_votes * (gCV_MapVoteRunOffPerc.FloatValue / 100.0);

		if (winningvotes < required)
		{
			/* Insufficient Winning margin - Lets do a runoff */
			gH_VoteMenu = new Menu(Handler_MapVoteMenu, MENU_ACTIONS_ALL);
			gH_VoteMenu.SetTitle("Runoff Vote Nextmap");
			gH_VoteMenu.VoteResultCallback = Handler_VoteFinishedGeneric;

			char map[PLATFORM_MAX_PATH];
			char info1[PLATFORM_MAX_PATH];
			char info2[PLATFORM_MAX_PATH];

			menu.GetItem(item_info[0][VOTEINFO_ITEM_INDEX], map, sizeof(map), _, info1, sizeof(info1));
			gH_VoteMenu.AddItem(map, info1);
			menu.GetItem(item_info[1][VOTEINFO_ITEM_INDEX], map, sizeof(map), _, info2, sizeof(info2));
			gH_VoteMenu.AddItem(map, info2);

			gH_VoteMenu.ExitButton = true;
			gH_VoteMenu.DisplayVoteToAll(RoundFloat(gCV_MapVoteDuration.FloatValue * 60.0));

			/* Notify */
			float map1percent = float(item_info[0][VOTEINFO_ITEM_VOTES])/ float(num_votes) * 100;
			float map2percent = float(item_info[1][VOTEINFO_ITEM_VOTES])/ float(num_votes) * 100;


			Shavit_PrintToChatAll("%t", "Starting Runoff", gCV_MapVoteRunOffPerc.FloatValue, info1, map1percent, info2, map2percent);
			LogMessage("Voting for next map was indecisive, beginning runoff vote");

			return;
		}
	}

	Handler_VoteFinishedGeneric(menu, num_votes, num_clients, client_info, num_items, item_info);
}

public Action Timer_StartMapVote(Handle timer, DataPack data)
{
	if (timer == gH_RetryTimer)
	{
		gH_RetryTimer = null;
	}

	if (!gA_MapList.Length || gB_MapVoteFinished || gB_MapVoteStarted)
	{
		return Plugin_Stop;
	}

	MapChange when = view_as<MapChange>(data.ReadCell());

	InitiateMapVote(when);

	return Plugin_Stop;
}

public void Handler_VoteFinishedGeneric(Menu menu, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	char map[PLATFORM_MAX_PATH];
	char displayName[PLATFORM_MAX_PATH];

	menu.GetItem(item_info[0][VOTEINFO_ITEM_INDEX], map, sizeof(map), _, displayName, sizeof(displayName));

	if(StrEqual(map, "extend"))
	{
		gI_ExtendCount++;

		int time;
		if(GetMapTimeLimit(time))
		{
			if(time > 0)
			{
				ExtendMapTimeLimit(gCV_MapVoteExtendTime.IntValue * 60);
			}
		}

		Shavit_PrintToChatAll("%t", "Current Map Extended", RoundToFloor(float(item_info[0][VOTEINFO_ITEM_VOTES])/float(num_votes)*100), num_votes);
		LogAction(-1, -1, "Voting for next map has finished. The current map has been extended.");

		// We extended, so we'll have to vote again.
		gB_MapVoteStarted = false;
		gF_LastMapvoteTime = GetEngineTime();

		ClearRTV();
	}
	else if(StrEqual(map, "dontchange"))
	{
		Shavit_PrintToChatAll("%t", "Current Map Stays", RoundToFloor(float(item_info[0][VOTEINFO_ITEM_VOTES])/float(num_votes)*100), num_votes);
		LogAction(-1, -1, "Voting for next map has finished. 'No Change' was the winner");

		gB_MapVoteFinished = false;
		gB_MapVoteStarted = false;
		gF_LastMapvoteTime = GetEngineTime();

		ClearRTV();
	}
	else
	{
		if(g_ChangeTime == MapChange_MapEnd)
		{
			SetNextMap(map);
		}
		else if(g_ChangeTime == MapChange_Instant)
		{
			int needed, rtvcount, total;
			GetRTVStuff(total, needed, rtvcount);

			if(needed <= 0)
			{
				Call_StartForward(gH_Forward_OnSuccesfulRTV);
				Call_Finish();
			}

			DataPack data = new DataPack();
			CreateDataTimer(1.0, Timer_ChangeMap, data);
			data.WriteString(map);
			data.WriteString("RTV Mapvote");
			ClearRTV();
		}

		gB_MapVoteStarted = false;
		gB_MapVoteFinished = true;

		Shavit_PrintToChatAll("%t", "Nextmap Voting Finished", displayName, RoundToFloor(float(item_info[0][VOTEINFO_ITEM_VOTES])/float(num_votes)*100), num_votes);
		LogAction(-1, -1, "Voting for next map has finished. Nextmap: %s.", map);
	}
}

public int Handler_MapVoteMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_DrawItem:
		{
			if (gB_VoteDelayed[param1])
			{
				return ITEMDRAW_DISABLED;
			}

			char map[PLATFORM_MAX_PATH];
			menu.GetItem(param2, map, sizeof(map));

			if (map[0] == 0)
			{
				return ITEMDRAW_DISABLED;
			}
		}

		case MenuAction_Cancel: // comes up for novote
		{
			if (gB_VoteDelayed[param1])
			{
				gB_VoteDelayed[param1] = false;
				RedrawClientVoteMenu(param1);
				return 0;
			}
		}

		case MenuAction_End:
		{
			delete menu;
		}

		case MenuAction_Display:
		{
			Panel panel = view_as<Panel>(param2);
			panel.SetTitle("Vote Nextmap");
		}

		case MenuAction_DisplayItem:
		{
			if (menu.ItemCount - 1 == param2)
			{
				char map[PLATFORM_MAX_PATH], buffer[255];
				menu.GetItem(param2, map, sizeof(map));
	
				if (strcmp(map, "extend", false) == 0)
				{
					FormatEx(buffer, sizeof(buffer), "%T", "Extend Map", param1);
					return RedrawMenuItem(buffer);
				}
				else if (strcmp(map, "novote", false) == 0)
				{
					FormatEx(buffer, sizeof(buffer), "%T", "No Vote", param1);
					return RedrawMenuItem(buffer);
				}
				else if (strcmp(map, "dontchange", false) == 0)
				{
					FormatEx(buffer, sizeof(buffer), "%T", "Dont Change", param1);
					return RedrawMenuItem(buffer);
				}
			}
		}

		case MenuAction_VoteCancel:
		{
			// If we receive 0 votes, pick at random.
			if(param1 == VoteCancel_NoVotes)
			{
				int count = menu.ItemCount;
				char map[PLATFORM_MAX_PATH];
				menu.GetItem(0, map, sizeof(map));

				// Make sure the first map in the menu isn't one of the special items.
				// This would mean there are no real maps in the menu, because the special items are added after all maps. Don't do anything if that's the case.
				if(strcmp(map, "extend", false) != 0 && strcmp(map, "dontchange", false) != 0)
				{
					// Get a random map from the list.

					// Make sure it's not one of the special items.
					do
					{
						int item = GetRandomInt(0, count - 1);
						menu.GetItem(item, map, sizeof(map));
					}
					while(strcmp(map, "extend", false) == 0 || strcmp(map, "dontchange", false) == 0);

					SetNextMap(map);
					Shavit_PrintToChatAll("%t", "Nextmap Voting Finished", map, 0, 0);
					LogAction(-1, -1, "Voting for next map has finished. Nextmap: %s.", map);
					gB_MapVoteFinished = true;
					ClearRTV();
				}
			}
			else
			{
				// We were actually cancelled. I guess we do nothing.
			}

			gB_MapVoteStarted = false;
		}
	}

	return 0;
}

// extends map while also notifying players and setting plugin data
void ExtendMap(int client, int time)
{
	if(time == 0)
	{
		time = RoundFloat(gCV_MapVoteExtendTime.FloatValue * 60);
	}

	ExtendMapTimeLimit(time);
	Shavit_PrintToChatAll("%t", "AdminExtendMap", client, time / 60);
}

void SQL_DBConnect()
{
	GetTimerSQLPrefix(gS_SQLPrefix, sizeof(gS_SQLPrefix));
	gH_SQL = GetTimerDatabaseHandle2(false);
}

void RemoveExcludesFromArrayList(ArrayList list, bool lowercase, char[][] exclude_prefixes, int exclude_count)
{
	int length = list.Length;

	for (int i = 0; i < length; i++)
	{
		char buffer[PLATFORM_MAX_PATH];
		list.GetString(i, buffer, sizeof(buffer));

		for (int x = 0; x < exclude_count; x++)
		{
			if (strncmp(buffer, exclude_prefixes[x], strlen(exclude_prefixes[x]), lowercase) == 0)
			{
				list.SwapAt(i, --length);
				break;
			}
		}
	}

	list.Resize(length);
}

void LoadMapList()
{
	gA_MapList.Clear();
	gA_AllMapsList.Clear();
	gSM_MapList.Clear();

	gI_ExcludePrefixesCount = ExplodeCvar(gCV_ExcludePrefixes, gS_ExcludePrefixesBuffers, sizeof(gS_ExcludePrefixesBuffers), sizeof(gS_ExcludePrefixesBuffers[]));

	GetTimerSQLPrefix(gS_SQLPrefix, sizeof(gS_SQLPrefix));

	switch(gCV_MapListType.IntValue)
	{
		case MapListZoned:
		{
			if (gH_SQL == null)
			{
				gH_SQL = GetTimerDatabaseHandle2();
			}

			char buffer[512];

			FormatEx(buffer, sizeof(buffer), "SELECT `map` FROM `%smapzones` WHERE `type` = 1 AND `track` = 0 ORDER BY `map`", gS_SQLPrefix);
			gH_SQL.Query(LoadZonedMapsCallback, buffer, _, DBPrio_High);
		}
		case MapListFolder:
		{
			ReadMapsFolderArrayList(gA_MapList, true, false, true, true, gS_ExcludePrefixesBuffers, gI_ExcludePrefixesCount);
			CreateNominateMenu();
		}
		case MapListFile:
		{
			ReadMapList(gA_MapList, gI_MapFileSerial, "default", MAPLIST_FLAG_CLEARARRAY);
			RemoveExcludesFromArrayList(gA_MapList, false, gS_ExcludePrefixesBuffers, gI_ExcludePrefixesCount);
			CreateNominateMenu();
		}
		case MapListMixed, MapListZonedMixedWithFolder:
		{
			if (gH_SQL == null)
			{
				gH_SQL = GetTimerDatabaseHandle2();
			}

			if (gCV_MapListType.IntValue == MapListMixed)
			{
				ReadMapList(gA_AllMapsList, gI_MapFileSerial, "default", MAPLIST_FLAG_CLEARARRAY);
				RemoveExcludesFromArrayList(gA_AllMapsList, false, gS_ExcludePrefixesBuffers, gI_ExcludePrefixesCount);
			}
			else
			{
				ReadMapsFolderArrayList(gA_AllMapsList, true, false, true, true, gS_ExcludePrefixesBuffers, gI_ExcludePrefixesCount);
			}

			char buffer[512];
			FormatEx(buffer, sizeof(buffer), "SELECT `map` FROM `%smapzones` WHERE `type` = 1 AND `track` = 0 ORDER BY `map`", gS_SQLPrefix);
			gH_SQL.Query(LoadZonedMapsCallbackMixed, buffer, _, DBPrio_High);
		}
	}
}

public void LoadZonedMapsCallback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("[shavit-mapchooser] - (LoadMapZonesCallback) - %s", error);
		return;
	}

	char map[PLATFORM_MAX_PATH];
	char map2[PLATFORM_MAX_PATH];
	while(results.FetchRow())
	{
		results.FetchString(0, map, sizeof(map));
		FindMapResult res = FindMap(map, map2, sizeof(map2));

		if (res == FindMap_Found || (gCV_MatchFuzzyMap.BoolValue && res == FindMap_FuzzyMatch))
		{
			gA_MapList.PushString(map2);
		}
	}

	CreateNominateMenu();
}

public void LoadZonedMapsCallbackMixed(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("[shavit-mapchooser] - (LoadMapZonesCallbackMixed) - %s", error);
		return;
	}

	char map[PLATFORM_MAX_PATH];

	for (int i = 0; i < gA_AllMapsList.Length; ++i)
	{
		gA_AllMapsList.GetString(i, map, sizeof(map));
		LessStupidGetMapDisplayName(map, map, sizeof(map));
		gSM_MapList.SetValue(map, i, true);
	}

	int resultlength, mapsadded;
	while(results.FetchRow())
	{
		resultlength++;
		results.FetchString(0, map, sizeof(map));//db mapname
		LowercaseString(map);

		int index;
		if (gSM_MapList.GetValue(map, index))
		{
			gA_MapList.PushString(map);
			mapsadded++;
		}
	}

	PrintToServer("Shavit-Mapchooser Query callback. Number of returned results: %i, Maps added to gA_MapList:%i, gA_AllMapsList.Length:%i, gSM_MapList:%i", resultlength, mapsadded, gA_AllMapsList.Length, gSM_MapList.Size);

	CreateNominateMenu();
}

bool DoFindMap(const char[] mapname, char[] output, int maxlen)
{
	int length = gA_MapList.Length;
	for(int i = 0; i < length; i++)
	{
		char entry[PLATFORM_MAX_PATH];
		gA_MapList.GetString(i, entry, sizeof(entry));

		if(StrContains(entry, mapname) != -1)
		{
			strcopy(output, maxlen, entry);
			return true;
		}
	}

	return false;
}

void DoNominateMatches(int client, const char[] mapname)
{
	Menu subNominateMenu = new Menu(NominateMenuHandler);
	subNominateMenu.SetTitle("Nominate\nMaps matching \"%s\"\n ", mapname);
	bool isCurrentMap = false;
	bool isOldMap = false;
	char map[PLATFORM_MAX_PATH];
	char oldMapName[PLATFORM_MAX_PATH];
	StringMap tiersMap = gB_Rankings ? Shavit_GetMapTiers() : new StringMap();

	int length = gA_MapList.Length;
	for(int i = 0; i < length; i++)
	{
		char entry[PLATFORM_MAX_PATH];
		gA_MapList.GetString(i, entry, sizeof(entry));

		if(StrContains(entry, mapname) != -1)
		{
			if(StrEqual(entry, gS_MapName))
			{
				isCurrentMap = true;
				continue;
			}

			int idx = gA_OldMaps.FindString(entry);
			if(idx != -1)
			{
				isOldMap = true;
				oldMapName = entry;
				continue;
			}

			map = entry;
			char mapdisplay[PLATFORM_MAX_PATH];
			LessStupidGetMapDisplayName(entry, mapdisplay, sizeof(mapdisplay));

			int tier = 0;
			tiersMap.GetValue(mapdisplay, tier);

			char mapdisplay2[PLATFORM_MAX_PATH];
			FormatEx(mapdisplay2, sizeof(mapdisplay2), "%s | T%i", mapdisplay, tier);

			subNominateMenu.AddItem(entry, mapdisplay2);
		}
	}

	delete tiersMap;

	switch (subNominateMenu.ItemCount)
	{
		case 0:
		{
			if (isCurrentMap)
			{
				Shavit_PrintToChat(client, "%T", "Can't Nominate Current Map", client);
			}
			else if (isOldMap)
			{
				Shavit_PrintToChat(client, "%s %T", oldMapName, "Recently Played", client);
			}
			else
			{
				Shavit_PrintToChat(client, "%T", "Map was not found", client, mapname);
			}

			if (subNominateMenu != INVALID_HANDLE)
			{
				CloseHandle(subNominateMenu);
			}
		}
		case 1:
		{
			Nominate(client, map);

			if (subNominateMenu != INVALID_HANDLE)
			{
				CloseHandle(subNominateMenu);
			}
		}
		default:
		{
			subNominateMenu.Display(client, MENU_TIME_FOREVER);
		}
	}
}

bool IsRTVEnabled()
{
	float time = GetEngineTime();

	if(gF_LastMapvoteTime != 0.0)
	{
		if(time - gF_LastMapvoteTime > gCV_MapVoteRevoteTime.FloatValue * 60)
		{
			return true;
		}
	}
	else if(time - gF_MapStartTime > gCV_RTVDelayTime.FloatValue * 60)
	{
		return true;
	}
	return false;
}

void ClearRTV()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		gB_RockTheVote[i] = false;
	}
}

/* Timers */
public Action Timer_ChangeMap(Handle timer, DataPack data)
{
	char reason[PLATFORM_MAX_PATH];
	char map[PLATFORM_MAX_PATH];

	data.Reset();
	data.ReadString(map, sizeof(map));
	data.ReadString(reason, sizeof(reason));

	ForceChangeLevel(map, reason);

	return Plugin_Stop;
}

/* Commands */
public Action Command_Extend(int client, int args)
{
	int extendtime;
	if(args > 0)
	{
		char sArg[8];
		GetCmdArg(1, sArg, sizeof(sArg));
		extendtime = RoundFloat(StringToFloat(sArg) * 60);
	}
	else
	{
		extendtime = RoundFloat(gCV_MapVoteExtendTime.FloatValue * 60.0);
	}

	ExtendMap(client, extendtime);

	return Plugin_Handled;
}

public Action Command_ForceMapVote(int client, int args)
{
	if(gB_MapVoteStarted || gB_MapVoteFinished)
	{
		Shavit_PrintToChat(client, "%T", (gB_MapVoteStarted) ? "MapVote-Initiated" : "MapVote-Finished", client);
	}
	else
	{
		InitiateMapVote(MapChange_Instant);
	}

	return Plugin_Handled;
}

public Action Command_ReloadMaplist(int client, int args)
{
	LoadMapList();

	return Plugin_Handled;
}

public Action Command_Nominate(int client, int args)
{
	if (gB_MapVoteStarted || gB_MapVoteFinished)
	{
		Shavit_PrintToChat(client, "%T", (gB_MapVoteStarted) ? "MapVote-Initiated" : "MapVote-Finished", client);
		return Plugin_Handled;
	}

	if(args < 1)
	{
		if (gCV_EnhancedMenu.BoolValue)
		{
			OpenEnhancedMenu(client);
		}
		else
		{
			OpenNominateMenu(client);
		}
		return Plugin_Handled;
	}

	char mapname[PLATFORM_MAX_PATH];
	GetCmdArg(1, mapname, sizeof(mapname));
	return Command_Nominate_Internal(client, mapname);
}

public Action Command_Nominate_Internal(int client, char mapname[PLATFORM_MAX_PATH])
{
	if (gB_MapVoteStarted || gB_MapVoteFinished)
	{
		Shavit_PrintToChat(client, "%T", (gB_MapVoteStarted) ? "MapVote-Initiated" : "MapVote-Finished", client);
		return Plugin_Handled;
	}

	LowercaseString(mapname);

	if (gCV_DoNominateMatches.BoolValue)
	{
		DoNominateMatches(client, mapname);
	}
	else
	{
		if(DoFindMap(mapname, mapname, sizeof(mapname)))
		{
			if(StrEqual(mapname, gS_MapName))
			{
				Shavit_PrintToChat(client, "%T", "Can't Nominate Current Map", client);
				return Plugin_Handled;
			}

			int idx = gA_OldMaps.FindString(mapname);
			if(idx != -1)
			{
				Shavit_PrintToChat(client, "%s %T", mapname, "Recently Played", client);
				return Plugin_Handled;
			}

			ReplySource old = SetCmdReplySource(SM_REPLY_TO_CHAT);
			Nominate(client, mapname);
			SetCmdReplySource(old);
		}
		else
		{
			Shavit_PrintToChat(client, "%T", "Map was not found", client, mapname);
		}
	}

	return Plugin_Handled;
}

public Action Command_UnNominate(int client, int args)
{
	if (gB_MapVoteStarted || gB_MapVoteFinished)
	{
		Shavit_PrintToChat(client, "%T", (gB_MapVoteStarted) ? "MapVote-Initiated" : "MapVote-Finished", client);
		return Plugin_Handled;
	}

	if (gF_LastNominateTime[client] && (GetEngineTime() - gF_LastNominateTime[client]) < gCV_AntiSpam.FloatValue)
	{
		Shavit_PrintToChat(client, "%T", "Stop Spamming", client);
		return Plugin_Handled;
	}

	if (!CheckCommandAccess(client, "sm_map", ADMFLAG_CHANGEMAP))
	{
		gF_LastNominateTime[client] = GetEngineTime();
	}

	if(gS_NominatedMap[client][0] == '\0')
	{
		Shavit_PrintToChat(client, "%T", "Haven't Nominated", client);
		return Plugin_Handled;
	}

	int idx = gA_NominateList.FindString(gS_NominatedMap[client]);
	if(idx != -1)
	{
		Shavit_PrintToChat(client, "%T", "Removed Nomination", client, gS_NominatedMap[client]);
		gA_NominateList.Erase(idx);
		gS_NominatedMap[client][0] = '\0';
	}

	return Plugin_Handled;
}

public int SlowSortThatSkipsFolders(int index1, int index2, Handle array, Handle stupidgarbage)
{
	char a[PLATFORM_MAX_PATH], b[PLATFORM_MAX_PATH];
	ArrayList list = view_as<ArrayList>(array);
	list.GetString(index1, a, sizeof(a));
	list.GetString(index2, b, sizeof(b));
	return strcmp(a[FindCharInString(a, '/', true)+1], b[FindCharInString(b, '/', true)+1], true);
}

void CreateNominateMenu()
{
	if (gB_Rankings && !gB_TiersAssigned)
	{
		gB_WaitingForTiers = true;
		return;
	}

	int min = GetConVarInt(gCV_MinTier);
	int max = GetConVarInt(gCV_MaxTier);

	if (max < min)
	{
		int temp = max;
		max = min;
		min = temp;
		SetConVarInt(gCV_MinTier, min);
		SetConVarInt(gCV_MaxTier, max);
	}

	delete gH_NominateMenu;
	gH_NominateMenu = new Menu(NominateMenuHandler);

	gH_NominateMenu.SetTitle("Nominate");
	StringMap tiersMap = gB_Rankings ? Shavit_GetMapTiers() : new StringMap();

	gA_MapList.SortCustom(SlowSortThatSkipsFolders);

	int length = gA_MapList.Length;
	for(int i = 0; i < length; ++i)
	{
		int style = ITEMDRAW_DEFAULT;
		char mapname[PLATFORM_MAX_PATH];
		gA_MapList.GetString(i, mapname, sizeof(mapname));

		if(StrEqual(mapname, gS_MapName))
		{
			style = ITEMDRAW_DISABLED;
		}

		int idx = gA_OldMaps.FindString(mapname);
		if(idx != -1)
		{
			style = ITEMDRAW_DISABLED;
		}

		char mapdisplay[PLATFORM_MAX_PATH];
		LessStupidGetMapDisplayName(mapname, mapdisplay, sizeof(mapdisplay));

		if (gB_Rankings)
		{
			int tier = 0;
			tiersMap.GetValue(mapdisplay, tier);

			if (min <= tier <= max)
			{
				char mapdisplay2[PLATFORM_MAX_PATH];
				FormatEx(mapdisplay2, sizeof(mapdisplay2), "%s | T%i", mapdisplay, tier);
				gH_NominateMenu.AddItem(mapname, mapdisplay2, style);
			}
		}
		else
		{
			gH_NominateMenu.AddItem(mapname, mapdisplay, style);
		}
	}

	delete tiersMap;

	if (gCV_EnhancedMenu.BoolValue)
	{
		CreateTierMenus();
	}
}

void CreateEnhancedMenu()
{
	delete gH_EnhancedMenu;

	gH_EnhancedMenu = new Menu(EnhancedMenuHandler);
	gH_EnhancedMenu.ExitButton = true;

	gH_EnhancedMenu.SetTitle("Nominate");
	gH_EnhancedMenu.AddItem("Alphabetic", "Alphabetic");

	for(int i = GetConVarInt(gCV_MinTier); i <= GetConVarInt(gCV_MaxTier); ++i)
	{
		int count = GetMenuItemCount(gH_TierMenus[i]);

		if (count > 0)
		{
			char tierDisplay[32];
			FormatEx(tierDisplay, sizeof(tierDisplay), "Tier %i (%d)", i, count);

			char tierString[16];
			IntToString(i, tierString, sizeof(tierString));
			gH_EnhancedMenu.AddItem(tierString, tierDisplay);
		}
	}
}

void CreateTierMenus()
{
	int min = GetConVarInt(gCV_MinTier);
	int max = GetConVarInt(gCV_MaxTier);

	InitTierMenus(min,max);
	StringMap tiersMap = gB_Rankings ? Shavit_GetMapTiers() : new StringMap();

	int length = gA_MapList.Length;
	for(int i = 0; i < length; ++i)
	{
		int style = ITEMDRAW_DEFAULT;
		char mapname[PLATFORM_MAX_PATH];
		gA_MapList.GetString(i, mapname, sizeof(mapname));

		char mapdisplay[PLATFORM_MAX_PATH];
		LessStupidGetMapDisplayName(mapname, mapdisplay, sizeof(mapdisplay));

		int mapTier = 0;
		tiersMap.GetValue(mapdisplay, mapTier);

		if(StrEqual(mapname, gS_MapName))
		{
			style = ITEMDRAW_DISABLED;
		}

		int idx = gA_OldMaps.FindString(mapname);
		if(idx != -1)
		{
			style = ITEMDRAW_DISABLED;
		}

		char mapdisplay2[PLATFORM_MAX_PATH];
		FormatEx(mapdisplay2, sizeof(mapdisplay2), "%s | T%i", mapdisplay, mapTier);

		if (min <= mapTier <= max)
		{
			AddMenuItem(gH_TierMenus[mapTier], mapname, mapdisplay2, style);
		}
	}

	delete tiersMap;

	CreateEnhancedMenu();
}

void InitTierMenus(int min, int max)
{
	for (int i = 0; i < sizeof(gH_TierMenus); i++)
	{
		delete gH_TierMenus[i];
	}

	for(int i = min; i <= max; i++)
	{
		Menu TierMenu = new Menu(NominateMenuHandler);
		TierMenu.SetTitle("Nominate\nTier \"%i\" Maps\n ", i);
		TierMenu.ExitBackButton = true;
		gH_TierMenus[i] = TierMenu;
	}
}

void OpenNominateMenu(int client)
{
	if (gCV_EnhancedMenu.BoolValue)
	{
		gH_NominateMenu.ExitBackButton = true;
	}
	gH_NominateMenu.Display(client, MENU_TIME_FOREVER);
}

void OpenEnhancedMenu(int client)
{
	gH_EnhancedMenu.Display(client, MENU_TIME_FOREVER);
}

void OpenNominateMenuTier(int client, int tier)
{
	DisplayMenu(gH_TierMenus[tier], client, MENU_TIME_FOREVER);
}

public int MapsMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char map[PLATFORM_MAX_PATH];
		menu.GetItem(param2, map, sizeof(map));

		Shavit_PrintToChatAll("%N %t", param1, "Changing map", map);
		LogAction(param1, -1, "\"%L\" changed map to \"%s\"", param1, map);

		DataPack dp = new DataPack();
		CreateDataTimer(1.0, Timer_ChangeMap, dp);
		dp.WriteString(map);
		dp.WriteString("sm_map");
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

public int NominateMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char mapname[PLATFORM_MAX_PATH];
		menu.GetItem(param2, mapname, sizeof(mapname));

		Nominate(param1, mapname);
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack && GetConVarBool(gCV_EnhancedMenu))
	{
		OpenEnhancedMenu(param1);
	}
	else if (action == MenuAction_End)
	{
		if (menu != gH_NominateMenu && menu != INVALID_HANDLE)
		{
			for (int i = 0; i < sizeof(gH_TierMenus); i++)
			{
				if (gH_TierMenus[i] == menu)
				{
					return 0;
				}
			}

			CloseHandle(menu);
		}
	}

	return 0;
}

public int EnhancedMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_Select)
	{
		char option[PLATFORM_MAX_PATH];
		menu.GetItem(param2, option, sizeof(option));

		if (StrEqual(option , "Alphabetic"))
		{
			OpenNominateMenu(client);
		}
		else
		{
			OpenNominateMenuTier(client, StringToInt(option));
		}
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		OpenEnhancedMenu(client);
	}

	return 0;
}

void Nominate(int client, const char mapname[PLATFORM_MAX_PATH])
{
	if (GetEngineTime() - gF_MapStartTime < gCV_NominateDelayTime.FloatValue * 60)
	{
		Shavit_PrintToChat(client, "%T", "NominateDisabled", client);
		return;
	}

	if (gF_LastNominateTime[client] && (GetEngineTime() - gF_LastNominateTime[client]) < gCV_AntiSpam.FloatValue)
	{
		Shavit_PrintToChat(client, "%T", "Stop Spamming", client);
		return;
	}

	if (!CheckCommandAccess(client, "sm_map", ADMFLAG_CHANGEMAP))
	{
		gF_LastNominateTime[client] = GetEngineTime();
	}

	int idx = gA_NominateList.FindString(mapname);
	if(idx != -1)
	{
		Shavit_PrintToChat(client, "%T", "Map Already Nominated", client);
		return;
	}

	if(gS_NominatedMap[client][0] != '\0')
	{
		RemoveString(gA_NominateList, gS_NominatedMap[client]);
	}

	gA_NominateList.PushString(mapname);
	gS_NominatedMap[client] = mapname;
	char name[MAX_NAME_LENGTH];
	GetClientName(client, name, sizeof(name));

	Shavit_PrintToChatAll("%t", "Map Nominated", name, mapname);
}

public Action Command_RockTheVote(int client, int args)
{
	if(!IsRTVEnabled())
	{
		Shavit_PrintToChat(client, "%T", "RTV Not Allowed", client);
	}
	else if(gB_MapVoteStarted)
	{
		Shavit_PrintToChat(client, "%T", "RTV Started", client);
	}
	else if(gB_RockTheVote[client])
	{
		int needed, rtvcount, total;
		GetRTVStuff(total, needed, rtvcount);
		Shavit_PrintToChat(client, "%T", "UnRTV", client, rtvcount);
	}
	else if(gCV_RTVMinimumPoints.IntValue != -1 && Shavit_GetPoints(client) <= gCV_RTVMinimumPoints.FloatValue)
	{
		Shavit_PrintToChat(client, "%T", "RankedRTV", client, gCV_RTVMinimumPoints.FloatValue, Shavit_GetPoints(client));
	}
	else if(GetClientTeam(client) == CS_TEAM_SPECTATOR && !gCV_RTVAllowSpectators.BoolValue)
	{
		Shavit_PrintToChat(client, "%T", "BlockSpectatorRTV", client);
	}
	else
	{
		if (gF_LastRtvTime[client] && (GetEngineTime() - gF_LastRtvTime[client]) < gCV_AntiSpam.FloatValue)
		{
			Shavit_PrintToChat(client, "%T", "Stop Spamming", client);
			return Plugin_Handled;
		}

		if (!CheckCommandAccess(client, "sm_map", ADMFLAG_CHANGEMAP))
		{
			gF_LastRtvTime[client] = GetEngineTime();
		}

		RTVClient(client);
		CheckRTV(client);
	}

	return Plugin_Handled;
}

int CheckRTV(int client = 0)
{
	int needed, rtvcount, total;
	GetRTVStuff(total, needed, rtvcount);
	char name[MAX_NAME_LENGTH];

	if(client != 0)
	{
		GetClientName(client, name, sizeof(name));
	}
	if(needed > 0)
	{
		if(client != 0)
		{
			Shavit_PrintToChatAll("%t", "RTV Requested", name, rtvcount, total);
		}
	}
	else
	{
		if(gB_MapVoteFinished)
		{
			char map[PLATFORM_MAX_PATH];
			GetNextMap(map, sizeof(map));

			if(client != 0)
			{
				Shavit_PrintToChatAll("%t", "RTVFinished-MapChange", client, map);
			}
			else
			{
				Shavit_PrintToChatAll("%t", "RTVFinishedMajorily-MapChange", map);
			}

			SetNextMap(map);
			DataPack data = new DataPack();
			CreateDataTimer(1.0, Timer_ChangeMap, data);
			data.WriteString(map);
			data.WriteString("no reason");
		}
		else
		{
			if(client != 0)
			{
				Shavit_PrintToChatAll("%t", "RTVFinished-MapVote", client);
			}
			else
			{
				Shavit_PrintToChatAll("%t", "RTVFinishedMajorily-MapVote");
			}

			InitiateMapVote(MapChange_Instant);
		}
	}

	return needed;
}

public Action Command_UnRockTheVote(int client, int args)
{
	if(!IsRTVEnabled())
	{
		Shavit_PrintToChat(client, "%T", "RTVDisabled", client);
	}
	else if(gB_MapVoteStarted || gB_MapVoteFinished)
	{
		Shavit_PrintToChat(client, "%T", (gB_MapVoteStarted) ? "MapVote-Initiated" : "MapVote-Finished", client);
	}
	else if(gB_RockTheVote[client])
	{
		if (gF_LastRtvTime[client] && (GetEngineTime() - gF_LastRtvTime[client]) < gCV_AntiSpam.FloatValue)
		{
			Shavit_PrintToChat(client, "%T", "Stop Spamming", client);
			return Plugin_Handled;
		}

		if (!CheckCommandAccess(client, "sm_map", ADMFLAG_CHANGEMAP))
		{
			gF_LastRtvTime[client] = GetEngineTime();
		}

		UnRTVClient(client);

		int needed, rtvcount, total;
		GetRTVStuff(total, needed, rtvcount);

		if(needed > 0)
		{
			Shavit_PrintToChatAll("%t", "UnRTVNeeds", client, needed);
		}
	}

	return Plugin_Handled;
}

public Action Command_NomList(int client, int args)
{
	if(gA_NominateList.Length < 1)
	{
		Shavit_PrintToChat(client, "%T", "No Maps Nominated", client);
		return Plugin_Handled;
	}

	Menu nomList = new Menu(Null_Callback);
	nomList.SetTitle("Nominated Maps");
	for(int i = 0; i < gA_NominateList.Length; ++i)
	{
		char buffer[PLATFORM_MAX_PATH];
		gA_NominateList.GetString(i, buffer, sizeof(buffer));

		nomList.AddItem(buffer, buffer, ITEMDRAW_DISABLED);
	}

	nomList.Display(client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}

public int Null_Callback(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

public void FindUnzonedMapCallback(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
	{
		LogError("[shavit-mapchooser] - (FindUnzonedMapCallback) - %s", error);
		return;
	}

	StringMap mapList = new StringMap();

	gI_ExcludePrefixesCount = ExplodeCvar(gCV_ExcludePrefixes, gS_ExcludePrefixesBuffers, sizeof(gS_ExcludePrefixesBuffers), sizeof(gS_ExcludePrefixesBuffers[]));

	ReadMapsFolderStringMap(mapList, true, true, true, true, gS_ExcludePrefixesBuffers, gI_ExcludePrefixesCount);

	char buffer[PLATFORM_MAX_PATH];

	while (results.FetchRow())
	{
		results.FetchString(0, buffer, sizeof(buffer));
		mapList.SetValue(buffer, true, true);
	}

	delete results;

	StringMapSnapshot snapshot = mapList.Snapshot();
	bool foundMap = false;

	for (int i = 0; i < snapshot.Length; i++)
	{
		snapshot.GetKey(i, buffer, sizeof(buffer));

		bool hasZones = false;
		mapList.GetValue(buffer, hasZones);

		if (!hasZones && !StrEqual(gS_MapName, buffer, false))
		{
			foundMap = true;
			break;
		}
	}

	delete snapshot;
	delete mapList;

	if (foundMap)
	{
		Shavit_PrintToChatAll("%t", "Loading Unzoned Map", buffer);

		DataPack dp = new DataPack();
		CreateDataTimer(1.0, Timer_ChangeMap, dp);
		dp.WriteString(buffer);
		dp.WriteString("sm_loadunzonedmap");
	}
}

public Action Command_LoadUnzonedMap(int client, int args)
{
	char sQuery[256];
	FormatEx(sQuery, sizeof(sQuery), "SELECT DISTINCT map FROM %smapzones;", gS_SQLPrefix);
	gH_SQL.Query(FindUnzonedMapCallback, sQuery, 0, DBPrio_Normal);
	return Plugin_Handled;
}

public Action Command_ReloadMap(int client, int args)
{
	Shavit_PrintToChatAll("%t", "Reloading Current Map");

	DataPack dp = new DataPack();
	CreateDataTimer(1.0, Timer_ChangeMap, dp);
	dp.WriteString(gS_MapName);
	dp.WriteString("sm_reloadmap");

	return Plugin_Handled;
}

public Action BaseCommands_Command_Map_Menu(int client, int args)
{
	char map[PLATFORM_MAX_PATH];
	Menu menu = new Menu(MapsMenuHandler);

	if (args < 1)
	{
		menu.SetTitle("%T\n ", "Choose Map", client);
	}
	else
	{
		GetCmdArg(1, map, sizeof(map));
		LowercaseString(map);
		ReplaceString(map, sizeof(map), "\\", "/", true);

		menu.SetTitle("Maps matching \"%s\"\n ", map);
	}

	StringMap tiersMap = gB_Rankings ? Shavit_GetMapTiers() : new StringMap();
	ArrayList maps = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
	ReadMapsFolderArrayList(maps);

	int length = maps.Length;
	for(int i = 0; i < length; i++)
	{
		char entry[PLATFORM_MAX_PATH];
		maps.GetString(i, entry, sizeof(entry));

		if (args < 1 || StrContains(entry, map) != -1)
		{
			char mapdisplay[PLATFORM_MAX_PATH];
			LessStupidGetMapDisplayName(entry, mapdisplay, sizeof(mapdisplay));

			int tier = 0;
			tiersMap.GetValue(mapdisplay, tier);

			char mapdisplay2[PLATFORM_MAX_PATH];
			FormatEx(mapdisplay2, sizeof(mapdisplay2), "%s | T%i", mapdisplay, tier);

			menu.AddItem(entry, mapdisplay2);
		}
	}

	delete maps;
	delete tiersMap;

	switch (menu.ItemCount)
	{
		case 0:
		{
			Shavit_PrintToChat(client, "%T", "Map was not found", client, map);
			delete menu;
		}
		case 1:
		{
			menu.GetItem(0, map, sizeof(map));

			Shavit_PrintToChatAll("%N %t", client, "Changing map", map);
			LogAction(client, -1, "\"%L\" changed map to \"%s\"", client, map);

			DataPack dp = new DataPack();
			CreateDataTimer(1.0, Timer_ChangeMap, dp);
			dp.WriteString(map);
			dp.WriteString("sm_map");
			delete menu;
		}
		default:
		{
			menu.Display(client, MENU_TIME_FOREVER);
		}
	}

	return Plugin_Handled;
}

public Action BaseCommands_Command_Map(int client, int args)
{
	char map[PLATFORM_MAX_PATH];
	char displayName[PLATFORM_MAX_PATH];
	GetCmdArg(1, map, sizeof(map));
	LowercaseString(map);
	ReplaceString(map, sizeof(map), "\\", "/", true);

	gI_AutocompletePrefixesCount = ExplodeCvar(gCV_AutocompletePrefixes, gS_AutocompletePrefixesBuffers, sizeof(gS_AutocompletePrefixesBuffers), sizeof(gS_AutocompletePrefixesBuffers[]));

	StringMap maps = new StringMap();
	ReadMapsFolderStringMap(maps);

	int temp;
	bool foundMap;
	char buffer[PLATFORM_MAX_PATH];

	for (int i = -1; i < gI_AutocompletePrefixesCount; i++)
	{
		char prefix[12];

		if (i > -1)
		{
			prefix = gS_AutocompletePrefixesBuffers[i];
		}

		FormatEx(buffer, sizeof(buffer), "%s%s", prefix, map);

		if ((foundMap = maps.GetValue(buffer, temp)) != false)
		{
			map = buffer;
			break;
		}
	}

	if (!foundMap)
	{
		// do a smaller 

		StringMapSnapshot snapshot = maps.Snapshot();
		int length = snapshot.Length;

		for (int i = 0; i < length; i++)
		{
			snapshot.GetKey(i, buffer, sizeof(buffer));

			if (StrContains(buffer, map, true) != -1)
			{
				foundMap = true;
				map = buffer;
				break;
			}
		}

		delete snapshot;
	}

	delete maps;

	if (!foundMap)
	{
		Shavit_PrintToChat(client, "%T", "Map was not found", client, map);
		return Plugin_Handled;
	}

	LessStupidGetMapDisplayName(map, displayName, sizeof(displayName));

	Shavit_PrintToChatAll("%N %t", client, "Changing map", displayName);
	LogAction(client, -1, "\"%L\" changed map to \"%s\"", client, map);

	DataPack dp = new DataPack();
	CreateDataTimer(1.0, Timer_ChangeMap, dp);
	dp.WriteString(map);
	dp.WriteString("sm_map");

	return Plugin_Handled;
}

public Action Command_MapButFaster(int client, const char[] command, int args)
{
	if (!gCV_HijackMap.BoolValue || !CheckCommandAccess(client, "sm_map", ADMFLAG_CHANGEMAP))
	{
		return Plugin_Continue;
	}

	if (client == 0)
	{
		if (args < 1)
		{
			Shavit_PrintToChat(client, "%T", "Usage-sm_map", client);
			return Plugin_Stop;
		}

		BaseCommands_Command_Map(client, args);
	}
	else
	{
		BaseCommands_Command_Map_Menu(client, args);
	}

	return Plugin_Stop;
}

void RTVClient(int client)
{
	gB_RockTheVote[client] = true;
	Call_StartForward(gH_Forward_OnRTV);
	Call_PushCell(client);
	Call_Finish();
}

void UnRTVClient(int client)
{
	gB_RockTheVote[client] = false;
	Call_StartForward(gH_Forward_OnUnRTV);
	Call_PushCell(client);
	Call_Finish();
}

/* Stocks */
stock void RemoveString(ArrayList array, const char[] target)
{
	int idx = array.FindString(target);
	if(idx != -1)
	{
		array.Erase(idx);
	}
}

void GetRTVStuff(int& total_needed, int& remaining_needed, int& rtvcount)
{
	float now = GetEngineTime();

	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i))
		{
			// dont count players that can't vote
			if(!gCV_RTVAllowSpectators.BoolValue && IsClientObserver(i) && (now - gF_SpecTimerStart[i]) >= gCV_RTVSpectatorCooldown.FloatValue)
			{
				continue;
			}

			if(gCV_RTVMinimumPoints.IntValue != -1 && Shavit_GetPoints(i) <= gCV_RTVMinimumPoints.FloatValue)
			{
				continue;
			}

			total_needed++;

			if(gB_RockTheVote[i])
			{
				rtvcount++;
			}
		}
	}

	total_needed = RoundToCeil(total_needed * (gCV_RTVRequiredPercentage.FloatValue / 100));

	// always clamp to 1, so if rtvcount is 0 it never initiates RTV
	if (total_needed < 1)
	{
		total_needed = 1;
	}

	remaining_needed = total_needed - rtvcount;
}
