# Makefile for C-evo-x


all : \
	tmp/CevoWin32.exe \
	tmp/CevoDotNet.exe \
	tmp/cevo.dll \
	\
	tmp/AIProject.dll \
	tmp/AIProject.ai.txt \
	tmp/AIProject.bmp \
	\
	tmp/AI.dll \
	tmp/AI.ai.txt \
	\
	tmp/fonts.txt \
	tmp/language.txt \
	tmp/language2.txt \
	\
	tmp/AppData/Saved/(Example).cevo \
	\
	tmp/Graphics/Background.bmp \
	tmp/Graphics/BigCityMap.bmp \
	tmp/Graphics/Cities66x32.bmp \
	tmp/Graphics/Cities66x32.credits.txt \
	tmp/Graphics/Cities96x48.bmp \
	tmp/Graphics/Cities96x48.credits.txt \
	tmp/Graphics/City.bmp \
	tmp/Graphics/Colors.bmp \
	tmp/Graphics/Icons.bmp \
	tmp/Graphics/Icons.credits.txt \
	tmp/Graphics/MiliRes.bmp \
	tmp/Graphics/Nation.bmp \
	tmp/Graphics/Nation1.bmp \
	tmp/Graphics/Nation1.credits.txt \
	tmp/Graphics/Nation2.bmp \
	tmp/Graphics/Nation2.credits.txt \
	tmp/Graphics/Paper.jpg \
	tmp/Graphics/SmallCityMap.bmp \
	tmp/Graphics/StdCities.bmp \
	tmp/Graphics/StdCities.credits.txt \
	tmp/Graphics/StdUnits.bmp \
	tmp/Graphics/StdUnits.credits.txt \
	tmp/Graphics/System.bmp \
	tmp/Graphics/System2.bmp \
	tmp/Graphics/Templates.bmp \
	tmp/Graphics/Terrain66x32.bmp \
	tmp/Graphics/Terrain66x32.credits.txt \
	tmp/Graphics/Terrain96x48.bmp \
	tmp/Graphics/Terrain96x48.credits.txt \
	tmp/Graphics/Texture0.jpg \
	tmp/Graphics/Texture1.jpg \
	tmp/Graphics/Texture2.jpg \
	tmp/Graphics/Texture3.jpg \
	tmp/Graphics/Texture4.jpg \
	tmp/Graphics/Unit.bmp \
	\
	tmp/Help/AdvTree.bmp \
	tmp/Help/AITShot.bmp \
	tmp/Help/CityShot.bmp \
	tmp/Help/Corruption.bmp \
	tmp/Help/DraftShot.bmp \
	tmp/Help/help.txt \
	tmp/Help/MoveShot.bmp \
	\
	tmp/Sounds/8MM_AT_C-BlackCow-8186_hifi.mp3 \
	tmp/Sounds/Boulder_-oblius-7747_hifi.mp3 \
	tmp/Sounds/Cash_reg-public_d-296_hifi.mp3 \
	tmp/Sounds/Hammer_o-Public_D-243_hifi.mp3 \
	tmp/Sounds/sg_angry.mp3 \
	tmp/Sounds/sg_autogun.mp3 \
	tmp/Sounds/sg_battery.mp3 \
	tmp/Sounds/sg_cavalry.mp3 \
	tmp/Sounds/sg_cheers.mp3 \
	tmp/Sounds/sg_drum.mp3 \
	tmp/Sounds/sg_drum2.mp3 \
	tmp/Sounds/sg_fanfare.mp3 \
	tmp/Sounds/sg_gain.mp3 \
	tmp/Sounds/sg_harp.mp3 \
	tmp/Sounds/sg_horsemen.mp3 \
	tmp/Sounds/sg_invent.mp3 \
	tmp/Sounds/sg_jet.mp3 \
	tmp/Sounds/sg_marching.mp3 \
	tmp/Sounds/sg_mechanical.mp3 \
	tmp/Sounds/sg_militia.mp3 \
	tmp/Sounds/sg_moan.mp3 \
	tmp/Sounds/sg_musketeers.mp3 \
	tmp/Sounds/sg_nono.mp3 \
	tmp/Sounds/sg_plane.mp3 \
	tmp/Sounds/sg_sad.mp3 \
	tmp/Sounds/sg_space.mp3 \
	tmp/Sounds/sg_steal.mp3 \
	tmp/Sounds/sg_warning.mp3 \
	tmp/Sounds/sizzle-Sith_Mas-7716_hifi.mp3 \
	tmp/Sounds/Small_Sw-Public_D-262_hifi.mp3 \
	tmp/Sounds/sound.credits.txt \
	tmp/Sounds/sound.txt \
	tmp/Sounds/victory.mp3 \
	\
	tmp/Tribes/Americans.tribe.txt \
	tmp/Tribes/Babyl.tribe.txt \
	tmp/Tribes/British.tribe.txt \
	tmp/Tribes/Chinese.tribe.txt \
	tmp/Tribes/Egyptians.tribe.txt \
	tmp/Tribes/French.tribe.txt \
	tmp/Tribes/Germans.tribe.txt \
	tmp/Tribes/Greeks.tribe.txt \
	tmp/Tribes/Japanese.tribe.txt \
	tmp/Tribes/Mongols.tribe.txt \
	tmp/Tribes/Persians.tribe.txt \
	tmp/Tribes/Phoenicians.tribe.txt \
	tmp/Tribes/Romans.tribe.txt \
	tmp/Tribes/Russians.tribe.txt \
	tmp/Tribes/Spanish.tribe.txt \
	tmp/Tribes/StdUnits.txt \
	tmp/Tribes/Vikings.tribe.txt \
	\
	tmp/Configurator.exe


