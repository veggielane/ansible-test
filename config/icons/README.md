# config/icons/

Images that Windchill serves from `codebase\netmarkets\images`: type icons
above all. `acme.windchill.icons` mirrors the folders listed in
`inventory/group_vars/windchill/icons.yml` onto the server, before the soft
types are imported.

Keep the same sub-folder layout the type definitions refer to. A type whose
icon property says `netmarkets/images/acme/widget.gif` needs
`config/icons/acme/widget.gif` here (mirrored to the root) or
`config/icons/widget.gif` with `dest: acme`.

`lab/` holds a placeholder icon for the fake Windchill.
