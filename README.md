# omakasui/build-apt-omakasui

Builds and publishes APT packages for [omakasui/apt-omakasui](https://github.com/omakasui/apt-omakasui).

Keys in `versions.yml` use short names without the `omakasui-` prefix. The installed name is set by `produces[]` in `package.yml`.

## versions.yml

One entry per package:

```yaml
package-name:
  version: "1.2.3"
  depends_on: []
  stable_release: false
  external: false
  frozen_suites: []
  auto_update: true
```

| Field | Default | Description |
| --- | --- | --- |
| `version` | required | Upstream version to build. |
| `depends_on` | `[]` | Sibling keys needed at build time. |
| `stable_release` | `false` | Set to `true` to also publish to the stable channel. |
| `external` | `false` | Set to `true` if the package is built in `build-apt-packages` rather than here. |
| `frozen_suites` | `[]` | Suites to skip. |
| `auto_update` | `true` | Set to `false` to skip the periodic upstream check. |

## package.yml

```yaml
type: repackage
arch: all
layer_cache: false
produces: [omakasui-example]
distros: [debian13, ubuntu2404]
```

| Field | Default | Description |
| --- | --- | --- |
| `type` | `build` | Either `build` or `repackage`. See below. |
| `arch` | `any` | Use `all` for amd64-only packages. |
| `layer_cache` | `false` | Set to `true` to cache Docker layers in CI. See below. |
| `produces` | required | Installed names. |
| `distros` | required | Target distributions. |

### Build types

* **`build`**: the Dockerfile stages files under `/output/staged/`, assembled from `packages/<name>/debian/`.
* **`repackage`**: the Dockerfile writes complete `.deb` files directly to `/output/`, and control fields live in the cloned repo's own `debian/control`.

### Dockerfile arguments

* `ARG VERSION` is required in every Dockerfile.
* `BASE_IMAGE`, `SUITE` and `TARGETARCH` are also available.

### Layer caching

Set `layer_cache: true` only when the Dockerfile pins its source to `VERSION`, for example `git clone --branch "v${VERSION}"`. Otherwise a cached clone layer would freeze the upstream source indefinitely.

## update-sources.yml

Upstream source per auto-updated package, read by `scripts/check-updates.sh`:

```yaml
package-name:
  upstream: "github:owner/repo"
  tag_prefix: "v"
  use_tags: true
```

| Field | Description |
| --- | --- |
| `upstream` | Source in the form `github:owner/repo`, `codeberg:owner/repo` or `sibling:owner/repo`. |
| `tag_prefix` | Prefix stripped from upstream tags. |
| `use_tags` | Optional. Set to `true` to use git tags instead of Releases. |

`sibling:` tracks release tags in `omakasui/build-apt-packages`, for packages marked `external: true`.

## Adding a package

1. Add an entry to `versions.yml`.
2. Create `packages/<name>/Dockerfile` and `package.yml`.
3. Push. CI builds it automatically.

Manual trigger: GitHub > Actions > **Build package** > Run workflow.

## Dependencies

`depends_on` lists sibling keys. Their `.deb` is downloaded and installed before the build starts. Set `external: true` for dependencies built in `build-apt-packages`.

## Local build

Requires:

* `docker` (with buildx)
* `yq`
* `fakeroot`
* `dpkg-deb`
* `gh` (dependencies and check-updates)
* `qemu-user-static` (arm64 builds only)

```bash
make build PKG=aether
make lint PKG=aether
make check-updates PKG=aether
make list
make clean
```

Output: `output/<package>/`.
