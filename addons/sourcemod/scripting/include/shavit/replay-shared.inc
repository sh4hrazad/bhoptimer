#if defined _shavit_replay_shared_included_
#endinput
#endif
#define _shavit_replay_shared_included_

enum struct frame_t
{
	float pos[3];
	float ang[2];
	int buttons;
	// iReplayVersion >= 0x02
	int flags;
	MoveType mt;
	// Everything below is generally NOT loaded into memory for playback
	// iReplayVersion >= 0x06
	int mousexy; // `mousex | (mousey << 16)` // unpack with UnpackSignedShorts
	int vel; // basically `forwardmove | (sidemove << 16)` // unpack with UnpackSignedShorts
}

enum struct frame_cache_t
{
	int iFrameCount;
	float fTime;
	bool bNewFormat;
	int iReplayVersion;
	char sReplayName[MAX_NAME_LENGTH];
	int iPreFrames;
	ArrayList aFrames;
	// iReplayVersion >= 0x05
	int iPostFrames;
	float fTickrate;
}

enum struct replay_header_t
{
	char sReplayFormat[40];
	int iReplayVersion;
	char sMap[PLATFORM_MAX_PATH];
	int iStyle;
	int iTrack;
	int iStage;
	int iPreFrames;
	int iFrameCount;
	float fTime;
	int iSteamID;
	int iPostFrames;
	float fTickrate;
	float fZoneOffset[2];
}



// =====[ NATIVES ]====

/**
 * Retrieves a client's frame count.
 *
 * @param client					Client Index.
 * @return							Current number of frames.
 */
native int Shavit_GetClientFrameCount(int client);

/**
 * returns the number of preframes in the players current run.
 *
 * @param client					Client index
 *
 * @return 							Preframe count
 */
native int Shavit_GetPlayerPreFrames(int client);

/**
 * Retrieves a replay's total length in seconds.
 *
 * @param style						Style.
 * @param track						Track.
 * @param stage						Stage. Default 0 means Main bot.
 * @return							Replay length.
 */
native float Shavit_GetReplayLength(int style, int track, int stage = 0);