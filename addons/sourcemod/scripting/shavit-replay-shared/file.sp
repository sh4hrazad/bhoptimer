// History of REPLAY_FORMAT_SUBVERSION:
// 0x01: standard origin[3], angles[2], and buttons
// 0x02: flags added movetype added
// 0x03: integrity stuff: style, track, and map added to header. preframe count added (unimplemented until later though)
// 0x04: steamid/accountid written as a 32-bit int instead of a string
// 0x05: postframes & fTickrate added
// 0x06: mousexy and vel added
// 0x07: fixed iFrameCount because postframes were included in the value when they shouldn't be
// 0x08: added zone-offsets to header

// =====[ CONSTANTS ]=====
#define REPLAY_FORMAT_V2 "{SHAVITREPLAYFORMAT}{V2}"
#define REPLAY_FORMAT_FINAL "{SHAVITREPLAYFORMAT}{FINAL}"
#define REPLAY_FORMAT_SUBVERSION 0x08
#define REPLAY_FORMAT_CURRENT_USED_CELLS 8
#define FRAMES_PER_WRITE 100 // amounts of frames to write per read/write call



// =====[ STOCKS ]=====

stock void GetReplayFilePath(int style, int track, const char[] mapname, char sPath[PLATFORM_MAX_PATH])
{
	char sTrack[4];
	FormatEx(sTrack, 4, "_%d", track);
	FormatEx(sPath, PLATFORM_MAX_PATH, "%s/%d/%s%s.replay", gS_ReplayFolder, style, mapname, (track > 0)? sTrack:"");
}

stock bool LoadReplay(frame_cache_t cache, int style, int track, const char[] path, const char[] mapname)
{
	bool success = false;
	replay_header_t header;
	File fFile = ReadReplayHeader(path, header, style, track);

	if (fFile != null)
	{
		if (header.iReplayVersion > REPLAY_FORMAT_SUBVERSION)
		{
			// not going to try and read it
		}
		else if (header.iReplayVersion < 0x03 || (StrEqual(header.sMap, mapname, false) && header.iStyle == style && header.iTrack == track))
		{
			success = ReadReplayFrames(fFile, header, cache);
		}

		delete fFile;
	}

	return success;
}

stock bool ReadReplayFrames(File file, replay_header_t header, frame_cache_t cache)
{
	int total_cells = 6;
	int used_cells = 6;
	bool is_btimes = false;

	if (header.iReplayVersion > 0x01)
	{
		total_cells = 8;
		used_cells = 8;
	}

	// We have differing total_cells & used_cells because we want to save memory during playback since the latest two cells added (vel & mousexy) aren't needed and are only useful for replay file anticheat usage stuff....
	if (header.iReplayVersion >= 0x06)
	{
		total_cells = 10;
		used_cells = 8;
	}

	any aReplayData[sizeof(frame_t)];

	delete cache.aFrames;
	int iTotalSize = header.iFrameCount + header.iPreFrames + header.iPostFrames;
	cache.aFrames = new ArrayList(used_cells, iTotalSize);

	if (!header.sReplayFormat[0]) // old replay format. no header.
	{
		char sLine[320];
		char sExplodedLine[6][64];

		if(!file.Seek(0, SEEK_SET))
		{
			return false;
		}

		while (!file.EndOfFile())
		{
			file.ReadLine(sLine, 320);
			int iStrings = ExplodeString(sLine, "|", sExplodedLine, 6, 64);

			aReplayData[0] = StringToFloat(sExplodedLine[0]);
			aReplayData[1] = StringToFloat(sExplodedLine[1]);
			aReplayData[2] = StringToFloat(sExplodedLine[2]);
			aReplayData[3] = StringToFloat(sExplodedLine[3]);
			aReplayData[4] = StringToFloat(sExplodedLine[4]);
			aReplayData[5] = (iStrings == 6) ? StringToInt(sExplodedLine[5]) : 0;

			cache.aFrames.PushArray(aReplayData, 6);
		}

		cache.iFrameCount = cache.aFrames.Length;
	}
	else // assumes the file position will be at the start of the frames
	{
		is_btimes = StrEqual(header.sReplayFormat, "btimes");

		for (int i = 0; i < iTotalSize; i++)
		{
			if(file.Read(aReplayData, total_cells, 4) >= 0)
			{
				cache.aFrames.SetArray(i, aReplayData, used_cells);

				if (is_btimes && (aReplayData[5] & IN_BULLRUSH))
				{
					if (!header.iPreFrames)
					{
						header.iPreFrames = i;
						header.iFrameCount -= i;
					}
					else if (!header.iPostFrames)
					{
						header.iPostFrames = header.iFrameCount + header.iPreFrames - i;
						header.iFrameCount -= header.iPostFrames;
					}
				}
			}
		}

		if (StrEqual(header.sReplayFormat, REPLAY_FORMAT_FINAL))
		{
			DataPack hPack = new DataPack();
			hPack.WriteCell(header.iStyle);
			hPack.WriteCell(header.iTrack);

			DB_GetUserName(header.iSteamID, hPack);
		}
	}

	cache.iFrameCount = header.iFrameCount;
	cache.fTime = header.fTime;
	cache.iReplayVersion = header.iReplayVersion;
	cache.bNewFormat = StrEqual(header.sReplayFormat, REPLAY_FORMAT_FINAL) || is_btimes;
	cache.sReplayName = "unknown";
	cache.iPreFrames = header.iPreFrames;
	cache.iPostFrames = header.iPostFrames;
	cache.fTickrate = header.fTickrate;

	return true;
}

