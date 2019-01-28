using System;
using System.Collections.Generic;
using System.Text;
using System.IO;
using System.Windows.Forms;
using System.Net;
using System.ComponentModel;
using System.IO.Compression;

namespace Configurator
{
	class Installer : Process
	{
		static string programFolder;
		static string appDataFolder;
		static string downloadFolder;
		static AddOnSet installedAddOns = null;
		static AddOnSet availableAddOns = null;
		static WebClient downloader = new WebClient();

		static Installer()
		{
			programFolder = Path.GetDirectoryName(Application.ExecutablePath);
			appDataFolder = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
			if (appDataFolder == "")
				appDataFolder = programFolder;
			else
			{
				appDataFolder += "\\C-evo";
				if (!Directory.Exists(appDataFolder))
					Directory.CreateDirectory(appDataFolder);
			}

			downloadFolder = Path.GetTempPath().TrimEnd('\\');
			if (downloadFolder == "")
			{
				downloadFolder = appDataFolder + "\\Temp";
				if (!Directory.Exists(downloadFolder))
					Directory.CreateDirectory(downloadFolder);
			}

			installedAddOns = new AddOnSet(true);
			if (File.Exists(appDataFolder + "\\addons.xml"))
			{
				try
				{
					installedAddOns.AddXML(File.ReadAllText(appDataFolder + "\\addons.xml"));
				}
				catch (Exception)
				{
					MessageBox.Show("Error reading file 'addons.xml' from AppData folder!", "Error");
				}
			}
			if (File.Exists(programFolder + "\\addons.xml"))
			{
				try
				{
					installedAddOns.AddXML(File.ReadAllText(programFolder + "\\addons.xml"));
				}
				catch (Exception)
				{
					MessageBox.Show("Error reading file 'addons.xml' from program folder!", "Error");
				}
			}
		}

		static bool HaveWriteAccess(string folderPath)
		{
			string testFilePath = folderPath + "\\conftest.txt";
			string[] lines = { "TEST" };
			try
			{
				File.WriteAllLines(testFilePath, lines);
				File.Delete(testFilePath);
			}
			catch (Exception)
			{
				return false;
			}
			return true;
		}

		public static bool CanInstall(AddOnType type, out string message)
		{
			message = "";
			if (type == AddOnType.AI)
			{
				if (HaveWriteAccess(programFolder))
					return true;
				else
				{
					message = "Adding or removing AI modules requires write access to the C-evo program folder. Please contact your administrator.";
					return false;
				}
			}
			else
				return true;
		}

		static string GetAddOnFolder(AddOn addOn)
		{
			switch (addOn.Type)
			{
				case AddOnType.Language:
					return appDataFolder + "\\Localization";
				case AddOnType.MapSet:
					return appDataFolder + "\\Maps";
				case AddOnType.AI:
					return programFolder;
				default:
					return "";
			}
		}

		public static string GetReadmePath(AddOn addOn)
		{
			if (addOn.Readme == "")
				return "";
			else
				return GetAddOnFolder(addOn) + "\\" + addOn.Readme;
		}


		AddOnSet installSet = new AddOnSet(false);
		AddOnSet uninstallSet = new AddOnSet(true);
		int lastProgressPercentage;
		int currentDownloadIndex = 0;
		long totalDownloadSize;
		long completedDownloadSize;

		public string AppDataFolder { get { return appDataFolder; } }
		public AddOnSet InstalledAddOns { get { return installedAddOns; } }
		public AddOnSet AvailableAddOns { get { return availableAddOns; } }
		public bool InstallOrdered { get { return installSet.Count > 0; } }
		public bool UninstallOrdered { get { return uninstallSet.Count > 0; } }

		public AddOnSet Added
		{
			get
			{
				AddOnSet added = new AddOnSet(true);
				foreach (AddOn addOn in installSet)
				{
					if (installedAddOns.Find(addOn) != null)
						added.Add(addOn);
				}
				return added;
			}
		}

		public class IndexReader : Process
		{
			public IndexReader()
			{
			}

			public override bool Progressing { get { return false; } }

			void DownloadStringCompleted(Object sender, DownloadStringCompletedEventArgs e)
			{
				availableAddOns = new AddOnSet(false);
				if (!e.Cancelled)
				{
					if (e.Error != null)
						MessageBox.Show("Can't connect to server c-evo.org!\nOnly limited options will be available.", "No Internet Connection",
							MessageBoxButtons.OK, MessageBoxIcon.Exclamation);
					else
					{
						try
						{
							availableAddOns.AddXML(e.Result);
						}
						catch (Exception)
						{
							MessageBox.Show("Error reading file 'index.xml'!", "Error");
						}
					}
				}
				downloader.DownloadStringCompleted -= DownloadStringCompleted;
				RaiseComplete();
			}

