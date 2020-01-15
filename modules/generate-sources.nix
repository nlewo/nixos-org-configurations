with builtins;
let
  pkgs = import <nixpkgs> {};
  mirrors = import <nixpkgs/pkgs/build-support/fetchurl/mirrors.nix>;
  urls = import <nixpkgs/maintainers/scripts/find-tarballs.nix> {
    expr = import <nixpkgs/maintainers/scripts/all-tarballs.nix>;
  };
  
  # Resolve the mirror:// part of the url by looking into the defined
  # mirror list.
  # If the url scheme is `mirror`, this translates this mirror to a
  # real URL by looking in nixpkgs mirrors
  resolveMirrorUrl = url: with pkgs.lib; let
    splited = splitString "/" url;
    isMirrorUrl = elemAt splited 0 != "mirror:";
    mirror = elemAt splited 2;
    path = concatStringsSep "/" (drop 3 splited);
    resolvedUrl = elemAt (getAttr mirror mirrors) 0;
  in if isMirrorUrl
  then url
  else resolvedUrl + "/" + path;

  # Transform the url list to swh format
  toSwh = s: {
    type="url";
    url = resolveMirrorUrl s.url;
  };
in
{
  version = 1;
  sources = map toSwh urls;
}
