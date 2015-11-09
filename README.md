# yamldiff

Diff two YAML files based on their keys

## Rationale

- make sure two translation files have identical keys and are complete
- etc.

## Build

`make`

## Usage

```bash
% ./yamldiff a.yml b.yml
--- a.yml
+++ b.yml
-colonA
+colonB
-b
+c
-longA
+longBB
-    A
+    c
-x
zsh: exit 5     ./yamldiff a.yml b.yml
```

## License

GPLv3+