			public override void Go()
			{
				downloader.Encoding = Encoding.UTF8;
				downloader.DownloadStringCompleted += DownloadStringCompleted;
				downloader.DownloadStringAsync(new Uri("http://c-evo.org/files/index.xml"));
				//downloader.DownloadStringAsync(new Uri("http://c-evo.org/files/cevosetup.exe")); // test slow connection
			}

			public override void Cancel()
			{
				downloader.CancelAsync();
			}
		}

		public Installer()
		{
		}

		public override bool Progressing { get { return true; } }

		public void Install(AddOnSet set)
		{
			installSet.AddRange(set);
		}

		public void Uninstall(AddOnSet set)
		{
			uninstallSet.AddRange(set);
		}

		void DownloadProgressChanged(object sender, DownloadProgressChangedEventArgs e)
		{
			int progressPercentage = (int)((completedDownloadSize * 100 + installSet[currentDownloadIndex].Size * e.ProgressPercentage) / totalDownloadSize);
			if (progressPercentage > lastProgressPercentage)
			{
				lastProgressPercentage = progressPercentage;
				RaiseProgressChanged(progressPercentage);
			}
		}

		void DownloadComplete(object sender, AsyncCompletedEventArgs e)
		{
			if (!e.Cancelled)
			{ // unzip downloaded file
				AddOn currentDownload = installSet[currentDownloadIndex];
				try
				{
					currentDownload.Files.Clear();
					string zipFilePath = downloadFolder + "\\" + Path.GetFileName(currentDownload.URL);
					string targetFolder = GetAddOnFolder(currentDownload);
					if (targetFolder != "")
					{
						if (targetFolder != programFolder && !Directory.Exists(targetFolder))
							Directory.CreateDirectory(targetFolder);
						using (ZipStorerLight package = ZipStorerLight.Open(zipFilePath))
						{
							List<ZipStorerLight.ZipFileEntry> content = package.ReadCentralDir();
							foreach (ZipStorerLight.ZipFileEntry item in content)
							{
								if (item.FileSize > 0) // skip folders
								{
									package.ExtractFile(item, targetFolder + "\\" + item.FilenameInZip);
									currentDownload.Files.Add(targetFolder + "\\" + item.FilenameInZip);
								}
							}
						}
						File.Delete(zipFilePath);
						installedAddOns.Add(currentDownload);
					}
				}
				catch (Exception ex)
				{
					MessageBox.Show(string.Format("Exception while trying to install '{1}':\n{0}", ex, currentDownload.Name), "Error");
				}
			}

			if (e.Cancelled || currentDownloadIndex + 1 >= installSet.Count)
			{
				downloader.DownloadProgressChanged -= DownloadProgressChanged;
				downloader.DownloadFileCompleted -= DownloadComplete;
				SaveAndQuit();
			}
			else
			{ // start next
				completedDownloadSize += installSet[currentDownloadIndex].Size;
				currentDownloadIndex++;
				StartCurrentDownload();
			}
		}

		void StartCurrentDownload()
		{
			downloader.DownloadFileAsync(new Uri(installSet[currentDownloadIndex].URL),
				downloadFolder + "\\" + Path.GetFileName(installSet[currentDownloadIndex].URL));
		}

		public override void Go()
		{
			foreach (AddOn uninstallAddOn in uninstallSet)
			{ // uninstall first
				try
				{
					foreach (string filePath in uninstallAddOn.Files)
					{
						if (File.Exists(filePath))
							File.Delete(filePath);
					}
					installedAddOns.Remove(uninstallAddOn);
				}
				catch (Exception ex)
				{
					MessageBox.Show(string.Format("Exception while trying to uninstall '{1}'\n{0}!", ex, uninstallAddOn.Name), "Error");
					installSet.Clear();
					break;
				}
			}

			if (installSet.Count > 0)
			{
				totalDownloadSize = 0;
				foreach (AddOn addOn in installSet)
					totalDownloadSize += addOn.Size;
				currentDownloadIndex = 0;
				completedDownloadSize = 0;
				lastProgressPercentage = 0;
				downloader.DownloadProgressChanged += DownloadProgressChanged;
				downloader.DownloadFileCompleted += DownloadComplete;
				StartCurrentDownload();
			}
			else
				SaveAndQuit();
		}

		private void SaveAndQuit()
		{
			if (uninstallSet.Count > 0 || installSet.Count > 0)
			{
				if (HaveWriteAccess(programFolder))
					File.WriteAllText(programFolder + "\\addons.xml", installedAddOns.ExtractXML(AddOnType.AI, AddOnType.Other));
				File.WriteAllText(appDataFolder + "\\addons.xml", installedAddOns.ExtractXML(AddOnType.Language, AddOnType.MapSet, AddOnType.BookSet));
			}
			RaiseComplete();
		}

		public override void Cancel()
		{
			downloader.CancelAsync();
		}
	}
}
