# Privacy Policy — hermes-agent

_Last updated: 2026-09-19_

This document exists because Google requires a privacy policy URL before an
OAuth application can be moved to production. It describes, accurately, what
the `hermes-agent` OAuth client does with Google account data.

## What this application is

A **personal, single-user** deployment of [Hermes Agent](https://github.com/NousResearch/hermes-agent)
(Nous Research), self-hosted on a private Kubernetes cluster owned and operated
by the owner of this repository.

It is not a commercial service. There is no sign-up, no public endpoint, and no
user base: the only person who authorizes it and the only person whose data it
touches are the same individual. The OAuth client is configured as *External*
solely because the underlying Google account is a personal one, which makes the
*Internal* audience type unavailable.

## What data is accessed

Only after an explicit OAuth consent granted by the account owner:

| Scope | Purpose |
| --- | --- |
| `gmail.readonly` | Read message metadata and content to identify what needs scheduling or attention |
| `calendar` | Read events to build a daily schedule; create and update events on the owner's own calendar |

The application requests these scopes to produce a "daily brief" — the day's
schedule, conflicts, meeting preparation, and mail that needs attention — and to
place the resulting events on the owner's calendar.

Additional scopes may appear in a consent screen because they are declared by the
upstream skill bundled with Hermes Agent. Any scope whose corresponding Google API
is not enabled on the Cloud project is inert.

## Where the data goes

- **Processing happens on hardware operated by the repository owner.** There is
  no intermediate server, no hosted backend, and no analytics of any kind.
- **OAuth credentials** (the client secret and the refresh token) are stored on a
  persistent volume inside that cluster. They are not present in this repository,
  in any form, encrypted or otherwise.
- **Message and calendar content is sent to the configured language model
  provider** in order to generate a response. This is the one case where data
  leaves the owner's infrastructure. At the time of writing that provider is a
  third-party API; the deployment is being migrated to a self-hosted model running
  on the owner's own network, after which no content leaves the premises. This
  section will be updated when that migration completes.

## What is not done

- No data is sold, rented, shared, or otherwise disclosed to any party other than
  the language model provider named above.
- No advertising, profiling, or tracking.
- No access is granted to anyone other than the account owner.
- Data is not used to train any model.

## Retention

Conversation history and derived state live on the cluster's persistent volume
for as long as the owner keeps them, and are deleted when that volume is deleted.
OAuth tokens persist until revoked.

## Revoking access

Access can be withdrawn at any time, and takes effect immediately:

- From the Google account: <https://myaccount.google.com/permissions>
- From the deployment itself, which also deletes the stored token:
  `setup.py --revoke`

## Contact

Via the issue tracker of this repository:
<https://github.com/streamixs/cluster/issues>
