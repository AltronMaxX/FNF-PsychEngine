{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    SDL2
    alsa-lib
    libGL
    libX11
    libXext
    libXinerama
    libXrandr
    libXi
    libXcursor
    wayland
    libxkbcommon
  ];

  shellHook = ''
    export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath (with pkgs; [
      SDL2 alsa-lib libGL 
      libX11 libXext libXinerama libXrandr libXi libXcursor 
      wayland libxkbcommon
    ])}:$LD_LIBRARY_PATH"
  '';
}