using System;
using System.Collections.Generic;
using System.Text;
using System.Runtime.InteropServices;

namespace Configurator
{
	[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
	struct DEVMODE
	{
		[MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
		public string dmDeviceName;
		public short dmSpecVersion;
		public short dmDriverVersion;
		public short dmSize;
		public short dmDriverExtra;
		public int dmFields;
		public short dmOrientation;
		public short dmPaperSize;
		public short dmPaperLength;
		public short dmPaperWidth;
		public short dmScale;
		public short dmCopies;
		public short dmDefaultSource;
		public short dmPrintQuality;
		public short dmColor;
		public short dmDuplex;
		public short dmYResolution;
		public short dmTTOption;
		public short dmCollate;
		[MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
		public string dmFormName;
		public short dmLogPixels;
		public int dmBitsPerPel;
		public int dmPelsWidth;
		public int dmPelsHeight;
		public int dmDisplayFlags;
		public int dmDisplayFrequency;
	}

	class DisplayModeList : List<DEVMODE>
	{
		[DllImport("user32.dll", CharSet = CharSet.Auto)]
		public static extern bool EnumDisplaySettings(string deviceName, int modeNum, ref DEVMODE devMode);

		public DisplayModeList()
		{
			DEVMODE devMode = new DEVMODE();
			devMode.dmSize = (short)Marshal.SizeOf(typeof(DEVMODE));
			int index = 0;
			while (EnumDisplaySettings(null, index, ref devMode))
			{
				bool doAdd = true;
				for (int j = 0; j < Count; j++)
				{
					if (devMode.dmPelsWidth == this[j].dmPelsWidth &&
						devMode.dmPelsHeight == this[j].dmPelsHeight &&
						(devMode.dmDisplayFrequency + 2) / 5 == (this[j].dmDisplayFrequency + 2) / 5)
					{ // modes are identical, only keep one
						if (devMode.dmBitsPerPel > this[j].dmBitsPerPel)
							this[j] = devMode;
						doAdd = false;
						break;
					}
				}
				if (doAdd)
					Add(devMode);
				index++;
			}
		}
	}
}
