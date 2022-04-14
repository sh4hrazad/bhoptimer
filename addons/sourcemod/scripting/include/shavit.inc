/*
 * shavit's Timer - .inc file
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

#if defined _shavit_included
	#endinput
#endif
#define _shavit_included

#define SHAVIT_VERSION "3.0.9a"
#define TRACK_LIMIT 16
#define STYLE_LIMIT 16
#define MAX_ZONES 128
#define MAX_STAGES 32
#define MAX_CPZONES 16


// HUD
#define HUD_NONE				0
#define HUD_MASTER				(1 << 0) // master setting
#define HUD_CENTER				(1 << 1) // show hud as hint text
#define HUD_ZONEHUD				(1 << 2) // show start/end zone hud
#define HUD_OBSERVE				(1 << 3) // show the HUD of the player you spectate
#define HUD_SPECTATORS			(1 << 4) // show list of spectators
#define HUD_KEYOVERLAY			(1 << 5) // show a key overlay
#define HUD_HIDEWEAPON			(1 << 6) // hide the player's weapon
#define HUD_TOPLEFT				(1 << 7) // show top left white HUD with WR/PB times
#define HUD_SYNC				(1 << 8) // shows sync at right side of the screen (css only)
#define HUD_TIMELEFT			(1 << 9) // shows time left at right tside of the screen (css only)
#define HUD_2DVEL				(1 << 10) // shows 2d velocity
#define HUD_NOSOUNDS			(1 << 11) // disables sounds on personal best, world record etc
#define HUD_MAPTIER			(1 << 12)

#define SHAVIT_LOG_QUERIES 0

// status
enum TimerStatus
{
	Timer_Stopped,
	Timer_Running,
	Timer_Paused
};

// pb overwrite
enum
{
	PB_UnRanked = -1,
	PB_NoQuery,
	PB_Insert,
	PB_Update
};

enum
{
	CPR_ByConVar = (1 << 0),
	CPR_NoTimer = (1 << 1),
	CPR_InStartZone = (1 << 2),
	CPR_NotOnGround = (1 << 3),
	CPR_Moving = (1 << 4),
	CPR_Duck = (1 << 5), // quack
	CPR_InEndZone = (1 << 6),
};

enum
{
	STATUS_ONTELEPORT = (1 << 0), /* Client is teleporting */
};

enum
{
	Migration_RemoveWorkshopMaptiers,
	Migration_RemoveWorkshopMapzones,
	Migration_RemoveWorkshopPlayertimes,
	Migration_LastLoginIndex,
	Migration_RemoveCountry,
	Migration_ConvertIPAddresses, // 5
	Migration_ConvertSteamIDsUsers,
	Migration_ConvertSteamIDsPlayertimes,
	Migration_ConvertSteamIDsChat,
	Migration_PlayertimesDateToInt,
	Migration_AddZonesFlagsAndData, // 10
	Migration_AddPlayertimesCompletions,
	Migration_AddCustomChatAccess,
	Migration_AddPlayertimesExactTimeInt,
	Migration_FixOldCompletionCounts, // old completions accidentally started at 2
	Migration_AddPlaytime, // 15
	// sorry, this is kind of dumb but it's better than trying to manage which ones have
	// finished and which tables exist etc etc in a transaction or a completion counter...
	Migration_Lowercase_maptiers,
	Migration_Lowercase_mapzones,
	Migration_Lowercase_playertimes,
	Migration_Lowercase_stagetimeswr, // 20
	Migration_Lowercase_startpositions,
	MIGRATIONS_END
};

enum
{
	Zone_Start,
	Zone_End,
	Zone_Stage,
	Zone_Checkpoint,	// track checkpoint zone
	Zone_Stop,		// stops the player's timer
	Zone_Teleport,		// teleports to a defined point
	Zone_Mark,		// do nothing, better to use with !hookzone
	Zone_AntiJump,
	Zone_AutoBhop,
	ZONETYPES_SIZE
};

enum
{
	Track_Main,
	Track_Bonus,
	Track_Bonus_Last = TRACK_LIMIT,
	TRACKS_SIZE
};

// for Shavit_GetStyleStrings
enum
{
	sStyleName,
	sShortName,
	sHTMLColor,
	sChangeCommand,
	sClanTag,
	sSpecialString,
	sStylePermission
};

// for Shavit_GetChatStrings
enum
{
	sMessagePrefix,
	sMessageText,
	sMessageWarning,
	sMessageTeam,
	sMessageStyle,
	sMessageGood,
	sMessageBad
};

enum struct stylestrings_t
{
	char sStyleName[64];
	char sShortName[32];
	char sHTMLColor[32];
	char sChangeCommand[128];
	char sClanTag[32];
	char sSpecialString[128];
	char sStylePermission[64];
}

enum struct chatstrings_t
{
	char sPrefix[64];
	char sText[16];
	char sWarning[16];
	char sTeam[16];
	char sStyle[16];
	char sGood[16]; // green
	char sBad[16];	// red
}

enum struct timer_snapshot_t
{
	bool bTimerEnabled;
	float fCurrentTime;
	bool bClientPaused;
	int iJumps;
	int bsStyle;
	int iStrafes;
	int iTotalMeasures;
	int iGoodGains;
	float fServerTime;
	int iSHSWCombination;
	int iTimerTrack;
	float fZoneOffset[2];
	float fDistanceOffset[2];
	float fAvgVelocity;
	float fMaxVelocity;
	float fTimescale;
	int iZoneIncrement; // convert to array for per zone offsets (?)
	float fTimescaledTicks;

	bool bPracticeMode;

	bool bJumped;
	bool bCanUseAllKeys;
	bool bOnGround;

	float fPauseOrigin[3];
	float fPauseAngles[3];
	float fPauseVelocity[3];

	int iLastButtons;
	float fLastAngle;
	float fLastInputVel[2];
	int iLandingTick;
	MoveType iLastMoveType;
	float fStrafeWarning;

	float fplayer_speedmod;

	int iCurrentStage;
	int iCurrentCP;
	int iLastStage;
	int iLastCP;
	float fLeaveStageTime;

	bool bStageTimer;
}

stock void Shavit_LogQuery(const char[] query)
{
	static File hLogFile;

	if (hLogFile == null)
	{
		char sPlugin[PLATFORM_MAX_PATH];
		GetPluginFilename(INVALID_HANDLE, sPlugin, sizeof(sPlugin));
		ReplaceString(sPlugin, PLATFORM_MAX_PATH, ".smx", "");
		ReplaceString(sPlugin, PLATFORM_MAX_PATH, "\\", "/");

		int start = FindCharInString(sPlugin, '/', true);

		char sFilename[PLATFORM_MAX_PATH];
		BuildPath(Path_SM, sFilename, sizeof(sFilename), "logs/%s_sql.log", sPlugin[start+1]);

		hLogFile = OpenFile(sFilename, "a");
	}

	if (hLogFile)
	{
		LogToOpenFileEx(hLogFile, "%s", query);
	}
}

methodmap Database2 < Database
{
	public void Query(SQLQueryCallback callback, const char[] query, any data = 0, DBPriority prio = DBPrio_Normal)
	{
#if SHAVIT_LOG_QUERIES
		Shavit_LogQuery(query);
#endif
		this.Query(callback, query, data, prio);
	}
}

methodmap Transaction2 < Transaction
{
	public Transaction2()
	{
		return view_as<Transaction2>(new Transaction());
	}

	public int AddQuery(const char[] query, any data = 0)
	{
#if SHAVIT_LOG_QUERIES
		Shavit_LogQuery(query);
#endif
		return this.AddQuery(query, data);
	}
}

// connects synchronously to the bhoptimer database
// calls errors if needed
stock Database GetTimerDatabaseHandle(bool reuse_persistent_connection=true)
{
	Database db = null;
	char sError[255];

	if(SQL_CheckConfig("shavit"))
	{
		if((db = SQL_Connect("shavit", reuse_persistent_connection, sError, 255)) == null)
		{
			SetFailState("Timer startup failed. Reason: %s", sError);
		}
	}
	else
	{
		db = SQLite_UseDatabase("shavit", sError, 255);
	}

	// support unicode names
	if (!db.SetCharset("utf8mb4"))
	{
		db.SetCharset("utf8");
	}

	return db;
}

