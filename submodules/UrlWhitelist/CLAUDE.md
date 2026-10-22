# UrlWhitelist — agent notes

## Links with a login part (`UrlWhitelistTests`)

`//submodules/UrlWhitelist:UrlWhitelistTests` is a host `swift_test` (root `CLAUDE.md`, "Running tests"). It pins
`externalUrlWithLoginPart`, the check that makes opening a link with a login part in front of its host ask first: in
`https://telegram.org∕test∕@evil.org` the `∕` (U+2215) is not a slash, so `telegram.org∕test∕` is a user name and the
link opens evil.org.

- The check runs in the external-URL opener (`openExternalUrlImpl`), which every external link leaves through,
  including the openers that never ask about anything (admin log, Instant View). Its parse is the opener's own
  (`canonicalExternalUrl`, in `UrlWhitelist`).
- The prompts in `openUserGeneratedUrl` and `TextLinkHandling` also flag such links.
- Every prompt, and the title of every long-press link menu (`displayUrlRevealingLoginPart`; Copy still copies the link
  as written), shows the address without the login part. Accepting a prompt records the address
  (`noteLoginPartConfirmed`) so the opener does not ask a second time.
- Keep the check out of `parseUrl`: its `concealed` flag also makes the shared-links list title a link with its whole
  address instead of its host.