stock File ReadReplayHeader(const char[] path, replay_header_t header, int style, int track)
{
	replay_header_t empty_header;
	header = empty_header;

	if (!FileExists(path))
	{
		return null;
	}

	File file = OpenFile(path, "rb");

	if (file == null)
	{
		return null;
	}

	char sHeader[64];

	if(!file.ReadLine(sHeader, 64))
	{
		delete file;
		return null;
	}

	TrimString(sHeader);
	char sExplodedHeader[2][64];
	ExplodeString(sHeader, ":", sExplodedHeader, 2, 64);

	strcopy(header.sReplayFormat, sizeof(header.sReplayFormat), sExplodedHeader[1]);

	if(StrEqual(header.sReplayFormat, REPLAY_FORMAT_FINAL)) // hopefully, the last of them
	{
		int version = StringToInt(sExplodedHeader[0]);

		header.iReplayVersion = version;

		// replay file integrity and PreFrames
		if(version >= 0x03)
		{
			file.ReadString(header.sMap, PLATFORM_MAX_PATH);
			file.ReadUint8(header.iStyle);
			file.ReadUint8(header.iTrack);
			
			file.ReadInt32(header.iPreFrames);

			// In case the replay was from when there could still be negative preframes
			if(header.iPreFrames < 0)
			{
				header.iPreFrames = 0;
			}
		}

		file.ReadInt32(header.iFrameCount);
		file.ReadInt32(view_as<int>(header.fTime));

		if (header.iReplayVersion < 0x07)
		{
			header.iFrameCount -= header.iPreFrames;
		}

		if(version >= 0x04)
		{
			file.ReadInt32(header.iSteamID);
		}
		else
		{
			char sAuthID[32];
			file.ReadString(sAuthID, 32);
			ReplaceString(sAuthID, 32, "[U:1:", "");
			ReplaceString(sAuthID, 32, "]", "");
			header.iSteamID = StringToInt(sAuthID);
		}

		if (version >= 0x05)
		{
			file.ReadInt32(header.iPostFrames);
			file.ReadInt32(view_as<int>(header.fTickrate));

			if (header.iReplayVersion < 0x07)
			{
				header.iFrameCount -= header.iPostFrames;
			}
		}

		if (version >= 0x08)
		{
			file.ReadInt32(view_as<int>(header.fZoneOffset[0]));
			file.ReadInt32(view_as<int>(header.fZoneOffset[1]));
		}
	}
	else if(StrEqual(header.sReplayFormat, REPLAY_FORMAT_V2))
	{
		header.iFrameCount = StringToInt(sExplodedHeader[0]);
	}
	else // old, outdated and slow - only used for ancient replays
	{
		// check for btimes replays
		file.Seek(0, SEEK_SET);
		any stuff[2];
		file.Read(stuff, 2, 4);

		int btimes_player_id = stuff[0];
		float run_time = stuff[1];

		if (btimes_player_id >= 0 && run_time > 0.0 && run_time < (10.0 * 60.0 * 60.0))
		{
			header.sReplayFormat = "btimes";
			header.fTime = run_time;

			file.Seek(0, SEEK_END);
			header.iFrameCount = (file.Position / 4 - 2) / 6;
			file.Seek(2*4, SEEK_SET);
		}
	}

	if (header.iReplayVersion < 0x03)
	{
		header.iStyle = style;
		header.iTrack = track;
	}

	if (header.iReplayVersion < 0x05)
	{
		header.fTickrate = gF_Tickrate;
	}

	return file;
}