clean :
	-rm -rf tmp
	-rm -rf Configurator/obj
	-rm -rf AI_Template/CevoDotNet/obj
	-rm -rf AI_Template/Project/obj


# ----- Game executable

tmp/CevoWin32.exe : \
		Project/CevoWin32.dpr \
		Project/CevoWin32.dof \
		tmp/units/CevoWin32/cevo.res
	-mkdir -p tmp/units/CevoWin32
	cd Project
	dcc32 CevoWin32.dpr
	cd ..

tmp/units/CevoWin32/cevo.res : \
		Project/cevo.rc \
		Project/cevoxp2.ico
	mkdir -p tmp/units/CevoWin32
	cd tmp/units/CevoWin32
	brcc32 -focevo.res ../../../Project/cevo.rc
	cd ../../..


# ----- Game executable for .NET

tmp/CevoDotNet.exe : \
		AI_Template/CevoDotNet/CevoDotNet.csproj \
		\
		AI_Template/CevoDotNet/AIPlugin.cs \
		AI_Template/CevoDotNet/cevoxp2.ico \
		AI_Template/CevoDotNet/Program.cs \
		AI_Template/CevoDotNet/Protocol.cs \
		\
		AI_Template/CevoDotNet/Properties/AssemblyInfo.cs \
		AI_Template/CevoDotNet/Properties/Resources.Designer.cs \
		AI_Template/CevoDotNet/Properties/Resources.resx \
		AI_Template/CevoDotNet/Properties/Settings.Designer.cs \
		AI_Template/CevoDotNet/Properties/Settings.settings
	MSBuild.exe AI_Template/CevoDotNet/CevoDotNet.csproj


# ----- Game library

tmp/cevo.dll : \
		Project/cevo.dpr \
		Project/cevo.dof \
		tmp/units/cevo/Res1.res \
		\
		Project/Area.pas \
		Project/Back.dfm \
		Project/Back.pas \
		Project/ButtonA.pas \
		Project/ButtonB.pas \
		Project/ButtonBase.pas \
		Project/ButtonC.pas \
		Project/ButtonN.pas \
		Project/CityProcessing.pas \
		Project/CmdList.pas \
		Project/Database.pas \
		Project/Direct.dfm \
		Project/Direct.pas \
		Project/Directories.pas \
		Project/EOTButton.pas \
		Project/GameServer.pas \
		Project/Inp.dfm \
		Project/Inp.pas \
		Project/Log.dfm \
		Project/Log.pas \
		Project/Messg.dfm \
		Project/Messg.pas \
		Project/NoTerm.dfm \
		Project/NoTerm.pas \
		Project/ScreenTools.pas \
		Project/Sound.dfm \
		Project/Sound.pas \
		Project/Start.dfm \
		Project/Start.pas \
		Project/Switches.pas \
		Project/StringTables.pas \
		Project/UnitProcessing.pas \
		\
		Project/LocalPlayer/BaseWin.pas \
		Project/LocalPlayer/Battle.dfm \
		Project/LocalPlayer/Battle.pas \
		Project/LocalPlayer/CityScreen.dfm \
		Project/LocalPlayer/CityScreen.pas \
		Project/LocalPlayer/CityType.dfm \
		Project/LocalPlayer/CityType.pas \
		Project/LocalPlayer/ClientTools.pas \
		Project/LocalPlayer/Diagram.dfm \
		Project/LocalPlayer/Diagram.pas \
		Project/LocalPlayer/Diplomacy.pas \
		Project/LocalPlayer/Draft.dfm \
		Project/LocalPlayer/Draft.pas \
		Project/LocalPlayer/Enhance.dfm \
		Project/LocalPlayer/Enhance.pas \
		Project/LocalPlayer/Help.dfm \
		Project/LocalPlayer/Help.pas \
		Project/LocalPlayer/IsoEngine.pas \
		Project/LocalPlayer/LocalPlayer.pas \
		Project/LocalPlayer/MessgEx.dfm \
		Project/LocalPlayer/MessgEx.pas \
		Project/LocalPlayer/NatStat.dfm \
		Project/LocalPlayer/NatStat.pas \
		Project/LocalPlayer/Nego.dfm \
		Project/LocalPlayer/Nego.pas \
		Project/LocalPlayer/PVSB.pas \
		Project/LocalPlayer/Rates.dfm \
		Project/LocalPlayer/Rates.pas \
		Project/LocalPlayer/Select.dfm \
		Project/LocalPlayer/Select.pas \
		Project/LocalPlayer/TechTree.dfm \
		Project/LocalPlayer/TechTree.pas \
		Project/LocalPlayer/Term.dfm \
		Project/LocalPlayer/Term.pas \
		Project/LocalPlayer/Tribes.pas \
		Project/LocalPlayer/UnitStat.dfm \
		Project/LocalPlayer/UnitStat.pas \
		Project/LocalPlayer/Wonders.dfm \
		Project/LocalPlayer/Wonders.pas \
		\
		Protocol/Protocol.pas
	-mkdir -p tmp/units/cevo
	cd Project
	dcc32 cevo.dpr
	cd ..

