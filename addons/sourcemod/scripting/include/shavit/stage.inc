/*
	stage Plugin Include
	
	Website: https://github.com/Ciallo-Ani/surftimer
*/

#if defined _shavit_stage_included_
#endinput
#endif
#define _shavit_stage_included_



// =====[ ENUM STRUCTS ]=====

enum struct cp_t
{
	int iAttemps;
	int iDate;
	float fTime;
	float fRealTime;
	float fPrespeed;
	float fPostspeed;
}

enum struct stage_t
{
	int iSteamid;
	int iDate;
	int iCompletions;
	float fTime;
	float fPostspeed;
	char sName[MAX_NAME_LENGTH];
}



// =====[ NATIVES ]=====

/**
 * Reload WRStages.
 *
 * @noreturn
 */
native void Shavit_ReloadWRStages();

/**
 * Reload WRCPs.
 *
 * @noreturn
 */
native void Shavit_ReloadWRCPs();

/**
 * Get the amount of records on the current map/style on a stage.
 *
 * @param style						Style.
 * @param stage						Timer stage.
 * @return							Amount of stage records.
 */
native int Shavit_GetStageRecordAmount(int style, int stage);

/**
 * Calculate potential stage rank for a given style and time.
 *
 * @param style						Style.
 * @param time						Time to check for.
 * @param stage						Timer stage.
 * @return							Stage rank.
 */
native int Shavit_GetStageRankForTime(int style, float time, int stage);

/**
 * Gets the WRStage's date on the map on a variable.(TODO)
 *
 * @param stage						WRStage stage.
 * @param style						Style to get the WRStage for.
 * @return							WRStage Date.
 */
native float Shavit_GetWRStageDate(int stage, int style);

/**
 * Gets the WRStage's time on the map on a variable.
 *
 * @param stage						WRStage stage.
 * @param style						Style to get the WRStage for.
 * @return							WRStage Time.
 */
native float Shavit_GetWRStageTime(int stage, int style);

/**
 * Gets the WRStage's postspeed on the map on a variable.
 *
 * @param stage						WRStage stage.
 * @param style						Style to get the WRStage for.
 * @return							WRStage Postspeed.
 */
native float Shavit_GetWRStagePostspeed(int stage, int style);

/**
 * Saves the WRStage's player name on the map on a variable.
 *
 * @param style						Style to get the WRStage for.
 * @param stage						WRStage checkpoint.
 * @param wrstagename				Reference to the name variable.
 * @param wrstagemaxlength			Max length for the string.
 * @noreturn
 */
native void Shavit_GetWRStageName(int style, int stage, char[] wrstagename, int wrstagemaxlength);

/**
 * Gets the WRCP's attemps on the stage on a variable.
 *
 * @param cp						WRCP checkpoint.
 * @param style						Style to get the WRCP for.
 * @return							WRCP Attemps.
 */
native int Shavit_GetWRCPAttemps(int cp, int style);

/**
 * Gets the WRCP's time on the map on a variable.
 *
 * @param cp						WRCP checkpoint.
 * @param style						Style to get the WRCP for.
 * @return							WRCP Time.
 */
native float Shavit_GetWRCPTime(int cp, int style);

/**
 * Gets the WRCP's real stage time on the map on a variable.
 *
 * @param cp						WRCP checkpoint.
 * @param style						Style to get the WRCP for.
 * @return							WRCP real Time.
 */
native float Shavit_GetWRCPRealTime(int cp, int style);

/**
 * Gets the WRCP's prespeed on the map on a variable.
 *
 * @param cp						WRCP checkpoint.
 * @param style						Style to get the WRCP for.
 * @return							WRCP Prespeed.
 */
native float Shavit_GetWRCPPrespeed(int cp, int style);

/**
 * Gets the WRCP's postspeed on the map on a variable.
 *
 * @param cp						WRCP checkpoint.
 * @param style						Style to get the WRCP for.
 * @return							WRCP Postspeed.
 */
native float Shavit_GetWRCPPostspeed(int cp, int style);

/**
 * Gets the difference time between WR's checkpoint time and client checkpoint time.
 *
 * @param client					Client index.
 * @return							Difference time.
 */