stock Database2 GetTimerDatabaseHandle2(bool reuse_persistent_connection=true)
{
	return view_as<Database2>(GetTimerDatabaseHandle(reuse_persistent_connection));
}

// figures out if the database is a mysql database
stock bool IsMySQLDatabase(Database db)
{
	char sDriver[8];
	db.Driver.GetIdentifier(sDriver, 8);

	return StrEqual(sDriver, "mysql", false);
}

stock void LowercaseString(char[] str)
{
	static char to_lowercase_table[256+1] = "\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0A\x0B\x0C\x0D\x0E\x0F\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1A\x1B\x1C\x1D\x1E\x1F\x20\x21\x22\x23\x24\x25\x26\x27\x28\x29\x2A\x2B\x2C\x2D\x2E\x2F\x30\x31\x32\x33\x34\x35\x36\x37\x38\x39\x3A\x3B\x3C\x3D\x3E\x3F\x40\x61\x62\x63\x64\x65\x66\x67\x68\x69\x6A\x6B\x6C\x6D\x6E\x6F\x70\x71\x72\x73\x74\x75\x76\x77\x78\x79\x7A\x5B\x5C\x5D\x5E\x5F\x60\x61\x62\x63\x64\x65\x66\x67\x68\x69\x6A\x6B\x6C\x6D\x6E\x6F\x70\x71\x72\x73\x74\x75\x76\x77\x78\x79\x7A\x7B\x7C\x7D\x7E\x7F\x80\x81\x82\x83\x84\x85\x86\x87\x88\x89\x8A\x8B\x8C\x8D\x8E\x8F\x90\x91\x92\x93\x94\x95\x96\x97\x98\x99\x9A\x9B\x9C\x9D\x9E\x9F\xA0\xA1\xA2\xA3\xA4\xA5\xA6\xA7\xA8\xA9\xAA\xAB\xAC\xAD\xAE\xAF\xB0\xB1\xB2\xB3\xB4\xB5\xB6\xB7\xB8\xB9\xBA\xBB\xBC\xBD\xBE\xBF\xC0\xC1\xC2\xC3\xC4\xC5\xC6\xC7\xC8\xC9\xCA\xCB\xCC\xCD\xCE\xCF\xD0\xD1\xD2\xD3\xD4\xD5\xD6\xD7\xD8\xD9\xDA\xDB\xDC\xDD\xDE\xDF\xE0\xE1\xE2\xE3\xE4\xE5\xE6\xE7\xE8\xE9\xEA\xEB\xEC\xED\xEE\xEF\xF0\xF1\xF2\xF3\xF4\xF5\xF6\xF7\xF8\xF9\xFA\xFB\xFC\xFD\xFE\xFF";

	for (int i = 0; str[i] != 0; i++)
	{
		int x = str[i];
		str[i] = to_lowercase_table[x];
	}
}

// GetMapDisplayName ends up opening every single fucking file to verify it's valid.
// I don't care about that. I just want the stupid fucking mapname string.
// Also this lowercases the string.
stock void LessStupidGetMapDisplayName(const char[] map, char[] displayName, int maxlen)
{
	char temp[PLATFORM_MAX_PATH];
	char temp2[PLATFORM_MAX_PATH];

	strcopy(temp, sizeof(temp), map);
	ReplaceString(temp, sizeof(temp), "\\", "/", true);

	int slashpos = FindCharInString(map, '/', true);
	strcopy(temp2, sizeof(temp2), map[slashpos+1]);

	int ugcpos = StrContains(temp2, ".ugc", true);

	if (ugcpos != -1)
	{
		temp2[ugcpos] = 0;
	}

	LowercaseString(temp2);
	strcopy(displayName, maxlen, temp2);
}

stock void GetLowercaseMapName(char sMap[PLATFORM_MAX_PATH])
{
	GetCurrentMap(sMap, sizeof(sMap));
	LessStupidGetMapDisplayName(sMap, sMap, sizeof(sMap));
}

stock bool ReadMapsFolderHandler(const char path[PLATFORM_MAX_PATH], bool is_stringmap, Handle data, bool lowercase, bool display, bool iter_subfolders, bool use_valve_fs, char[][] exclude_prefixes, int exclude_count)
{
	bool first_iteration = StrEqual(path, "maps");
	DirectoryListing dir = OpenDirectory(path, use_valve_fs);

	if (dir == null)
	{
		return false;
	}

	char buffer[PLATFORM_MAX_PATH];
	FileType type;

	while (dir.GetNext(buffer, sizeof(buffer), type))
	{
		if (type == FileType_Directory)
		{
			if (buffer[0] == '.' && (buffer[1] == 0 || (buffer[1] == '.' && buffer[2] == 0)))
			{
				continue;
			}

			if (iter_subfolders)
			{
				char subfolder[PLATFORM_MAX_PATH];
				FormatEx(subfolder, sizeof(subfolder), "%s/%s", path, buffer);
				ReadMapsFolderHandler(subfolder, is_stringmap, data, lowercase, display, iter_subfolders, use_valve_fs, exclude_prefixes, exclude_count);
			}
		}
		else if (type == FileType_File)
		{
			int length = strlen(buffer);

			if (length < 5 || buffer[length-4] != '.') // a.bsp
			{
				continue;
			}

			if ((buffer[length-3] == 'b' && buffer[length-2] == 's' && buffer[length-1] == 'p') ||
			    (buffer[length-3] == 'u' && buffer[length-2] == 'g' && buffer[length-1] == 'c'))
			{
				buffer[length-4] = 0;

				if (lowercase)
				{
					LowercaseString(buffer);
				}

				bool skip = false;

				for (int i = 0; i < exclude_count; i++)
				{
					if (strncmp(buffer, exclude_prefixes[i], strlen(exclude_prefixes[i]), lowercase) == 0)
					{
						skip = true;
						break;
					}
				}

				if (skip)
				{
					continue;
				}

				if (!display && !first_iteration)
				{
					char temp[PLATFORM_MAX_PATH];
					int skip_this = 5; // strlen("maps/")
					FormatEx(temp, sizeof(temp), "%s/%s", path[skip_this], buffer);
					buffer = temp;
				}

				if (is_stringmap)
				{
					view_as<StringMap>(data).SetValue(buffer, false, false);
				}
				else
				{
					view_as<ArrayList>(data).PushString(buffer);
				}
			}
		}
	}

	delete dir;
	return true;
}

static char empty_excludes[][] = {""};

stock bool ReadMapsFolderStringMap(StringMap data, bool lowercase=true, bool display=false, bool iter_subfolders=true, bool use_valve_fs=true, char[][] exclude_prefixes=empty_excludes, int exclude_count=0)
{
	return ReadMapsFolderHandler("maps", true, data, lowercase, display, iter_subfolders, use_valve_fs, exclude_prefixes, exclude_count);
}

// don't forget to declare your ArrayList like below :)))
//// ArrayList maps = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
stock bool ReadMapsFolderArrayList(ArrayList data, bool lowercase=true, bool display=false, bool iter_subfolders=true, bool use_valve_fs=true, char[][] exclude_prefixes=empty_excludes, int exclude_count=0)
{
	return ReadMapsFolderHandler("maps", false, data, lowercase, display, iter_subfolders, use_valve_fs, exclude_prefixes, exclude_count);
}

// retrieves the table prefix defined in configs/shavit-prefix.txt
stock void GetTimerSQLPrefix(char[] buffer, int maxlen)
{
	char sFile[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sFile, PLATFORM_MAX_PATH, "configs/shavit-prefix.txt");

	File fFile = OpenFile(sFile, "r");

	if(fFile == null)
	{
		SetFailState("Cannot open \"configs/shavit-prefix.txt\". Make sure this file exists and that the server has read permissions to it.");
	}
	
	char sLine[PLATFORM_MAX_PATH * 2];

	if(fFile.ReadLine(sLine, PLATFORM_MAX_PATH * 2))
	{
		TrimString(sLine);
		strcopy(buffer, maxlen, sLine);
	}

	delete fFile;
}