tmp/units/cevo/Res1.res : \
		Project/Res1.rc \
		Project/drag.cur \
		Project/flathand.cur
	mkdir -p tmp/units/cevo
	cd tmp/units/cevo
	brcc32 -foRes1.res ../../../Project/Res1.rc
	cd ../../..


# ----- Delphi AI sample

tmp/AIProject.dll : Delphi_AI_Kit/AIProject.dpr \
		Delphi_AI_Kit/AI.pas \
		Delphi_AI_Kit/CustomAI.pas \
		Delphi_AI_Kit/Names.pas \
		Delphi_AI_Kit/Pile.pas \
		Delphi_AI_Kit/Switches.pas \
		Delphi_AI_Kit/ToolAI.pas \
		\
		Protocol/Protocol.pas
	-mkdir -p tmp/units/AIProject
	cd Delphi_AI_Kit
	dcc32 AIProject.dpr
	cd ..

tmp/AIProject.ai.txt : Delphi_AI_Kit/AIProject.ai.txt
	-mkdir -p tmp
	cp Delphi_AI_Kit/AIProject.ai.txt tmp/AIProject.ai.txt

tmp/AIProject.bmp : Delphi_AI_Kit/AIProject.bmp
	-mkdir -p tmp
	cp Delphi_AI_Kit/AIProject.bmp tmp/AIProject.bmp


# ----- C# AI sample

tmp/AI.dll : \
		AI_Template/Project/AI.csproj \
		\
		AI_Template/Project/City.cs \
		AI_Template/Project/Empire.cs \
		AI_Template/Project/Model.cs \
		AI_Template/Project/Persistent.cs \
		AI_Template/Project/Plugin.cs \
		AI_Template/Project/Unit.cs \
		\
		AI_Template/Project/Lib/AddressPriorityQueue.cs \
		AI_Template/Project/Lib/CevoPedia.cs \
		AI_Template/Project/Lib/CityBase.cs \
		AI_Template/Project/Lib/DiplomacyBase.cs \
		AI_Template/Project/Lib/Map.cs \
		AI_Template/Project/Lib/ModelBase.cs \
		AI_Template/Project/Lib/Nation.cs \
		AI_Template/Project/Lib/PlayResult.cs \
		AI_Template/Project/Lib/Protocol.cs \
		AI_Template/Project/Lib/Sprawl.cs \
		AI_Template/Project/Lib/ToughSet.cs \
		AI_Template/Project/Lib/UnitBase.cs \
		\
		AI_Template/Project/Properties/AssemblyInfo.cs
	MSBuild.exe AI_Template/Project/AI.csproj

tmp/AI.ai.txt : AI_Template/AI.ai.txt
	mkdir -p tmp
	cp AI_Template/AI.ai.txt tmp/AI.ai.txt


# ----- Resource files

tmp/fonts.txt : Resources/fonts.txt
	-mkdir -p tmp
	cp Resources/fonts.txt tmp/fonts.txt

tmp/language.txt : Resources/language.txt
	-mkdir -p tmp
	cp Resources/language.txt tmp/language.txt

tmp/language2.txt : Resources/language2.txt
	-mkdir -p tmp
	cp Resources/language2.txt tmp/language2.txt

tmp/AppData/Saved/(Example).cevo : Resources/AppData/Saved/(Example).cevo
	-mkdir -p tmp/AppData/Saved
	cp Resources/AppData/Saved/(Example).cevo tmp/AppData/Saved/(Example).cevo

tmp/Graphics/Background.bmp : Resources/Graphics/Background.bmp
	-mkdir -p tmp/Graphics
	cp Resources/Graphics/Background.bmp tmp/Graphics/Background.bmp

