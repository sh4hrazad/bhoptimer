// ======[ EVENTS ]======

void RegisterCookies()
{
	RegisterCookie_Hide();
	RegisterCookie_Advs();
	RegisterCookie_AutoRestart();
}

void OnMapStart_CacheCookies()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i))
		{
			OnClientPutInServer(i);

			if(AreClientCookiesCached(i))
			{
				OnClientCookiesCached(i);
			}
		}
	}
}

public void OnClientCookiesCached(int client)
{
	if(IsFakeClient(client))
	{
		return;
	}

	OnClientCookiesCached_Hide(client);
	OnClientCookiesCached_AutoRestart(client);
}