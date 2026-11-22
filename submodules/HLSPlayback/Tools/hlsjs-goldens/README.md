# hls.js golden vectors

`Tests/HLSJSGoldens.swift` holds values computed by hls.js v1.7.3's own TypeScript
(`e5ff3583965e3af16c4a4b4d2b5f7bd1ffb5b7de`) on fixed inputs. The Swift port's tests compare against them, so the
port is checked against hls.js itself rather than against a reading of it.

Regenerate (needs network for `git clone` and `npx esbuild`):

```sh
sh submodules/HLSPlayback/Tools/hlsjs-goldens/generate.sh
```

Never edit `HLSJSGoldens.swift` by hand. To add cases, change `entry.ts` and regenerate; a change that moves an
existing case's values means either hls.js or the inputs changed, and has to be explained in the commit.
