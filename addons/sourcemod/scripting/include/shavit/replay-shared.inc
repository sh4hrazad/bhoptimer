#if defined _shavit_replay_shared_included_
#endinput
#endif
#define _shavit_replay_shared_included_



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