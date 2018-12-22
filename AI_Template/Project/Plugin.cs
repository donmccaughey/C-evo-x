using System;
using System.Collections.Generic;

namespace AI
{
	public sealed class Plugin
	{
		Empire theEmpire;

		public Plugin()
		{
		}

		public void Initialize(int nationID, IntPtr serverPtr, IntPtr dataPtr, bool isNewGame)
		{
			theEmpire = new Empire(nationID, serverPtr, dataPtr, isNewGame);
		}

		public void Call(int command, IntPtr dataPtr)
		{
			theEmpire.Process(command, dataPtr);
		}
	}
}
