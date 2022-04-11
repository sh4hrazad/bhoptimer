#include <clientprefs>
#include <sdktools>
#include <sourcemod>
#include <convar_class>
#include <shavit>

#pragma newdecls required
#pragma semicolon 1

#define PLUGIN_VERSION "2.0"

#define PAINT_DISTANCE_SQ 1.0

/* Colour name, file name */
char gS_PaintColours[][][64] =    // Modify this to add/change colours
{
	{ "Random",     "random"         },
	{ "White",      "paint_white"    },
	{ "Black",      "paint_black"    },
	{ "Blue",       "paint_blue"     },
	{ "Light Blue", "paint_lightblue"},
	{ "Brown",      "paint_brown"    },
	{ "Cyan",       "paint_cyan"     },
	{ "Green",      "paint_green"    },
	{ "Dark Green", "paint_darkgreen"},
	{ "Red",        "paint_red"      },
	{ "Orange",     "paint_orange"   },
	{ "Yellow",     "paint_yellow"   },
	{ "Pink",       "paint_pink"     },
	{ "Light Pink", "paint_lightpink"},
	{ "Purple",     "paint_purple"   },
};

/* Size name, size suffix */
char gS_PaintSizes[][][64] =    // Modify this to add more sizes
{
	{ "Small",  ""      },
	{ "Medium", "_med"  },
	{ "Large",  "_large"},
};

int gI_Sprites[sizeof(gS_PaintColours) - 1][sizeof(gS_PaintSizes)];

Menu gH_PaintMenu;
Menu gH_PaintSizeMenu;

int gI_PlayerPaintColour[MAXPLAYERS + 1];
int gI_PlayerPaintSize[MAXPLAYERS + 1];

float gF_LastPaint[MAXPLAYERS + 1][3];
bool gB_IsPainting[MAXPLAYERS + 1];

/* COOKIES */
Handle gH_PlayerPaintColour;
Handle gH_PlayerPaintSize;

/* ConVars */
ConVar gCV_PaintSendToAll = null;

public Plugin myinfo =
{
	name = "[shavit] Paint",
	author = "SlidyBat",
	description = "Allow players to paint on walls.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Ciallo-Ani/surftimer"
}

public void OnPluginStart()
{
	gCV_PaintSendToAll = new Convar("shavit_paint_sendtoall", "0", "Should the paint be sent to everyone?", 0, true, 0.0, true, 1.0);

	Convar.AutoExecConfig();

	/* Register Cookies */
	gH_PlayerPaintColour = RegClientCookie("paint_playerpaintcolour", "paint_playerpaintcolour", CookieAccess_Protected);
	gH_PlayerPaintSize = RegClientCookie("paint_playerpaintsize", "paint_playerpaintsize", CookieAccess_Protected);

	/* COMMANDS */
	RegConsoleCmd("+paint", Command_EnablePaint);
	RegConsoleCmd("-paint", Command_DisablePaint);
	RegConsoleCmd("sm_paintcolour", Command_PaintColour);
	RegConsoleCmd("sm_paintcolor", Command_PaintColour);
	RegConsoleCmd("sm_paintsize", Command_PaintSize);

	CreatePaintMenus();

	/* Late loading */
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			OnClientCookiesCached(i);
		}
	}
}

public void OnClientCookiesCached(int client)
{
	char sValue[64];

	GetClientCookie(client, gH_PlayerPaintColour, sValue, sizeof(sValue));
	gI_PlayerPaintColour[client] = StringToInt(sValue);

	GetClientCookie(client, gH_PlayerPaintSize, sValue, sizeof(sValue));
	gI_PlayerPaintSize[client] = StringToInt(sValue);
}

