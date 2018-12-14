using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Text;
using System.Windows.Forms;
using System.IO;

namespace Configurator
{
	public partial class TextViewer : Form
	{
		public TextViewer()
		{
			InitializeComponent();
		}

		internal void ShowReadme(AddOn addOn)
		{
			string readmePath = Installer.GetReadmePath(addOn);
			Text = addOn.Name + " - Notes of the author";
			textBox.Text = File.ReadAllText(readmePath, Encoding.GetEncoding(1252));
			textBox.Select(0, 0);
			ShowDialog();
		}
	}
}