stock bool IsValidClient(int client, bool bAlive = false)
{
	return (client >= 1 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client) && !IsClientSourceTV(client) && (!bAlive || IsPlayerAlive(client)));
}

stock bool IsSource2013(EngineVersion ev)
{
	return (ev == Engine_CSS || ev == Engine_TF2);
}

stock void IPAddressToString(int ip, char[] buffer, int maxlen)
{
	FormatEx(buffer, maxlen, "%d.%d.%d.%d", ((ip >> 24) & 0xFF), ((ip >> 16) & 0xFF), ((ip >> 8) & 0xFF), (ip & 0xFF));
}

stock int IPStringToAddress(const char[] ip)
{
	char sExplodedAddress[4][4];
	ExplodeString(ip, ".", sExplodedAddress, 4, 4, false);

	int iIPAddress =
			(StringToInt(sExplodedAddress[0]) << 24) |
			(StringToInt(sExplodedAddress[1]) << 16) |
			(StringToInt(sExplodedAddress[2]) << 8) |
			StringToInt(sExplodedAddress[3]);

	return iIPAddress;
}

// Retrieves authid from STEAM_X:Y:Z and [U:1:123]
stock int SteamIDToAuth(const char[] sInput)
{
	char sSteamID[32];
	strcopy(sSteamID, sizeof(sSteamID), sInput);
	ReplaceString(sSteamID, 32, "\"", "");

	if (StrContains(sSteamID, "STEAM_") != -1)
	{
		ReplaceString(sSteamID, 32, "STEAM_", "");

		char parts[3][11];
		ExplodeString(sSteamID, ":", parts, 3, 11);

		// Let X, Y and Z constants be defined by the SteamID: STEAM_X:Y:Z.
		// Using the formula W=Z*2+Y, a SteamID can be converted:
		return StringToInt(parts[2]) * 2 + StringToInt(parts[1]);
	}
	else if (StrContains(sSteamID, "U:1:") != -1)
	{
		ReplaceString(sSteamID, 32, "[", "");
		ReplaceString(sSteamID, 32, "U:1:", "");
		ReplaceString(sSteamID, 32, "]", "");

		return StringToInt(sSteamID);
	}

	return 0;
}

// time formatting!
stock void FormatSeconds(float time, char[] newtime, int newtimesize, bool precise = true, bool nodecimal = false, bool full_hms = false)
{
	float fTempTime = time;

	if(fTempTime < 0.0)
	{
		fTempTime = -fTempTime;
	}

	int iRounded = RoundToFloor(fTempTime);
	int iSeconds = (iRounded % 60);
	float fSeconds = iSeconds + fTempTime - iRounded;

	char sSeconds[8];

	if (nodecimal)
	{
		FormatEx(sSeconds, 8, "%d", iSeconds);
	}
	else
	{
		FormatEx(sSeconds, 8, precise? "%.3f":"%.1f", fSeconds);
	}

	if (!full_hms && fTempTime < 60.0)
	{
		strcopy(newtime, newtimesize, sSeconds);
		FormatEx(newtime, newtimesize, "%s%s", (time < 0.0) ? "-":"", sSeconds);
	}
	else
	{
		int iMinutes = (iRounded / 60);

		if (!full_hms && fTempTime < 3600.0)
		{
			FormatEx(newtime, newtimesize, "%s%d:%s%s", (time < 0.0)? "-":"", iMinutes, (fSeconds < 10)? "0":"", sSeconds);
		}
		else
		{
			int iHours = (iMinutes / 60);
			iMinutes %= 60;

			FormatEx(newtime, newtimesize, "%s%d:%s%d:%s%s", (time < 0.0)? "-":"", iHours, (iMinutes < 10)? "0":"", iMinutes, (fSeconds < 10)? "0":"", sSeconds);
		}
	}
}

stock void FormatHUDSeconds(float time, char[] newtime, int newtimesize)
{
	float fTempTime = time;

	if(fTempTime < 0.0)
	{
		fTempTime = -fTempTime;
	}
	
	int iRounded = RoundToFloor(fTempTime);
	float fSeconds = (iRounded % 60) + fTempTime - iRounded;

	char sSeconds[8];
	FormatEx(sSeconds, 8, "%.02f", fSeconds);

	if(fTempTime < 60.0)
	{
		strcopy(newtime, newtimesize, sSeconds);
		FormatEx(newtime, newtimesize, "%s00:%s%s", (time < 0.0) ? "-":"", (fSeconds < 10) ? "0":"", sSeconds);
	}

	else
	{
		int iMinutes = (iRounded / 60);

		if(fTempTime < 3600.0)
		{
			FormatEx(newtime, newtimesize, "%s%s%d:%s%s", (time < 0.0)? "-":"", (fTempTime < 600)? "0":"", iMinutes, (fSeconds < 10)? "0":"", sSeconds);
		}

		else
		{
			iMinutes %= 60;
			int iHours = (iRounded / 3600);

			FormatEx(newtime, newtimesize, "%s%d:%s%d:%s%s", (time < 0.0)? "-":"", iHours, (iMinutes < 10)? "0":"", iMinutes, (fSeconds < 10)? "0":"", sSeconds);
		}
	}
}

stock bool GuessBestMapName(ArrayList maps, const char input[PLATFORM_MAX_PATH], char output[PLATFORM_MAX_PATH])
{
	if(maps.FindString(input) != -1)
	{
		output = input;
		return true;
	}

	char sCache[PLATFORM_MAX_PATH];

	for(int i = 0; i < maps.Length; i++)
	{
		maps.GetString(i, sCache, PLATFORM_MAX_PATH);

		if(StrContains(sCache, input) != -1)
		{
			output = sCache;
			return true;
		}
	}

	return false;
}

stock void GetTrackName(int client, int track, char[] output, int size)
{
	if (track == Track_Main)
	{
		FormatEx(output, size, "%T", "Track_Main", client);
	}
	else if (track >= Track_Bonus)
	{
		FormatEx(output, size, "%T", "Track_Bonus", client, track);
	}
	else //if (track < Track_Main)
	{
		FormatEx(output, size, "%T", "Track_Unknown", client);
	}
}

stock void GetZoneName(int client, int type, char[] output, int size)
{
	switch(type)
	{
		case Zone_Start:
		{
			FormatEx(output, size, "%T", "Zone_Start", client);
		}

		case Zone_End:
		{
			FormatEx(output, size, "%T", "Zone_End", client);
		}

		case Zone_Stage:
		{
			FormatEx(output, size, "%T", "Zone_Stage", client);
		}

		case Zone_Checkpoint:
		{
			FormatEx(output, size, "%T", "Zone_Checkpoint", client);
		}

		case Zone_Stop:
		{
			FormatEx(output, size, "%T", "Zone_Stop", client);
		}

		case Zone_Teleport:
		{
			FormatEx(output, size, "%T", "Zone_Teleport", client);
		}

		case Zone_AntiJump:
		{
			FormatEx(output, size, "%T", "Zone_AntiJump", client);
		}

		case Zone_AutoBhop:
		{
			FormatEx(output, size, "%T", "Zone_AutoBhop", client);
		}

		default:
		{
			FormatEx(output, size, "%T", "Zone_Mark", client);
		}
	}
}

stock int GetSpectatorTarget(int client, int fallback = -1)
{
	int target = fallback;

	if(IsClientObserver(client))
	{
		int iObserverMode = GetEntProp(client, Prop_Send, "m_iObserverMode");

		if (iObserverMode >= 3 && iObserverMode <= 7)
		{
			int iTarget = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");

			if (IsValidEntity(iTarget))
			{
				target = iTarget;
			}
		}
	}

	return target;
}

