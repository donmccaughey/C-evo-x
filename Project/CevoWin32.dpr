program Win32Loader;

procedure Run(clientPtr: pointer); stdcall; external 'cevo.dll' name 'Run';

begin
Run(nil);
end.