stock bool DeleteReplay(int style, int track, int accountid, const char[] mapname)
{
	char sPath[PLATFORM_MAX_PATH];
	GetReplayFilePath(style, track, mapname, sPath);

	if(!FileExists(sPath))
	{
		return false;
	}

	if(accountid != 0)
	{
		replay_header_t header;
		File file = ReadReplayHeader(sPath, header, style, track);

		if (file == null)
		{
			return false;
		}

		delete file;

		if (accountid != header.iSteamID)
		{
			return false;
		}
	}

	if(!DeleteFile(sPath))
	{
		return false;
	}

	if(StrEqual(mapname, gS_Map, false))
	{
		UnloadReplay(style, track, false, false);
	}

	return true;
}

stock void DeleteAllReplays(const char[] map)
{
	for(int i = 0; i < gI_Styles; i++)
	{
		if(!ReplayEnabled(i))
		{
			continue;
		}

		for(int j = 0; j < TRACKS_SIZE; j++)
		{
			char sTrack[4];
			FormatEx(sTrack, 4, "_%d", j);

			char sPath[PLATFORM_MAX_PATH];
			FormatEx(sPath, PLATFORM_MAX_PATH, "%s/%d/%s%s.replay", gS_ReplayFolder, i, map, (j > 0)? sTrack:"");

			if(FileExists(sPath))
			{
				DeleteFile(sPath);
			}
		}
	}
}

stock bool LoadStageReplay(frame_cache_t cache, int style, int stage)
{
	char sPath[PLATFORM_MAX_PATH];
	FormatEx(sPath, PLATFORM_MAX_PATH, "%s/%d/%s_stage_%d.replay", gS_ReplayFolder, style, gS_Map, stage);
	if(!FileExists(sPath))
	{
		return false;
	}

	File fFile = OpenFile(sPath, "rb");

	char sHeader[64];
	if(!fFile.ReadLine(sHeader, 64))
	{
		delete fFile;
		return false;
	}

	TrimString(sHeader);
	char sExplodedHeader[2][64];
	ExplodeString(sHeader, ":", sExplodedHeader, 2, 64);

	replay_header_t header;
	strcopy(header.sReplayFormat, sizeof(header.sReplayFormat), sExplodedHeader[1]);

	header.iReplayVersion = StringToInt(sExplodedHeader[0]);

	fFile.ReadString(header.sMap, PLATFORM_MAX_PATH);
	fFile.ReadUint8(header.iStage);
	fFile.ReadUint8(header.iStyle);
	fFile.ReadInt32(header.iFrameCount);
	fFile.ReadInt32(view_as<int>(header.fTime));
	fFile.ReadInt32(header.iSteamID);
	fFile.ReadInt32(view_as<int>(header.fTickrate));


	int total_cells = 10;
	int used_cells = 8;

	any aReplayData[sizeof(frame_t)];

	delete cache.aFrames;
	cache.aFrames = new ArrayList(used_cells, header.iFrameCount);

	for(int i = 0; i < header.iFrameCount; i++)
	{
		if(fFile.Read(aReplayData, total_cells, 4) >= 0)
		{
			cache.aFrames.SetArray(i, aReplayData, used_cells);
		}
	}

	cache.iFrameCount = header.iFrameCount;
	cache.fTime = header.fTime;
	cache.iReplayVersion = header.iReplayVersion;
	cache.bNewFormat = StrEqual(header.sReplayFormat, REPLAY_FORMAT_FINAL);
	cache.sReplayName = "unknown";
	cache.iPreFrames = header.iPreFrames;
	cache.iPostFrames = header.iPostFrames;
	cache.fTickrate = header.fTickrate;

	DataPack hPack = new DataPack();
	hPack.WriteCell(header.iStyle);
	hPack.WriteCell(header.iStage);

	DB_GetStageUserName(header.iSteamID, hPack);

	delete fFile;

	return true;
}

stock void WriteReplayHeader(File fFile, int style, int track, float time, int steamid, int preframes, int postframes, float fZoneOffset[2], int iSize)
{
	fFile.WriteLine("%d:" ... REPLAY_FORMAT_FINAL, REPLAY_FORMAT_SUBVERSION);

	fFile.WriteString(gS_Map, true);
	fFile.WriteInt8(style);
	fFile.WriteInt8(track);
	fFile.WriteInt32(preframes);

	fFile.WriteInt32(iSize - preframes - postframes);
	fFile.WriteInt32(view_as<int>(time));
	fFile.WriteInt32(steamid);

	fFile.WriteInt32(postframes);
	fFile.WriteInt32(view_as<int>(gF_Tickrate));

	fFile.WriteInt32(view_as<int>(fZoneOffset[0]));
	fFile.WriteInt32(view_as<int>(fZoneOffset[1]));
}

