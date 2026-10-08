# Capstone Marketplace

A schema-first full-stack marketplace where students and developers buy and sell capstone projects. Built with Next.js (App Router) + SQLite.

## Contract-first process

The entire app is derived from locked contract files — no field, route, or rule exists in code that isn't in these:

| Artifact | Purpose |
|---|---|
| `docs/SPEC.md` | Approved scope, personas, permission matrix, business rules |
| `db/SCHEMA.sql` | Source of truth: tables, types, constraints, indexes, seed |
| `docs/SECURITY_RULES.md` | Zero-trust access control (API-layer enforced; SQLite has no RLS) |
| `ui_layouts/*.json` | One JSON per screen: elements mapped to `table.column`, API route targets |
| `api_routes/*.json` | One JSON per route group: accepted_attributes, DB ops, responses |

## Features

### Core Marketplace (Phase 1)
- **Roles**: Guest / User / Admin with server-enforced permission matrix
- **Listings**: create → pending → admin approve/reject → live; optional price ("Price on request"), free-form tags, category taxonomy
- **Discovery**: keyword search, category filter, tag filter, price/date/rating sort
- **Inquiry buying**: buyers message sellers (1 inquiry per buyer per listing, upsert); sellers mark responded
- **Reviews**: open reviews, 1 per user per listing, star average; users can flag; admins delete
- **Admin panel**: moderation queue, user suspend/restore, flagged review removal

### Social Network Layer (Phase 2)
- **Activity Feed Dashboard** (`/dashboard`): social-media-style feed showing listings + reviews from followed users merged with own activity
- **Follow System**: follow/unfollow other users, with follower/following counts and notification generation
- **Bookmarks/Saved**: save favorite listings via heart icon, view all saved at `/saved`
- **Notifications** (`/notifications` + bell badge in navbar): real-time badge count, dropdown preview, full page — events for inquiries, reviews, follows, likes
- **Discover Grid** (`/discover`): Instagram-style visual card grid sorted by rating/trending
- **Public Profiles** (`/profile/[id]`): avatar, stats grid (projects/followers/following/rating), their project listing grid
- **User Search** (`/search/users`): find people by name/email with stats, role badges, follow buttons
- **Info Pages**: About (`/about`), FAQ (`/faq`) with expandable Q&As, Help & Support (`/help`) with troubleshooting
- **Dark Mode**: toggle button in navbar, persisted via localStorage, respects system preference as fallback
- **Landing Page** (`/`): hero section with gradient, inline search, category pills, trending projects grid, feature strip, CTA footer

### Security
- bcrypt (cost 12), signed HttpOnly sessions, suspended-user blocking, soft deletes, parameterized queries, strict server-side validation, IDOR checks
- Notification privacy: users can only read/modify their own notifications
- Follow spam prevention: unique PK constraint prevents duplicate follows
- Dark mode preference stored client-side only (localStorage)

## Run

```bash
cd app
npm install
npm run seed     # demo data (idempotent)
npm run dev      # or: npm run build && npm run start
```

Open http://localhost:3000

### Demo accounts

| Role | Email | Password |
|---|---|---|
| Admin | admin@capstone.test | admin123 |
| Seller | alice@capstone.test | password123 |
| Seller | bob@capstone.test | password123 |
| Buyer | carol@capstone.test | password123 |
| Buyer | dave@capstone.test | password123 |

## Test

```bash
npm run build && npm start   # server on :3000
node ../e2e.mjs              # 17-step browser E2E (register → list → approve → buy → review → flag → suspend)
```

## Routes

### Public
| Route | Page |
|---|---|
| `/` | Landing page (hero, trending, features) |
| `/discover` | Visual browse grid (sorted by rating) |
| `/listings/[id]` | Listing detail with bookmark button |
| `/profile/[id]` | Public user profile |
| `/about` | About the platform |
| `/faq` | Expandable FAQ accordion |
| `/help` | Help center with troubleshooting |
| `/login`, `/register` | Auth forms |

### Authenticated
| Route | Page |
|---|---|
| `/dashboard` | Activity feed (social feed) |
| `/saved` | Bookmarked/saved listings |
| `/notifications` | Full notification history |
| `/search/users` | Find people |
| `/profile` | Edit own account |
| `/listings/new` | Create new listing |
| `/listings/[id]/edit` | Edit existing listing |

