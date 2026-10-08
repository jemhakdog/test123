# SECURITY_RULES.md — Capstone Marketplace

> Zero-trust access control. SQLite has **no RLS**, so every rule here is enforced in code: server-side validation on every route + Next.js Server Actions + middleware route guards. The database layer adds constraints/checks as a last line of defense only.

## 1. Authentication

- Sessions: signed, HttpOnly, `Secure` in production, SameSite=Lax. 30-day expiry.
- Passwords: `bcrypt` with cost 12. Never stored in plaintext. No password length cap on hashing (only on input: min 8).
- Suspended users **cannot log in** (login rejects `is_suspended = 1`). Their listings are hidden from browse/discover.

## 2. Authorization Matrix (enforced at API layer)

| Operation | Guest | User | Admin |
|---|---|---|---|
| List / search / view approved listings | ✅ | ✅ | ✅ |
| View listing detail (incl. pending/rejected by owner) | ✅ (public only) | owner sees own pending/rejected | ✅ all |
| Create listing | ❌ 401 | ✅ → `pending` | ✅ → auto-`approved` |
| Edit listing | ❌ | ✅ owner only, not if `deleted` | ✅ any |
| Delete (soft) listing | ❌ | ✅ owner only | ✅ any |
| Send inquiry | ❌ 401 | ✅ (not own listing, not to suspended seller) | ✅ |
| Update inquiry (responded) | ❌ | ✅ seller of that listing only | ✅ |
| Create review | ❌ 401 | ✅ one per (user, listing); author not the seller | ✅ |
| Flag review | ❌ 401 | ✅ one per (user, review); cannot flag own review | ✅ |
| Follow / unfollow users | ❌ | ✅ (not self) | ✅ |
| Bookmark / unbookmark listings | ❌ | ✅ | ✅ |
| View own notifications | ❌ | ✅ | ✅ |
| View others' notifications | ❌ | ❌ 403 | ❌ 403 |
| View public profiles | ✅ | ✅ | ✅ |
| Suspend / restore user | ❌ | ❌ 403 | ✅ (not self) |
| Approve / reject / pin listing | ❌ | ❌ 403 | ✅ |

## 3. Social Feature Security Rules

### Follows (`follows` table)
- Self-follow blocked by DB CHECK constraint (`follower_id != following_id`) + server guard.
- Unauthenticated requests rejected by `getSession()` check.
- Follow/unfollow is fire-and-forget: no CSRF protection needed beyond session cookie (idempotent upsert).

### Bookmarks (`bookmarks` table)
- Ownership checked: user can only toggle bookmarks on their own account.
- Bookmark state persists across sessions via session cookie.

### Notifications (`notifications` table)
- **Read isolation**: user can ONLY fetch/modify rows where `user_id = session_user.id`. Cross-user notification reads return empty set or 401.
- **Write isolation**: actor cannot be notified about their own actions (`createActivityNotification` bails early when `userId === actorId`).
- Notification type enum restricted: `inquiry_received`, `inquiry_responded`, `review`, `follow`, `like`. Unknown types rejected by DB CHECK.
- Unread count is a simple COUNT query scoped to `user_id`; no client-side tampering possible since it runs server-side.

### Public Profiles
- Profile data (name, email, role, created_at) is visible to all logged-out guests — this is intentional for discoverability.
- A user cannot see their own follow status from another user's profile (requires auth).

## 4. Server-Side Validation (every accepted_attributes payload)

- All string lengths, ranges, enums per SCHEMA.sql `CHECK` constraints — mirrored in route validation.
- `price`: optional; must be a finite number ≥ 0; blank → `NULL`. No strings.
- `tags`: array of ≤ 8 unique strings, each 1–30 chars, lowercased/trimmed.
- `rating`: integer 1–5.
- Unknown/extra fields in payloads are **rejected**, never silently ignored.

## 5. Data Integrity Rules (enforced server-side)

- Listing visible to public only when `status = 'approved'`.
- Only the seller sees their own `pending`/`rejected` listings; Admin sees all.
- Creating a listing as Admin auto-approves it (`approved_at = now, approved_by = self`).
- No inquiry on own listing; no inquiry on deleted/suspended-seller listings.
- No review by the listing's seller on their own listing.
- Editing a listing resets it to `pending` if the content changed (MVP rule: keep moderation simple — content edits require re-approval).
- Deleting a listing sets `status='deleted'`; its inquiries/reviews become invisible (soft cascade: queries filter on listing status).
- Cascade deletes: deleting a listing removes its bookmarks and tags automatically (DB FK ON DELETE CASCADE).
- Following someone creates a `follow` notification targeting the followed user — but only if not self-follow.

## 6. Threat Model & Defenses

| Threat | Defense |
|---|---|
| SQL injection | Parameterized queries everywhere; no string-built SQL |
| Mass assignment / extra fields | Strict allow-list of `accepted_attributes` per route |
| XSS | React escapes by default; no `dangerouslySetInnerHTML` |
| CSRF | SameSite=Lax + Server Actions origin checks; state-changing routes require session |
| Brute force login | bcrypt cost 12 + per-IP rate limit (50/min) |
| Enumeration (email exists) | Generic error message on login/register |
| IDOR (edit other's listing) | Owner/role check server-side on every row operation |
| Price tampering | `price` validated as number ≥ 0; never trusted from client beyond that |
| Stored XSS via reviews/descriptions | Output escaping (React) + max length checks |
| Notification privacy leak | Query always scoped to `WHERE user_id = ?`; DB CHECK on type enum |
| Follow spam | Unique PK `(follower_id, following_id)` prevents duplicate follows |
| Bookmark enumeration | Bookmarks always queried with `WHERE user_id = ?` |

## 7. Sessions & Cookies

- `session` cookie: `HttpOnly`, `SameSite=Lax`, `Secure` when `NODE_ENV=production`, 30-day max-age, path `/`.
- Session store: signed cookie with secret from `AUTH_SECRET` env; invalid/expired → 401.
- Role is read from the DB on each request (never from the cookie alone) — a user suspended mid-session is rejected immediately.

## 8. Dark Mode

- Dark mode preference stored in `localStorage("theme")` — client-side only. No server security implications. Respects `prefers-color-scheme: dark` as fallback.

## 9. Admin Actions Audit

- Every admin action (approve/reject/suspend/restore/delete review) logs `{admin_id, action, target_id, at}` to `admin_audit_log` (table added at integration time if needed). MVP: log to the `listings.approved_by` / `updated_at` fields; full audit table is a future item.
