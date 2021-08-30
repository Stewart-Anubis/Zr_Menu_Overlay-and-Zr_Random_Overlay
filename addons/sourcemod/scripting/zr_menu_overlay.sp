/*
 * =============================================================================
 * File:		  zr_menu_overlay.sp
 * Type:		  Base
 * Description:   Plugin's base file.
 *
 * Copyright (C) $CURRENT_YEAR  Anubis Edition. All rights reserved.
 * =============================================================================
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * As a special exception, AlliedModders LLC gives you permission to link the
 * code of this program (as well as its derivative works) to "Half-Life 2," the
 * "Source Engine," the "SourcePawn JIT," and any Game MODs that run on software
 * by the Valve Corporation.  You must obey the GNU General Public License in
 * all respects for all other code used.  Additionally, AlliedModders LLC grants
 * this exception to all derivative works.  AlliedModders LLC defines further
 * exceptions, found in LICENSE.txt (as of this writing, version JULY-31-2007),
 * or <http://www.sourcemod.net/license.php>.
 */
#define PLUGIN_NAME           "Zr Menu Round End Overlay"
#define PLUGIN_AUTHOR         "Anubis"
#define PLUGIN_DESCRIPTION    "Zr Menu Round End Overlay"
#define PLUGIN_VERSION        "1.1"
#define PLUGIN_URL            "https://github.com/Stewart-Anubis"
#define CVARS_ZR_ROUNDEND_OVERLAY_LOCKED 0

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>
#include <cstrike>

#pragma newdecls required

ConVar g_CvarEnable =null,
	g_CvarTimePreview = null,
	g_CvarZr_Roundend_Overlay = null,
	g_CvarConfig_FilePath = null;

ArrayList g_smOverlayNameH;
ArrayList g_smOverlayPathH;
ArrayList g_smOverlayNameZ;
ArrayList g_smOverlayPathZ;

Handle g_hOverlayClientZombie = null,
	g_hOverlayClientHuman = null,
	g_hOverlayClientTime[MAXPLAYERS + 1] = {null, ...};

int g_iOverlayClientZombie[MAXPLAYERS + 1] = {-1, ...},
	g_iOverlayClientHuman[MAXPLAYERS + 1] = {-1, ...},
	g_iItenSelect[MAXPLAYERS + 1] = {0, ...};

bool g_bEnable = true,
	g_bRoundEnd = false;

float g_fTimePreview = 10.0;

char g_sConfig_FilePath[PLATFORM_MAX_PATH];

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public void OnPluginStart()
{
	int iArraySizePath = ByteCountToCells(PLATFORM_MAX_PATH);
	int iArraySizeName = ByteCountToCells(64);
	g_smOverlayNameH = new ArrayList(iArraySizeName);
	g_smOverlayPathH = new ArrayList(iArraySizePath);
	g_smOverlayNameZ = new ArrayList(iArraySizeName);
	g_smOverlayPathZ = new ArrayList(iArraySizePath);

	g_CvarEnable = CreateConVar("zr_menu_overlay_enable", "1", "Menu Overlay Enable = 1/Disable = 0");
	g_CvarTimePreview = CreateConVar("zr_menu_overlay_preview_time", "10.0", "Preview Time.");
	g_CvarConfig_FilePath = CreateConVar("zr_menu_overlay_config_path", "configs/zr/zr_menu_overlay.txt", "Location of configuration file.");
	g_CvarZr_Roundend_Overlay = FindConVar("zr_roundend_overlay");

	g_CvarEnable.AddChangeHook(OnConVarChanged);
	g_CvarTimePreview.AddChangeHook(OnConVarChanged);
	g_CvarConfig_FilePath.AddChangeHook(OnConVarChanged);
	g_CvarZr_Roundend_Overlay.AddChangeHook(OnConVarChanged);

	OnConVarChanged(null, "", "");
	AutoExecConfig(true, "zombiereloaded/zr_menu_overlay");
	if (g_bEnable) SetConVarInt(g_CvarZr_Roundend_Overlay, CVARS_ZR_ROUNDEND_OVERLAY_LOCKED);

	g_hOverlayClientZombie = RegClientCookie("Zr Overlay Zombis Win", "Zombie overlay selected by the customer.", CookieAccess_Private);
	g_hOverlayClientHuman = RegClientCookie("Zr Overlay Humans Win", "Human overlay selected by the customer.", CookieAccess_Private);

	RegConsoleCmd("sm_overlay", Command_Overlay, "Overlay change.");
	RegAdminCmd("sm_overlayreload", Command_Reload, ADMFLAG_ROOT, "Descrição");
	
	// Hook events
	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);

	for(int i = 1; i <= MaxClients; i++)
	{ 
		if(IsValidClient(i))
		{	
			if(!IsFakeClient(i)) OnClientCookiesCached(i);
		}
	}
	File_ReadDownloadList();
}

