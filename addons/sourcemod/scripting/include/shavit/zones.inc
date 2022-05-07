/**
 * Include file for shavit-zones.sp
 *
 * Original plugin website: https://github.com/Ciallo-Ani/mytimer/tree/gokz-framework
 */

#if defined _shavit_zones_included
	#endinput
#endif
#define _shavit_zones_included

#define MAX_ZONES 128

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

/* -- Stocks -- */

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

/* -- Forwards -- */

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
 * (WARNING: Will be called every tick when the player stands at the end zone!)
 *
 * @param client					Client index.
 * @noreturn
 */
forward Action Shavit_OnEndZone(int client);

/* -- Natives -- */

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
 * Checks if a mapzone exists.
 *
 * @param type						Mapzone type.
 * @param track						Mapzone track, -1 to ignore track.
 * @return							Boolean value.
 */
native bool Shavit_ZoneExists(int type, int track);

/**
 * Deletes all map zones for the specified map.
 * Plugin will refresh if map is currently on.
 *
 * @param map						Map name.
 * @noreturn
 */
native void Shavit_Zones_DeleteMap(const char[] map);

/**
 * Sets the player's current location as their spawn location for the specified track.
 * (I did not find code for the native, so i don't know whether it works.)
 *
 * @param client                 Client index.
 * @param track                  Timer track.
 * @param anglesonly             Whether to save angles only.
 * @noreturn
 */
native void Shavit_SetStart(int client, int track, bool anglesonly);

/**
 * Deletes the player's current set start position for the specified track.
 * (I did not find code for the native, so i don't know whether it works.)
 *
 * @param client                 Client index.
 * @param track                  Timer track.
 * @noreturn
 */
native void Shavit_DeleteSetStart(int client, int track);

public SharedPlugin __pl_shavit_zones =
{
	name = "shavit-zones",

	file = "shavit-zones.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_shavit_zones_SetNTVOptional()
{
        MarkNativeAsOptional("Shavit_GetZoneData");
	MarkNativeAsOptional("Shavit_GetZoneFlags");
	MarkNativeAsOptional("Shavit_GetMapBonuses");
	MarkNativeAsOptional("Shavit_GetMapStages");
	MarkNativeAsOptional("Shavit_GetMapCheckpoints");
	MarkNativeAsOptional("Shavit_InsideZone");
	MarkNativeAsOptional("Shavit_InsideZoneGetID");
	MarkNativeAsOptional("Shavit_InsideZoneGetType");
	MarkNativeAsOptional("Shavit_IsLinearMap");
	MarkNativeAsOptional("Shavit_IsClientCreatingZone");
	MarkNativeAsOptional("Shavit_ZoneExists");
	MarkNativeAsOptional("Shavit_Zones_DeleteMap");
        MarkNativeAsOptional("Shavit_SetStart");
        MarkNativeAsOptional("Shavit_DeleteSetStart");
}
#endif