tmp/Graphics/BigCityMap.bmp : Resources/Graphics/BigCityMap.bmp 
	-mkdir -p tmp/Graphics
	cp Resources/Graphics/BigCityMap.bmp tmp/Graphics/BigCityMap.bmp  

tmp/Graphics/Cities66x32.bmp : Resources/Graphics/Cities66x32.bmp 
	-mkdir -p tmp/Graphics
	cp Resources/Graphics/Cities66x32.bmp tmp/Graphics/Cities66x32.bmp 
	
tmp/Graphics/Cities66x32.credits.txt : Resources/Graphics/Cities66x32.credits.txt 
	-mkdir -p tmp/Graphics
	cp Resources/Graphics/Cities66x32.credits.txt tmp/Graphics/Cities66x32.credits.txt 

tmp/Graphics/Cities96x48.bmp : Resources/Graphics/Cities96x48.bmp 
	-mkdir -p tmp/Graphics
	cp Resources/Graphics/Cities96x48.bmp tmp/Graphics/Cities96x48.bmp 

tmp/Graphics/Cities96x48.credits.txt : Resources/Graphics/Cities96x48.credits.txt 
	-mkdir -p tmp/Graphics
	cp Resources/Graphics/Cities96x48.credits.txt tmp/Graphics/Cities96x48.credits.txt 

tmp/Graphics/City.bmp : Resources/Graphics/City.bmp 
	-mkdir -p tmp/Graphics
	cp Resources/Graphics/City.bmp tmp/Graphics/City.bmp 

tmp/Graphics/Colors.bmp : Resources/Graphics/Colors.bmp 
	-mkdir -p tmp/Graphics
	cp Resources/Graphics/Colors.bmp tmp/Graphics/Colors.bmp 
	
tmp/Graphics/Icons.bmp : Resources/Graphics/Icons.bmp 
	-mkdir -p tmp/Graphics
	cp Resources/Graphics/Icons.bmp tmp/Graphics/Icons.bmp 

tmp/Graphics/Icons.credits.txt : Resources/Graphics/Icons.credits.txt 
	-mkdir -p tmp/Graphics
	cp Resources/Graphics/Icons.credits.txt tmp/Graphics/Icons.credits.txt 

tmp/Graphics/MiliRes.bmp : Resources/Graphics/MiliRes.bmp 
	-mkdir -p tmp/Graphics
	cp Resources/Graphics/MiliRes.bmp tmp/Graphics/MiliRes.bmp 

tmp/Graphics/Nation.bmp : Resources/Graphics/Nation.bmp 
	-mkdir -p tmp/Graphics
	cp Resources/Graphics/Nation.bmp tmp/Graphics/Nation.bmp 

tmp/Graphics/Nation1.bmp : Resources/Graphics/Nation1.bmp 
	-mkdir -p tmp/Graphics
	cp Resources/Graphics/Nation1.bmp tmp/Graphics/Nation1.bmp 

tmp/Graphics/Nation1.credits.txt : Resources/Graphics/Nation1.credits.txt 
	-mkdir -p tmp/Graphics
	cp Resources/Graphics/Nation1.credits.txt tmp/Graphics/Nation1.credits.txt 
	
tmp/Graphics/Nation2.bmp : Resources/Graphics/Nation2.bmp 
	-mkdir -p tmp/Graphics
	cp Resources/Graphics/Nation2.bmp tmp/Graphics/Nation2.bmp 

tmp/Graphics/Nation2.credits.txt : Resources/Graphics/Nation2.credits.txt 
	-mkdir -p tmp/Graphics
	cp Resources/Graphics/Nation2.credits.txt tmp/Graphics/Nation2.credits.txt 

tmp/Graphics/Paper.jpg : Resources/Graphics/Paper.jpg 
	-mkdir -p tmp/Graphics
	cp Resources/Graphics/Paper.jpg tmp/Graphics/Paper.jpg 

tmp/Graphics/SmallCityMap.bmp : Resources/Graphics/SmallCityMap.bmp 
	-mkdir -p tmp/Graphics
	cp Resources/Graphics/SmallCityMap.bmp tmp/Graphics/SmallCityMap.bmp 

tmp/Graphics/StdCities.bmp : Resources/Graphics/StdCities.bmp 
	-mkdir -p tmp/Graphics
	cp Resources/Graphics/StdCities.bmp tmp/Graphics/StdCities.bmp 
	
tmp/Graphics/StdCities.credits.txt : Resources/Graphics/StdCities.credits.txt 
	-mkdir -p tmp/Graphics
	cp Resources/Graphics/StdCities.credits.txt tmp/Graphics/StdCities.credits.txt 
	
tmp/Graphics/StdUnits.bmp : Resources/Graphics/StdUnits.bmp 
	-mkdir -p tmp/Graphics
	cp Resources/Graphics/StdUnits.bmp tmp/Graphics/StdUnits.bmp 