public void OnConVarChanged(ConVar convar, char[] oldValue, char[] newValue)
{
	g_bEnable = g_CvarEnable.BoolValue;
	g_fTimePreview = g_CvarTimePreview.FloatValue;
	g_CvarConfig_FilePath.GetString(g_sConfig_FilePath ,sizeof(g_sConfig_FilePath));
	if (convar == g_CvarZr_Roundend_Overlay)
	{
		if (!g_bEnable || StringToInt(newValue) == CVARS_ZR_ROUNDEND_OVERLAY_LOCKED) return;
		SetConVarInt(g_CvarZr_Roundend_Overlay, CVARS_ZR_ROUNDEND_OVERLAY_LOCKED);
	}
}

void File_ReadDownloadList()
{
	KeyValues g_hKvOverlay;

	g_smOverlayNameH.Clear();
	g_smOverlayPathH.Clear();
	g_smOverlayNameZ.Clear();
	g_smOverlayPathZ.Clear();

	char sBuffer_temp[PLATFORM_MAX_PATH];

	BuildPath(Path_SM, sBuffer_temp, sizeof(sBuffer_temp), g_sConfig_FilePath);

	g_hKvOverlay = new KeyValues("Overlay");

	if(!FileExists(sBuffer_temp))
	{
		SetFailState("Could not find config: \"%s\"", sBuffer_temp);
		return;
	}
	else FileToKeyValues(g_hKvOverlay, sBuffer_temp);

	KvRewind(g_hKvOverlay);
	if(KvJumpToKey(g_hKvOverlay, "Overlay_Humans"))
	{
		if(KvGotoFirstSubKey(g_hKvOverlay))
		{
			do
			{
				KvGetString(g_hKvOverlay, "name", sBuffer_temp, sizeof(sBuffer_temp), "MISSING");
				g_smOverlayNameH.PushString(sBuffer_temp);
				KvGetString(g_hKvOverlay, "Overlay", sBuffer_temp, sizeof(sBuffer_temp), "MISSING");
				g_smOverlayPathH.PushString(sBuffer_temp);
				Format(sBuffer_temp, sizeof(sBuffer_temp), "materials/%s.vmt", sBuffer_temp);
				AddFileToDownloadsTable(sBuffer_temp);
				ReplaceString(sBuffer_temp, sizeof(sBuffer_temp), ".vmt", ".vtf");
				AddFileToDownloadsTable(sBuffer_temp);
			} while (KvGotoNextKey(g_hKvOverlay));
		}
	}
	KvRewind(g_hKvOverlay);
	if(KvJumpToKey(g_hKvOverlay, "Overlay_Zombies"))
	{
		if(KvGotoFirstSubKey(g_hKvOverlay))
		{
			do
			{
				KvGetString(g_hKvOverlay, "name", sBuffer_temp, sizeof(sBuffer_temp), "MISSING");
				g_smOverlayNameZ.PushString(sBuffer_temp);
				KvGetString(g_hKvOverlay, "Overlay", sBuffer_temp, sizeof(sBuffer_temp), "MISSING");
				g_smOverlayPathZ.PushString(sBuffer_temp);
				Format(sBuffer_temp, sizeof(sBuffer_temp), "materials/%s.vmt", sBuffer_temp);
				AddFileToDownloadsTable(sBuffer_temp);
				ReplaceString(sBuffer_temp, sizeof(sBuffer_temp), ".vmt", ".vtf");
				AddFileToDownloadsTable(sBuffer_temp);
			} while (KvGotoNextKey(g_hKvOverlay));
		}
	}
	KvRewind(g_hKvOverlay);
	delete g_hKvOverlay;
}

public void OnPluginEnd()
{
	g_smOverlayNameH.Clear();
	g_smOverlayPathH.Clear();
	g_smOverlayNameZ.Clear();
	g_smOverlayPathZ.Clear();
}

public void OnMapStart()
{
	LoadTranslations("zr_menu_overlay.phrases");
}

