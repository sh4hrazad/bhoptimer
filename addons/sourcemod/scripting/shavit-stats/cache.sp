// ======[ EVENTS ]======

void OnClientConnected_InitCache(int client)
{
	gF_PlaytimeStart[client] = 0.0;
	gF_PlaytimeStyleStart[client] = 0.0;

	any empty[STYLE_LIMIT];
	gF_PlaytimeStyleSum[client] = empty;
	gB_HavePlaytimeOnStyle[client] = empty;
	gB_QueriedPlaytime[client] = false;
}

void OnClientPutInServer_InitCache(int client)
{
	gB_CanOpenMenu[client] = true;

	float now = GetEngineTime();
	gF_PlaytimeStart[client] = now;
	gF_PlaytimeStyleStart[client] = now;
}