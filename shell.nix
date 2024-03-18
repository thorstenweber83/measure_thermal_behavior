let
  pkgs = import <nixpkgs> { };
in
pkgs.mkShell {
  buildInputs = [
    (pkgs.python3.withPackages (ps: with ps;[
      matplotlib
      numpy
      pandas
      rich
      rich-argparse
      (
        buildPythonPackage
          (
            let
              pname = "ruptures";
              version = "1.1.9";
              src = fetchPypi {
                inherit pname version;
                hash = "sha256-qpQPPAIjXauUdT/xVon466yhDIPaccspy7f5gd+jYtw=";
              };
            in
            {
              inherit pname version src;
              pyproject = true;
              nativeBuildInputs = [
                setuptools-scm
              ];
              propagatedBuildInputs = [
                cython
                scipy
                setuptools
                oldest-supported-numpy
              ];
            }
          )
      )
      requests
    ]))
  ];
}
