# Firestore security-rules tests

These test `mobile/firestore.rules` against the **local Firestore emulator only**. They use the `demo-quit-companion` project id, so they never touch the real Firebase project and need no credentials.

Requirements: Node 18+, Java 11+, Firebase CLI (`firebase --version`).

```bash
cd mobile/test/firestore_rules
npm install        # first time; node_modules/ is git-ignored here
npm test           # starts the emulator, runs rules.test.mjs, stops it
```

The `PERMISSION_DENIED` log lines are expected: they are the writes the tests assert are rejected.

If you see "port 8080 taken", an emulator from an earlier run is still alive. Stop that `java ... cloud-firestore-emulator` process and run the tests again.

Current coverage (FR10 community validation) is described at the top of `rules.test.mjs`.

On Windows the Firebase CLI can leave the emulator's Java process running even after a successful `npm test`. Afterwards, check that nothing is listening on port 8080, and stop any leftover `cloud-firestore-emulator` process.