stock float GetAngleDiff(float current, float previous)
{
	float diff = current - previous;
	return diff - 360.0 * RoundToFloor((diff + 180.0) / 360.0);
}

// https://forums.alliedmods.net/showthread.php?t=216841
// Trims display string to specified max possible length, and appends "..." if initial string exceeds that length
stock void TrimDisplayString(const char[] str, char[] outstr, int outstrlen, int max_allowed_length)
{
	int count, finallen;
	for(int i = 0; str[i]; i++)
	{
		count += ((str[i] & 0xc0) != 0x80) ? 1 : 0;
		
		if(count <= max_allowed_length)
		{
			outstr[i] = str[i];
			finallen = i;
		}
	}
	
	outstr[finallen + 1] = '\0';
	
	if(count > max_allowed_length)
		Format(outstr, outstrlen, "%s...", outstr);
}

// taken from shavit's oryx
stock bool IsSurfing(int client)
{
	float fPosition[3];
	GetClientAbsOrigin(client, fPosition);

	float fEnd[3];
	fEnd = fPosition;
	fEnd[2] -= 64.0;

	float fMins[3];
	GetEntPropVector(client, Prop_Send, "m_vecMins", fMins);

	float fMaxs[3];
	GetEntPropVector(client, Prop_Send, "m_vecMaxs", fMaxs);

	Handle hTR = TR_TraceHullFilterEx(fPosition, fEnd, fMins, fMaxs, MASK_PLAYERSOLID, TRFilter_NoPlayers, client);

	if(TR_DidHit(hTR))
	{
		float fNormal[3];
		TR_GetPlaneNormal(hTR, fNormal);

		delete hTR;

		// If the plane normal's Z axis is 0.7 or below (alternatively, -0.7 when upside-down) then it's a surf ramp.
		// https://github.com/alliedmodders/hl2sdk/blob/92dcf04225a278b75170cc84917f04e98f5d08ec/game/server/physics_main.cpp#L1059
		// https://github.com/ValveSoftware/source-sdk-2013/blob/0d8dceea4310fde5706b3ce1c70609d72a38efdf/mp/src/game/server/physics_main.cpp#L1065

		return (-0.7 <= fNormal[2] <= 0.7);
	}

	delete hTR;

	return false;
}

stock bool TRFilter_NoPlayers(int entity, int mask, any data)
{
	return (entity != view_as<int>(data) || (entity < 1 || entity > MaxClients));
}

/**
 * Called before shavit-core processes the client's usercmd.
 * Before this is called, safety checks (fake/dead clients) happen.
 * Use this forward in modules that use OnPlayerRunCmd to avoid errors and unintended behavior.
 * If a module conflicts with buttons/velocity/angles being changed in shavit-core, this forward is recommended.
 * This forward will NOT be called if a player's timer is paused.
 * 
 * @param client					Client index.
 * @param buttons					Buttons sent in the usercmd.
 * @param impulse					Impulse sent in the usercmd.
 * @param vel						A vector that contains the player's desired movement. vel[0] is forwardmove, vel[1] is sidemove.
 * @param angles					The player's requested viewangles. They will not necessarily be applied as SRCDS itself won't accept every value.
 * @param status					The player's timer status.
 * @param track						The player's timer track.
 * @param style						The player's bhop style.
 * @param mouse						Mouse direction (x, y).
 * @return							Plugin_Continue to let shavit-core keep doing what it does, Plugin_Changed to pass different values.
 */
forward Action Shavit_OnUserCmdPre(int client, int &buttons, int &impulse, float vel[3], float angles[3], TimerStatus status, int track, int style, int mouse[2]);

/**
 * Called just before shavit-core adds time to a player's timer.
 * This is the forward you should use to modify the player's timer smoothly.
 * A good example use case is timescaling.
 *
 * @param client					Client index.
 * @param snapshot					A snapshot with the player's current timer. You cannot manipulate it here.
 * @param time						The time to be added to the player's timer.
 * @noreturn
 */
forward void Shavit_OnTimeIncrement(int client, timer_snapshot_t snapshot, float &time);

/**
 * Called just before shavit-core adds time to a player's timer.
 * This is the forward you should use to modify the player's timer smoothly.
 * A good example use case is timescaling.
 *
 * @param client					Client index.
 * @param snapshot					A snapshot with the player's current timer. Read above in shavit.inc for more information.
 * @param time						The time to be added to the player's timer.
 * @noreturn
 */
forward void Shavit_OnTimeIncrementPost(int client, float time);

/**
 * Called when a player's timer is about to start.
 * (WARNING: Will be called every tick when the player stands at the start zone!)
 *
 * @param client                    Client index.
 * @param track                     Timer track.
 * @return                          Plugin_Continue to do nothing or anything else to not start the timer.
 */
forward Action Shavit_OnStartPre(int client, int track);

/**
 * Called when a player's timer starts.
 * (WARNING: Will be called every tick when the player stands at the start zone!)
 *
 * @param client                    Client index.
 * @param track                     Timer track.
 * @return                          Unused.
 */
forward Action Shavit_OnStart(int client, int track);

/**
 * Called when player is in stage zone.
 * (NOTE: Bonus stage won't be called)
 * (WARNING: Will be called every tick when the player stands at the stage zone!)
 *
 * @param client					Client index.
 * @param stage 					Current stage number that client stands.
 * @noreturn
 */
forward Action Shavit_OnStage(int client, int stage);

/**
 * Called when player is in end zone.
 * (WARNING: Will be called every tick when the player stands at the stage zone!)
 *
 * @param client					Client index.
 * @noreturn
 */
forward Action Shavit_OnEndZone(int client);

/**
 * Called when a player uses the restart command.
 *
 * @param client                    Client index.
 * @param track                     Timer track.
 * @return                          Plugin_Continue to do nothing or anything else to not restart.
 */
forward Action Shavit_OnRestartPre(int client, int track);

/**
 * Called when a player uses the restart command.
 *
 * @param client					Client index.
 * @param track						Timer track.
 * @noreturn
 */
forward void Shavit_OnRestart(int client, int track);

/**
 * Called when a player uses the !end command.
 *
 * @param client					Client index.
 * @param track						Timer track.
 * @noreturn
 */
forward void Shavit_OnEnd(int client, int track);

/**
 * Called before a player's timer is stopped. (stop =/= finish a map)
 *
 * @param client					Client index.
 * @param track						Timer track.
 * @return							False to prevent the timer from stopping.
 */
forward bool Shavit_OnStopPre(int client, int track);

/**
 * Called when a player's timer stops. (stop =/= finish a map)
 *
 * @param client					Client index.
 * @param track						Timer track.
 * @noreturn
 */
forward void Shavit_OnStop(int client, int track);

/**
 * Called before a player finishes a map.
 *
 * @param client					Client index.
 * @param snapshot					A snapshot of the player's timer.
 * @return							Plugin_Continue to do nothing, Plugin_Changed to change the variables or anything else to stop the timer from finishing.
 */
forward Action Shavit_OnFinishPre(int client, timer_snapshot_t snapshot);

/**
 * Called when a player finishes a map. (touches the end zone)
 *
 * @param client					Client index.
 * @param style						Style the record was done on.
 * @param time						Record time.
 * @param jumps						Jumps amount.
 * @param strafes					Amount of strafes.
 * @param sync						Sync percentage (0.0 to 100.0) or -1.0 when not measured.
 * @param track						Timer track.
 * @param oldtime					The player's best time on the map before this finish.
 * @param avgvel					Player's average velocity throughout the run.
 * @param maxvel					Player's highest reached velocity.
 * @param timestamp					System time of when player finished.
 * @noreturn
 */
forward void Shavit_OnFinish(int client, int style, float time, int jumps, int strafes, float sync, int track, float& oldtime, float avgvel, float maxvel, int timestamp);

/**
 * Called when a player's timer paused.
 *
 * @param client					Client index.
 * @param track						Timer track.
 * @noreturn
 */
