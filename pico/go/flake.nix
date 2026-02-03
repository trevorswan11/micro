{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            go
            tinygo
            gopls
            gcc-arm-embedded
            picotool
            just
          ];

          shellHook = ''
            TINY_INFO=$(tinygo info pico)

            export GOOS=$(echo "$TINY_INFO" | grep "GOOS:" | awk '{print $2}')
            export GOARCH=$(echo "$TINY_INFO" | grep "GOARCH:" | awk '{print $2}')
            export GOROOT=$(echo "$TINY_INFO" | grep "cached GOROOT:" | awk '{print $3}')

            TAGS=$(echo "$TINY_INFO" | grep "build tags:" | sed 's/build tags://' | xargs | tr ' ' ',')
            export GOFLAGS="-tags=$TAGS"
          '';
        };
      }
    );
}
