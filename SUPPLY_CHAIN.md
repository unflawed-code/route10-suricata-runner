# Supply Chain Verification

This repo uses a lightweight SLSA Build L2 release posture for artifacts produced by the `Release Provenance` GitHub Actions workflow:

- CI runs shell syntax checks and hermetic tests.
- Tags matching `v*` build a release tarball from the exact Git commit.
- Release artifacts include `SHA256SUMS`.
- GitHub Actions generates Sigstore-backed SLSA provenance attestations for the tarball and checksums.

This does not claim SLSA Build L3. The goal is practical Build L2 provenance: users can verify that a release artifact was produced by this GitHub repository's hosted workflow for the tagged commit.

## Release Artifacts

For tag `vX.Y.Z`, the release workflow publishes:

```text
route10-suricata-runner-vX.Y.Z.tar.gz
SHA256SUMS
```

## Verify A Release

Install the GitHub CLI, then download and verify:

```bash
gh release download vX.Y.Z --repo unflawed-code/route10-suricata-runner
sha256sum -c SHA256SUMS
gh attestation verify route10-suricata-runner-vX.Y.Z.tar.gz --repo unflawed-code/route10-suricata-runner
```

The attestation should show that the artifact was produced by `unflawed-code/route10-suricata-runner` from the expected tag workflow.