forward void Shavit_OnPause(int client, int track);

/**
 * Called when a player's timer resumed.
 *
 * @param client					Client index.
 * @param track						Timer track.
 * @noreturn
 */
forward void Shavit_OnResume(int client, int track);

/**
 * Called when a player changes their bhopstyle.
 * Note: Doesn't guarantee that the player is in-game or connected.
 *
 * @param client					Client index.
 * @param oldstyle					Old bhop style.
 * @param newstyle					New bhop style.
 * @param track						Timer track.
 * @param manual					Was the change manual, or assigned automatically?
 * @noreturn
 */
forward void Shavit_OnStyleChanged(int client, int oldstyle, int newstyle, int track, bool manual);

/**
 * Called when a player changes their bhop track.
 *
 * @param client					Client index.
 * @param oldtrack					Old bhop track.
 * @param newtrack					New bhop track.
 * @noreturn
 */
forward void Shavit_OnTrackChanged(int client, int oldtrack, int newtrack);

/**
 * Called when the styles configuration finishes loading and it's ready to load everything into the cache.
 *
 * @param styles					Amount of styles loaded.
 * @noreturn
 */
forward void Shavit_OnStyleConfigLoaded(int styles);

/**
 * Called when there's a successful connection to the database and it is ready to be used.
 * Called through shavit-core after migrations have been applied, and after the attempt to create the default `users` table.
 *
 * @noreturn
 */
forward void Shavit_OnDatabaseLoaded();

/**
 * Called when the chat messages configuration finishes loading and it's ready to load everything into the cache.
 *
 * @noreturn
 */
forward void Shavit_OnChatConfigLoaded();

/**
 * Called when a player enters a zone.
 *
 * @param client					Client index.
 * @param type						Zone type.
 * @param track						Zone track.
 * @param id						Zone ID.
 * @param entity					Zone trigger entity index.
 * @param data						Zone data if any.
 * @return							Plugin_Continue to continue deletion, anything else to prevent.
 */
forward Action Shavit_OnEnterZone(int client, int type, int track, int id, int entity, int data);

/**
 * Called when a player leaves a zone.
 *
 * @param client					Client index.
 * @param type						Zone type.
 * @param track						Zone track.
 * @param id						Zone ID.
 * @param entity					Zone trigger entity index.
 * @param data						Zone data if any.
 * @return							Plugin_Continue to continue deletion, anything else to prevent.
 */
forward Action Shavit_OnLeaveZone(int client, int type, int track, int id, int entity, int data);

/**
 * Called when a bot enters a stage zone.
 *
 * @param bot						Bot index.
 * @param stage						Stage id.
 * @noreturn
 */
forward void Shavit_OnEnterStageZone_Bot(int bot, int stage);

/**
 * Called when a bot enters a checkpoint zone.
 *
 * @param bot						Bot index.
 * @param cp						Checkpoint id.
 * @noreturn
 */
forward void Shavit_OnEnterCheckpointZone_Bot(int bot, int cp);

/**
 * Called after a player start timer.
 *
 * @param client					Client index.
 * @param style						Client style.
 * @param track						Client track.
 * @param speed						Client speed(3D).
 * @noreturn
 */
forward void Shavit_OnStartTimer_Post(int client, int style, int track, float speed);

/**
 * Called after a player start stage timer. (Track_Main only)
 *
 * @param client					Client index.
 * @param style						Client style.
 * @param stage						Client stage id.
 * @param speed						Client speed(3D).
 * @noreturn
 */
forward void Shavit_OnStageTimer_Post(int client, int style, int stage, float speed);

/**
 * Called when a player sm_back to a stage-zone.
 *
 * @param client					Client index.
 * @param stage						Stage number.
 * @param style						Style index.
 * @param stagetimer				Check client is not finishing the map, only stage timer.
 * @noreturn
 */
forward void Shavit_OnTeleportBackStagePost(int client, int stage, int style, bool stagetimer);

/**
 * Called when top left HUD updates.
 *
 * @param client					Client index that recieves the hud.
 * @param target					Target entity that is either the client or what the client is spectating.
 * @param topleft					Reference to the HUD buffer.
 * @param topleftlength				Max length of the topleft buffer.
 * @return							Plugin_Handled or Plugin_Stop to block the HUD message from appearing. Anything else to pass along new values.
 */
forward Action Shavit_OnTopLeftHUD(int client, int target, char[] topleft, int topleftlength);

/**
 * Called when a time offset is calculated
 *
 * @param client					Client index.
 * @param zonetype					Zone type (Zone_Start or Zone_End).
 * @param offset					Time offset from the given zone.
 * @param distance					Distance used in time offset.
 * @noreturn							
 */
forward void Shavit_OnTimeOffsetCalculated(int client, int zonetype, float offset, float distance);

/**
 * Called when a clients dynamic timescale has been changed.
 *
 * @param client					Client index.
 * @param oldtimescale				The old timescale value
 * @param newtimescale				The new timescale value
 * @noreturn
 */
forward void Shavit_OnTimescaleChanged(int client, float oldtimescale, float newtimescale);

/**
 * Called before the server & timer handle the ProcessMovement method.
 *
 * @param client					Client Index.
 * @noreturn
 */
forward void Shavit_OnProcessMovement(int client);

/**
 * Called After the server handles the ProcessMovement method, but before the timer handles the method.
 *
 * @param client					Client Index.
 * @noreturn
 */
forward void Shavit_OnProcessMovementPost(int client);

/**
 * Called when client use !deletemap.
 *
 * @param client					Client Index.
 * @param map						Map name. This map's data will be deleted
 * @noreturn
 */
forward void Shavit_OnDeleteMapData(int client, const char[] map);

/**
 * Called when client use !style(s).
 *
 * @param client					Client Index.
 * @param style						Style index shown.
 * @param wrtime					Current style's wr, handled by shavit-wr.
 * @noreturn
 */
forward void Shavit_OnCommandStyle(int client, int style, float& wrtime);

/**
 * Called when client use !wipeplayer.
 *
 * @param client					Client Index.
 * @param steamid					steamid.
 * @noreturn
 */
forward void Shavit_OnUserDeleteData(int client, int steamid);

/**
 * Called after client use !wipeplayer successfully.
 *
 * @param client					Client Index.
 * @param steamid					steamid.
 * @noreturn
 */
forward void Shavit_OnDeleteRestOfUserSuccess(int client, int steamid);

/**
 * Called when a player RTV's.
 * Requires shavit-mapchooser.
 *
 * @param client					Client index.
 * @noreturn
 */
forward void Shavit_OnRTV(int client);

/**
 * Called when a player UNRTV's.
 * Requires shavit-mapchooser.
 *
 * @param client					Client index.
 * @noreturn
 */
forward void Shavit_OnUnRTV(int client);

/**
 * Called when the map changes from an RTV.
 * Requires shavit-mapchooser.
 *
 * @noreturn
 */
forward void Shavit_OnSuccesfulRTV();

/**
 * Returns bhoptimer's database handle.
 * Call within Shavit_OnDatabaseLoaded. Safety is not guaranteed anywhere else!
 *
 * @return							Database handle.
 */
native Database Shavit_GetDatabase();

/**
 * Starts the timer for a player.
 * Will not teleport the player to anywhere, it's handled inside the mapzones plugin.
 *
 * @param client					Client index.
 * @param track						Timer track.
 * @noreturn
 */
native void Shavit_StartTimer(int client, int track);

/**
 * Sets the player's current location as their spawn location for the specified track.
 *
 * @param client					Client index.
 * @param track 					Timer track.
 * @param anglesonly 				Whether to save angles only.
 * @noreturn
 */
native void Shavit_SetStart(int client, int track, bool anglesonly);

/**
 * Deletes the player's current set start position for the specified track.
 *
 * @param client					Client index.
 * @param track 					Timer track.
 * @noreturn
 */
native void Shavit_DeleteSetStart(int client, int track);

