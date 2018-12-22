using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

namespace Loader
{
	unsafe static class Program
	{
		delegate void CallPlayerHandler(int command, int player, int* data);

		[DllImport("cevo.dll", CallingConvention = CallingConvention.StdCall)]
		static extern void Run(IntPtr clientPtr);

		static CallPlayerHandler callPlayerHandler;
		static IntPtr clientPtr;
		static IntPtr serverPtr;

		static AIPlugin[] playerPlugin = new AIPlugin[Protocol.nPl];
		//static bool getReadyDone = false;
		static bool breakGameDone = false;

		static void CallPlayer(int command, int player, int* data)
		{
			if (command >= Protocol.cTurn)
			{
				if (player >= 0 && playerPlugin[player] != null)
					playerPlugin[player].Call(command, (IntPtr)data);
			}
			else
			{
				switch (command)
				{
					case Protocol.cInitModule:
						{
							serverPtr = ((IntPtr*)data)[0];
							((int*)data)[2] = 4096; // reserve maximum possible
							break;
						}

					case Protocol.cNewGame:
					case Protocol.cLoadGame:
						{ // possibly called multiple times per game because loader controls all .NET AIs
							// read string from data
							string assemblyPath = "";
							byte* read = (byte*)(data + 4 + 2 * Protocol.nPl);
							while (*read != 0)
							{
								assemblyPath += (char)*read;
								read++;
							}

							for (int playerX = 0; playerX < Protocol.nPl; playerX++)
								if (data[4 + Protocol.nPl + playerX] != 0)
								{ // it's one of the players to use this assembly
									playerPlugin[playerX] = new AIPlugin(assemblyPath);
									playerPlugin[playerX].Initialize(playerX, serverPtr, (IntPtr)data, command == Protocol.cNewGame);
								}

							//getReadyDone = false;
							breakGameDone = false;
							break;
						}

					//case Protocol.cGetReady:
					//    { // possibly called multiple times per game because loader controls all .NET AIs
					//        if (!getReadyDone)
					//        {
					//            getReadyDone = true;
					//            for (int playerX = 0; playerX < Protocol.nPl; playerX++)
					//            {
					//                if (playerPlugin[playerX] != null)
					//                    playerPlugin[playerX].Call(command, new IntPtr(data));
					//            }
					//        }
					//        break;
					//    }

					case Protocol.cBreakGame:
						{ // possibly called multiple times per game because loader controls all .NET AIs
							if (!breakGameDone)
							{
								breakGameDone = true;
								Array.Clear(playerPlugin, 0, Protocol.nPl);
							}
							break;
						}
				}
			}
		}

		/// <summary>
		/// The main entry point for the application.
		/// </summary>
		[STAThread]
		static void Main()
		{
			callPlayerHandler = CallPlayer;
			clientPtr = Marshal.GetFunctionPointerForDelegate(callPlayerHandler);
			Run(clientPtr);
		}
	}
}