native float Shavit_GetWRCPDiffTime(int client);

/**
 * Detect bypass first.
 * If true, finishes the stage for a player, with their current timer stats defaultly(depend on bypass).
 * Otherwise, finishes the stage but not insert any data to forward and mysql.
 * Will not teleport the player to anywhere, it's handled inside the mapzones plugin.
 *
 * @param client					Client index.
 * @param bypass					Bypass call to Shavit_OnFinishStagePre.
 * @noreturn
 */
native void Shavit_FinishStage(int client, bool bypass = true);

/**
 * Detect bypass first.
 * If true, finishes the checkpoint for a player, with their current timer stats defaultly(depend on bypass).
 * Otherwise, finish the checkpoint but not insert any data to forward and mysql.
 * Will not teleport the player to anywhere, it's handled inside the mapzones plugin.
 *
 * @param client					Client index.
 * @param bypass					Bypass call to Shavit_OnFinishCheckpointPre.
 * @noreturn
 */
native void Shavit_FinishCheckpoint(int client, bool bypass = true);

/**
 * Retrieves the best stage status of a player.
 *
 * @param client					Client index.
 * @param style						Style to get the PB for.
 * @param stage						Timer stage.
 * @param pb						stage_t struct type.
 * @param size						Size of the stagepb buffer, e.g sizeof(stage_t)
 * @noreturn
 */
native void Shavit_GetStagePB(int client, int style, int stage, any[] pb, int size = sizeof(stage_t));

/**
 * Retrieves the best checkpoint status of a player.
 *
 * @param client					Client index.
 * @param style						Style to get the PB for.
 * @param cp						Timer checkpoint(map cp).
 * @param pb						cp_t struct type.
 * @param size						Size of the checkpointpb buffer, e.g sizeof(cp_t)
 * @noreturn
 */
native void Shavit_GetCheckpointPB(int client, int style, int cp, any[] pb, int size = sizeof(cp_t));



// =====[ FORWARDS ]=====

/**
 * Called when a player enters a stage-zone.
 *
 * @param client					Client index.
 * @param stage						Stage number.
 * @param style						Style index.
 * @param enterspeed				Speed when client enters stage zone.
 * @param time						Client current time.
 * @param stagetimer				Check client is not finishing the map, only stage timer.
 * @noreturn
 */
forward void Shavit_OnEnterStage(int client, int stage, int style, float enterspeed, float time, bool stagetimer);

/**
 * Called when a player enters a checkpoint-zone.
 *
 * @param client					Client index.
 * @param stage						Stage number.
 * @param style						Style index.
 * @param enterspeed				Speed when client enters checkpoint zone.
 * @param time						Client current time.
 * @noreturn
 */
forward void Shavit_OnEnterCheckpoint(int client, int cp, int style, float enterspeed, float time);

/**
 * Called when a player leaves a stage-zone.
 *
 * @param client					Client index.
 * @param stage						Stage number.
 * @param style						Style index.
 * @param leavespeed				Speed when client leaves stage zone.
 * @param time						Client current time.
 * @param stagetimer				Check client is not finishing the map, only stage timer.
 * @noreturn
 */
forward void Shavit_OnLeaveStage(int client, int stage, int style, float leavespeed, float time, bool stagetimer);

/**
 * Called when a player leaves a checkpoint-zone.
 *
 * @param client					Client index.
 * @param stage						Stage number.
 * @param style						Style index.
 * @param leavespeed				Speed when client leaves checkpoint zone.
 * @param time						Client current time.
 * @noreturn
 */
forward void Shavit_OnLeaveCheckpoint(int client, int cp, int style, float leavespeed, float time);

/**
 * Called when there's a new WRCP on the map.
 *
 * @param client					Client index.
 * @param stage						Stage number.
 * @param style						Style index.
 * @param steamid					WRCP steamid.
 * @param records					Current stage records.
 * @param oldtime					Old WRCP time.
 * @param time						WRCP time.
 * @param leavespeed				The speed on leaving the stage.
 * @param mapname					Current mapname.
 * @noreturn
 */
forward void Shavit_OnWRCP(int client, int stage, int style, int steamid, int records, float oldtime, float time, float leavespeed, const char[] mapname);

