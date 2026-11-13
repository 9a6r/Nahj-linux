# Reused build cache: stale detached package signature

Local ISO07 stopped before package installation. The unchanged installer package
was already in the shared pacman cache with a detached signature from the
November 6 build. That key had expired, while ISO07's local repository had the
same package bytes signed with a fresh, trusted build key. Pacman preferred
the cached signature and tried to retrieve the expired key.

`build-iso.sh` now places its own local repository first in the generated
profile's `CacheDir` list. Its newly signed package/signature pairs take
precedence; existing caches remain available for official packages. Archiso
honors this explicit cache order. No shared cache was cleared, and signature
requirements remain enabled for both official and local packages.

## Actual pacman transaction checks

All three checks used `pacman -Sddw --noconfirm nahj-installer` with ISO07's
disposable sync database and the builder's trusted keyring. Download-only mode
checks package integrity without installing into the builder or host system.

| Case | Exit | Result |
| --- | --- | --- |
| Original cache order | 1 | Expired cached signature's key could not be retrieved |
| New cache order, same package and sync database | 0 | Keyring and package integrity checks pass |
| New cache order with an intentionally damaged signature in a disposable cache | 1 | Invalid signature rejected |

Retained outputs: [before](cache-signature-before.txt),
[after](cache-signature-after.txt), [invalid signature](cache-signature-invalid.txt).
The failed ISO07 build produced no ISO. A later fresh ISO09 build completed with
this correction; see the [artifact checks](../tests-2026-11-13/README.md).
These checks do not establish desktop performance or boot animation smoothness.