public void OnClientCookiesCached(int client)
{
	char scookie[32];
	GetClientCookie(client, g_hOverlayClientZombie, scookie, sizeof(scookie));
	if(!StrEqual(scookie, ""))
	{
		g_iOverlayClientZombie[client] = StringToInt(scookie);
		if (g_iOverlayClientZombie[client] > (g_smOverlayPathZ.Length - 1)) g_iOverlayClientZombie[client] = 0;
	}
	else	g_iOverlayClientZombie[client] = 0;

	GetClientCookie(client, g_hOverlayClientHuman, scookie, sizeof(scookie));
	if(!StrEqual(scookie, ""))
	{
		g_iOverlayClientHuman[client] = StringToInt(scookie);
		if (g_iOverlayClientHuman[client] > (g_smOverlayPathH.Length - 1)) g_iOverlayClientHuman[client] = 0;
	}
	else	g_iOverlayClientHuman[client] = 0;
}

public Action Command_Overlay(int client, int arg)
{
	if(g_bEnable && IsValidClient(client)) MakeMenuOverlay(client);

	return Plugin_Handled;
}

public Action Command_Reload(int client, int arg)
{
	if(IsValidClient(client)) File_ReadDownloadList();

	return Plugin_Handled;
}

void MakeMenuOverlay(int client, int bMenu = 0, int i_Last = -1)
{
	if (!IsValidClient(client))
	{
		return;
	}

	SetGlobalTransTarget(client);

	g_iItenSelect[client] = bMenu;

	char OverlayTitle[64];
	char Menu_Humans_Win[64];
	char Menu_Zombis_Win[64];
	char Menu_Random[64];
	char Menu_Disabled[64];
	char sIndex_temp[20];

	Format(OverlayTitle, sizeof(OverlayTitle), "%t\n ", "Overlay Menu Title");
	Format(Menu_Humans_Win, sizeof(Menu_Humans_Win), "%t", "Overlay Menu Humans");
	Format(Menu_Zombis_Win, sizeof(Menu_Zombis_Win), "%t", "Overlay Menu Zombies");
	Format(Menu_Random, sizeof(Menu_Random), "%t", "Random");
	Format(Menu_Disabled, sizeof(Menu_Disabled), "%t", "Disabled");

	if(bMenu == 3)
	{
		char sbuffer[64];

		Menu MenuOverlay = new Menu(MenuClientOverlayCallBack);
		MenuOverlay.ExitBackButton = true;
		Format(sbuffer, sizeof(sbuffer), "%s\n ", Menu_Humans_Win);
		MenuOverlay.SetTitle(sbuffer);

		if (g_iOverlayClientHuman[client] == -2) Format(sbuffer, sizeof(sbuffer), "%s [X]", Menu_Disabled);
		else Format(sbuffer, sizeof(sbuffer), "%s [ ]", Menu_Disabled);
		MenuOverlay.AddItem("-2", sbuffer);

		if (g_iOverlayClientHuman[client] == -1) Format(sbuffer, sizeof(sbuffer), "%s [X]", Menu_Random);
		else Format(sbuffer, sizeof(sbuffer), "%s [ ]", Menu_Random);
		MenuOverlay.AddItem("-1", sbuffer);
		
		for (int i = 0; i < g_smOverlayNameH.Length; i++)
		{
			IntToString(i, sIndex_temp, sizeof(sIndex_temp));
			g_smOverlayNameH.GetString(i, sbuffer, sizeof(sbuffer));
			if (g_iOverlayClientHuman[client] == i) Format(sbuffer, sizeof(sbuffer), "%s [X]", sbuffer);
			else Format(sbuffer, sizeof(sbuffer), "%s [ ]", sbuffer);
			MenuOverlay.AddItem(sIndex_temp, sbuffer);
		}

		if(i_Last == -1) MenuOverlay.Display(client, MENU_TIME_FOREVER);
		else MenuOverlay.DisplayAt(client, (i_Last/GetMenuPagination(MenuOverlay))*GetMenuPagination(MenuOverlay), MENU_TIME_FOREVER);
	}	
	else if(bMenu == 2)
	{
		char sbuffer[64];

		Menu MenuOverlay = new Menu(MenuClientOverlayCallBack);
		MenuOverlay.ExitBackButton = true;
		Format(sbuffer, sizeof(sbuffer), "%s\n ", Menu_Zombis_Win);
		MenuOverlay.SetTitle(sbuffer);

		if (g_iOverlayClientZombie[client] == -2) Format(sbuffer, sizeof(sbuffer), "%s [X]", Menu_Disabled);
		else Format(sbuffer, sizeof(sbuffer), "%s [ ]", Menu_Disabled);
		MenuOverlay.AddItem("-2", sbuffer);

		if (g_iOverlayClientZombie[client] == -1) Format(sbuffer, sizeof(sbuffer), "%s [X]", Menu_Random);
		else Format(sbuffer, sizeof(sbuffer), "%s [ ]", Menu_Random);
		MenuOverlay.AddItem("-1", sbuffer);

		for (int i = 0; i < g_smOverlayNameZ.Length; i++)
		{
			IntToString(i, sIndex_temp, sizeof(sIndex_temp));
			g_smOverlayNameZ.GetString(i, sbuffer, sizeof(sbuffer));
			if (g_iOverlayClientZombie[client] == i) Format(sbuffer, sizeof(sbuffer), "%s [X]", sbuffer);
			else Format(sbuffer, sizeof(sbuffer), "%s [ ]", sbuffer);
			MenuOverlay.AddItem(sIndex_temp, sbuffer);
		}

		if(i_Last == -1) MenuOverlay.Display(client, MENU_TIME_FOREVER);
		else MenuOverlay.DisplayAt(client, (i_Last/GetMenuPagination(MenuOverlay))*GetMenuPagination(MenuOverlay), MENU_TIME_FOREVER);
	}
	else if(bMenu <= 1)
	{
		char sZbuffer[64];
		char sHbuffer[64];

		if (g_iOverlayClientZombie[client] >= 0)
		{
			g_smOverlayNameZ.GetString(g_iOverlayClientZombie[client], sZbuffer, sizeof(sZbuffer));
			Format(sZbuffer, sizeof(sZbuffer), "%s [%s]", Menu_Zombis_Win, sZbuffer);
		}
		else if (g_iOverlayClientZombie[client] == -1) Format(sZbuffer, sizeof(sZbuffer), "%s [%s]", Menu_Zombis_Win, Menu_Random);
		else if (g_iOverlayClientZombie[client] == -2) Format(sZbuffer, sizeof(sZbuffer), "%s [%s]", Menu_Zombis_Win, Menu_Disabled);

		if (g_iOverlayClientHuman[client] >= 0)
		{
			g_smOverlayNameH.GetString(g_iOverlayClientHuman[client], sHbuffer, sizeof(sHbuffer));
			Format(sHbuffer, sizeof(sHbuffer), "%s [%s]", Menu_Humans_Win, sHbuffer);
		}
		if (g_iOverlayClientHuman[client] == -1) Format(sHbuffer, sizeof(sHbuffer), "%s [%s]", Menu_Humans_Win, Menu_Random);
		if (g_iOverlayClientHuman[client] == -2) Format(sHbuffer, sizeof(sHbuffer), "%s [%s]", Menu_Humans_Win, Menu_Disabled);

		Menu MenuOverlay = new Menu(MenuClientOverlayCallBack);

		MenuOverlay.ExitButton = true;
		MenuOverlay.SetTitle(OverlayTitle);

		MenuOverlay.AddItem("Menu_Humans_Win", sHbuffer);
		MenuOverlay.AddItem("Menu_Zombis_Win", sZbuffer);
		MenuOverlay.AddItem("", "", ITEMDRAW_NOTEXT);

		MenuOverlay.Display(client, MENU_TIME_FOREVER);
	}
}