public void OnMapStart()
{
	char buffer[PLATFORM_MAX_PATH];

	AddFileToDownloadsTable("materials/decals/paint/paint_decal.vtf");
	for (int colour = 1; colour < sizeof(gS_PaintColours); colour++)
	{
		for (int size = 0; size < sizeof(gS_PaintSizes); size++)
		{
			Format(buffer, sizeof(buffer), "decals/paint/%s%s.vmt", gS_PaintColours[colour][1], gS_PaintSizes[size][1]);
			gI_Sprites[colour - 1][size] = PrecachePaint(buffer); // colour - 1 because starts from [1], [0] is reserved for random
		}
	}

	CreateTimer(0.1, Timer_Paint, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action Command_EnablePaint(int client, int args)
{
	TraceEye(client, gF_LastPaint[client]);
	gB_IsPainting[client] = true;

	return Plugin_Handled;
}

public Action Command_DisablePaint(int client, int args)
{
	gB_IsPainting[client] = false;

	return Plugin_Handled;
}

public Action Command_PaintColour(int client, int args)
{
	gH_PaintMenu.Display(client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}

public Action Command_PaintSize(int client, int args)
{
	gH_PaintSizeMenu.Display(client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}

public Action Timer_Paint(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && gB_IsPainting[i])
		{
			static float pos[3];
			TraceEye(i, pos);

			if (GetVectorDistance(pos, gF_LastPaint[i], true) > PAINT_DISTANCE_SQ)
			{
				AddPaint(i, pos, gI_PlayerPaintColour[i], gI_PlayerPaintSize[i]);

				gF_LastPaint[i] = pos;
			}
		}
	}

	return Plugin_Continue;
}

void AddPaint(int client, float pos[3], int paint = 0, int size = 0)
{
	if (paint == 0)
	{
		paint = GetRandomInt(1, sizeof(gS_PaintColours) - 1);
	}

	TE_SetupWorldDecal(pos, gI_Sprites[paint - 1][size]);

	if (gCV_PaintSendToAll.BoolValue)
	{
		TE_SendToAll();
	}
	else
	{
		TE_SendToClient(client);
	}
}

int PrecachePaint(char[] filename)
{
	char tmpPath[PLATFORM_MAX_PATH];
	Format(tmpPath, sizeof(tmpPath), "materials/%s", filename);
	AddFileToDownloadsTable(tmpPath);

	return PrecacheDecal(filename, true);
}

void CreatePaintMenus()
{
	/* COLOURS MENU */
	delete gH_PaintMenu;
	gH_PaintMenu = new Menu(PaintColourMenuHandle);

	gH_PaintMenu.SetTitle("选择喷漆颜色:");

	for (int i = 0; i < sizeof(gS_PaintColours); i++)
	{
		gH_PaintMenu.AddItem(gS_PaintColours[i][0], gS_PaintColours[i][0]);
	}

	/* SIZE MENU */
	delete gH_PaintSizeMenu;
	gH_PaintSizeMenu = new Menu(PaintSizeMenuHandle);

	gH_PaintSizeMenu.SetTitle("选择喷漆尺寸:");

	for (int i = 0; i < sizeof(gS_PaintSizes); i++)
	{
		gH_PaintSizeMenu.AddItem(gS_PaintSizes[i][0], gS_PaintSizes[i][0]);
	}
}

public int PaintColourMenuHandle(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		SetClientPaintColour(param1, param2);
	}

	return 0;
}

public int PaintSizeMenuHandle(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		SetClientPaintSize(param1, param2);
	}

	return 0;
}

void SetClientPaintColour(int client, int paint)
{
	char sValue[64];
	gI_PlayerPaintColour[client] = paint;
	IntToString(paint, sValue, sizeof(sValue));
	SetClientCookie(client, gH_PlayerPaintColour, sValue);

	Shavit_PrintToChat(client, "喷漆颜色已修改为: \x10%s", gS_PaintColours[paint][0]);
}

void SetClientPaintSize(int client, int size)
{
	char sValue[64];
	gI_PlayerPaintSize[client] = size;
	IntToString(size, sValue, sizeof(sValue));
	SetClientCookie(client, gH_PlayerPaintSize, sValue);

	Shavit_PrintToChat(client, "喷漆尺寸已修改为: \x10%s", gS_PaintSizes[size][0]);
}

stock void TE_SetupWorldDecal(const float vecOrigin[3], int index)
{
	TE_Start("World Decal");
	TE_WriteVector("m_vecOrigin", vecOrigin);
	TE_WriteNum("m_nIndex", index);
}

stock void TraceEye(int client, float pos[3])
{
	float vAngles[3], vOrigin[3];
	GetClientEyePosition(client, vOrigin);
	GetClientEyeAngles(client, vAngles);

	TR_TraceRayFilter(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, TraceEntityFilterPlayer);

	if (TR_DidHit())
	{
		TR_GetEndPosition(pos);
	}
}

public bool TraceEntityFilterPlayer(int entity, int contentsMask)
{
	return (entity > MaxClients || !entity);
}