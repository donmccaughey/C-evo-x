program Win32Loader;

{$R cevo.res}

procedure Run(clientPtr: pointer); stdcall; external 'cevo.dll' name 'Run';

begin
Run(nil);
end.