tmp/Graphics/StdUnits.credits.txt : Resources/Graphics/StdUnits.credits.txt 
	-mkdir -p tmp/Graphics
	cp Resources/Graphics/StdUnits.credits.txt tmp/Graphics/StdUnits.credits.txt 

tmp/Graphics/System.bmp : Resources/Graphics/System.bmp 
	-mkdir -p tmp/Graphics
	cp Resources/Graphics/System.bmp tmp/Graphics/System.bmp 

tmp/Graphics/System2.bmp : Resources/Graphics/System2.bmp 
	-mkdir -p tmp/Graphics
	cp Resources/Graphics/System2.bmp tmp/Graphics/System2.bmp 

tmp/Graphics/Templates.bmp : Resources/Graphics/Templates.bmp 
	-mkdir -p tmp/Graphics
	cp Resources/Graphics/Templates.bmp tmp/Graphics/Templates.bmp 

tmp/Graphics/Terrain66x32.bmp : Resources/Graphics/Terrain66x32.bmp  
	-mkdir -p tmp/Graphics
	cp Resources/Graphics/Terrain66x32.bmp tmp/Graphics/Terrain66x32.bmp 

tmp/Graphics/Terrain66x32.credits.txt : Resources/Graphics/Terrain66x32.credits.txt  
	-mkdir -p tmp/Graphics
	cp Resources/Graphics/Terrain66x32.credits.txt tmp/Graphics/Terrain66x32.credits.txt 

tmp/Graphics/Terrain96x48.bmp : Resources/Graphics/Terrain96x48.bmp  
	-mkdir -p tmp/Graphics
	cp Resources/Graphics/Terrain96x48.bmp tmp/Graphics/Terrain96x48.bmp 

tmp/Graphics/Terrain96x48.credits.txt : Resources/Graphics/Terrain96x48.credits.txt  
	-mkdir -p tmp/Graphics
	cp Resources/Graphics/Terrain96x48.credits.txt tmp/Graphics/Terrain96x48.credits.txt 

tmp/Graphics/Texture0.jpg : Resources/Graphics/Texture0.jpg  
	-mkdir -p tmp/Graphics
	cp Resources/Graphics/Texture0.jpg tmp/Graphics/Texture0.jpg 

tmp/Graphics/Texture1.jpg : Resources/Graphics/Texture1.jpg  
	-mkdir -p tmp/Graphics
	cp Resources/Graphics/Texture1.jpg tmp/Graphics/Texture1.jpg 

tmp/Graphics/Texture2.jpg : Resources/Graphics/Texture2.jpg  
	-mkdir -p tmp/Graphics
	cp Resources/Graphics/Texture2.jpg tmp/Graphics/Texture2.jpg 

tmp/Graphics/Texture3.jpg : Resources/Graphics/Texture3.jpg  
	-mkdir -p tmp/Graphics
	cp Resources/Graphics/Texture3.jpg tmp/Graphics/Texture3.jpg 

tmp/Graphics/Texture4.jpg : Resources/Graphics/Texture4.jpg  
	-mkdir -p tmp/Graphics
	cp Resources/Graphics/Texture4.jpg tmp/Graphics/Texture4.jpg 

tmp/Graphics/Unit.bmp : Resources/Graphics/Unit.bmp  
	-mkdir -p tmp/Graphics
	cp Resources/Graphics/Unit.bmp tmp/Graphics/Unit.bmp 

tmp/Help/AdvTree.bmp : Resources/Help/AdvTree.bmp  
	-mkdir -p tmp/Help
	cp Resources/Help/AdvTree.bmp tmp/Help/AdvTree.bmp 

tmp/Help/AITShot.bmp : Resources/Help/AITShot.bmp  
	-mkdir -p tmp/Help
	cp Resources/Help/AITShot.bmp tmp/Help/AITShot.bmp 

tmp/Help/CityShot.bmp : Resources/Help/CityShot.bmp  
	-mkdir -p tmp/Help
	cp Resources/Help/CityShot.bmp tmp/Help/CityShot.bmp 

tmp/Help/Corruption.bmp : Resources/Help/Corruption.bmp  
	-mkdir -p tmp/Help
	cp Resources/Help/Corruption.bmp tmp/Help/Corruption.bmp 

tmp/Help/DraftShot.bmp : Resources/Help/DraftShot.bmp  
	-mkdir -p tmp/Help
	cp Resources/Help/DraftShot.bmp tmp/Help/DraftShot.bmp 

tmp/Help/help.txt : Resources/Help/help.txt  
	-mkdir -p tmp/Help
	cp Resources/Help/help.txt tmp/Help/help.txt 

tmp/Help/MoveShot.bmp : Resources/Help/MoveShot.bmp  
	-mkdir -p tmp/Help
	cp Resources/Help/MoveShot.bmp tmp/Help/MoveShot.bmp 

