/*
	checkpoints Plugin Include
	
	Website: https://github.com/Ciallo-Ani/surftimer
*/

#if defined _shavit_checkpoints_included_
#endinput
#endif
#define _shavit_checkpoints_included_


// =====[ DEFINES ]=====

#define CP_ANGLES   			(1 << 0)
#define CP_VELOCITY				(1 << 1)

#define CP_DEFAULT				(CP_ANGLES|CP_VELOCITY)

enum struct persistent_data_t
{
	int iSteamID;
	int iDisconnectTime;
	int iTimesTeleported;
	ArrayList aCheckpoints;
	int iCurrentCheckpoint;
	cp_cache_t cpcache;
}

typedef StopTimerCallback = function void (int data);



// =====[ NATIVES]=====

/**
 * Gets CP data for a client at specified index
 *
 * @param client					Client index
 * @param index						Index of CP to get
 * @param cpcache					Buffer to store cp data in sizeof(cp_cache_t)
 * @param size						Size of the cpcache buffer, e.g sizeof(cp_cache_t)
 *
 * @noreturn
 */
native bool Shavit_GetCheckpoint(int client, int index, any[] cpcache, int size = sizeof(cp_cache_t));

/**
 * Sets checkpoint data at the given index for the given client
 *
 * @param client					Client index
 * @param index						Index of CP to set, or -1 to push cp as last
 * @param cpcache					Buffer to store cp data in sizeof(cp_cache_t)
 * @param size						Size of the cpcache buffer, e.g sizeof(cp_cache_t)
 * @param cpcache					Buffer with cp data
 *
 * @noreturn
 */
native void Shavit_SetCheckpoint(int client, int index, any[] cpcache, int size = sizeof(cp_cache_t));

/**
 * Clears all saved checkpoints for the specified client
 *
 * @param client					Client index
 *
 * @noreturn
 */
native void Shavit_ClearCheckpoints(int client);

/**
 * Teleports client to the checkpoint at given index
 *
 * @param client					Client index
 * @param index						Index of CP to teleport to
 * @param suppress					Supress checkpoint message
 *
 * @noreturn
 */
native void Shavit_TeleportToCheckpoint(int client, int index, bool suppress = false);

/**
 * Gets the total number of CPs that a client has saved
 *
 * @param client					Client index
 *
 * @return							Total number of checkpoints
 */
native int Shavit_GetTotalCheckpoints(int client);

/**
 * Opens checkpoint menu for a client
 *
 * @param client					Client index
 *
 * @noreturn
 */
native void Shavit_OpenCheckpointMenu(int client);

/**
 * Saves a new checkpoint and returns the new checkpoint index
 *
 * @param client					Client index
 *
 * @return							The new current checkpoint
 */
native int Shavit_SaveCheckpoint(int client);

/**
 * Gets the current checkpoint index.
 *
 * @param client					Client index
 *
 * @return							The current checkpoint
 */
native int Shavit_GetCurrentCheckpoint(int client);

/**
 * Sets the current checkpoint index.
 *
 * @param client					Client index
 * @param index						New index to use
 *
 * @noreturn
 */
native void Shavit_SetCurrentCheckpoint(int client, int index);

/**
 * Gets how many times the client has teleported to checkpoints.
 *
 * @param client					Client index
 *
 * @return							The number of times the client has teleported to checkpoints.
 */
native int Shavit_GetTimesTeleported(int client);

/**
 * Checks whether the client has savestate data.
 *
 * @param client                    Client index
 *
 * @return                          Whether a savestate or rejoin-savestate data exists for the client.
 */
native bool Shavit_HasSavestate(int client);



// =====[ FORWARDS ]=====

/**
 * Called when a player saves a checkpoint.
 *
 * @param client					Client index.
 * @param index						Checkpoint that was saved to.
 * @param overflow					Does this checkpoint shift the rest.
 * @return							Plugin_Continue to allow saving, anything else to prevent.
 */
forward Action Shavit_OnSave(int client, int index, bool overflow);

/**
 * Called when a player deletes a checkpoint.
 *
 * @param client					Client index.
 * @param index						Checkpoint that will be deleted.
 * @return							Plugin_Continue to continue deletion, anything else to prevent.
 */
forward Action Shavit_OnDelete(int client, int index);

/**
 * Called when a player teleports with checkpoints.
 *
 * @param client					Client index.
 * @param index						Checkpoint that was teleported to.
 * @return							Plugin_Continue to allow teleporting, anything else to prevent.
 */
forward Action Shavit_OnTeleport(int client, int index);

/**
 * Called after the checkpoint menu has been made and before it's sent to the client.
 *
 * @param client					Client index.
 * @param segmented					If the menu was a segmented menu
 * @return							Plugin_Handled or Plugin_Stop to stop the menu.
 */
forward Action Shavit_OnCheckPointMenuMade(int client, bool segmented);

/**
 * Called before a selection is processed in the main checkpoint menu.
 *
 * @param client					Client index.
 * @param param2					Second parameter in the callback, usually the item selected.
 * @param info						reference copy of the info string used in the callback
 * @param maxlength					length of the info buffer
 * @param currentCheckpoint			Clients current checkpoint
 * @param maxCPs					Max checkpoints the client can use
 * @return							Plugin_Continue to continue the callback.
 */
forward Action Shavit_OnCheckpointMenuSelect(int client, int param2, char[] info, int maxlength, int currentCheckpoint, int maxCPs);



// =====[ DEPENDENCY ]=====

public SharedPlugin __pl_shavit_checkpoints = 
{
	name = "shavit-checkpoints", 
	file = "shavit-checkpoints.smx", 
	#if defined REQUIRE_PLUGIN
	required = 1, 
	#else
	required = 0, 
	#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_shavit_checkpoints_SetNTVOptional()
{
	MarkNativeAsOptional("Shavit_GetCheckpoint");
	MarkNativeAsOptional("Shavit_SetCheckpoint");
	MarkNativeAsOptional("Shavit_ClearCheckpoints");
	MarkNativeAsOptional("Shavit_TeleportToCheckpoint");
	MarkNativeAsOptional("Shavit_GetTotalCheckpoints");
	MarkNativeAsOptional("Shavit_OpenCheckpointMenu");
	MarkNativeAsOptional("Shavit_SaveCheckpoint");
	MarkNativeAsOptional("Shavit_GetCurrentCheckpoint");
	MarkNativeAsOptional("Shavit_SetCurrentCheckpoint");
	MarkNativeAsOptional("Shavit_GetTimesTeleported");
	MarkNativeAsOptional("Shavit_HasSavestate");
}
#endif