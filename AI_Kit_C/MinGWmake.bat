::This small batch file is for people who use MinGW 2.0 (GCC 3.2)
::idea submitted by Julien Pierrehumbert [julp@myrealbox.com]

g++ -shared -o MyAI.dll aimain.cpp aiclasses.cpp MyAI.def -s
