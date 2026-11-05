# Disposable Windows capture probe

Synthetic experiment, not a released application. No recorder source, user details, recordings, contacts,
credentials or private data are included. This bundle tests a public FFmpeg
build against an animated test marker in a disposable Windows runner.

Run only in an explicitly authorized disposable test environment. Standard public runners are free under current GitHub terms.
Private runs consume included compute and may be billed; this file grants no
authority to spend credits or money. No remote access server is started.

Manually dispatch the workflow. It runs on Windows Server 2025, not on a user's
Windows11/old GPU. Check logs and inspect both screenshots/video. Success means
native WGC created changing frames in this runner only. It does not prove game
capture, WASAPI audio, real hardware performance or full-screen transitions.

The job downloads a checksum-pinned public FFmpeg ZIP, uses a moving test form,
records for 12 seconds, decodes the file and saves evidence for one day. Artifacts
may be visible with the repository's audience; do not run on a private desktop.

Viability is NOT confirmed. Current official runner image scripts disable some
per-user services but do not explicitly list CaptureService. That does not prove
an active interactive session or WGC availability. Preflight saves OS/session/
service metadata and refuses Session0/noninteractive/unavailable input desktop.
No service changes, impersonation, desktop bypass or remote access are attempted.
A passing preflight still requires actual WGC output and pixel inspection.