public int MenuClientOverlayCallBack(Handle MenuOverlay, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_End)
	{
		delete MenuOverlay;
	}

	if (action == MenuAction_Select)
	{
		char sItem[64];
		GetMenuItem(MenuOverlay, itemNum, sItem, sizeof(sItem));

		if (g_iItenSelect[client] == 3) 
		{
			g_iOverlayClientHuman[client] = StringToInt(sItem);
			SetClientCookie(client, g_hOverlayClientHuman, sItem);
			MakeMenuOverlay(client, 3, itemNum);
			PreviewOverlay(client, 3, StringToInt(sItem));
			return 0;
		}
		else if (g_iItenSelect[client] == 2)
		{
			g_iOverlayClientZombie[client] = StringToInt(sItem);
			SetClientCookie(client, g_hOverlayClientZombie, sItem);
			MakeMenuOverlay(client, 2, itemNum);
			PreviewOverlay(client, 2, StringToInt(sItem));
			return 0;
		}
		else if (g_iItenSelect[client] <= 1)
		{
			if (StrEqual(sItem[0], "Menu_Humans_Win"))
			{
				MakeMenuOverlay(client, 3);
				return 0;
			}
			if (StrEqual(sItem[0], "Menu_Zombis_Win"))
			{
				MakeMenuOverlay(client, 2);
				return 0;
			}
		}
	}

	if (action == MenuAction_Cancel && itemNum == MenuCancel_ExitBack)
	{
		MakeMenuOverlay(client);
	}

	return 0;
}

