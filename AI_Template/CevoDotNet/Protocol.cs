using System;
using System.Collections.Generic;

namespace Loader
{
	static class Protocol
	{
		public const int nPl = 15;

		public const int cInitModule = 0x0000;
		public const int cReleaseModule = 0x0100;
		public const int cNewGame = 0x0800;
		public const int cLoadGame = 0x0810;
		public const int cReplay = 0x08E0;
		public const int cGetReady = 0x08F0;
		public const int cBreakGame = 0x0900;
		public const int cTurn = 0x2000;
	}
}