stock void SaveReplay(int style, int track, float time, int steamid, int preframes, ArrayList playerrecording, int iSize, int postframes, int timestamp, float fZoneOffset[2], bool saveCopy, bool saveReplay, char[] sPath, int sPathLen)
{
	char sTrack[4];
	FormatEx(sTrack, 4, "_%d", track);

	File fWR = null;
	File fCopy = null;

	if (saveReplay)
	{
		FormatEx(sPath, sPathLen, "%s/%d/%s%s.replay", gS_ReplayFolder, style, gS_Map, (track > 0)? sTrack:"");
		DeleteFile(sPath);
		fWR = OpenFile(sPath, "wb");
	}

	if (saveCopy)
	{
		FormatEx(sPath, sPathLen, "%s/copy/%d_%d_%s.replay", gS_ReplayFolder, timestamp, steamid, gS_Map);
		DeleteFile(sPath);
		fCopy = OpenFile(sPath, "wb");
	}

	if (saveReplay)
	{
		WriteReplayHeader(fWR, style, track, time, steamid, preframes, postframes, fZoneOffset, iSize);
	}

	if (saveCopy)
	{
		WriteReplayHeader(fCopy, style, track, time, steamid, preframes, postframes, fZoneOffset, iSize);
	}

	any aFrameData[sizeof(frame_t)];
	any aWriteData[sizeof(frame_t) * FRAMES_PER_WRITE];
	int iFramesWritten = 0;

	for(int i = 0; i < iSize; i++)
	{
		playerrecording.GetArray(i, aFrameData, sizeof(frame_t));

		for(int j = 0; j < sizeof(frame_t); j++)
		{
			aWriteData[(sizeof(frame_t) * iFramesWritten) + j] = aFrameData[j];
		}

		if(++iFramesWritten == FRAMES_PER_WRITE || i == iSize - 1)
		{
			if (saveReplay)
			{
				fWR.Write(aWriteData, sizeof(frame_t) * iFramesWritten, 4);
			}

			if (saveCopy)
			{
				fCopy.Write(aWriteData, sizeof(frame_t) * iFramesWritten, 4);
			}

			iFramesWritten = 0;
		}
	}

	delete fWR;
	delete fCopy;
}

stock void SaveStageReplay(int stage, int style, float time, int steamid, int preframes, ArrayList playerrecording, int iSize)
{
	char sPath[PLATFORM_MAX_PATH];
	FormatEx(sPath, PLATFORM_MAX_PATH, "%s/%d/%s_stage_%d.replay", gS_ReplayFolder, style, gS_Map, stage);
	if(FileExists(sPath))
	{
		DeleteFile(sPath);
	}

	File fFile = OpenFile(sPath, "wb");
	fFile.WriteLine("%d:" ... REPLAY_FORMAT_FINAL, REPLAY_FORMAT_SUBVERSION);

	fFile.WriteString(gS_Map, true);
	fFile.WriteInt8(stage);
	fFile.WriteInt8(style);
	fFile.WriteInt32(iSize - preframes);
	fFile.WriteInt32(view_as<int>(time));
	fFile.WriteInt32(steamid);
	fFile.WriteInt32(view_as<int>(gF_Tickrate));

	any aFrameData[sizeof(frame_t)];
	any aWriteData[sizeof(frame_t) * FRAMES_PER_WRITE];
	int iFramesWritten = 0;

	for(int i = preframes; i < iSize; i++)
	{
		playerrecording.GetArray(i, aFrameData, sizeof(frame_t));

		for(int j = 0; j < sizeof(frame_t); j++)
		{
			aWriteData[(sizeof(frame_t) * iFramesWritten) + j] = aFrameData[j];
		}

		if(++iFramesWritten == FRAMES_PER_WRITE || i == iSize - 1)
		{
			fFile.Write(aWriteData, sizeof(frame_t) * iFramesWritten, 4);
			iFramesWritten = 0;
		}
	}

	delete fFile;
}



// =====[ PRIVATE ]=====

// Can be used to unpack frame_t.mousexy and frame_t.vel
static stock void UnpackSignedShorts(int x, int out[2])
{
	out[0] =  ((x        & 0xFFFF) ^ 0x8000) - 0x8000;
	out[1] = (((x >> 16) & 0xFFFF) ^ 0x8000) - 0x8000;
}