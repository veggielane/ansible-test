# lab/ - practise without a Windchill

`fake_windchill/` is a stand-in for a Windchill installation. Installed onto
your own PC by `playbooks/lab_setup.yml` (with the lab inventory), it lets
every playbook and role run for real, end to end.

```
C:\FakeWindchill\Windchill\                <- windchill_home in inventory/group_vars/lab
├── bin\windchill.cmd                      <- launcher; real Windchill: windchill.exe
├── bin\FakeLoadFromFile.ps1               <- imitates wt.load.LoadFromFile
├── loadXMLFiles\standardX26.dtd           <- DTD lookup, like the real loader
└── fakedb\
    ├── oir\<container>\<rule>.xml         <- "loaded" object initialization rules
    └── TypeDefinitionLoader\<type>.xml    <- "loaded" soft types (any other loader: fakedb\<LoaderClass>\)
C:\FakeWindchill\ansible\                  <- windchill_staging_dir (staging\, applied\, logs\)
```

What the fake gets right, on purpose, because the real one behaves this way:

| Real behaviour | Fake |
|---|---|
| Exit code 0 even when the load failed | same: failures are only visible in the output |
| Validates against `loadXMLFiles\<dtd>` from the DOCTYPE | checks the file exists |
| Wrong password -> `wt.util.WTException: Authentication failed` | password `wrong` |
| No `-u`/`-p` -> a login dialog opens and the process waits forever | sleeps 90 s |
| Every `csv*` element with a `handler` is one loaded item | rules are checked and keyed by name inside a container; anything else is filed under its loader class |

Things to try (all from tutorial lesson 07):

- run `playbooks/site.yml` and watch the order: types first, then rules
- change a rule body in `config/oir/` and re-run: only that rule reloads
- set `vault_windchill_admin_password: wrong` and watch the failure pattern catch it
- delete a file under `fakedb\` to see that Ansible does *not* notice
  (it trusts its `applied\` copy) and how `-e windchill_oir_force=true` fixes it

Reset the lab: delete `C:\FakeWindchill` and run `lab_setup.yml` again.
