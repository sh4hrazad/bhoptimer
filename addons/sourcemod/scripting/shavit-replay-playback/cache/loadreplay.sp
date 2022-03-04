bool Shavit_OnReplaySaved_CanBeCached(int style, int track, ArrayList frames, int preframes, int postframes, float time, const char[] name, bool isbestreplay, bool istoolong)
{
	if (!isbestreplay || istoolong)
	{
		return false;
	}

	delete gA_FrameCache[style][track].aFrames;
	gA_FrameCache[style][track].aFrames = view_as<ArrayList>(CloneHandle(frames));
	gA_FrameCache[style][track].iFrameCount = frames.Length - preframes - postframes;
	gA_FrameCache[style][track].fTime = time;
	gA_FrameCache[style][track].iReplayVersion = REPLAY_FORMAT_SUBVERSION;
	gA_FrameCache[style][track].bNewFormat = true;
	strcopy(gA_FrameCache[style][track].sReplayName, MAX_NAME_LENGTH, name);
	gA_FrameCache[style][track].iPreFrames = preframes;
	gA_FrameCache[style][track].iPostFrames = postframes;
	gA_FrameCache[style][track].fTickrate = gF_Tickrate;

	return true;
}

bool Shavit_OnStageReplaySaved_CanBeCached(int style, int stage, ArrayList frames, float time, const char[] name)
{
	delete gA_FrameCache_Stage[style][stage].aFrames;
	gA_FrameCache_Stage[style][stage].aFrames = view_as<ArrayList>(CloneHandle(frames));
	gA_FrameCache_Stage[style][stage].iFrameCount = frames.Length;
	gA_FrameCache_Stage[style][stage].fTime = time;
	gA_FrameCache_Stage[style][stage].iReplayVersion = REPLAY_FORMAT_SUBVERSION;
	gA_FrameCache_Stage[style][stage].bNewFormat = true;
	strcopy(gA_FrameCache_Stage[style][stage].sReplayName, sizeof(frame_cache_t::sReplayName), name);
	gA_FrameCache_Stage[style][stage].iPreFrames = 0;
	gA_FrameCache_Stage[style][stage].iPostFrames = 0;
	gA_FrameCache_Stage[style][stage].fTickrate = gF_Tickrate;

	return true;
}

void SetupIfCustomFrames(bot_info_t info, frame_cache_t cache)
{
	info.bCustomFrames = false;

	if (cache.aFrames != null)
	{
		info.bCustomFrames = true;
		info.aCache = cache;
		info.aCache.aFrames = view_as<ArrayList>(CloneHandle(info.aCache.aFrames));
	}
}

void GetReplayFilePath(int style, int track, const char[] mapname, char sPath[PLATFORM_MAX_PATH])
{
	char sTrack[4];
	FormatEx(sTrack, 4, "_%d", track);
	FormatEx(sPath, PLATFORM_MAX_PATH, "%s/%d/%s%s.replay", gS_ReplayFolder, style, mapname, (track > 0)? sTrack:"");
}

bool DefaultLoadReplay(frame_cache_t cache, int style, int track)
{
	char sPath[PLATFORM_MAX_PATH];
	GetReplayFilePath(style, track, gS_Map, sPath);

	if (!LoadReplay(cache, style, track, sPath, gS_Map))
	{
		return false;
	}

	if (gB_ClosestPos)
	{
		delete gH_ClosestPos[track][style];
		gH_ClosestPos[track][style] = new ClosestPos(cache.aFrames);
	}

	return true;
}