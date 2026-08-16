# omakasui/build-apt-omakasui

Builds and publishes APT packages for [omakasui/apt-omakasui](https://github.com/omakasui/apt-omakasui).

Keys in `versions.yml` use short names without the `omakasui-` prefix; `produces[]` in `package.yml` sets the installed name.

## versions.yml

```yaml
package-name:
  version: "1.2.3"
  depends_on: []        # sibling keys needed at build time
  stable_release: false # true → also publish to stable channel
  external: false       # true → built in build-apt-packages, not here
  frozen_suites: []     # suites to skip
  auto_update: true     # false → skip periodic upstream check
```

## package.yml

```yaml
type: repackage          # build (default) | repackage
arch: all                 # any (default) | all (amd64-only)
produces: [omakasui-example]
distros: [debian13, ubuntu2404]
```

- `build` — Dockerfile stages files under `/output/staged/`; assembled from `packages/<name>/debian/`.
- `repackage` — Dockerfile writes complete `.deb`(s) directly to `/output/`; control fields live in the cloned repo's own `debian/control`.

`ARG VERSION` required in every Dockerfile. `BASE_IMAGE`, `SUITE`, `TARGETARCH` also available.

## update-sources.yml

Upstream source per auto-updated package, read by `scripts/check-updates.sh`:

```yaml
package-name:
  upstream: "github:owner/repo"   # or codeberg:owner/repo, or sibling:owner/repo
  tag_prefix: "v"
  use_tags: true                  # optional — use git tags instead of Releases
```

`sibling:` tracks release tags in `omakasui/build-apt-packages` for `external: true` packages.

## Adding a package

1. Add an entry to `versions.yml`.
2. Create `packages/<name>/Dockerfile` and `package.yml`.
3. Push — CI builds it automatically.

Manual trigger: GitHub > Actions > **Build package** > Run workflow.

## Dependencies

`depends_on` lists sibling keys; their `.deb` is downloaded and installed before build. Set `external: true` for deps built in `build-apt-packages`.

## Local build

Requires: `docker` (buildx), `yq`, `fakeroot`, `dpkg-deb`, `gh` (deps/check-updates), `qemu-user-static` (arm64).

```bash
make build PKG=aether
make lint PKG=aether
make check-updates PKG=aether
make list
make clean
```

Output: `output/<package>/`.
