# This module generates a JSON file describing all sources used by
# nixpkgs and copy it to the nixpkgs-tarballs S3 bucket. This file is
# then reachable on http://tarballs.nixos.org/sources.json and can be
# consumed by Software Heritage to fill their archive.
#
# This JSON file looks like:
# {
#   "version": 1
#   "sources": [
#     {
#       "type": "url",
#       "url": "https://ftpmirror.gnu.org//hello/hello-2.10.tar.gz"
#     },
#     {
#       "type": "url",
#       "url": "http://hackage.haskell.org/package//hackage-db-2.1.0.tar.gz"
#     }
#   ],
# }
#
# Note: this service expects AWS credentials for uploading to
# s3://nixpkgs-tarballs in /home/tarball-mirror/.aws/credentials.

{ config, lib, pkgs, ... }:

with lib;

let

  nixosRelease = "19.09";

in

{

  systemd.services.export-sources =
    { description = "Generate and export nixpkgs source urls";
      path  = [ config.nix.package pkgs.git pkgs.bash pkgs.aws ];
      environment.NIX_REMOTE = "daemon";
      # Use this user to get AWS credentials
      serviceConfig.User = "tarball-mirror";
      serviceConfig.Type = "oneshot";
      serviceConfig.PrivateTmp = true;
      script =
        ''
          dir=/home/tarball-mirror/nixpkgs-channels-for-expose-sources
          if ! [[ -e $dir ]]; then
            git clone git://github.com/NixOS/nixpkgs-channels.git $dir
          fi
          cd $dir
          git remote update origin
          git checkout origin/nixos-${nixosRelease}
          # FIXME: use IAM role.
          export AWS_ACCESS_KEY_ID=$(sed 's/aws_access_key_id=\(.*\)/\1/ ; t; d' ~/.aws/credentials)
          export AWS_SECRET_ACCESS_KEY=$(sed 's/aws_secret_access_key=\(.*\)/\1/ ; t; d' ~/.aws/credentials)

          NIX_PATH=nixpkgs=. GC_INITIAL_HEAP_SIZE=4g nix-instantiate --strict --eval --json ${./generate-sources.nix} > ./sources.json
           aws s3 cp ./sources.json s3://nixpkgs-tarballs/sources.json
        '';
      # One hour after the tarball-mirror job
      startAt = "06:30";
    };

}
