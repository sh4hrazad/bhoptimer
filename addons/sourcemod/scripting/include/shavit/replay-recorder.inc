/*
	replay-recorder Plugin Include
	
	Website: https://github.com/Ciallo-Ani/surftimer
*/

#if defined _shavit_replay_recorder_included_
#endinput
#endif
#define _shavit_replay_recorder_included_



// =====[ STRUCTS ]=====

#if !defined _shavit_replay_playback_included_

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

#endif

// =====[ FORWARDS ]=====

/**
 * Called when a player finishes a time. Allows you to save a replay even if the run is not a WR.
 *
 * @param client                    Client index.
 * @param style                     Style the record was done on.
 * @param time                      Record time.
 * @param jumps                     Jumps amount.
 * @param strafes                   Amount of strafes.
 * @param sync                      Sync percentage (0.0 to 100.0) or -1.0 when not measured.
 * @param track                     Timer track.
 * @param oldtime                   The player's best time on the map before this finish.
 * @param avgvel                    Player's average velocity throughout the run.
 * @param maxvel                    Player's highest reached velocity.
 * @param timestamp                 System time of when player finished.
 * @param isbestreplay              If the time is the new replay.
 * @param istoolong                 If the time is too long to save a replay if the time is a WR. Note: replays WON'T be full length if this is true.
 *
 * @return                          Return Plugin_Changed (or higher) to cause a copy of the replay to be saved. Return Plugin_Continue otherwise.
 */
forward Action Shavit_ShouldSaveReplayCopy(int client, int style, float time, int jumps, int strafes, float sync, int track, float oldtime, float avgvel, float maxvel, int timestamp, bool isbestreplay, bool istoolong);

/**
 * Called when either a WR replay or a copy of a replay has been saved.
 *
 * @param client                    Client index.
 * @param style                     Style the record was done on.
 * @param time                      Record time.
 * @param jumps                     Jumps amount.
 * @param strafes                   Amount of strafes.
 * @param sync                      Sync percentage (0.0 to 100.0) or -1.0 when not measured.
 * @param track                     Timer track.
 * @param oldtime                   The player's best time on the map before this finish.
 * @param avgvel                    Player's average velocity throughout the run.
 * @param maxvel                    Player's highest reached velocity.
 * @param timestamp                 System time of when player finished.
 * @param isbestreplay              If the time is the new replay.
 * @param istoolong                 If the time is too long to save a replay if the time is a WR. Note: replays WON'T be full length if this is true.
 * @param iscopy                    If the path points to a copy of the replay.
 * @param replaypath                Path to the saved replay.
 * @param frames                	ArrayList of the player's frames in the replay.
 * @param preframes                	The number of preframes in the replay.
 * @param postframes                The number of postframes in the replay.
 * @param name                		Player's name at the time of the replay.
 *
 * @noreturn
 */
forward void Shavit_OnReplaySaved(int client, int style, float time, int jumps, int strafes, float sync, int track, float oldtime, float avgvel, float maxvel, int timestamp, bool isbestreplay, bool istoolong, bool iscopy, const char[] replaypath, ArrayList frames, int preframes, int postframes, const char[] name);

/**
 * TODO
 * @noreturn
 */
forward void Shavit_OnStageReplaySaved(int client, int stage, int style, float time, int steamid, ArrayList frames, int preframes, int size);



// =====[ NATIVES ]====

#if !defined _shavit_replay_shared_included_

/**
 * Retrieves a client's frame count.
 *
 * @param client					Client Index.
 * @return							Current number of frames.
 */
native int Shavit_GetClientFrameCount(int client);

#endif

/**
 * Hijack the replay data so that this view angle will be used for the next tick.
 * Use case is to make segmented runs look smoother.
 *
 * @param client					Client index.
 * @param pitch						Vertical view angle.
 * @param yaw						Horizontal view angle.
 * @noreturn
 */
native void Shavit_HijackAngles(int client, float pitch, float yaw, int ticks);

/**
 * Saves a player's replay recording frames (if exists) into an ArrayList.
 * To be used by save states/TAS etc.
 *
 * @param client					Client index.
 * @param cheapCloneHandle			False means we duplicate the frames (Arraylist.Clone). True means we clone the handle to the frames (CloneHandle). This is going to be used for peristent-data in shavit-misc so we don't allocate duplicate memory needlessly.
 * @return							ArrayList with proper replay data, or null if the player has no recorded data.
 */
native ArrayList Shavit_GetReplayData(int client, bool cheapCloneHandle=false);

/**
 * Sets a player's replay recording frames from a provided ArrayList.
 * To be used by save states/TAS etc.
 *
 * @param client					Client index.
 * @param data						ArrayList with proper replay data.
 * @param cheapCloneHandle			False means we duplicate the frames (ArrayList.Clone). True means we clone the handle to the frames (CloneHandle).
 * @noreturn
 */
native void Shavit_SetReplayData(int client, ArrayList data, bool cheapCloneHandle=false);

#if !defined _shavit_replay_shared_included_

/**
 * returns the number of preframes in the players current run.
 *
 * @param client					Client index
 *
 * @return 							Preframe count
 */
native int Shavit_GetPlayerPreFrames(int client);

#endif

/**
 * Sets player's preframe length.
 *
 * @param client					Client index
 * @param PreFrame					PreFrame length
 * @param TimerPreFrame				Timer start frame length
 *
 * @noreturn
 */
native void Shavit_SetPlayerPreFrames(int client, int PreFrame);

/**
 * returns the number of stage preframes in the players current run.
 *
 * @param client					Client index
 *
 * @return 							Preframe count
 */
native int Shavit_GetPlayerStagePreFrames(int client);

/**
 * Sets player's stage preframe length.
 *
 * @param client					Client index
 * @param PreFrame					PreFrame length
 * @param TimerPreFrame				Timer start frame length
 *
 * @noreturn
 */
native void Shavit_SetPlayerStagePreFrames(int client, int PreFrame);



// =====[ DEPENDENCY ]=====

public SharedPlugin __pl_shavit_replay_recorder = 
{
	name = "shavit-replay-recorder", 
	file = "shavit-replay-recorder.smx", 
	#if defined REQUIRE_PLUGIN
	required = 1, 
	#else
	required = 0, 
	#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_shavit_replay_recorder_SetNTVOptional()
{
	MarkNativeAsOptional("Shavit_GetClientFrameCount");
	MarkNativeAsOptional("Shavit_HijackAngles");
	MarkNativeAsOptional("Shavit_GetReplayData");
	MarkNativeAsOptional("Shavit_SetReplayData");
	MarkNativeAsOptional("Shavit_GetPlayerPreFrames");
	MarkNativeAsOptional("Shavit_SetPlayerPreFrames");
	MarkNativeAsOptional("Shavit_GetPlayerStagePreFrames");
	MarkNativeAsOptional("Shavit_SetPlayerStagePreFrames");
}
#endif