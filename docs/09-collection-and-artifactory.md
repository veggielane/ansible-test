# Lesson 09 - Two repositories: the collection and Artifactory

**Goal:** understand why the roles now live in their own repository, how this
repository gets them, and how a change travels from a role edit to live.

## Two repositories, two lifecycles

| Repository | Contains | What "a version" means |
|---|---|---|
| `ansible-collection-windchill` | the roles, as the Ansible collection `acme.windchill`; later custom modules | a tag `v1.2.0` = a published tarball in Artifactory |
| `ansible` (this one) | inventory, per-environment values, vaults, `config/`, playbooks, lessons, lab | a commit = a desired state of Windchill, applied with `ansible-playbook` |

Rule of thumb: if a file would differ for another company running the same
automation, it is configuration and lives here. If it would be identical,
it is tooling and lives in the collection.

Artifactory stores versions of the collection only. It never sees your
configuration, which reaches Windchill only when you run a playbook.

```
 git: ansible-collection-windchill          git: ansible (this repo)
        │ tag v1.2.0, CI publishes                  │ requirements-windchill.yml: acme.windchill == 1.2.0
        ▼                                           │
   Artifactory  ── docker build (release mode) ─────┤
   acme.windchill 1.2.0                             ▼
                                        ansible-playbook site.yml -e target=dev
                                                    │
                                                    ▼
                                           Windchill dev server
```

## Dev mode and release mode

The control-node image can get the collection two ways:

| | Dev mode (default) | Release mode |
|---|---|---|
| Build | `docker compose build` | `docker build ... --build-arg ARTIFACTORY_GALAXY_URL=... --secret id=artifactory_token,src=.artifactory_token` (exact command in `docker/Dockerfile`) |
| Collection comes from | your checkout at `../ansible-collection-windchill`, mounted read-only by `docker-compose.yml` | Artifactory, at the version pinned in `requirements-windchill.yml`, baked into the image |
| Edits to a role | visible immediately | need a new version and a rebuild |
| Use it for | learning, developing a role, the lab | dev, PPE, live |

Both can coexist: `ANSIBLE_COLLECTIONS_PATH` lists the dev mount first, so a
checkout, when present, wins over the installed version. Delete the mount
line in `docker-compose.yml` when you want the image to be the only source.

## Artifactory setup (once)

| Repo key | Type | Purpose |
|---|---|---|
| `ansible-local` | local, package type *Ansible* | published versions of `acme.windchill` |
| `ansible-remote` | remote, upstream `https://galaxy.ansible.com` | caches `ansible.windows` and friends; builds no longer need the internet |
| `ansible` | virtual, includes both | the only URL clients use |

Client URL pattern: `https://<artifactory>/artifactory/api/ansible/<repo-key>/`.
Create an access token for a service account with deploy rights on
`ansible-local` and read on `ansible`. Put it in `.artifactory_token` here
(git-ignored) for release builds, and in the collection project's CI/CD
variables for publishing.

## Releasing a change to a role

1. In the collection repo: edit, `ansible-lint`, update `CHANGELOG.md`, bump
   `version` in `galaxy.yml`, merge to `main`, tag `vX.Y.Z`.
2. GitLab CI lints, self-tests, builds, installs the tarball, syntax-checks
   the roles, and on the tag publishes to `ansible-local`. It refuses a tag
   that does not match `galaxy.yml`; Artifactory refuses to overwrite a version.
3. Here: raise the pin in `requirements-windchill.yml`, rebuild in release
   mode, run the lab, then `-e target=dev`, PPE, live.

Live keeps its version until you raise the pin. If you need live on an
older collection than dev for a while, build the image per version
(`windchill-ansible-control:1.1.0`, `:1.2.0`) and run live with the older tag.

## Renaming the namespace

`acme` is a placeholder. Rename it once, before publishing anything:

- collection repo: `galaxy.yml` (`namespace`), `roles/oir/meta/main.yml`,
  `roles/oir/tasks/load_rule.yml`, `tests/syntax.yml`, `.gitlab-ci.yml`
- here: `requirements-windchill.yml`, `docker-compose.yml` (mount path),
  `playbooks/site.yml`, `playbooks/windchill_oir.yml`, `playbooks/lab_render_oir.yml`

A search for `acme.windchill` and `acme/windchill` across both repos finds them all.

## Adding a role now

Lesson 08's recipe still applies; the role is created in the collection repo
(`roles/<area>/`), depends on `acme.windchill.common`, and is released with
the next version. Its data (`inventory/group_vars/windchill/<area>.yml`,
`config/<area>/`) and its line in `playbooks/site.yml` are added here.

While developing it you are in dev mode, so you can iterate on the role and
its data together without publishing anything.
