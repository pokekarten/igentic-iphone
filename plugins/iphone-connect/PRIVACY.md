# Privacy in the local developer package

Two additional read-only B2B catalog tools serve only checked-in, public,
synthetic research descriptions from a bundled projection. They do not access
enterprise accounts, private repositories, customer records or remote APIs.
An unknown catalog slug is rejected; the model cannot use a slug as a file path.

The current phone tools return a fixed device alias, availability, fixed capability
names, counts, recognized public demo labels and bounded session/proposal
references. They do not return screenshots, arbitrary accessibility text, raw
subprocess errors, installed app inventories, device identifiers or credentials.

The local driver reads the permitted app's accessibility hierarchy into memory
to recognize the fixed navigation target. Raw values are discarded at the
adapter boundary; they are not written to project logs or returned as tool
content. Foreground identity is checked before and after observation. This does
not guarantee notification-free screen capture; screen capture is not exposed.

Session/proposal/result state is process-local. An exclusive lease containing
local process and session identifiers is held in a 0700 application-support
directory; its file is 0600. Device ID, app identity and executable paths remain
in the user's 0600 local configuration. Stop releases a completed session's
lease; restart cannot restore execution authority. A crash may leave the lease
for operator inspection.

ChatGPT receives the tool arguments/results selected for the conversation.
Using a local driver or a private tunnel does not make ChatGPT inference
offline. The plugin itself makes no model/provider API calls and enables no
paid fallback, telemetry service or account connection. The separately installed
MobileCLI may maintain its own operational state; consult its documentation and
terms independently. No analytics are added by iGentic.

This describes the implemented local developer package. It is not a privacy
policy for an unbuilt hosted multi-user service or a public directory listing.
