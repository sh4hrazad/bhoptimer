static GlobalForward H_Forwards_OnClanTagChangePre = null;
static GlobalForward H_Forwards_OnClanTagChangePost = null;



// ======[ FORWARDS ]======

void CreateGlobalForwards()
{
	H_Forwards_OnClanTagChangePre = new GlobalForward("Shavit_OnClanTagChangePre", ET_Event, Param_Cell, Param_String, Param_Cell);
	H_Forwards_OnClanTagChangePost = new GlobalForward("Shavit_OnClanTagChangePost", ET_Event, Param_Cell, Param_String, Param_Cell);
}

void Call_OnClanTagChangePre(int client, char[] clantag, int clantaglength, Action &result)
{
	Call_StartForward(H_Forwards_OnClanTagChangePre);
	Call_PushCell(client);
	Call_PushStringEx(clantag, clantaglength, SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushCell(clantaglength);
	Call_Finish(result);
}

void Call_OnClanTagChangePost(int client, char[] customtag, int customtaglength)
{
	Call_StartForward(H_Forwards_OnClanTagChangePost);
	Call_PushCell(client);
	Call_PushStringEx(customtag, customtaglength, SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushCell(customtaglength);
	Call_Finish();
}