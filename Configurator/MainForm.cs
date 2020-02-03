using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Text;
using System.Windows.Forms;
using Microsoft.Win32;
using System.IO;

namespace Configurator
{
	public partial class MainForm : Form
	{
		const int thisVersion = 1002002; // 1.2.2
		const string registryKeyPath = @"Software\cevo\RegVer9";


		public static string SizeString(long size)
		{
			return string.Format(size >= 9.95 * 1048576.0 ? "{0:F0}M" : "{0:F1}M", size / 1048576.0);
		}

		class DisplayMode
		{
			public readonly DEVMODE mode;

			public DisplayMode(DEVMODE mode)
			{
				this.mode = mode;
			}

			public override string ToString()
			{
				return string.Format("{0}x{1} ({2}Hz)", mode.dmPelsWidth, mode.dmPelsHeight, mode.dmDisplayFrequency);
			}
		}

		string runAfterClosed;
		Installer installer;
		AddOn english = null;

		public MainForm(string[] args)
		{
			InitializeComponent();
			if (args.Length > 0 && string.Compare(args[0].Substring(0, 2), "-r", true) == 0)
				runAfterClosed = args[0].Substring(2).Trim('"');
			else
				runAfterClosed = "";
		}

		private void MainForm_Load(object sender, EventArgs e)
		{
			changeLabel.Text = "Add: 0\r\nRemove: 0";

			int ScreenMode = 1;
			int ResolutionX = 0;
			int ResolutionY = 0;
			int ResolutionFreq = 0;
			RegistryKey registry = null;
			try
			{
				registry = Registry.CurrentUser.OpenSubKey(registryKeyPath, false);
				if (registry != null)
				{
					object value = registry.GetValue("ScreenMode");
					if (value != null)
						ScreenMode = (int)value;
					value = registry.GetValue("ResolutionX");
					if (value != null)
						ResolutionX = (int)value;
					value = registry.GetValue("ResolutionY");
					if (value != null)
						ResolutionY = (int)value;
					value = registry.GetValue("ResolutionFreq");
					if (value != null)
						ResolutionFreq = (int)value;
				}
			}
			finally
			{
				if (registry != null)
					registry.Close();
			}

			DisplayModeList displayModeList = new DisplayModeList();
			foreach (DEVMODE mode in displayModeList)
			{
				if (mode.dmPelsWidth >= 800 && mode.dmPelsHeight >= 480 && mode.dmBitsPerPel >= 16)
				{
					resolutionBox.Items.Add(new DisplayMode(mode));
					if (mode.dmPelsWidth == ResolutionX && mode.dmPelsHeight == ResolutionY && mode.dmDisplayFrequency == ResolutionFreq)
						resolutionBox.SelectedIndex = resolutionBox.Items.Count - 1;
				}
			}
			if (resolutionBox.SelectedIndex < 0)
				resolutionBox.SelectedIndex = resolutionBox.Items.Count - 1;
			switch (ScreenMode)
			{
				case 0: screenWindowRadio.Checked = true; break;
				case 1: screenNormalRadio.Checked = true; break;
				case 2: screenResolutionRadio.Checked = true; break;
			}

			installer = new Installer();
			english = new AddOn(AddOnType.Language, "english", false);
			english.Name = "English";

			Text += " " + AddOn.VersionToString(thisVersion);
		}

		AddOnSet LanguageAddSet
		{
			get
			{
				AddOn selected = (AddOn)languageBox.SelectedItem;
				AddOnSet set = new AddOnSet(false);
				if (selected != english)
				{
					if (selected.Installed)
					{
						AddOn update = installer.AvailableAddOns.Find(selected);
						if (update != null && update.Version > selected.Version && languageUpdateBox.Checked)
							set.Add(update); // update translation
					}
					else
						set.Add(selected);
				}
				return set;
			}
		}

		AddOnSet LanguageRemoveSet
		{
			get
			{
				AddOn selected = (AddOn)languageBox.SelectedItem;
				AddOnSet set = new AddOnSet(true);
				if (selected != english && selected.Installed)
				{ // no change in language, maybe update requested
					AddOn update = installer.AvailableAddOns.Find(selected);
					if (update != null && update.Version > selected.Version && languageUpdateBox.Checked)
						set.Add(selected); // update translation -- remove old first
				}
				else
				{
					foreach (AddOn addOn in installer.InstalledAddOns)
					{
						if (addOn.Type == AddOnType.Language && addOn != selected)
							set.Add(addOn); // this should be no more than one
					}
				}
				return set;
			}
		}

		private void languageBox_SelectedIndexChanged(object sender, EventArgs e)
		{
			bool showUpdate = false;
			AddOn selected = (AddOn)languageBox.SelectedItem;
			if (selected == english)
				translatorLabel.Text = "";
			else
			{
				translatorLabel.Text = "Translated by " + selected.Creator;
				if (selected.Installed)
				{
					AddOn update = installer.AvailableAddOns.Find(selected);
					if (update != null && update.Version > selected.Version)
					{
						languageUpdateBox.Text = string.Format("Update {0} to {1}",
							AddOn.VersionToString(selected.Version), AddOn.VersionToString(update.Version));
						showUpdate = true;
					}
				}
			}
			languageUpdateBox.Visible = showUpdate;
			selector_Changed(sender);
		}

		private void exploreButton_Click(object sender, EventArgs e)
		{
			System.Diagnostics.Process.Start(installer.AppDataFolder);
		}

		private void newVersionLabel_LinkClicked(object sender, LinkLabelLinkClickedEventArgs e)
		{
			System.Diagnostics.Process.Start("http://c-evo.org/files/");
		}

