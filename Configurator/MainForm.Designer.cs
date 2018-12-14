namespace Configurator
{
	partial class MainForm
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

		#region Windows Form Designer generated code

		/// <summary>
		/// Required method for Designer support - do not modify
		/// the contents of this method with the code editor.
		/// </summary>
		private void InitializeComponent()
		{
			System.ComponentModel.ComponentResourceManager resources = new System.ComponentModel.ComponentResourceManager(typeof(MainForm));
			this.tabControl = new System.Windows.Forms.TabControl();
			this.generalPage = new System.Windows.Forms.TabPage();
			this.newVersionLabel = new System.Windows.Forms.LinkLabel();
			this.groupBox2 = new System.Windows.Forms.GroupBox();
			this.screenWindowRadio = new System.Windows.Forms.RadioButton();
			this.screenNormalRadio = new System.Windows.Forms.RadioButton();
			this.resolutionBox = new System.Windows.Forms.ComboBox();
			this.screenResolutionRadio = new System.Windows.Forms.RadioButton();
			this.groupBox1 = new System.Windows.Forms.GroupBox();
			this.translatorLabel = new System.Windows.Forms.Label();
			this.languageUpdateBox = new System.Windows.Forms.CheckBox();
			this.languageBox = new System.Windows.Forms.ComboBox();
			this.panel1 = new System.Windows.Forms.Panel();
			this.zipStorerLabel = new System.Windows.Forms.LinkLabel();
			this.mapPage = new System.Windows.Forms.TabPage();
			this.mapSelector = new Configurator.AddOnSelector();
			this.aiPage = new System.Windows.Forms.TabPage();
			this.aiSelector = new Configurator.AddOnSelector();
			this.advancedPage = new System.Windows.Forms.TabPage();
			this.label1 = new System.Windows.Forms.Label();
			this.exploreButton = new System.Windows.Forms.Button();
			this.okButton = new System.Windows.Forms.Button();
			this.cancelButton = new System.Windows.Forms.Button();
			this.changeLabel = new System.Windows.Forms.Label();
			this.tabControl.SuspendLayout();
			this.generalPage.SuspendLayout();
			this.groupBox2.SuspendLayout();
			this.groupBox1.SuspendLayout();
			this.mapPage.SuspendLayout();
			this.aiPage.SuspendLayout();
			this.advancedPage.SuspendLayout();
			this.SuspendLayout();
			// 
			// tabControl
			// 
			this.tabControl.Anchor = ((System.Windows.Forms.AnchorStyles)((((System.Windows.Forms.AnchorStyles.Top | System.Windows.Forms.AnchorStyles.Bottom)
						| System.Windows.Forms.AnchorStyles.Left)
						| System.Windows.Forms.AnchorStyles.Right)));
			this.tabControl.Controls.Add(this.generalPage);
			this.tabControl.Controls.Add(this.mapPage);
			this.tabControl.Controls.Add(this.aiPage);
			this.tabControl.Controls.Add(this.advancedPage);
			this.tabControl.Location = new System.Drawing.Point(12, 12);
			this.tabControl.Name = "tabControl";
			this.tabControl.Padding = new System.Drawing.Point(40, 6);
			this.tabControl.SelectedIndex = 0;
			this.tabControl.Size = new System.Drawing.Size(670, 340);
			this.tabControl.SizeMode = System.Windows.Forms.TabSizeMode.Fixed;
			this.tabControl.TabIndex = 0;
			// 
			// generalPage
			// 
			this.generalPage.Controls.Add(this.newVersionLabel);
			this.generalPage.Controls.Add(this.groupBox2);
			this.generalPage.Controls.Add(this.groupBox1);
			this.generalPage.Controls.Add(this.panel1);
			this.generalPage.Controls.Add(this.zipStorerLabel);
			this.generalPage.Location = new System.Drawing.Point(4, 31);
			this.generalPage.Name = "generalPage";
			this.generalPage.Padding = new System.Windows.Forms.Padding(8);
			this.generalPage.Size = new System.Drawing.Size(662, 305);
			this.generalPage.TabIndex = 0;
			this.generalPage.Text = "General";
			this.generalPage.UseVisualStyleBackColor = true;
			// 
			// newVersionLabel
			// 
			this.newVersionLabel.AutoSize = true;
			this.newVersionLabel.LinkColor = System.Drawing.Color.FromArgb(((int)(((byte)(192)))), ((int)(((byte)(0)))), ((int)(((byte)(0)))));
			this.newVersionLabel.Location = new System.Drawing.Point(25, 275);
			this.newVersionLabel.Name = "newVersionLabel";
			this.newVersionLabel.Size = new System.Drawing.Size(307, 17);
			this.newVersionLabel.TabIndex = 4;
			this.newVersionLabel.TabStop = true;
			this.newVersionLabel.Text = "A new C-evo version is available from c-evo.org";
			this.newVersionLabel.Visible = false;
			this.newVersionLabel.VisitedLinkColor = System.Drawing.Color.FromArgb(((int)(((byte)(192)))), ((int)(((byte)(0)))), ((int)(((byte)(0)))));
			this.newVersionLabel.LinkClicked += new System.Windows.Forms.LinkLabelLinkClickedEventHandler(this.newVersionLabel_LinkClicked);
			// 
			// groupBox2
			// 
			this.groupBox2.Controls.Add(this.screenWindowRadio);
			this.groupBox2.Controls.Add(this.screenNormalRadio);
			this.groupBox2.Controls.Add(this.resolutionBox);
			this.groupBox2.Controls.Add(this.screenResolutionRadio);
			this.groupBox2.Location = new System.Drawing.Point(298, 11);
			this.groupBox2.Margin = new System.Windows.Forms.Padding(3, 2, 3, 2);
			this.groupBox2.Name = "groupBox2";
			this.groupBox2.Padding = new System.Windows.Forms.Padding(3, 2, 3, 2);
			this.groupBox2.Size = new System.Drawing.Size(353, 180);
			this.groupBox2.TabIndex = 1;
			this.groupBox2.TabStop = false;
			this.groupBox2.Text = "Screen";
			// 
			// screenWindowRadio
			// 
			this.screenWindowRadio.AutoSize = true;
			this.screenWindowRadio.Location = new System.Drawing.Point(27, 37);
			this.screenWindowRadio.Margin = new System.Windows.Forms.Padding(3, 2, 3, 2);
			this.screenWindowRadio.Name = "screenWindowRadio";
			this.screenWindowRadio.Size = new System.Drawing.Size(119, 21);
			this.screenWindowRadio.TabIndex = 0;
			this.screenWindowRadio.Text = "Run in window";
			this.screenWindowRadio.UseVisualStyleBackColor = true;
			// 
			// screenNormalRadio
			// 
			this.screenNormalRadio.AutoSize = true;
			this.screenNormalRadio.Checked = true;
			this.screenNormalRadio.Location = new System.Drawing.Point(27, 68);
			this.screenNormalRadio.Margin = new System.Windows.Forms.Padding(3, 2, 3, 2);
			this.screenNormalRadio.Name = "screenNormalRadio";
			this.screenNormalRadio.Size = new System.Drawing.Size(272, 21);
			this.screenNormalRadio.TabIndex = 1;
			this.screenNormalRadio.TabStop = true;
			this.screenNormalRadio.Text = "Full screen, keep system\'s video mode";
			this.screenNormalRadio.UseVisualStyleBackColor = true;
			// 
			// resolutionBox
			// 
			this.resolutionBox.DropDownStyle = System.Windows.Forms.ComboBoxStyle.DropDownList;
			this.resolutionBox.Enabled = false;
			this.resolutionBox.FormattingEnabled = true;
			this.resolutionBox.Location = new System.Drawing.Point(50, 126);
			this.resolutionBox.Margin = new System.Windows.Forms.Padding(3, 2, 3, 2);
			this.resolutionBox.Name = "resolutionBox";
			this.resolutionBox.Size = new System.Drawing.Size(169, 24);
			this.resolutionBox.TabIndex = 3;
			// 
			// screenResolutionRadio
			// 
			this.screenResolutionRadio.AutoSize = true;
			this.screenResolutionRadio.Location = new System.Drawing.Point(27, 98);
			this.screenResolutionRadio.Margin = new System.Windows.Forms.Padding(3, 2, 3, 2);
			this.screenResolutionRadio.Name = "screenResolutionRadio";
			this.screenResolutionRadio.Size = new System.Drawing.Size(223, 21);
			this.screenResolutionRadio.TabIndex = 2;
			this.screenResolutionRadio.Text = "Full screen, change resolution:";
			this.screenResolutionRadio.UseVisualStyleBackColor = true;
			this.screenResolutionRadio.CheckedChanged += new System.EventHandler(this.screenResolutionRadio_CheckedChanged);
			// 
			// groupBox1
			// 
			this.groupBox1.Controls.Add(this.translatorLabel);
			this.groupBox1.Controls.Add(this.languageUpdateBox);
			this.groupBox1.Controls.Add(this.languageBox);
			this.groupBox1.Location = new System.Drawing.Point(11, 11);
			this.groupBox1.Margin = new System.Windows.Forms.Padding(3, 2, 3, 2);
			this.groupBox1.Name = "groupBox1";
			this.groupBox1.Padding = new System.Windows.Forms.Padding(3, 2, 3, 2);
			this.groupBox1.Size = new System.Drawing.Size(281, 180);
			this.groupBox1.TabIndex = 0;
			this.groupBox1.TabStop = false;
			this.groupBox1.Text = "Language";
			// 
			// translatorLabel
			// 
			this.translatorLabel.Location = new System.Drawing.Point(29, 79);
			this.translatorLabel.Name = "translatorLabel";
			this.translatorLabel.Size = new System.Drawing.Size(246, 59);
			this.translatorLabel.TabIndex = 4;
			// 
			// languageUpdateBox
			// 
			this.languageUpdateBox.AutoSize = true;
			this.languageUpdateBox.Location = new System.Drawing.Point(32, 145);
			this.languageUpdateBox.Name = "languageUpdateBox";
			this.languageUpdateBox.Size = new System.Drawing.Size(140, 21);
			this.languageUpdateBox.TabIndex = 1;
			this.languageUpdateBox.Text = "Update 1.0 to 1.1";
			this.languageUpdateBox.UseVisualStyleBackColor = true;
			this.languageUpdateBox.Visible = false;
			this.languageUpdateBox.CheckedChanged += new System.EventHandler(this.languageUpdateBox_CheckedChanged);
			// 
			// languageBox
			// 
			this.languageBox.DropDownStyle = System.Windows.Forms.ComboBoxStyle.DropDownList;
			this.languageBox.FormattingEnabled = true;
			this.languageBox.Location = new System.Drawing.Point(29, 48);
			this.languageBox.Margin = new System.Windows.Forms.Padding(3, 2, 3, 2);
			this.languageBox.Name = "languageBox";
			this.languageBox.Size = new System.Drawing.Size(217, 24);
			this.languageBox.TabIndex = 0;
			this.languageBox.SelectedIndexChanged += new System.EventHandler(this.languageBox_SelectedIndexChanged);
			// 
			// panel1
			// 
			this.panel1.BackgroundImage = ((System.Drawing.Image)(resources.GetObject("panel1.BackgroundImage")));
			this.panel1.BackgroundImageLayout = System.Windows.Forms.ImageLayout.Center;
			this.panel1.Location = new System.Drawing.Point(516, 198);
			this.panel1.Margin = new System.Windows.Forms.Padding(3, 2, 3, 2);
			this.panel1.Name = "panel1";
			this.panel1.Size = new System.Drawing.Size(120, 74);
			this.panel1.TabIndex = 3;
			// 
			// zipStorerLabel
			// 
			this.zipStorerLabel.AutoSize = true;
			this.zipStorerLabel.LinkColor = System.Drawing.Color.Gray;
			this.zipStorerLabel.Location = new System.Drawing.Point(499, 275);
			this.zipStorerLabel.Name = "zipStorerLabel";
			this.zipStorerLabel.Size = new System.Drawing.Size(153, 17);
			this.zipStorerLabel.TabIndex = 2;
			this.zipStorerLabel.TabStop = true;
			this.zipStorerLabel.Text = "zipstorer.codeplex.com";
			this.zipStorerLabel.VisitedLinkColor = System.Drawing.Color.Gray;
			this.zipStorerLabel.LinkClicked += new System.Windows.Forms.LinkLabelLinkClickedEventHandler(this.zipStorerLabel_LinkClicked);
			// 
			// mapPage
			// 
			this.mapPage.Controls.Add(this.mapSelector);
			this.mapPage.Location = new System.Drawing.Point(4, 31);
			this.mapPage.Name = "mapPage";
			this.mapPage.Size = new System.Drawing.Size(662, 305);
			this.mapPage.TabIndex = 2;
			this.mapPage.Text = "Maps";
			this.mapPage.UseVisualStyleBackColor = true;
			// 
			// mapSelector
			// 
			this.mapSelector.AutoSizeMode = System.Windows.Forms.AutoSizeMode.GrowAndShrink;
			this.mapSelector.Dock = System.Windows.Forms.DockStyle.Fill;
			this.mapSelector.Location = new System.Drawing.Point(0, 0);
			this.mapSelector.Name = "mapSelector";
			this.mapSelector.Padding = new System.Windows.Forms.Padding(8);
			this.mapSelector.Size = new System.Drawing.Size(662, 305);
			this.mapSelector.TabIndex = 0;
			this.mapSelector.Changed += new Configurator.AddOnSelector.ChangeEventHandler(this.selector_Changed);
			// 
			// aiPage
			// 
			this.aiPage.Controls.Add(this.aiSelector);
			this.aiPage.Location = new System.Drawing.Point(4, 31);
			this.aiPage.Name = "aiPage";
			this.aiPage.Size = new System.Drawing.Size(662, 305);
			this.aiPage.TabIndex = 3;
			this.aiPage.Text = "AI";
			this.aiPage.UseVisualStyleBackColor = true;
			// 
			// aiSelector
			// 
			this.aiSelector.AutoSizeMode = System.Windows.Forms.AutoSizeMode.GrowAndShrink;
			this.aiSelector.Dock = System.Windows.Forms.DockStyle.Fill;
			this.aiSelector.Location = new System.Drawing.Point(0, 0);
			this.aiSelector.Name = "aiSelector";
			this.aiSelector.Padding = new System.Windows.Forms.Padding(8);
			this.aiSelector.Size = new System.Drawing.Size(662, 305);
			this.aiSelector.TabIndex = 0;
			this.aiSelector.Changed += new Configurator.AddOnSelector.ChangeEventHandler(this.selector_Changed);
			// 
			// advancedPage
			// 
			this.advancedPage.Controls.Add(this.label1);
			this.advancedPage.Controls.Add(this.exploreButton);
			this.advancedPage.Location = new System.Drawing.Point(4, 31);
			this.advancedPage.Name = "advancedPage";
			this.advancedPage.Padding = new System.Windows.Forms.Padding(8);
			this.advancedPage.Size = new System.Drawing.Size(662, 305);
			this.advancedPage.TabIndex = 4;
			this.advancedPage.Text = "Advanced";
			this.advancedPage.UseVisualStyleBackColor = true;
			// 
			// label1
			// 
			this.label1.ForeColor = System.Drawing.SystemColors.WindowText;
			this.label1.Location = new System.Drawing.Point(306, 82);
			this.label1.Name = "label1";
			this.label1.Size = new System.Drawing.Size(233, 76);
			this.label1.TabIndex = 12;
			this.label1.Text = "Find saved books and maps, as well as downloaded language files. Doing changes no" +
				"t recommended.";
			// 
			// exploreButton
			// 
			this.exploreButton.Location = new System.Drawing.Point(111, 90);
			this.exploreButton.Name = "exploreButton";
			this.exploreButton.Size = new System.Drawing.Size(178, 34);
			this.exploreButton.TabIndex = 11;
			this.exploreButton.Text = "Browse Folders";
			this.exploreButton.UseVisualStyleBackColor = true;
			this.exploreButton.Click += new System.EventHandler(this.exploreButton_Click);
			// 
			// okButton
			// 
			this.okButton.Anchor = ((System.Windows.Forms.AnchorStyles)((System.Windows.Forms.AnchorStyles.Bottom | System.Windows.Forms.AnchorStyles.Right)));
			this.okButton.Location = new System.Drawing.Point(461, 372);
			this.okButton.Margin = new System.Windows.Forms.Padding(3, 2, 3, 2);
			this.okButton.Name = "okButton";
			this.okButton.Size = new System.Drawing.Size(108, 34);
			this.okButton.TabIndex = 2;
			this.okButton.Text = "OK";
			this.okButton.UseVisualStyleBackColor = true;
			this.okButton.Click += new System.EventHandler(this.okButton_Click);
			// 
			// cancelButton
			// 
			this.cancelButton.Anchor = ((System.Windows.Forms.AnchorStyles)((System.Windows.Forms.AnchorStyles.Bottom | System.Windows.Forms.AnchorStyles.Right)));
			this.cancelButton.DialogResult = System.Windows.Forms.DialogResult.Cancel;
			this.cancelButton.Location = new System.Drawing.Point(574, 372);
			this.cancelButton.Margin = new System.Windows.Forms.Padding(3, 2, 3, 2);
			this.cancelButton.Name = "cancelButton";
			this.cancelButton.Size = new System.Drawing.Size(108, 34);
			this.cancelButton.TabIndex = 3;
			this.cancelButton.Text = "Cancel";
			this.cancelButton.UseVisualStyleBackColor = true;
			this.cancelButton.Click += new System.EventHandler(this.cancelButton_Click);
			// 
			// changeLabel
			// 
			this.changeLabel.Anchor = ((System.Windows.Forms.AnchorStyles)(((System.Windows.Forms.AnchorStyles.Bottom | System.Windows.Forms.AnchorStyles.Left)
						| System.Windows.Forms.AnchorStyles.Right)));
			this.changeLabel.Location = new System.Drawing.Point(13, 372);
			this.changeLabel.Name = "changeLabel";
			this.changeLabel.Size = new System.Drawing.Size(412, 39);
			this.changeLabel.TabIndex = 1;
			// 
			// MainForm
			// 
			this.AutoScaleDimensions = new System.Drawing.SizeF(8F, 16F);
			this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
			this.ClientSize = new System.Drawing.Size(694, 427);
			this.Controls.Add(this.changeLabel);
			this.Controls.Add(this.cancelButton);
			this.Controls.Add(this.okButton);
			this.Controls.Add(this.tabControl);
			this.FormBorderStyle = System.Windows.Forms.FormBorderStyle.FixedSingle;
			this.Icon = ((System.Drawing.Icon)(resources.GetObject("$this.Icon")));
			this.Margin = new System.Windows.Forms.Padding(3, 2, 3, 2);
			this.MaximizeBox = false;
			this.MinimizeBox = false;
			this.Name = "MainForm";
			this.StartPosition = System.Windows.Forms.FormStartPosition.CenterScreen;
			this.Text = "C-evo Configurator";
			this.Load += new System.EventHandler(this.MainForm_Load);
			this.Shown += new System.EventHandler(this.MainForm_Shown);
			this.tabControl.ResumeLayout(false);
			this.generalPage.ResumeLayout(false);
			this.generalPage.PerformLayout();
			this.groupBox2.ResumeLayout(false);
			this.groupBox2.PerformLayout();
			this.groupBox1.ResumeLayout(false);
			this.groupBox1.PerformLayout();
			this.mapPage.ResumeLayout(false);
			this.aiPage.ResumeLayout(false);
			this.advancedPage.ResumeLayout(false);
			this.ResumeLayout(false);

		}

		#endregion

		private System.Windows.Forms.TabControl tabControl;
		private System.Windows.Forms.TabPage generalPage;
		private System.Windows.Forms.Button okButton;
		private System.Windows.Forms.Button cancelButton;
		private System.Windows.Forms.TabPage mapPage;
		private System.Windows.Forms.TabPage aiPage;
		private System.Windows.Forms.ComboBox languageBox;
		private System.Windows.Forms.LinkLabel zipStorerLabel;
		private System.Windows.Forms.Panel panel1;
		private System.Windows.Forms.ComboBox resolutionBox;
		private System.Windows.Forms.RadioButton screenResolutionRadio;
		private System.Windows.Forms.RadioButton screenNormalRadio;
		private System.Windows.Forms.RadioButton screenWindowRadio;
		private System.Windows.Forms.GroupBox groupBox2;
		private System.Windows.Forms.GroupBox groupBox1;
		private System.Windows.Forms.CheckBox languageUpdateBox;
		private System.Windows.Forms.TabPage advancedPage;
		private System.Windows.Forms.Button exploreButton;
		private AddOnSelector aiSelector;
		private AddOnSelector mapSelector;
		private System.Windows.Forms.Label changeLabel;
		private System.Windows.Forms.Label label1;
		private System.Windows.Forms.Label translatorLabel;
		private System.Windows.Forms.LinkLabel newVersionLabel;
	}
}