/**
 * Called After the server deleted WRCP.
 *
 * @param stage						WRCP stage.
 * @param style						WRCP style.
 * @param steamid					WRCP steamid.
 * @param mapname					WRCP map's name.
 * @noreturn
 */
forward void Shavit_OnWRCPDeleted(int stage, int style, int steamid, const char[] mapname);

/**
 * Called before a player finishes a stage.
 *
 * @param client					Client index.
 * @param stage						Stage id.
 * @param style						Style id.
 * @return							Plugin_Handled to prevent the stage from finishing.
 */
forward Action Shavit_OnFinishStagePre(int client, int stage, int style);

/**
 * After forward 'Shavit_OnFinishStage' and the insertion query was called.
 * Called from shavit-stage
 *
 * @param client					Client index.
 * @param stage						Stage id was done on.
 * @param style						Style the record was done on.
 * @param time						Record time.
 * @param diff						Difference between old time and current time.
 * @param overwrite					1 - brand new record. 2 - update.
 * @param records					The stage's records amount.
 * @param rank						Client's rank on the stage.
 * @param wrcp						True if the record is a wrcp.
 * @param leavespeed				The speed on leaving the stage.
 * @noreturn
 */
forward void Shavit_OnFinishStage_Post(int client, int stage, int style, float time, float diff, int overwrite, int records, int rank, bool wrcp, float leavespeed);

/**
 * Called before a player finishes a checkpoint.
 *
 * @param client					Client index.
 * @param cpnum						Checkpoint/Stage zone number was done on.
 * @param style						Style id.
 * @return							Plugin_Handled to prevent the Checkpoint/Stage from finishing.
 */
forward Action Shavit_OnFinishCheckpointPre(int client, int cpnum, int style);

/**
 * Called when a player finishes a checkpoint. (touches the checkpoint/stage zone)
 *
 * @param client					Client index.
 * @param cpnum						Checkpoint/Stage zone number was done on.
 * @param style						Style the record was done on.
 * @param time						Current time when the checkpoint finished.
 * @param wrdiff					Difference between wr checkpoint time and current checkpoint time, below 0 means faster, otherwise slower.
 * @param pbdiff					Difference between pb checkpoint time and current checkpoint time, below 0 means faster, otherwise slower.
 * @param enterspeed				Speed when client enters checkpoint/stage zone.
 * @noreturn
 */
forward void Shavit_OnFinishCheckpoint(int client, int cpnum, int style, float time, float wrdiff, float pbdiff, float enterspeed);



// =====[ DEPENDENCY ]=====

public SharedPlugin __pl_shavit_stage = 
{
	name = "shavit-stage", 
	file = "shavit-stage.smx", 
	#if defined REQUIRE_PLUGIN
	required = 1, 
	#else
	required = 0, 
	#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_shavit_stage_SetNTVOptional()
{
	MarkNativeAsOptional("Shavit_ReloadWRStages");
	MarkNativeAsOptional("Shavit_ReloadWRCPs");
	MarkNativeAsOptional("Shavit_GetStageRecordAmount");
	MarkNativeAsOptional("Shavit_GetStageRankForTime");
	MarkNativeAsOptional("Shavit_GetWRStageDate");
	MarkNativeAsOptional("Shavit_GetWRStageTime");
	MarkNativeAsOptional("Shavit_GetWRStagePostspeed");
	MarkNativeAsOptional("Shavit_GetWRStageName");
	MarkNativeAsOptional("Shavit_GetWRCPAttemps");
	MarkNativeAsOptional("Shavit_GetWRCPTime");
	MarkNativeAsOptional("Shavit_GetWRCPRealTime");
	MarkNativeAsOptional("Shavit_GetWRCPPrespeed");
	MarkNativeAsOptional("Shavit_GetWRCPPostspeed");
	MarkNativeAsOptional("Shavit_GetWRCPDiffTime");
	MarkNativeAsOptional("Shavit_FinishStage");
	MarkNativeAsOptional("Shavit_FinishCheckpoint");
	MarkNativeAsOptional("Shavit_GetStagePB");
	MarkNativeAsOptional("Shavit_GetCheckpointPB");
}
#endif