program Win32Loader;

{$R cevo.res}
{$R CevoWin32.res}

procedure Run(clientPtr: pointer); stdcall; external 'cevo.dll' name 'Run';

begin
Run(nil);
end.

