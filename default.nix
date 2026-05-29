let
  nixpkgs = fetchTarball "https://github.com/NixOS/nixpkgs/tarball/nixos-24.05";
  pkgs = import nixpkgs { config = {}; overlays = []; };

in pkgs.mkShell {
  packages = with pkgs; [
    gcc13
    gcc13Stdenv
    wget
    less
    cmake
    autoconf
    automake
    curl
    git
    isl
    libmpc
    mpfr
    gmp
    gawk
    gnupg
    bison
    flex
    texinfo
    gperf
    libtool
    bc
    zlib
    bash
    ccache
    gnumake
    help2man
    openssh
    perl
    util-linux
    vim
    zlib
    locale
    (python3.withPackages (python-pkgs: [
      python-pkgs.hjson
      python-pkgs.mako
      python-pkgs.sphinx
      python-pkgs.sphinxcontrib-log-cabinet
      python-pkgs.sphinx_rtd_theme
      python-pkgs.recommonmark
      python-pkgs.pandas
    ]))
  ];

  hardeningDisable = [ "all" ];

  stdenv = pkgs.gcc13Stdenv;

  shellHook = ''
    export LOCALE_ARCHIVE=/usr/lib/locale/locale-archive ;
    export HPDCACHE_DIR=${toString ./.} ;
    export RISCV=${toString ./.}/tools/riscv ;
    source .github/scripts/env.sh ;
  '';
}
