static GlobalForward H_OnPlaySound = null;



// ======[ FORWARDS ]======

void CreateGlobalForwards()
{
	H_OnPlaySound = new GlobalForward("Shavit_OnPlaySound", ET_Event, Param_Cell, Param_String, Param_Cell, Param_Array, Param_CellByRef);
}

void Call_OnPlaySound(int client, char[] sound, int maxlength, int[] clients, int &count, Action &result)
{
	Call_StartForward(H_OnPlaySound);
	Call_PushCell(client);
	Call_PushStringEx(sound, maxlength, SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushCell(maxlength);
	Call_PushArrayEx(clients, MaxClients, SM_PARAM_COPYBACK);
	Call_PushCellRef(count);
	Call_Finish(result);
}