using System;
using System.Collections.Generic;
using System.Text;
using System.Xml;

namespace Configurator
{
	enum AddOnType { Language, BookSet, MapSet, AI, Other }

	class AddOn
	{
		public static int StringToVersion(string versionString)
		{
			int version = 0;
			string[] parts = versionString.Split('.');
			for (int i = 0; i < 3 && i < parts.Length; i++)
			{
				version *= 1000;
				int subVersion;
				if (int.TryParse(parts[i], out subVersion))
					version += subVersion;
			}
			return version;
		}

		public static string VersionToString(int version)
		{
			return string.Format("{0}.{1}.{2}", version / 1000000, (version / 1000) % 1000, version % 1000);
		}

		public readonly AddOnType Type;
		public readonly string ID;
		public readonly bool Installed;
		public string Name;
		public int Version; // aaabbbccc = a.b.c
		public string Creator;
		public string Readme;
		public string Info;
		public long Size;
		public string URL;
		public readonly List<string> Files = new List<string>();

		public AddOn(AddOnType type, string id, bool installed)
		{
			this.Type = type;
			this.ID = id;
			this.Installed = installed;
		}

		public override string ToString()
		{
			return Name;
		}
	}

	class AddOnSet : List<AddOn>
	{
		int currentVersion = 0;
		bool installed;

		public int CurrentVersion { get { return currentVersion; } }

		public AddOnSet(bool installed)
		{
			this.installed = installed;
		}

		public AddOn Find(AddOn addOn)
		{
			foreach (AddOn testAddOn in this)
			{
				if (testAddOn.Type == addOn.Type && testAddOn.ID == addOn.ID)
					return testAddOn;
			}
			return null;
		}

		public long TotalSize
		{
			get
			{
				long total = 0;
				foreach (AddOn addOn in this)
					total += addOn.Size;
				return total;
			}
		}
		public void AddXML(string xml)
		{
			XmlDocument doc = new XmlDocument();
			doc.LoadXml(xml);
			XmlElement root = doc.DocumentElement;
			if (root.Name.ToLower() != "cevo_addonset")
				throw new Exception("Wrong file format!");

			currentVersion = AddOn.StringToVersion(root.GetAttribute("vcurrent"));
			foreach (XmlElement addOnNode in root.ChildNodes)
			{
				AddOnType type = AddOnType.Other;
				switch (addOnNode.Name.ToLower())
				{
					case "language": type = AddOnType.Language; break;
					case "bookset": type = AddOnType.BookSet; break;
					case "mapset": type = AddOnType.MapSet; break;
					case "ai": type = AddOnType.AI; break;
				}
				AddOn addOn = new AddOn(type, addOnNode.GetAttribute("id"), installed);
				addOn.Name = addOnNode.GetAttribute("name");
				addOn.Creator = addOnNode.GetAttribute("creator");
				addOn.Readme = addOnNode.GetAttribute("readme");
				addOn.Info = addOnNode.GetAttribute("info");
				addOn.URL = addOnNode.GetAttribute("url");
				addOn.Version = AddOn.StringToVersion(addOnNode.GetAttribute("v"));
				string sizeString = addOnNode.GetAttribute("size");
				if (!long.TryParse(sizeString, out addOn.Size))
					addOn.Size = 0;

				foreach (XmlElement fileNode in addOnNode.ChildNodes)
				{
					if (fileNode.Name.ToLower() == "file")
						addOn.Files.Add(fileNode.GetAttribute("path"));
				}

				if (addOn.ID != "" && addOn.Name != "")
					Add(addOn);
			}
		}

		public string ExtractXML(params AddOnType[] types)
		{
			XmlDocument doc = new XmlDocument();
			doc.AppendChild(doc.CreateNode(XmlNodeType.Element, "cevo_addonset", null));
			XmlNode root = doc.DocumentElement;

			foreach (AddOn addOn in this)
			{
				if (Array.IndexOf<AddOnType>(types, addOn.Type) >= 0)
				{
					string addOnName = "";
					switch (addOn.Type)
					{
						case AddOnType.Language: addOnName = "language"; break;
						case AddOnType.BookSet: addOnName = "bookset"; break;
						case AddOnType.MapSet: addOnName = "mapset"; break;
						case AddOnType.AI: addOnName = "ai"; break;
						default: addOnName = "other"; break;
					}
					XmlElement addOnNode = doc.CreateElement(addOnName);
					root.AppendChild(addOnNode);

					addOnNode.SetAttribute("id", addOn.ID);
					addOnNode.SetAttribute("name", addOn.Name);
					addOnNode.SetAttribute("v", (addOn.Version / 1000).ToString() + "." + (addOn.Version % 1000).ToString());
					addOnNode.SetAttribute("creator", addOn.Creator);
					if (addOn.Readme != "")
						addOnNode.SetAttribute("readme", addOn.Readme);
					if (addOn.Info != "")
						addOnNode.SetAttribute("info", addOn.Info);
					if (addOn.Size != 0)
						addOnNode.SetAttribute("size", addOn.Size.ToString());
					if (addOn.URL != "")
						addOnNode.SetAttribute("url", addOn.URL);

					foreach (string filePath in addOn.Files)
					{
						XmlElement fileNode = doc.CreateElement("file");
						fileNode.SetAttribute("path", filePath);
						addOnNode.AppendChild(fileNode);
					}
				}
			}

			return "<?xml version=\"1.0\" encoding=\"utf-8\"?>\r\n<cevo_addonset>\r\n"
				+ doc.DocumentElement.InnerXml.Replace("<", "\t<").Replace("<file", "\t<file").Replace(">", ">\r\n")
				+ "</cevo_addonset>\r\n";
		}
	}
}
