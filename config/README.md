# config/

The actual Windchill configuration content, as files: rule bodies, later
lifecycle and workflow templates, property fragments, and so on.

Roles reference these files through the `config_dir` variable
(`inventory/group_vars/all.yml`), so from a rule definition you write
`content_file: oir/acme_wtpart.xml` and the role finds `config/oir/acme_wtpart.xml`.

| Folder | Used by | Contents |
|---|---|---|
| `oir/` | `acme.windchill.oir` | OIR bodies (`<AttributeValues>` XML) or complete LoadFromFile documents |

Keep this folder under version control: it is the history of your Windchill
configuration.
