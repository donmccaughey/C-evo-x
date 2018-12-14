using System;
using System.Collections.Generic;
using System.Text;

namespace Configurator
{
	abstract class Process
	{
		public delegate void ProgressChangedHandler(object sender, int percentage);
		public event ProgressChangedHandler ProgressChanged;
		protected void RaiseProgressChanged(int percentage)
		{
			if (ProgressChanged != null)
				ProgressChanged(this, percentage);
		}

		public delegate void CompleteHandler(object sender);
		public event CompleteHandler Complete;
		protected void RaiseComplete()
		{
			if (Complete != null)
				Complete(this);
		}

		public abstract bool Progressing { get; }

		public abstract void Go();

		public abstract void Cancel();
	}
}