		private void zipStorerLabel_LinkClicked(object sender, LinkLabelLinkClickedEventArgs e)
		{
			System.Diagnostics.Process.Start("http://zipstorer.codeplex.com");
		}

		private void selector_Changed(object sender)
		{
			string changeInfo = "";
			int addCount = LanguageAddSet.Count + mapSelector.AddSet.Count + aiSelector.AddSet.Count;
			if (addCount == 0)
				changeInfo = "Add: 0";
			else
				changeInfo = string.Format("Add: {0} ({1})", addCount,
					SizeString(LanguageAddSet.TotalSize + mapSelector.AddSet.TotalSize + aiSelector.AddSet.TotalSize));
			int removeCount = LanguageRemoveSet.Count + mapSelector.RemoveSet.Count + aiSelector.RemoveSet.Count;
			if (removeCount == 0)
				changeInfo += "\r\nRemove: 0";
			else
				changeInfo += "\r\n" + string.Format("Remove: {0}", removeCount);
			changeLabel.Text = changeInfo;
			if (addCount + removeCount == 0)
				changeLabel.ForeColor = SystemColors.GrayText;
			else
				changeLabel.ForeColor = SystemColors.ControlText;
		}

		private void languageUpdateBox_CheckedChanged(object sender, EventArgs e)
		{
			selector_Changed(sender);
		}

		private void screenResolutionRadio_CheckedChanged(object sender, EventArgs e)
		{
			resolutionBox.Enabled = screenResolutionRadio.Checked;
		}

		private void cancelButton_Click(object sender, EventArgs e)
		{
			CloseAndRun();
		}

		private void okButton_Click(object sender, EventArgs e)
		{
			//AddOnSet testSet = new AddOnSet();
			//AddOn addOn1 = new AddOn(AddOnType.AI, "X1", false);
			//addOn1.URL = "http://c-evo.org//files//v06_legal.exe";
			//addOn1.Size = 690176;
			//testSet.Add(addOn1);
			//AddOn addOn2 = new AddOn(AddOnType.AI, "X2", false);
			//addOn2.URL = "http://c-evo.org//files//cevosetup.exe";
			//addOn2.Size = 2957161;
			//testSet.Add(addOn2);
			//AddOn addOn3 = new AddOn(AddOnType.AI, "X3", false);
			//addOn3.URL = "http://c-evo.org//files//v0147.exe";
			//addOn3.Size = 1953792;
			//testSet.Add(addOn3);
			//installer.Install(testSet);

			RegistryKey registry = Registry.CurrentUser.CreateSubKey(registryKeyPath);
			if (screenWindowRadio.Checked)
				registry.SetValue("ScreenMode", 0);
			else if (screenNormalRadio.Checked)
				registry.SetValue("ScreenMode", 1);
			else if (screenResolutionRadio.Checked)
			{
				registry.SetValue("ScreenMode", 2);
				if (resolutionBox.SelectedIndex >= 0)
				{
					registry.SetValue("ResolutionX", ((DisplayMode)resolutionBox.SelectedItem).mode.dmPelsWidth);
					registry.SetValue("ResolutionY", ((DisplayMode)resolutionBox.SelectedItem).mode.dmPelsHeight);
					registry.SetValue("ResolutionBPP", ((DisplayMode)resolutionBox.SelectedItem).mode.dmBitsPerPel);
					registry.SetValue("ResolutionFreq", ((DisplayMode)resolutionBox.SelectedItem).mode.dmDisplayFrequency);
				}
			}
			registry.Close();

			installer.Uninstall(LanguageRemoveSet);
			installer.Uninstall(mapSelector.RemoveSet);
			installer.Uninstall(aiSelector.RemoveSet);
			installer.Install(LanguageAddSet);
			installer.Install(mapSelector.AddSet);
			installer.Install(aiSelector.AddSet);

			if (installer.InstallOrdered)
			{
				Visible = false;
				ProgressDialog progressDialog = new ProgressDialog(installer);
				progressDialog.Text = "Downloading...";
				progressDialog.ShowDialog();
				TextViewer textViewer = new TextViewer();
				foreach (AddOn addOn in installer.Added)
				{
					if (addOn.Readme != "" && File.Exists(Installer.GetReadmePath(addOn)))
						textViewer.ShowReadme(addOn);
				}
			}
			else
				installer.Go(); // remove only or nothing, expect this not to require progress indication
			CloseAndRun();
		}

		private void CloseAndRun()
		{
			if (runAfterClosed != "")
			{
				try
				{
					System.Diagnostics.Process.Start(runAfterClosed);
				}
				catch (Exception)
				{
				}
			}
			Close();
		}

		private void MainForm_Shown(object sender, EventArgs e)
		{
			Installer.IndexReader indexReader = new Installer.IndexReader();
			ProgressDialog progressDialog = new ProgressDialog(indexReader);
			progressDialog.Text = "Connecting to Server...";
			progressDialog.ShowDialog();

			newVersionLabel.Visible = installer.AvailableAddOns.CurrentVersion > thisVersion;

			// fill language combo box
			foreach (AddOn addOn in installer.InstalledAddOns)
			{
				if (addOn.Type == AddOnType.Language)
					languageBox.Items.Add(addOn); // this should be no more than one
			}
			languageBox.Items.Add(english);
			foreach (AddOn addOn in installer.AvailableAddOns)
			{
				if (addOn.Type == AddOnType.Language && installer.InstalledAddOns.Find(addOn) == null)
					languageBox.Items.Add(addOn);
			}
			languageBox.SelectedIndex = 0;

			aiSelector.SetData(installer.InstalledAddOns, installer.AvailableAddOns, AddOnType.AI);
			mapSelector.SetData(installer.InstalledAddOns, installer.AvailableAddOns, AddOnType.MapSet);
		}
	}
}
