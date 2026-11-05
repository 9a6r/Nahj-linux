# Installer password validation

The `nahj-installer` 3.3.14-3 package built successfully locally, including its
configuration schema checks, nine target-cleanup tests and all three native
Calamares account test suites. No GitHub workflow was dispatched.

Package SHA-256:
`03fc07386d8594f7408e1ebceaedd47c312a95192b170fd7db1855b328e6c0d7`.

## Reproduced problems and fixes

The previous installer allowed bypassing password requirements, including an
empty password. The original Vitreus greeter refuses to submit an empty
password. The installer now requires a matching password of 8–128 characters;
the original greeter is unchanged and the live account password remains `nahj`.

The installed libxcrypt accepts a 511-byte passphrase but returns the unusable
`*0` marker with ERANGE for 512 bytes. The previous Calamares code passed that
marker to `usermod`. A small patch against the pinned Calamares revision now
rejects NULL, empty or failure-marker hashes before modifying the account.
Embedded NUL is rejected in both configuration validation and the hash job,
preventing silent C-string truncation. The UI limit also leaves room for UTF-8
encoding; it counts Qt UTF-16 units, not bytes.

## Tests performed

The added native tests read the actual packaged `users.conf`, require weak
password bypass to be disabled, and exercise the real Config and SetPasswordJob
implementations. They reject empty, 7-character, 129-character, 512-character,
embedded-NUL and mismatched passwords. They accept 8- and 128-character ASCII,
128 Arabic characters, an Arabic phrase and a password containing quotes,
spaces, dollar signs and backticks. The backend regression uses a temporary
target and verifies the hash-failure error before any account modification.

The package check runs as the unprivileged builder with
`NAHJ_USERS_CONFIG` pointing to the actual config and
`QT_QPA_PLATFORM=offscreen`. All three account suites passed; the separately
retained detailed native run reports zero skipped cases, including both new
regressions. The nine Python target tests also passed in the final package
build. These tests do **not** establish successful end-to-end installation or
SDDM login with a newly created password: those remain required runtime tests.

## Current ISO provenance

Local ISO 04 completed successfully from `2caf2c2`, with the native BMP boot
frames and wallpaper service retry. Size: 3,584,294,912 bytes. SHA-256:
`4d131179dfa1ce253fcce178fa5e1c1e85e1cd75bc8333e7cc286c0ba6dbab8a`.
It contains installer 3.3.14-2, **not** the new password patch. The new installer
must be included in a fresh final image after runtime validation.

UEFI testing of ISO 04 with QEMU TCG, NVMe and experimental VirGL/Venus reached
a kernel panic screen. Its cause is under investigation. This is a failed boot,
not a passed UEFI or installation test. Physical GPU, VirtualBox, complete
installed-system boot and uninterrupted animation remain unverified.
