{
  config,
  pkgs,
  lib,
  ...
}:
with lib; let
  cfg = config.services.i-librarian;
  pkg = pkgs.callPackage ./derivation.nix {
    bgImage = cfg.backgroundImage;
  };
  configPath = pkgs.buildEnv {
    name = "i-librarian-config";
    paths = [pkg];
    pathsToLink = ["/config"];
  };

  privatePath = pkgs.buildEnv {
    name = "i-librarian-private";
    paths = [pkg];
    pathsToLink = ["/app" "/classes"];
  };

  pathsFile = pkgs.writeTextDir "paths.php" ''
    <?php
    $IL_CONFIG_PATH = '${configPath}';
    $IL_PRIVATE_PATH = '${privatePath}';
    $IL_DATA_PATH = '${cfg.dataDir}';
  '';

  publicPath = pkgs.runCommand "i-librarian-public" {} ''
    shopt -s extglob
    mkdir $out
    cp -r ${pkg}/public/!(paths.php) $out
    cp ${pathsFile}/paths.php $out
  '';

  extraBin = [
    pkgs.poppler-utils
    pkgs.ghostscript
    pkgs.tesseract
  ];
in {
  options.services.i-librarian = {
    enable = mkEnableOption "I, Librarian service";
    port = mkOption {
      type = types.port;
      default = 8080;
    };
    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/i-librarian";
    };
    domain = mkOption {type = types.str;};
    backgroundImage = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to custom background images to be injected into the package.";
    };
  };

  config = mkIf cfg.enable {
    users.groups.i-librarian = {};
    users.users.i-librarian = {
      description = "I, Librarian service user";
      group = "i-librarian";
      home = cfg.dataDir;
      isSystemUser = true;
    };

    services.phpfpm.pools.i-librarian = {
      user = "i-librarian";
      phpPackage = pkgs.php.withExtensions (
        {
          enabled,
          all,
        }:
          enabled
          ++ [
            all.sysvshm
            all.curl
            all.xml
            all.dom
            all.openssl
            all.sqlite3 # Critical for the DB
            all.sodium # Critical for security
            all.gd # Image handling
            all.mbstring # String handling
            all.intl # Localisation
            all.zip # File exports
          ]
      );
      phpEnv.PATH = "${makeBinPath extraBin}:/run/wrappers/bin:/run/current-system/sw/bin";
      settings = {
        "listen.owner" = "nginx";
        "listen.group" = "nginx";
        "pm" = "dynamic";
        "pm.max_children" = 75;
        "pm.start_servers" = 10;
        "pm.min_spare_servers" = 5;
        "pm.max_spare_servers" = 20;
      };
      phpOptions = ''
        upload_max_filesize = 200M
        post_max_size = 800M
        log_errors = on
        error_log = 'stderr'
      '';
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir}/data 0700 i-librarian i-librarian - -"
    ];

    services.nginx.virtualHosts."iLibrarian" = {
      root = publicPath;
      listen = [
        {
          addr = "0.0.0.0";
          port = cfg.port;
        }
      ];
      extraConfig = ''
        index index.php;
      '';
      locations."~ ^(.+\\.php)(.*)$" = {
        extraConfig = ''
          include ${config.services.nginx.package}/conf/fastcgi.conf;
          fastcgi_pass unix:${config.services.phpfpm.pools.i-librarian.socket};
          fastcgi_split_path_info ^(.+\.php)(.*)$;
          fastcgi_param PATH_INFO $fastcgi_path_info;

          fastcgi_param HTTPS on;
          fastcgi_param HTTP_X_FORWARDED_PROTO https;
        '';
      };
    };
  };
}