void PreviewOverlay(int iClient, int iTeam, int iIndex)
{
	if (IsValidClient(iClient))
	{
		if (g_hOverlayClientTime[iClient] != null)
		{
			KillTimer(g_hOverlayClientTime[iClient]);
			g_hOverlayClientTime[iClient] = null;
			PreviewOverlayEnd(INVALID_HANDLE, iClient);
			return ;
		}
		if (iIndex <= -1) return;

		char sBuffer_temp[PLATFORM_MAX_PATH];

		if (iTeam == 3)
		{
			g_smOverlayPathH.GetString(iIndex, sBuffer_temp, sizeof(sBuffer_temp));
		}
		if (iTeam == 2)
		{
			g_smOverlayPathZ.GetString(iIndex, sBuffer_temp, sizeof(sBuffer_temp));
		}
		ShowOverlayToClient(iClient, sBuffer_temp);
		g_hOverlayClientTime[iClient] = CreateTimer(g_fTimePreview, PreviewOverlayEnd, iClient);
	}
}

public Action PreviewOverlayEnd(Handle time, int client)
{
	g_hOverlayClientTime[client] = null;
	if (IsValidClient(client))
	{
		ShowOverlayToClient(client, "");
	}
	return Plugin_Stop;
}

public void Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	g_bRoundEnd = false;
	if(g_bEnable) ShowOverlayToAll("");
}

public void Event_RoundEnd(Handle event, const char[] name, bool dontBroadcast)
{
	if (!g_bRoundEnd)
	{
		g_bRoundEnd = true;
		// Get all required event info.
		int winner = GetEventInt(event, "winner");

		// Display the overlay to all clients.
		if(g_bEnable) CreateTimer(0.2, Event_RoundEndPost, winner, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action Event_RoundEndPost(Handle time, int winner)
{
	RoundEndOverlayStart(winner);
	return Plugin_Stop;
}

void RoundEndOverlayStart(int winner)
{
	char sBuffer_temp[PLATFORM_MAX_PATH];
	
	switch(winner)
	{
		// Show "zombies win" overlay.
		case CS_TEAM_T:
		{
			int randoverlay = GetRandomInt(0, (g_smOverlayPathZ.Length - 1));

			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i) && !IsFakeClient(i))
				{
					if (g_iOverlayClientZombie[i] == -2)
					{
						continue;
					}
					else if (g_iOverlayClientZombie[i] == -1)
					{
						g_smOverlayPathZ.GetString(randoverlay, sBuffer_temp, sizeof(sBuffer_temp));
						ShowOverlayToClient(i, sBuffer_temp);
					}
					else if (g_iOverlayClientZombie[i] >= 0)
					{
						g_smOverlayPathZ.GetString(g_iOverlayClientZombie[i], sBuffer_temp, sizeof(sBuffer_temp));
						ShowOverlayToClient(i, sBuffer_temp);
					}
				}
			}
		}
		// Show "humans win" overlay.
		case CS_TEAM_CT:
		{
			int randoverlay = GetRandomInt(0, (g_smOverlayPathH.Length - 1));

			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i) && !IsFakeClient(i))
				{
					if (g_iOverlayClientHuman[i] == -2)
					{
						continue;
					}
					else if (g_iOverlayClientHuman[i] == -1)
					{
						g_smOverlayPathH.GetString(randoverlay, sBuffer_temp, sizeof(sBuffer_temp));
						ShowOverlayToClient(i, sBuffer_temp);
					}
					else if (g_iOverlayClientHuman[i] >= 0)
					{
						g_smOverlayPathH.GetString(g_iOverlayClientHuman[i], sBuffer_temp, sizeof(sBuffer_temp));
						ShowOverlayToClient(i, sBuffer_temp);
					}
				}
			}
		}
		// Show no overlay.
		default:
		{
			ShowOverlayToAll("");
		}
	}
}

void ShowOverlayToAll(const char[] overlaypath)
{
	// x = client index.
	for (int x = 1; x <= MaxClients; x++)
	{
		// If client isn't in-game, then stop.
		if (IsClientInGame(x) && !IsFakeClient(x))
		{
			ShowOverlayToClient(x, overlaypath);
		}
	}
}

void ShowOverlayToClient(int client, const char[] overlaypath)
{
	ClientCommand(client, "r_screenoverlay \"%s\"", overlaypath);
}

stock bool IsValidClient(int client, bool bzrAllowBots = false, bool bzrAllowDead = true)
{
	if (!(1 <= client <= MaxClients) || !IsClientInGame(client) || (IsFakeClient(client) && !bzrAllowBots) || IsClientSourceTV(client) || IsClientReplay(client) || (!bzrAllowDead && !IsPlayerAlive(client)))
		return false;
	return true;
}