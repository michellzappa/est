# App Store metadata

The canonical App Store Connect copy lives in
[`appstore/appstore.md`](appstore/appstore.md). Edit that file, then run:

```sh
node appstore/metadata.mjs
```

The generated JSON under `appstore/metadata/` is ready for the `asc` CLI.
