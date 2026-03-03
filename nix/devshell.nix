{ pkgs }:
pkgs.mkShell {
  # Add build dependencies
  packages = with pkgs; [
    pnpm_9
    nodejs_22
  ];

  # Add environment variables
  env = { };

  # Load custom bash code
  shellHook = ''

  '';
}