/**
 * Restarts the timer for a player.
 * Will work as if the player just used sm_r.
 *
 * @param client					Client index.
 * @param track						Timer track.
 * @noreturn
 */
native void Shavit_RestartTimer(int client, int track);

/**
 * Stops the timer for a player.
 * Will not teleport the player to anywhere, it's handled inside the mapzones plugin.
 *
 * @param client					Client index.
 * @param bypass					Bypass call to Shavit_OnStopPre?
 * @return							True if the operation went through.
 */
native bool Shavit_StopTimer(int client, bool bypass = true);

/**
 * Deletes all map zones for the specified map.
 * Plugin will refresh if map is currently on.
 *
 * @param map						Map name.
 * @noreturn
 */
native void Shavit_Zones_DeleteMap(const char[] map);

/**
 * Changes a player's bhop style.
 *
 * @param client					Client index.
 * @param style						Style.
 * @param force						Ignore style permissions. This being true will bypass the `inaccessible` style setting as well.
 * @param manual					Is it a manual style change? (Was it caused by user interaction?)
 * @param noforward					Bypasses the call to `Shavit_OnStyleChanged`.
 * @return							False if failed due to lack of access, true otherwise.
 */
native bool Shavit_ChangeClientStyle(int client, int style, bool force = false, bool manual = false, bool noforward = false);

/**
 * Finishes the map for a player, with their current timer stats.
 * Will not teleport the player to anywhere, it's handled inside the mapzones plugin.
 *
 * @param client					Client index.
 * @param track						Timer track.
 * @noreturn
 */
native void Shavit_FinishMap(int client, int track);

/**
 * Retrieve a client's current time.
 *
 * @param client					Client index.
 * @return                          Current time.
 */
native float Shavit_GetClientTime(int client);

/**
 * Retrieve the client's track. (Track_Main/Track_Bonus etc..)
 *
 * @param client					Client index.
 * @return                          Timer track.
 */
native int Shavit_GetClientTrack(int client);

/**
 * Retrieve client jumps since timer start.
 *
 * @param client					Client index.
 * @return                          Current amount of jumps, 0 if timer is inactive.
 */
native int Shavit_GetClientJumps(int client);

/**
 * Retrieve a client's bhopstyle
 *
 * @param client					Client index.
 * @return                          Style.
 */
native int Shavit_GetBhopStyle(int client);

/**
 * Retrieve a client's timer status
 *
 * @param client					Client index.
 * @return                          See TimerStatus enum.
 */
native TimerStatus Shavit_GetTimerStatus(int client);

/**
 * Retrieve the map's bonus numbers.
 *
 * @return                          bonus numbers.
 */
native int Shavit_GetMapBonuses();

/**
 * Retrieve the map's stage numbers.
 *
 * @return                          stage numbers.
 */
native int Shavit_GetMapStages();

/**
 * Retrieve the map's checkpoint zones numbers.
 *
 * @return                          checkpoint zones numbers.
 */
native int Shavit_GetMapCheckpoints();

/**
 * Retrieve the amount of strafes done since the timer started.
 * Will return 0 if timer isn't running.
 *
 * @param client					Client index.
 * @return                          Amount of strafes since timer start.
 */
native int Shavit_GetStrafeCount(int client);

/**
 * Retrieve strafe sync since timer start.
 * Will return 0.0 if timer isn't running or -1.0 when not measured.
 *
 * @param client					Client index.
 * @return                          Amount of strafes since timer start.
 */
native float Shavit_GetSync(int client);

/**
 * Checks if a mapzone exists.
 *
 * @param type						Mapzone type.
 * @param track						Mapzone track, -1 to ignore track.
 * @return							Boolean value.
 */
native bool Shavit_ZoneExists(int type, int track);

/**
 * Checks if a player is inside a mapzone.
 *
 * @param client					Client index.
 * @param type						Mapzone type.
 * @param track						Mapzone track, -1 to ignore track.
 * @return							Boolean value.
 */
native bool Shavit_InsideZone(int client, int type, int track);

/**
 * Get player's inside zone id.
 *
 * @param client					Client index.
 * @param type						Mapzone type.
 * @param track						Mapzone track, -1 to ignore track.
 * @return							Zone id, -1 if not exist.
 */
native int Shavit_InsideZoneGetID(int client, int type, int track);

/**
 * Get player's inside zone type.
 *
 * @param client					Client index.
 * @param track						Mapzone track, -1 to ignore track.
 * @return							Zone type, -1 if not exist.
 */
native int Shavit_InsideZoneGetType(int client, int track);

/**
 * Gets the specified zone's data.
 *
 * @param zoneid					ID of the zone we query the data of.
 * @return							Zone data. 0 if none is specified.
 */
native int Shavit_GetZoneData(int zoneid);

/**
 * Gets the specified zone's flags.
 *
 * @param zoneid					ID of the zone we query the flags of.
 * @return							Zone flags. 0 if none is specified.
 */
native int Shavit_GetZoneFlags(int zoneid);

/**
 * Checks if the map is linear.
 *
 * @return							Boolean value.
 */
native bool Shavit_IsLinearMap();

/**
 * Checks if a player is in the process of creating a mapzone.
 *
 * @param client					Client index.
 * @return							Boolean value.
 */
native bool Shavit_IsClientCreatingZone(int client);

/**
 * Pauses a player's timer.
 *
 * @param client					Client index.
 * @noreturn
 */
native void Shavit_PauseTimer(int client);

/**
 * Resumes a player's timer.
 *
 * @param client					Client index.
 * @param teleport					Should the player be teleported to their location prior to saving?
 * @noreturn
 */
native void Shavit_ResumeTimer(int client, bool teleport = false);

/**
 * Gets a players zone offset.
 *
 * @param client					Client index.
 * @param teleport					Zone type (Zone_Start or Zone_End).
 * @return							Zone offset fraction if any for the given zone type.
 */
native float Shavit_GetZoneOffset(int client, int zonetype);

/**
 * Gets distance of a players distance offset given a zone.
 *
 * @param client					Client index.
 * @param teleport					Zone type  (Zone_Start or Zone_End).
 * @return 							Distance offset if any for the given zone type/
 */
native float Shavit_GetDistanceOffset(int client, int zonetype);

/**
 * Gets a value from the style config for the given style
 * e.g. Shavit_GetStyleSetting(Shavit_GetBhopStyle(client), "TAS", sBuffer, 2);
 *
 * @param style						Style index.
 * @param key						Style key to retreive.
 * @param value						Value buffer to store the return value in.
 * @param maxlength					Max length of the value buffer, cannot exceed 256.
 *
 * @return 							True if key was found, false otherwise.
 */
native bool Shavit_GetStyleSetting(int style, const char[] key, char[] value, int maxlength);

/**
 * Gets an int value from the style config for the given style. Returns 0 if key is not found.
 * e.g. Shavit_GetStyleSettingInt(Shavit_GetBhopStyle(client), "TAS");
 *
 * @param style						Style index.
 * @param key						Style key to retreive.
 *
 * @return 							Integer value if found, 0 if key is missing.
 */
native int Shavit_GetStyleSettingInt(int style, const char[] key);

/**
 * Gets the bool value from the style config for the given style. Returns false if key is not found.
 * e.g. if(Shavit_GetStyleSettingBool(Shavit_GetBhopStyle(client), "TAS"))
 *
 * @param style						Style index.
 * @param key						Style key to retreive.
 *
 * @return 							bool value if found, false if key is missing.
 */
native bool Shavit_GetStyleSettingBool(int style, const char[] key);

/**
 * Gets a float value from the style config for the given style. Returns 0.0 if key is not found
 * e.g. Shavit_GetStyleSettingFloat(Shavit_GetBhopStyle(client), "speed");
 *
 * @param style						Style index.
 * @param key						Style key to retreive.
 *
 * @return 							Float value if found, 0.0 if key is missing.
 */
native float Shavit_GetStyleSettingFloat(int style, const char[] key);

