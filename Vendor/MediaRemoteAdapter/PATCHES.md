# Local patches

Vendored from https://github.com/ungive/mediaremote-adapter at the commit in `UPSTREAM_COMMIT`.
The test client (`src/test`, except the header `test.m` imports) is left out.

- `src/adapter/stream.m`: `watchParent()` exits the adapter when the launching process dies,
  so a crashed or force-quit app does not leave an orphaned `perl` stream behind.
