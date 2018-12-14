namespace Configurator
{
	partial class AddOnSelector
	{
		/// <summary> 
		/// Required designer variable.
		/// </summary>
		private System.ComponentModel.IContainer components = null;

		/// <summary> 
		/// Clean up any resources being used.
		/// </summary>
		/// <param name="disposing">true if managed resources should be disposed; otherwise, false.</param>
		protected override void Dispose(bool disposing)
		{
			if (disposing && (components != null))
			{
				components.Dispose();
			}
			base.Dispose(disposing);
		}

		#region Component Designer generated code

		/// <summary> 
		/// Required method for Designer support - do not modify 
		/// the contents of this method with the code editor.
		/// </summary>
		private void InitializeComponent()
		{
			this.infoLabel = new System.Windows.Forms.Label();
			this.creatorLabel = new System.Windows.Forms.Label();
			this.list = new System.Windows.Forms.ListView();
			this.columnHeader1 = new System.Windows.Forms.ColumnHeader();
			this.columnHeader2 = new System.Windows.Forms.ColumnHeader();
			this.columnHeader4 = new System.Windows.Forms.ColumnHeader();
			this.readmeButton = new System.Windows.Forms.Button();
			this.SuspendLayout();
			// 
			// infoLabel
			// 
			this.infoLabel.Location = new System.Drawing.Point(383, 81);
			this.infoLabel.Name = "infoLabel";
			this.infoLabel.Size = new System.Drawing.Size(268, 172);
			this.infoLabel.TabIndex = 2;
			// 
			// creatorLabel
			// 
			this.creatorLabel.Location = new System.Drawing.Point(383, 35);
			this.creatorLabel.Name = "creatorLabel";
			this.creatorLabel.Size = new System.Drawing.Size(268, 42);
			this.creatorLabel.TabIndex = 1;
			// 
			// list
			// 
			this.list.CheckBoxes = true;
			this.list.Columns.AddRange(new System.Windows.Forms.ColumnHeader[] {
            this.columnHeader1,
            this.columnHeader2,
            this.columnHeader4});
			this.list.FullRowSelect = true;
			this.list.HeaderStyle = System.Windows.Forms.ColumnHeaderStyle.Nonclickable;
			this.list.HideSelection = false;
			this.list.Location = new System.Drawing.Point(8, 8);
			this.list.Margin = new System.Windows.Forms.Padding(3, 2, 3, 2);
			this.list.MultiSelect = false;
			this.list.Name = "list";
			this.list.ShowGroups = false;
			this.list.Size = new System.Drawing.Size(357, 287);
			this.list.TabIndex = 0;
			this.list.UseCompatibleStateImageBehavior = false;
			this.list.View = System.Windows.Forms.View.Details;
			this.list.ItemChecked += new System.Windows.Forms.ItemCheckedEventHandler(this.list_ItemChecked);
			this.list.SelectedIndexChanged += new System.EventHandler(this.list_SelectedIndexChanged);
			this.list.ItemCheck += new System.Windows.Forms.ItemCheckEventHandler(this.list_ItemCheck);
			// 
			// columnHeader1
			// 
			this.columnHeader1.Text = "Package";
			this.columnHeader1.Width = 160;
			// 
			// columnHeader2
			// 
			this.columnHeader2.Text = "Version";
			this.columnHeader2.Width = 70;
			// 
			// columnHeader4
			// 
			this.columnHeader4.Text = "Size";
			this.columnHeader4.Width = 50;
			// 
			// readmeButton
			// 
			this.readmeButton.Location = new System.Drawing.Point(386, 261);
			this.readmeButton.Name = "readmeButton";
			this.readmeButton.Size = new System.Drawing.Size(211, 34);
			this.readmeButton.TabIndex = 3;
			this.readmeButton.Text = "View notes of the author";
			this.readmeButton.UseVisualStyleBackColor = true;
			this.readmeButton.Visible = false;
			this.readmeButton.Click += new System.EventHandler(this.readmeButton_Click);
			// 
			// AddOnSelector
			// 
			this.AutoScaleDimensions = new System.Drawing.SizeF(8F, 16F);
			this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
			this.Controls.Add(this.readmeButton);
			this.Controls.Add(this.infoLabel);
			this.Controls.Add(this.creatorLabel);
			this.Controls.Add(this.list);
			this.Name = "AddOnSelector";
			this.Padding = new System.Windows.Forms.Padding(8);
			this.Size = new System.Drawing.Size(662, 305);
			this.Load += new System.EventHandler(this.AddOnSelector_Load);
			this.ResumeLayout(false);

		}

		#endregion

		private System.Windows.Forms.Label infoLabel;
		private System.Windows.Forms.Label creatorLabel;
		private System.Windows.Forms.ColumnHeader columnHeader1;
		private System.Windows.Forms.ColumnHeader columnHeader2;
		private System.Windows.Forms.ColumnHeader columnHeader4;
		private System.Windows.Forms.ListView list;
		private System.Windows.Forms.Button readmeButton;
	}
}
