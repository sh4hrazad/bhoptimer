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

void Shavit_OnFinish_PlaySounds(int client, float time, int track, float oldtime)
{
	if(track != Track_Main && gA_BonusSounds.Length != 0)
	{
		char sSound[PLATFORM_MAX_PATH];
		gA_BonusSounds.GetString(GetRandomInt(0, gA_BonusSounds.Length - 1), sSound, PLATFORM_MAX_PATH);

		if(StrContains(sSound, ".") != -1)
		{
			PlayEventSound(client, true, sSound);
		}
	}
	else if(oldtime != 0.0 && time > oldtime && gA_NoImprovementSounds.Length != 0)
	{
		char sSound[PLATFORM_MAX_PATH];
		gA_NoImprovementSounds.GetString(GetRandomInt(0, gA_NoImprovementSounds.Length - 1), sSound, PLATFORM_MAX_PATH);

		PlayEventSound(client, true, sSound);
	}
}

void Shavit_OnFinish_Post_PlaySounds(int client, int style, float time, int rank, int overwrite, int track)
{
	float fOldTime = Shavit_GetClientPB(client, style, track);

	char sSound[PLATFORM_MAX_PATH];
	bool bEveryone = true;
	bool bTop10 = rank >= 2 && rank <= 10;

	if(gA_FirstSounds.Length != 0 && overwrite == 1)
	{
		gA_FirstSounds.GetString(GetRandomInt(0, gA_FirstSounds.Length - 1), sSound, PLATFORM_MAX_PATH);
	}
	else if(gA_WorldSounds.Length != 0 && rank == 1)
	{
		gA_WorldSounds.GetString(GetRandomInt(0, gA_WorldSounds.Length - 1), sSound, PLATFORM_MAX_PATH);
	}
	else if(bTop10)
	{
		char sRank[8];
		IntToString(rank, sRank, 8);
		gSM_RankSounds.GetString(sRank, sSound, PLATFORM_MAX_PATH);
	}
	else if(gA_PersonalSounds.Length != 0 && (time < fOldTime || fOldTime == 0.0))
	{
		gA_PersonalSounds.GetString(GetRandomInt(0, gA_PersonalSounds.Length - 1), sSound, PLATFORM_MAX_PATH);
	}

	if(StrContains(sSound, ".") != -1) // file has an extension?
	{
		PlayEventSound(client, bEveryone, sSound);
	}
}

void Shavit_OnWorstRecord_PlaySounds(int client, int style, int track)
{
	if(gA_WorstSounds.Length != 0 && Shavit_GetRecordAmount(style, track) >= gCV_MinimumWorst.IntValue)
	{
		char sSound[PLATFORM_MAX_PATH];
		gA_WorstSounds.GetString(GetRandomInt(0, gA_WorstSounds.Length - 1), sSound, PLATFORM_MAX_PATH);

		if(StrContains(sSound, ".") != -1)
		{
			PlayEventSound(client, false, sSound);
		}
	}
}

void Shavit_OnWRCP_PlaySounds(int client)
{
	if(gA_WRCPSounds.Length != 0)
	{
		char sSound[PLATFORM_MAX_PATH];
		gA_WRCPSounds.GetString(GetRandomInt(0, gA_WRCPSounds.Length - 1), sSound, PLATFORM_MAX_PATH);

		if(StrContains(sSound, ".") != -1)
		{
			PlayEventSound(client, true, sSound);
		}
	}
}



// ======[ PRIVATE ]======

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