tmp/Sounds/8MM_AT_C-BlackCow-8186_hifi.mp3 : Resources/Sounds/8MM_AT_C-BlackCow-8186_hifi.mp3
	-mkdir -p tmp/Sounds
	cp Resources/Sounds/8MM_AT_C-BlackCow-8186_hifi.mp3 tmp/Sounds/8MM_AT_C-BlackCow-8186_hifi.mp3 

tmp/Sounds/Boulder_-oblius-7747_hifi.mp3 : Resources/Sounds/Boulder_-oblius-7747_hifi.mp3  
	-mkdir -p tmp/Sounds
	cp Resources/Sounds/Boulder_-oblius-7747_hifi.mp3 tmp/Sounds/Boulder_-oblius-7747_hifi.mp3 

tmp/Sounds/Cash_reg-public_d-296_hifi.mp3 : Resources/Sounds/Cash_reg-public_d-296_hifi.mp3  
	-mkdir -p tmp/Sounds
	cp Resources/Sounds/Cash_reg-public_d-296_hifi.mp3 tmp/Sounds/Cash_reg-public_d-296_hifi.mp3 

tmp/Sounds/Hammer_o-Public_D-243_hifi.mp3 : Resources/Sounds/Hammer_o-Public_D-243_hifi.mp3  
	-mkdir -p tmp/Sounds
	cp Resources/Sounds/Hammer_o-Public_D-243_hifi.mp3 tmp/Sounds/Hammer_o-Public_D-243_hifi.mp3 

tmp/Sounds/sg_angry.mp3 : Resources/Sounds/sg_angry.mp3  
	-mkdir -p tmp/Sounds
	cp Resources/Sounds/sg_angry.mp3 tmp/Sounds/sg_angry.mp3 

tmp/Sounds/sg_autogun.mp3 : Resources/Sounds/sg_autogun.mp3  
	-mkdir -p tmp/Sounds
	cp Resources/Sounds/sg_autogun.mp3 tmp/Sounds/sg_autogun.mp3 

tmp/Sounds/sg_battery.mp3 : Resources/Sounds/sg_battery.mp3  
	-mkdir -p tmp/Sounds
	cp Resources/Sounds/sg_battery.mp3 tmp/Sounds/sg_battery.mp3 

tmp/Sounds/sg_cavalry.mp3 : Resources/Sounds/sg_cavalry.mp3  
	-mkdir -p tmp/Sounds
	cp Resources/Sounds/sg_cavalry.mp3 tmp/Sounds/sg_cavalry.mp3 

tmp/Sounds/sg_cheers.mp3 : Resources/Sounds/sg_cheers.mp3  
	-mkdir -p tmp/Sounds
	cp Resources/Sounds/sg_cheers.mp3 tmp/Sounds/sg_cheers.mp3 

tmp/Sounds/sg_drum.mp3 : Resources/Sounds/sg_drum.mp3  
	-mkdir -p tmp/Sounds
	cp Resources/Sounds/sg_drum.mp3 tmp/Sounds/sg_drum.mp3 

tmp/Sounds/sg_drum2.mp3 : Resources/Sounds/sg_drum2.mp3  
	-mkdir -p tmp/Sounds
	cp Resources/Sounds/sg_drum2.mp3 tmp/Sounds/sg_drum2.mp3 

tmp/Sounds/sg_fanfare.mp3 : Resources/Sounds/sg_fanfare.mp3  
	-mkdir -p tmp/Sounds
	cp Resources/Sounds/sg_fanfare.mp3 tmp/Sounds/sg_fanfare.mp3 

tmp/Sounds/sg_gain.mp3 : Resources/Sounds/sg_gain.mp3  
	-mkdir -p tmp/Sounds
	cp Resources/Sounds/sg_gain.mp3 tmp/Sounds/sg_gain.mp3 

tmp/Sounds/sg_harp.mp3 : Resources/Sounds/sg_harp.mp3  
	-mkdir -p tmp/Sounds
	cp Resources/Sounds/sg_harp.mp3 tmp/Sounds/sg_harp.mp3 

tmp/Sounds/sg_horsemen.mp3 : Resources/Sounds/sg_horsemen.mp3 
	-mkdir -p tmp/Sounds
	cp Resources/Sounds/sg_horsemen.mp3 tmp/Sounds/sg_horsemen.mp3 

tmp/Sounds/sg_invent.mp3 : Resources/Sounds/sg_invent.mp3 
	-mkdir -p tmp/Sounds
	cp Resources/Sounds/sg_invent.mp3 tmp/Sounds/sg_invent.mp3 

tmp/Sounds/sg_jet.mp3 : Resources/Sounds/sg_jet.mp3  
	-mkdir -p tmp/Sounds
	cp Resources/Sounds/sg_jet.mp3 tmp/Sounds/sg_jet.mp3 

tmp/Sounds/sg_marching.mp3 : Resources/Sounds/sg_marching.mp3  
	-mkdir -p tmp/Sounds
	cp Resources/Sounds/sg_marching.mp3 tmp/Sounds/sg_marching.mp3 

