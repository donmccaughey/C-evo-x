using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Text;
using System.Windows.Forms;

namespace Configurator
{
	partial class ProgressDialog : Form
	{
		Process process;

		public ProgressDialog(Process process)
		{
			this.process = process;
			InitializeComponent();
		}

		private void cancelButton_Click(object sender, EventArgs e)
		{
			process.Cancel();
		}

		private void ProgressChangedAsync(object sender, int percentage)
		{
			Invoke(new Process.ProgressChangedHandler(ProgressChanged), sender, percentage);
		}

		private void ProgressChanged(object sender, int percentage)
		{
			if (percentage < 100)
				progressBar.Value = percentage + 1; // workaround for Windows animated progress bar delay
			progressBar.Value = percentage;
		}

		private void CompleteAsync(object sender)
		{
			Invoke(new Process.CompleteHandler(Complete), sender);
		}

		private void Complete(object sender)
		{
			Close();
		}

		private void ProgressDialog_Shown(object sender, EventArgs e)
		{
			progressBar.Style = process.Progressing ? ProgressBarStyle.Continuous : ProgressBarStyle.Marquee;
			process.ProgressChanged += ProgressChangedAsync;
			process.Complete += CompleteAsync;
			process.Go();
		}
	}
}
