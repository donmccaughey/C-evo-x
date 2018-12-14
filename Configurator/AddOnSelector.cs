using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Drawing;
using System.Data;
using System.Text;
using System.Windows.Forms;
using System.IO;

namespace Configurator
{
	partial class AddOnSelector : UserControl
	{
		public delegate void ChangeEventHandler(object sender);
		public event ChangeEventHandler Changed;

		AddOnType type;
		bool enabled;
		string disabledMessage;

		public AddOnSelector()
		{
			InitializeComponent();
		}

		private void AddOnSelector_Load(object sender, EventArgs e)
		{
			list.Columns[0].Width = list.Width * 215 / 385;
			list.Columns[1].Width = list.Width * 70 / 385;
			list.Columns[2].Width = list.Width * 55 / 385;
		}

		private void AddListItem(AddOn addOn)
		{
			ListViewItem item = new ListViewItem();
			item.Text = addOn.Name;
			item.SubItems.Add(AddOn.VersionToString(addOn.Version));
			if (!addOn.Installed && addOn.Size > 0)
				item.SubItems.Add(MainForm.SizeString(addOn.Size));
			item.Checked = addOn.Installed;
			item.Tag = addOn;
			list.Items.Add(item);
		}

		public void SetData(AddOnSet installed, AddOnSet available, AddOnType type)
		{
			this.type = type;
			foreach (AddOn addOn in installed)
			{
				if (addOn.Type == type)
				{
					AddListItem(addOn);
					AddOn current = available.Find(addOn);
					if (current != null && current.Version > addOn.Version)
						AddListItem(current);
				}
			}
			foreach (AddOn addOn in available)
			{
				if (addOn.Type == type && installed.Find(addOn) == null)
					AddListItem(addOn);
			}
			enabled = Installer.CanInstall(type, out disabledMessage);
		}

		private void list_SelectedIndexChanged(object sender, EventArgs e)
		{
			if (list.SelectedItems.Count == 0)
			{
				creatorLabel.Text = "";
				infoLabel.Text = "";
				readmeButton.Visible=false;
			}
			else
			{
				AddOn addOn = (AddOn)list.SelectedItems[0].Tag;
				creatorLabel.Text = "Created by " + addOn.Creator;
				infoLabel.Text = addOn.Info;
				readmeButton.Visible = addOn.Installed && addOn.Readme != "" && File.Exists(Installer.GetReadmePath(addOn));
			}
		}

		private void list_ItemChecked(object sender, ItemCheckedEventArgs e)
		{
			// don't allow installed addon and it's update to be checked at the same time
			if (e.Item.Checked)
			{
				foreach (ListViewItem item in list.Items)
				{
					if (item != e.Item &&
						((AddOn)item.Tag).Type == ((AddOn)e.Item.Tag).Type &&
						((AddOn)item.Tag).ID == ((AddOn)e.Item.Tag).ID)
					{
						item.Checked = false;
					}
				}
			}
			if (Changed != null)
				Changed(this);
		}

		public AddOnSet AddSet
		{
			get
			{
				AddOnSet set = new AddOnSet(false);
				foreach (ListViewItem item in list.Items)
				{
					if (item.Checked && !((AddOn)item.Tag).Installed)
						set.Add((AddOn)item.Tag);
				}
				return set;
			}
		}

		public AddOnSet RemoveSet
		{
			get
			{
				AddOnSet set = new AddOnSet(true);
				foreach (ListViewItem item in list.Items)
				{
					if (!item.Checked && ((AddOn)item.Tag).Installed)
						set.Add((AddOn)item.Tag);
				}
				return set;
			}
		}

		private void list_ItemCheck(object sender, ItemCheckEventArgs e)
		{
			if (!enabled && ((AddOn)list.Items[e.Index].Tag).Installed != (e.NewValue != CheckState.Unchecked))
			{
				MessageBox.Show(disabledMessage, "Change Not Possible", MessageBoxButtons.OK, MessageBoxIcon.Exclamation);
				e.NewValue = e.CurrentValue;
			}
		}

		private void readmeButton_Click(object sender, EventArgs e)
		{
			if (list.SelectedItems.Count > 0)
			{
				AddOn addOn = (AddOn)list.SelectedItems[0].Tag;
				if (addOn.Readme != "" && File.Exists(Installer.GetReadmePath(addOn)))
				{
					TextViewer textViewer = new TextViewer();
					textViewer.ShowReadme(addOn);
				}
			}
		}
	}
}