tmp/Sounds/sg_mechanical.mp3 : Resources/Sounds/sg_mechanical.mp3  
	-mkdir -p tmp/Sounds
	cp Resources/Sounds/sg_mechanical.mp3 tmp/Sounds/sg_mechanical.mp3 

tmp/Sounds/sg_militia.mp3 : Resources/Sounds/sg_militia.mp3  
	-mkdir -p tmp/Sounds
	cp Resources/Sounds/sg_militia.mp3 tmp/Sounds/sg_militia.mp3 

tmp/Sounds/sg_moan.mp3 : Resources/Sounds/sg_moan.mp3  
	-mkdir -p tmp/Sounds
	cp Resources/Sounds/sg_moan.mp3 tmp/Sounds/sg_moan.mp3 

tmp/Sounds/sg_musketeers.mp3 : Resources/Sounds/sg_musketeers.mp3  
	-mkdir -p tmp/Sounds
	cp Resources/Sounds/sg_musketeers.mp3 tmp/Sounds/sg_musketeers.mp3 

tmp/Sounds/sg_nono.mp3 : Resources/Sounds/sg_nono.mp3  
	-mkdir -p tmp/Sounds
	cp Resources/Sounds/sg_nono.mp3 tmp/Sounds/sg_nono.mp3 

tmp/Sounds/sg_plane.mp3 : Resources/Sounds/sg_plane.mp3  
	-mkdir -p tmp/Sounds
	cp Resources/Sounds/sg_plane.mp3 tmp/Sounds/sg_plane.mp3 

tmp/Sounds/sg_sad.mp3 : Resources/Sounds/sg_sad.mp3  
	-mkdir -p tmp/Sounds
	cp Resources/Sounds/sg_sad.mp3 tmp/Sounds/sg_sad.mp3 

tmp/Sounds/sg_space.mp3 : Resources/Sounds/sg_space.mp3  
	-mkdir -p tmp/Sounds
	cp Resources/Sounds/sg_space.mp3 tmp/Sounds/sg_space.mp3 

tmp/Sounds/sg_steal.mp3 : Resources/Sounds/sg_steal.mp3  
	-mkdir -p tmp/Sounds
	cp Resources/Sounds/sg_steal.mp3 tmp/Sounds/sg_steal.mp3 

tmp/Sounds/sg_warning.mp3 : Resources/Sounds/sg_warning.mp3  
	-mkdir -p tmp/Sounds
	cp Resources/Sounds/sg_warning.mp3 tmp/Sounds/sg_warning.mp3 

tmp/Sounds/sizzle-Sith_Mas-7716_hifi.mp3 : Resources/Sounds/sizzle-Sith_Mas-7716_hifi.mp3  
	-mkdir -p tmp/Sounds
	cp Resources/Sounds/sizzle-Sith_Mas-7716_hifi.mp3 tmp/Sounds/sizzle-Sith_Mas-7716_hifi.mp3 

tmp/Sounds/Small_Sw-Public_D-262_hifi.mp3 : Resources/Sounds/Small_Sw-Public_D-262_hifi.mp3  
	-mkdir -p tmp/Sounds
	cp Resources/Sounds/Small_Sw-Public_D-262_hifi.mp3 tmp/Sounds/Small_Sw-Public_D-262_hifi.mp3 

tmp/Sounds/sound.credits.txt : Resources/Sounds/sound.credits.txt  
	-mkdir -p tmp/Sounds
	cp Resources/Sounds/sound.credits.txt tmp/Sounds/sound.credits.txt 

tmp/Sounds/sound.txt : Resources/Sounds/sound.txt  
	-mkdir -p tmp/Sounds
	cp Resources/Sounds/sound.txt tmp/Sounds/sound.txt 

tmp/Sounds/victory.mp3 : Resources/Sounds/victory.mp3  
	-mkdir -p tmp/Sounds
	cp Resources/Sounds/victory.mp3 tmp/Sounds/victory.mp3 

tmp/Tribes/Americans.tribe.txt : Resources/Tribes/Americans.tribe.txt  
	-mkdir -p tmp/Tribes
	cp Resources/Tribes/Americans.tribe.txt tmp/Tribes/Americans.tribe.txt 

tmp/Tribes/Babyl.tribe.txt : Resources/Tribes/Babyl.tribe.txt  
	-mkdir -p tmp/Tribes
	cp Resources/Tribes/Babyl.tribe.txt tmp/Tribes/Babyl.tribe.txt 

tmp/Tribes/British.tribe.txt : Resources/Tribes/British.tribe.txt  
	-mkdir -p tmp/Tribes
	cp Resources/Tribes/British.tribe.txt tmp/Tribes/British.tribe.txt 