/**
 * Checks if the given key exists for that style
 * e.g. Shavit_HasStyleSetting(Shavit_GetBhopStyle(client), "tas");
 *
 * @param style						Style index.
 * @param key						Style key to retreive.
 *
 * @return 							True if found.
 */
native bool Shavit_HasStyleSetting(int style, const char[] key);

/**
 * Set the style setting to the given float value
 *
 * @param style						Style index.
 * @param key						Style key to set.
 * @param value						Value to set the style key to.
 * @param replace					Should the value be set if the given key already exists.
 *
 * @return 							True on success, false on failure.
 */
native bool Shavit_SetStyleSettingFloat(int style, const char[] key, float value, bool replace = true);

/**
 * Set the style setting to the given bool value
 *
 * @param style						Style index.
 * @param key						Style key to set.
 * @param value						Value to set the style key to.
 * @param replace					Should the value be set if the given key already exists.
 *
 * @return 							True on success, false on failure.
 */
native bool Shavit_SetStyleSettingBool(int style, const char[] key, bool value, bool replace = true);

/**
 * Set the style setting to the given int value
 *
 * @param style						Style index.
 * @param key						Style key to set.
 * @param value						Value to set the style key to.
 * @param replace					Should the value be set if the given key already exists.
 *
 * @return 							True on success, false on failure.
 */
native bool Shavit_SetStyleSettingInt(int style, const char[] key, int value, bool replace = true);

/**
 * Saves the style related strings on string references.
 *
 * @param style						Style index.
 * @param stringtype				String type to grab.
 * @param StyleStrings				Reference to the string buffer.
 * @param size						Max length for the buffer.
 * @return							SP_ERROR_NONE on success, anything else on failure.
 */
native int Shavit_GetStyleStrings(int style, int stringtype, char[] StyleStrings, int size);

/**
 * Saves the style related strings on string references.
 *
 * @param style                     Style index.
 * @param strings                   Reference to a stylestrings_t.
 * @param size                      Max length for the buffer.
 * @return                          SP_ERROR_NONE on success, anything else on failure.
 */
native int Shavit_GetStyleStringsStruct(int style, any[] strings, int size = sizeof(stylestrings_t));

/**
 * Retrieves the amount of styles in the server.
 *
 * @return							Amount of styles or -1 if there's an error.
 */
native int Shavit_GetStyleCount();

/**
 * Gets an array with style IDs in their configured menu ordering as specified in the styles config.
 *
 * @param arr						Reference to array to fill with style IDs.
 * @param size						Array size.
 * @noreturn
 */
native void Shavit_GetOrderedStyles(int[] arr, int size);

/**
 * Saves chat related strings on string references.
 *
 * @param stringtype				String type to grab.
 * @param ChatStrings				Reference to the string buffer.
 * @param size						Max length for the buffer.
 * @return							SP_ERROR_NONE on success, anything else on failure.
 */
native int Shavit_GetChatStrings(int stringtype, char[] ChatStrings, int size);

/**
 * Saves chat related strings on string references.
 *
 * @param strings                   Reference to a chatstrings_t.
 * @param size                      Size of chatstrings_t.
 * @return                          SP_ERROR_NONE on success, anything else on failure.
 */
native int Shavit_GetChatStringsStruct(any[] strings, int size = sizeof(chatstrings_t));

/**
 * Sets practice mode on a client.
 * Practice mode means that the client's records will not be saved, just like unranked mode, but for ranked styles.
 * Intended to be used by checkpoints.
 *
 * @param client					Client index.
 * @param practice					Enable or disable practice mode.
 * @noreturn
 */
native void Shavit_SetPracticeMode(int client, bool practice);

/**
 * Gets a client's practice mode status.
 *
 * @param client					Client index.
 * @return							Practice mode status.
 */
native bool Shavit_IsPracticeMode(int client);

/**
 * Save a client's timer into a snapshot.
 * See the timer_snapshot_t enum struct.
 *
 * @param client					Client index.
 * @param snapshot					Full snapshot of the client's timer.
 * @param size						Size of the snapshot buffer, e.g sizeof(timer_snapshot_t)
 * @noreturn
 */
native void Shavit_SaveSnapshot(int client, any[] snapshot, int size = sizeof(timer_snapshot_t));

/**
 * Restores the client's timer from a snapshot.
 *
 * @param client					Client index.
 * @param snapshot					Full snapshot of the client's timer.
 * @param size						Size of the snapshot buffer, e.g sizeof(timer_snapshot_t)
 * @noreturn
 */
native void Shavit_LoadSnapshot(int client, any[] snapshot, int size = sizeof(timer_snapshot_t));

/**
 * Use this native to stop the click sound that plays upon chat messages.
 * Call it before each Shavit_PrintToChat().
 *
 * @noreturn
 */
native void Shavit_StopChatSound();

/**
 * Retrieves style access for a player.
 *
 * @param client					Client index.
 * @param style						Style.
 * @return							Boolean value.
 */
native bool Shavit_HasStyleAccess(int client, int style);

/**
 * Determines whether a client's timer is paused or not.
 *
 * @param client					Client index.
 * @return							Boolean value.
 */
native bool Shavit_IsPaused(int client);

/**
 * Determines whether a client is able to pause their timer or not.
 *
 * @param client					Client index.
 * @return							Flags which are reasons to allow pausing or not, see CPR enum. 0 if toggling pause is allowed.
 */
native int Shavit_CanPause(int client);

/**
 * Use this native when printing anything in chat if it's related to the timer.
 * This native will auto-assign colors and a chat prefix.
 *
 * @param client					Client index.
 * @param format					Formatting rules.
 * @param any						Variable number of format parameters.
 * @return							PrintToChat()
 */
native int Shavit_PrintToChat(int client, const char[] format, any ...);

/**
 * Use this native when printing anything in chat if it's related to the timer.
 * This native will auto-assign colors and a chat prefix.
 *
 * @param format					Formatting rules.
 * @param any						Variable number of format parameters.
 * @noreturn
 */
native void Shavit_PrintToChatAll(const char[] format, any ...);

/**
 * Logs an entry to bhoptimer's log file.
 * (addons/sourcemod/logs/shavit.log)
 *
 * @param format					Formatting rules.
 * @param any						Variable number of format parameters.
 * @noreturn
 */
native void Shavit_LogMessage(const char[] format, any ...);

/**
 * Gets the average velocity of a player.
 * Average calculation: avg += (vel - avg) / frames
 *
 * @param client					Client index
 * @return							Client's average velocity
 */
native float Shavit_GetAvgVelocity(int client);

/**
 * Gets the max velocity of a player.
 *
 * @param client					Client index
 * @return							Client's highest velocity
 */
native float Shavit_GetMaxVelocity(int client);

/**
 * Sets the average velocity of a player.
 *
 * @param client					Client index
 * @param vel						Average velocity
 * @noreturn
 */
native void Shavit_SetAvgVelocity(int client, float vel);

/**
 * Sets the max velocity of a player.
 *
 * @param client					Client index
 * @param vel						Max velocity
 * @noreturn
 */
native void Shavit_SetMaxVelocity(int client, float vel);

/**
 * Gets the current stage of a player.
 *
 * @param client					Client index
 * @return							Client's current stage
 */
native int Shavit_GetCurrentStage(int client);

/**
 * Gets the current cp of a player.(Note: this is mapzone's checkpoint)
 *
 * @param client					Client index
 * @return							Client's current cp
 */
native int Shavit_GetCurrentCP(int client);

/**
 * Gets the last stage of a player.
 *
 * @param client					Client index
 * @return							Client's last stage
 */
native int Shavit_GetLastStage(int client);

/**
 * Gets the last cp of a player.(Note: this is mapzone's checkpoint)
 *
 * @param client					Client index
 * @return							Client's last cp
 */
native int Shavit_GetLastCP(int client);

/**
 * Sets the current stage of a player.
 *
 * @param client					Client index
 * @param stage						Stage index
 * @noreturn
 */
native void Shavit_SetCurrentStage(int client, int stage);

