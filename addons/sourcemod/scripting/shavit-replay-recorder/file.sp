#define REPLAY_FORMAT_V2 "{SHAVITREPLAYFORMAT}{V2}"
#define REPLAY_FORMAT_FINAL "{SHAVITREPLAYFORMAT}{FINAL}"
#define REPLAY_FORMAT_SUBVERSION 0x08
#define REPLAY_FORMAT_CURRENT_USED_CELLS 8
#define FRAMES_PER_WRITE 100 // amounts of frames to write per read/write call



void WriteReplayHeader(File fFile, int style, int track, float time, int steamid, int preframes, int postframes, float fZoneOffset[2], int iSize)
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

void SaveReplay(int style, int track, float time, int steamid, int preframes, ArrayList playerrecording, int iSize, int postframes, int timestamp, float fZoneOffset[2], bool saveCopy, bool saveReplay, char[] sPath, int sPathLen)
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

void SaveStageReplay(int client, int stage, int style, float time, int steamid, int preframes, ArrayList playerrecording, int iSize)
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

	ArrayList stageFrames = new ArrayList(sizeof(frame_t));

	for(int i = preframes; i < iSize; i++)
	{
		playerrecording.GetArray(i, aFrameData, sizeof(frame_t));
		stageFrames.PushArray(aFrameData, sizeof(frame_t));

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

	char sName[MAX_NAME_LENGTH];
	GetClientName(client, sName, sizeof(sName));

	Call_OnStageReplaySaved(client, stage, style, time, steamid, stageFrames, preframes, iSize, sName);

	delete stageFrames;
	delete fFile;
}