tmp/Tribes/Chinese.tribe.txt : Resources/Tribes/Chinese.tribe.txt  
	-mkdir -p tmp/Tribes
	cp Resources/Tribes/Chinese.tribe.txt tmp/Tribes/Chinese.tribe.txt 

tmp/Tribes/Egyptians.tribe.txt : Resources/Tribes/Egyptians.tribe.txt  
	-mkdir -p tmp/Tribes
	cp Resources/Tribes/Egyptians.tribe.txt tmp/Tribes/Egyptians.tribe.txt 

tmp/Tribes/French.tribe.txt : Resources/Tribes/French.tribe.txt  
	-mkdir -p tmp/Tribes
	cp Resources/Tribes/French.tribe.txt tmp/Tribes/French.tribe.txt 

tmp/Tribes/Germans.tribe.txt : Resources/Tribes/Germans.tribe.txt  
	-mkdir -p tmp/Tribes
	cp Resources/Tribes/Germans.tribe.txt tmp/Tribes/Germans.tribe.txt 

tmp/Tribes/Greeks.tribe.txt : Resources/Tribes/Greeks.tribe.txt  
	-mkdir -p tmp/Tribes
	cp Resources/Tribes/Greeks.tribe.txt tmp/Tribes/Greeks.tribe.txt 

tmp/Tribes/Japanese.tribe.txt : Resources/Tribes/Japanese.tribe.txt  
	-mkdir -p tmp/Tribes
	cp Resources/Tribes/Japanese.tribe.txt tmp/Tribes/Japanese.tribe.txt 

tmp/Tribes/Mongols.tribe.txt : Resources/Tribes/Mongols.tribe.txt  
	-mkdir -p tmp/Tribes
	cp Resources/Tribes/Mongols.tribe.txt tmp/Tribes/Mongols.tribe.txt 

tmp/Tribes/Persians.tribe.txt : Resources/Tribes/Persians.tribe.txt  
	-mkdir -p tmp/Tribes
	cp Resources/Tribes/Persians.tribe.txt tmp/Tribes/Persians.tribe.txt 

tmp/Tribes/Phoenicians.tribe.txt : Resources/Tribes/Phoenicians.tribe.txt  
	-mkdir -p tmp/Tribes
	cp Resources/Tribes/Phoenicians.tribe.txt tmp/Tribes/Phoenicians.tribe.txt 

tmp/Tribes/Romans.tribe.txt : Resources/Tribes/Romans.tribe.txt  
	-mkdir -p tmp/Tribes
	cp Resources/Tribes/Romans.tribe.txt tmp/Tribes/Romans.tribe.txt 

tmp/Tribes/Russians.tribe.txt : Resources/Tribes/Russians.tribe.txt  
	-mkdir -p tmp/Tribes
	cp Resources/Tribes/Russians.tribe.txt tmp/Tribes/Russians.tribe.txt 

tmp/Tribes/Spanish.tribe.txt : Resources/Tribes/Spanish.tribe.txt  
	-mkdir -p tmp/Tribes
	cp Resources/Tribes/Spanish.tribe.txt tmp/Tribes/Spanish.tribe.txt 

tmp/Tribes/StdUnits.txt : Resources/Tribes/StdUnits.txt  
	-mkdir -p tmp/Tribes
	cp Resources/Tribes/StdUnits.txt tmp/Tribes/StdUnits.txt 

tmp/Tribes/Vikings.tribe.txt : Resources/Tribes/Vikings.tribe.txt 
	-mkdir -p tmp/Tribes
	cp Resources/Tribes/Vikings.tribe.txt tmp/Tribes/Vikings.tribe.txt


# ----- Configurator

tmp/Configurator.exe : \
		Configurator\AddOn.cs \
		Configurator\AddOnSelector.cs \
		Configurator\AddOnSelector.Designer.cs \
		Configurator\AddOnSelector.resx \
		Configurator\cevoxp2.ico \
		Configurator\Configurator.csproj \
		Configurator\Configurator.sln \
		Configurator\DisplaySettings.cs \
		Configurator\Installer.cs \
		Configurator\MainForm.cs \
		Configurator\MainForm.Designer.cs \
		Configurator\MainForm.resx \
		Configurator\PoweredByZipStorer2.png \
		Configurator\Process.cs \
		Configurator\Program.cs \
		Configurator\ProgressDialog.cs \
		Configurator\ProgressDialog.Designer.cs \
		Configurator\ProgressDialog.resx \
		Configurator\TextViewer.cs \
		Configurator\TextViewer.Designer.cs \
		Configurator\TextViewer.resx \
		Configurator\ZipStorerLight.cs \
		\
		Configurator\Properties\AssemblyInfo.cs \
		Configurator\Properties\Resources.Designer.cs \
		Configurator\Properties\Resources.resx \
		Configurator\Properties\Settings.Designer.cs \
		Configurator\Properties\Settings.settings
	MSBuild.exe Configurator/Configurator.sln