/**
 * Sets the current cp of a player.(Note: this is mapzone's checkpoint)
 *
 * @param client					Client index
 * @param cp						Checkpoint index
 * @noreturn
 */
native void Shavit_SetCurrentCP(int client, int cp);

/**
 * Sets the last stage of a player.
 *
 * @param client					Client index
 * @param stage						Stage index
 * @noreturn
 */
native void Shavit_SetLastStage(int client, int stage);

/**
 * Sets the last cp of a player.(Note: this is mapzone's checkpoint)
 *
 * @param client					Client index
 * @param cp						Checkpoint index
 * @noreturn
 */
native void Shavit_SetLastCP(int client, int cp);

/**
 * Gets a client's StageTimer status (record single stage, not record whole map)
 *
 * @param client					Client index.
 * @return							StageTimer status.
 */
native bool Shavit_IsStageTimer(int client);

/**
 * Sets stage timer on a client.
 *
 * @param client					Client index.
 * @param enable					Enable or disable stage timer.
 * @noreturn
 */
native void Shavit_SetStageTimer(int client, bool enable);

/**
 * Gets the leave stage time of a player.
 *
 * @param client					Client index
 * @return							Client's leave stage time.
 */
native float Shavit_GetLeaveStageTime(int client);

/**
 * Sets the leave stage time of a player.
 *
 * @param client					Client index
 * @param time						Leave stage time.
 * @noreturn
 */
native void Shavit_SetLeaveStageTime(int client, float time);

/**
 * Gets client if they're on teleporting.
 *
 * @param client					Client index.
 * @return							True if teleporting.
 */
native bool Shavit_IsTeleporting(int client);

/**
 * Sets the clients dynamic timescale. -1.0 to use the timescale of the client's style.
 * Note: Values above 1.0 won't scale into the replay bot.
 *
 * @param client					Client index
 * @param scale						New timescale
 *
 * @noreturn
 */
native void Shavit_SetClientTimescale(int client, float scale);

/**
 * Gets the clients dynamic timescale, or -1.0 if unset.
 *
 * @param client					Client index
 *
 * @return							Client's dynamic timescale
 */
native float Shavit_GetClientTimescale(int client);

/**
 * Something to be used by the checkpoint plugin to trigger updating laggedmovement.
 *
 * @param client                    Client index
 * @param user_timescale            Whether to use fTimescale as a multiplier for laggedmovement too.
 *
 * @noreturn
 */
native void Shavit_UpdateLaggedMovement(int client, bool user_timescale=true);



public SharedPlugin __pl_shavit =
{
	name = "shavit",
	// SM bug? commented until it's fixed
	// file = "shavit-core.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_shavit_SetNTVOptional()
{
	MarkNativeAsOptional("Shavit_CanPause");
	MarkNativeAsOptional("Shavit_ChangeClientStyle");
	MarkNativeAsOptional("Shavit_FinishMap");
	MarkNativeAsOptional("Shavit_FormatChat");
	MarkNativeAsOptional("Shavit_GetBhopStyle");
	MarkNativeAsOptional("Shavit_GetChatStrings");
	MarkNativeAsOptional("Shavit_GetChatStringsStruct");
	MarkNativeAsOptional("Shavit_GetClientJumps");
	MarkNativeAsOptional("Shavit_GetClientTime");
	MarkNativeAsOptional("Shavit_GetClientTrack");
	MarkNativeAsOptional("Shavit_GetDatabase");
	MarkNativeAsOptional("Shavit_GetOrderedStyles");
	MarkNativeAsOptional("Shavit_GetStrafeCount");
	MarkNativeAsOptional("Shavit_GetStyleCount");
	MarkNativeAsOptional("Shavit_GetStyleSetting");
	MarkNativeAsOptional("Shavit_GetStyleSettingInt");
	MarkNativeAsOptional("Shavit_GetStyleSettingFloat");
	MarkNativeAsOptional("Shavit_GetStyleSettingBool");
	MarkNativeAsOptional("Shavit_HasStyleSetting");
	MarkNativeAsOptional("Shavit_GetStyleStrings");
	MarkNativeAsOptional("Shavit_GetStyleStringsStruct");
	MarkNativeAsOptional("Shavit_GetSync");
	MarkNativeAsOptional("Shavit_GetZoneOffset");
	MarkNativeAsOptional("Shavit_GetDistanceOffset");
	MarkNativeAsOptional("Shavit_GetTimerStatus");
	MarkNativeAsOptional("Shavit_GetZoneData");
	MarkNativeAsOptional("Shavit_GetZoneFlags");
	MarkNativeAsOptional("Shavit_HasStyleAccess");
	MarkNativeAsOptional("Shavit_InsideZone");
	MarkNativeAsOptional("Shavit_InsideZoneGetID");
	MarkNativeAsOptional("Shavit_InsideZoneGetType");
	MarkNativeAsOptional("Shavit_IsLinearMap");
	MarkNativeAsOptional("Shavit_IsClientCreatingZone");
	MarkNativeAsOptional("Shavit_IsPaused");
	MarkNativeAsOptional("Shavit_IsPracticeMode");
	MarkNativeAsOptional("Shavit_LoadSnapshot");
	MarkNativeAsOptional("Shavit_PauseTimer");
	MarkNativeAsOptional("Shavit_PrintToChat");
	MarkNativeAsOptional("Shavit_PrintToChatAll");
	MarkNativeAsOptional("Shavit_RestartTimer");
	MarkNativeAsOptional("Shavit_ResumeTimer");
	MarkNativeAsOptional("Shavit_SaveSnapshot");
	MarkNativeAsOptional("Shavit_SetPracticeMode");
	MarkNativeAsOptional("Shavit_StartTimer");
	MarkNativeAsOptional("Shavit_SetStart");
	MarkNativeAsOptional("Shavit_DeleteSetStart");
	MarkNativeAsOptional("Shavit_StopChatSound");
	MarkNativeAsOptional("Shavit_StopTimer");
	MarkNativeAsOptional("Shavit_ZoneExists");
	MarkNativeAsOptional("Shavit_Zones_DeleteMap");
	MarkNativeAsOptional("Shavit_GetClientTimescale");
	MarkNativeAsOptional("Shavit_SetClientTimescale");
	MarkNativeAsOptional("Shavit_GetAvgVelocity");
	MarkNativeAsOptional("Shavit_GetMaxVelocity");
	MarkNativeAsOptional("Shavit_SetAvgVelocity");
	MarkNativeAsOptional("Shavit_SetMaxVelocity");
	MarkNativeAsOptional("Shavit_UpdateLaggedMovement");
	MarkNativeAsOptional("Shavit_GetCurrentStage");
	MarkNativeAsOptional("Shavit_GetCurrentCP");
	MarkNativeAsOptional("Shavit_GetLastStage");
	MarkNativeAsOptional("Shavit_GetLastCP");
	MarkNativeAsOptional("Shavit_SetCurrentStage");
	MarkNativeAsOptional("Shavit_SetCurrentCP");
	MarkNativeAsOptional("Shavit_SetLastStage");
	MarkNativeAsOptional("Shavit_SetLastCP");
	MarkNativeAsOptional("Shavit_IsStageTimer");
	MarkNativeAsOptional("Shavit_SetStageTimer");
	MarkNativeAsOptional("Shavit_GetLeaveStageTime");
	MarkNativeAsOptional("Shavit_SetLeaveStageTime");
	MarkNativeAsOptional("Shavit_IsTeleporting");
	MarkNativeAsOptional("Shavit_SetStyleSetting");
	MarkNativeAsOptional("Shavit_SetStyleSettingFloat");
	MarkNativeAsOptional("Shavit_SetStyleSettingBool");
	MarkNativeAsOptional("Shavit_SetStyleSettingInt");
	MarkNativeAsOptional("Shavit_GetMapBonuses");
	MarkNativeAsOptional("Shavit_GetMapStages");
	MarkNativeAsOptional("Shavit_GetMapCheckpoints");
}
#endif