### Admin
| Route | Page |
|---|---|
| `/admin` | Moderation dashboard |

### API
| Route | Method | Purpose |
|---|---|---|
| `/api/notifications` | GET | Fetch JSON notifications |
| `/api/notifications/read` | POST | Mark all as read |

## Database Tables (10)

`users` · `categories` · `listings` · `listing_tags` · `inquiries` · `reviews` · `review_flags` · **`follows`** · **`bookmarks`** · **`notifications`**

Bold = Phase 2 additions.

## Structure

```
docs/
  SPEC.md              Scope, personas, routes, permissions, business rules
  SECURITY_RULES.md    Zero-trust access control (API-layer enforced)
db/SCHEMA.sql          All 10 tables, constraints, indexes, seed data
ui_layouts/            Screen contracts (17 JSON files)
  landing_layout.json         Home/landing page
  discover_layout.json        Discover browse grid
  dashboard_feed_layout.json  Social feed dashboard
  saved_layout.json           Saved/bookmarks page
  notifications_layout.json   Notification page
  search_users_layout.json    User search page
  public_profile_layout.json  Profile/[id] page
  about_layout.json           About page
  faq_layout.json             FAQ accordion
  help_layout.json            Help center
  listing_detail_layout.json  Single listing view
  listing_form_layout.json    Create/edit form
  browse_layout.json          Legacy (deprecated)
  dashboard_layout.json       Legacy dashboard
  profile_layout.json         Legacy profile edit
  admin_layout.json           Admin panel
  auth_layout.json            Login/register
api_routes/
  social_routes.json          Follows, bookmarks, notifications, feed, search
  listings_routes.json        CRUD + search listings
  inquiries_routes.json       Inquiry flow
  reviews_routes.json         Review + flag flow
  auth_routes.json            Register/login/logout
  admin_routes.json           Moderation
  users_routes.json           User management
app/                         Next.js App Router
  src/lib/
    db.ts                    SQLite connection (better-sqlite3)
    auth.ts                  Session management (HttpOnly cookies)
    validate.ts              Field-level validators
    types.ts                 Shared TypeScript interfaces (18+ types)
    queries.ts               Read functions (~520 lines, ~30 functions)
    actions.ts               Server actions (~420 lines, ~20 functions)
  src/app/
    api/notifications/       REST endpoints for notification bell
    [23 pages total]
  src/components/
    Nav.tsx                  Updated nav with dark mode + notif bell
    BookmarkButton.tsx       Client-side bookmark toggle
    FollowButton.tsx         Client-side follow toggle
    NotificationBell.tsx     Dropdown notification preview
    ListingCardGrid.tsx      Visual card grid component
    DarkModeToggle.tsx       Theme switcher
    [9 additional components]
  scripts/seed.ts            Demo data (5 users, 7 categories, listings, reviews, inquiries)
  data/app.db                SQLite database (gitignored)
e2e.mjs                      Browser E2E smoke tests
```

## Development

```bash
cd app
npm install
npm run seed     # demo data (idempotent) - required after DB reset
npm run dev      # Turbopack dev server on localhost:3000
```

Or build for production:
```bash
npm run build && npm start
```

### Demo accounts

| Role | Email | Password |
|---|---|---|
| Admin | admin@capstone.test | admin123 |
| Seller | alice@capstone.test | password123 |
| Seller | bob@capstone.test | password123 |
| Buyer | carol@capstone.test | password123 |
| Buyer | dave@capstone.test | password123 |

## Test

```bash
npm run build && npm start   # server on :3000
node ../e2e.mjs              # browser E2E smoke test
```

## Notes

- **DB resets needed when**: adding new tables via SCHEMA.sql. The engine uses `CREATE TABLE IF NOT EXISTS` which silently skips existing tables. Delete `app/data/app.db` to rebuild from the updated schema, then re-run `npm run seed`.
- SQLite has no RLS, so SECURITY_RULES.md is enforced at the API/action layer (parameterized queries + server-side role/ownership checks).
- Dark mode persists in `localStorage("theme")`; defaults to system `prefers-color-scheme`.
- Delivery of project files happens outside the platform (per approved scope) — no payments, no file storage.
- `AUTH_SECRET` env var should be set in production (dev falls back to a hardcoded value).
