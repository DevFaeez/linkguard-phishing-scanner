# Privacy notes

These notes describe the research prototype's current behavior; there is no hosted account
service or published app-store release.

## On-device checks

Manual scans use the local Dart model by default. Camera QR frames are decoded in memory and
the camera is released on exit, backgrounding or detection. Gallery QR uses Android's selected-
image picker; temporary private-cache copies are cleaned after reading/error and startup
recovery. Original gallery images are untouched. QR links require confirmation and are checked
on-device, even after a manual server session. Non-web payloads are not executed.

Clipboard is read only after an explicit paste action. Android Share supplies only text the
user chooses to share. URLs and results are held in memory, not saved as browsing history.

## Notification monitoring

Monitoring starts off and requires in-app consent, notification access and warning permission.
The initial all-app selection is disclosed and can be narrowed. Selecting no apps pauses it.
Readable notification text is processed by a headless on-device Dart engine. A bounded temporary
hash cache suppresses repeats. No raw notification text, sender or URL history is persisted or
sent to a server. Warnings omit URLs and message content and are hidden on the lock screen.
Users can pause monitoring or revoke Android access.

## Optional server mode

Manual server mode requires explicit session consent before sending a complete URL, which may
contain private tokens, to the configured server. Notifications and QR never use that path.
The included Python launcher binds to loopback and disables access logs; it does not fetch or
persist submitted destinations. A separately hosted server/proxy needs its own privacy review.

## Stored preferences and limits

Language, monitoring consent, source-app selection and setup progress are stored locally.
An interrupted system image picker may keep temporary selection metadata for recovery.
Android backup/cloud/device-transfer are excluded. There is no app analytics exporter, account
system or advertising SDK. Source/font/data licenses and attribution are retained.

Model results may be wrong. Android can hide text, disconnect listeners or suppress alerts.
Force stop and manufacturer battery behavior prevent a guarantee of continuous monitoring.
