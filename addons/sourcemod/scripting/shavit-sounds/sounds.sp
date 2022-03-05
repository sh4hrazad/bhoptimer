static ArrayList gA_FirstSounds = null;
static ArrayList gA_PersonalSounds = null;
static ArrayList gA_WorldSounds = null;
static ArrayList gA_WorstSounds = null;
static ArrayList gA_NoImprovementSounds = null;
static ArrayList gA_BonusSounds = null;
static ArrayList gA_WRCPSounds = null;
static StringMap gSM_RankSounds = null;



// ======[ EVENTS ]======

void OnPluginStart_InitSoundsCache()
{
	int cells = ByteCountToCells(PLATFORM_MAX_PATH);
	gA_FirstSounds = new ArrayList(cells);
	gA_PersonalSounds = new ArrayList(cells);
	gA_WorldSounds = new ArrayList(cells);
	gA_WorstSounds = new ArrayList(cells);
	gA_NoImprovementSounds = new ArrayList(cells);
	gA_BonusSounds = new ArrayList(cells);
	gA_WRCPSounds = new ArrayList(cells);
	gSM_RankSounds = new StringMap();
}

void OnMapStart_ClearSoundsCache()
{
	gA_FirstSounds.Clear();
	gA_PersonalSounds.Clear();
	gA_WorldSounds.Clear();
	gA_WorstSounds.Clear();
	gA_NoImprovementSounds.Clear();
	gA_BonusSounds.Clear();
	gA_WRCPSounds.Clear();
	gSM_RankSounds.Clear();
}

void OnMapStart_LoadSounds()
{
	char sFile[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sFile, PLATFORM_MAX_PATH, "configs/shavit-sounds.cfg");

	File fFile = OpenFile(sFile, "r"); // readonly, unless i implement in-game editing

	if(fFile == null && gCV_Enabled.BoolValue)
	{
		SetFailState("Cannot open \"configs/shavit-sounds.cfg\". Make sure this file exists and that the server has read permissions to it.");
	}
	else
	{
		char sLine[PLATFORM_MAX_PATH*2];
		char sDownloadString[PLATFORM_MAX_PATH];

		while(fFile.ReadLine(sLine, PLATFORM_MAX_PATH*2))
		{
			TrimString(sLine);

			if(sLine[0] != '\"')
			{
				continue;
			}

			ReplaceString(sLine, PLATFORM_MAX_PATH*2, "\"", "");

			char sExploded[2][PLATFORM_MAX_PATH];
			ExplodeString(sLine, " ", sExploded, 2, PLATFORM_MAX_PATH);

			if(StrEqual(sExploded[0], "first"))
			{
				gA_FirstSounds.PushString(sExploded[1]);
			}
			else if(StrEqual(sExploded[0], "personal"))
			{
				gA_PersonalSounds.PushString(sExploded[1]);
			}
			else if(StrEqual(sExploded[0], "world"))
			{
				gA_WorldSounds.PushString(sExploded[1]);
			}
			else if(StrEqual(sExploded[0], "worst"))
			{
				gA_WorstSounds.PushString(sExploded[1]);
			}
			else if(StrEqual(sExploded[0], "worse") || StrEqual(sExploded[0], "noimprovement"))
			{
				gA_NoImprovementSounds.PushString(sExploded[1]);
			}
			else if(StrEqual(sExploded[0], "bonus"))
			{
				gA_BonusSounds.PushString(sExploded[1]);
			}
			else if(StrEqual(sExploded[0], "wrcp"))
			{
				gA_WRCPSounds.PushString(sExploded[1]);
			}
			else
			{
				gSM_RankSounds.SetString(sExploded[0], sExploded[1]);
			}

			if(PrecacheSound(sExploded[1], true))
			{
				FormatEx(sDownloadString, PLATFORM_MAX_PATH, "sound/%s", sExploded[1]);
				AddFileToDownloadsTable(sDownloadString);
			}
			else
			{
				LogError("\"sound/%s\" could not be accessed.", sExploded[1]);
			}
		}
	}

	delete fFile;
}

void Shavit_OnFinish_Post_PlaySounds_Bonus(int client)
{
	char sSound[PLATFORM_MAX_PATH];
	GetSound(gA_BonusSounds, sSound);

	if(StrContains(sSound, ".") != -1)
	{
		PlayEventSound(client, true, sSound);
	}
}

void Shavit_OnFinish_Post_PlaySounds_Main(int client, int style, int rank, int overwrite)
{
	char sSound[PLATFORM_MAX_PATH];
	bool bTop10 = rank >= 2 && rank <= 10;

	if(Shavit_GetRecordAmount(style, Track_Main) <= 1)
	{
		GetSound(gA_FirstSounds, sSound);
	}
	else if(rank == 1)
	{
		GetSound(gA_WorldSounds, sSound);
	}
	else if(bTop10 && overwrite > 0)
	{
		if(gSM_RankSounds.Size != 0)
		{
			char sRank[8];
			IntToString(rank, sRank, 8);
			gSM_RankSounds.GetString(sRank, sSound, PLATFORM_MAX_PATH);
		}
	}
	else if(overwrite > 0)
	{
		GetSound(gA_PersonalSounds, sSound);
	}
	else
	{
		GetSound(gA_NoImprovementSounds, sSound);
	}

	if(StrContains(sSound, ".") != -1) // file has an extension?
	{
		PlayEventSound(client, true, sSound);
	}
}

void Shavit_OnWorstRecord_PlaySounds(int client, int style, int track)
{
	if(Shavit_GetRecordAmount(style, track) >= gCV_MinimumWorst.IntValue)
	{
		char sSound[PLATFORM_MAX_PATH];
		GetSound(gA_WorstSounds, sSound);

		if(StrContains(sSound, ".") != -1)
		{
			PlayEventSound(client, false, sSound);
		}
	}
}

void Shavit_OnWRCP_PlaySounds(int client)
{
	char sSound[PLATFORM_MAX_PATH];
	GetSound(gA_WRCPSounds, sSound);

	if(StrContains(sSound, ".") != -1)
	{
		PlayEventSound(client, true, sSound);
	}
}



// ======[ PRIVATE ]======

static void GetSound(ArrayList aSounds, char path[PLATFORM_MAX_PATH])
{
	if(aSounds.Length != 0)
	{
		aSounds.GetString(GetRandomInt(0, aSounds.Length - 1), path, sizeof(path));
	}
}

static void PlayEventSound(int client, bool everyone, char sound[PLATFORM_MAX_PATH])
{
	int clients[MAXPLAYERS+1];
	int count = 0;

	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsValidClient(i) || (gB_HUD && (Shavit_GetHUDSettings(i) & HUD_NOSOUNDS) > 0))
		{
			continue;
		}

		if (everyone || i == client || GetSpectatorTarget(i) == client)
		{
			clients[count++] = i;
		}
	}

	Action result = Plugin_Continue;
	Call_OnPlaySound(client, sound, PLATFORM_MAX_PATH, clients, count, result);

	if(result != Plugin_Continue && result != Plugin_Changed)
	{
		return;
	}

	if(count > 0)
	{
		EmitSound(clients, count, sound);
	}
}