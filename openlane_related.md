1. conda setup- wsl ubuntu
2. Using nix setup approach & NOT Docker
3. nix handles systems better
4. clone openlane2
5. To invoke openlane - `nix-shell --pure $HOME/openlane2/shell.nix`
6. To run all steps - `openlane config.json`
7. `openlane --last-run --flow OpenInKLayout config.json` for layout view
