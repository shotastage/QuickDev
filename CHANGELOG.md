# Changelog

## 0.0.5

- [x] Rename the `transfer` command to `register` while preserving the same directory validation, confirmation, move, and index refresh behavior.
- [x] Update `clone` so a successful repository clone also refreshes the cached project index automatically.

- [x] Add an `archive` command to safely archive projects as `.qda` files with dry-run planning, manifest embedding, warning detection, and default output under `~/.quickdev/archive/`.
- [x] Add a `restore` command that validates `.qda` structure, restores archives into `~/Developer/<project-name>` by default, supports dry-run previews, and prints embedded restore hints.

## 0.0.4

- Add a `clone` command to automatically clone a specified Git repository into the `~/Developer/` directory.


## 0.0.1~0.0.3 Implement basic commands

- These versions include the initial implementation and minor behavioral optimizations.
