{
  description = "docgen.nvim dev shell";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forEachSystem = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in {
      devShells = forEachSystem (pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            lua5_1
            lua51Packages.luarocks
            stylua
            luajitPackages.luacheck
            curl
          ];
          # On NixOS, luarocks can't find librt (glibc) via standard paths.
          # Bake the current glibc store path into a temp luarocks config at shell entry.
          # LUAROCKS_CONFIG is inherited by nvim -> lazy.nvim -> luarocks subprocesses.
          shellHook = if pkgs.stdenv.isLinux then ''
            cfg=$(mktemp /tmp/luarocks-XXXXXX.lua)
            printf 'external_deps_dirs = {"%s", "/usr/local", "/usr", "/"}\n' \
              "${pkgs.glibc}" > "$cfg"
            export LUAROCKS_CONFIG="$cfg"
          '' else "";
        };
      });
    };
}
