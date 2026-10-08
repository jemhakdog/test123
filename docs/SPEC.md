# Capstone Marketplace — SPEC.md

> Phase 1 + Phase 2 deliverable. All database schemas, pages, components, server actions, and API routes documented here. Changes in this file ripple through SCHEMA.sql, ui_layouts/, and api_routes/.

## 1. Objective

A **social-network-style marketplace** where students and developers buy, sell, and discover capstone (graduation) projects. Beyond the original listing/inquiry flow, users can follow each other, bookmark projects, browse trending content, engage in activity feeds, and communicate via notifications. All interactions are peer-to-peer — no payments processed on-platform.

## 2. Target Audience & MVP vs Future

| | Phase 1 (MVP) | Phase 2 (Built) | Future |
|---|---|---|---|
| **Discovery** | Category + tags + keyword search | Visual Discover grid (sorted by rating/trending), bookmarked collections | Recommendations engine, saved searches |
| **Social** | None | Activity feed dashboard, follow/unfollow system, bookmarks | Direct messaging, mentions, reels |
| **Trust** | Open reviews + ratings, flags | User profiles with stats (listings, followers, rating), community guidelines page | Verified purchases, seller verification badges |
| **Notifications** | None | Bell icon + dropdown + full notification page (inquiries, reviews, follows, likes) | Push notifications, real-time WebSocket events |
| **Info Pages** | None | About, FAQ, Help (with troubleshooting checklist) | Terms of Service, Privacy Policy |
| **UX** | Basic dashboard with listings table | Dark mode toggle, landing page hero, social media feel throughout | PWA support, offline caching |
| **Accounts** | Email+password auth, own profile edit | Public profile pages, follower counts, avatar initials | OAuth, 2FA, email verification |

## 3. Personas & Roles

- **Guest** — browse/discover listings, view listing details, read about/faq/help. Cannot inquire, review, follow, or bookmark.
- **User** — all Guest rights, plus: create/manage own listings, send purchase inquiries, leave one review per listing, flag reviews, bookmark/save projects, follow/unfollow users, view personal activity feed, manage own profile.
- **Admin** — all User rights, plus: approve/reject/pin/delete any listing, suspend/restore any user, delete any review, view moderation queue.

### Permission Matrix

| Action | Guest | User | Admin |
|---|---|---|---|
| Browse / search / view listing | ✅ | ✅ | ✅ |
| View public profile pages | ✅ | ✅ | ✅ |
| Create / edit / delete own listing | ❌ | ✅ | ✅ |
| Send purchase inquiry | ❌ | ✅ | ✅ |
| Review a listing (1 per listing) | ❌ | ✅ | ✅ |
| Flag a review | ❌ | ✅ | ✅ |
| Follow / unfollow users | ❌ | ✅ | ✅ |
| Bookmark / unbookmark listings | ❌ | ✅ | ✅ |
| View activity feed | ❌ | ✅ | ✅ |
| View / clear notifications | ❌ | ✅ | ✅ |
| Moderate listings (approve/reject/pin/delete) | ❌ | ❌ | ✅ |
| Suspend / restore users | ❌ | ❌ | ✅ |
| Delete any review | ❌ | ❌ | ✅ |
| View admin panel | ❌ | ❌ | ✅ |

## 4. Core User Journeys

1. **Seller lists a project**: register → login → `/dashboard` → click "+ Post" → fill title, description, category, tags, optional price → pending approval → admin approves → live → appears in Discover and followers' feeds.
2. **Buyer discovers & saves**: `/discover` → browse visual card grid → bookmark interesting projects via heart icon → return later at `/saved`.
3. **Buyer follows creators**: visit any public profile (`/profile/[id]`) → click "Follow" → that creator's new listings/reviews appear in the user's `/dashboard` activity feed.
4. **Buyer inquires**: on listing detail page → "Request Purchase" modal → message saved → seller notified → seller marks as "responded" on their dashboard.
5. **Buyer leaves review**: on listing detail after logged-in visit → stars (1-5) + comment → visible immediately → flaggable.
6. **Admin moderates**: `/admin` → pending listings queue → approve/reject; user list → suspend/restore; flagged reviews → remove.

## 5. Route Map

### Public Routes (no auth required)

| Route | Page | Access |
|---|---|---|
| `/` | Home (landing page) | All |
| `/discover` | Discover / browse grid | All |
| `/listings/[id]` | Listing detail page | All |
| `/listings/new` | New listing form | Authenticated only → redirect to /login |
| `/listings/[id]/edit` | Edit listing form | Owner or admin |
| `/profile/[id]` | Public user profile | All |
| `/about` | About page | All |
| `/faq` | FAQ page | All |
| `/help` | Help & Support page | All |
| `/login` | Login form | Redirect if already logged in |
| `/register` | Registration form | Redirect if already logged in |

### Authenticated Routes

| Route | Page | Access |
|---|---|---|
| `/dashboard` | Activity Feed (social feed) | Logged-in users only |
| `/saved` | Saved/bookmarked listings | Logged-in users only |
| `/notifications` | Full notification page | Logged-in users only |
| `/search/users` | Find people search | Logged-in users only |
| `/profile` | Edit own account profile | Logged-in users only |

### Admin Routes

| Route | Page | Access |
|---|---|---|
| `/admin` | Moderation panel | Admin only |

### API Routes

| Route | Method | Purpose |
|---|---|---|
| `/api/notifications` | GET | Fetch notifications JSON for dropdown |
| `/api/notifications` | POST | Mark all notifications as read |

## 6. Database Schema

### Tables (8 total)

1. **users** — `id, name (2-80), email (unique), password_hash, role (user/admin), is_suspended, created_at`
2. **categories** — fixed enum: `web-app, mobile-app, ml-ai, game, iot-embedded, data-analysis, other`
3. **listings** — `id, seller_id → users, category_id → categories, title (3-120), description (20-5000), price (nullable ≥0), status (pending/approved/rejected/sold/deleted), created_at, updated_at, approved_at, approved_by → users`
4. **listing_tags** — composite PK `(listing_id, tag)`, tag max 30 chars
5. **inquiries** — one per `(listing_id, buyer_id)`: `id, listing_id, buyer_id, message (1-2000), status (sent/responded), created_at, updated_at`
6. **reviews** — one per `(listing_id, author_id)`: `id, listing_id, author_id, rating (1-5), comment (1-2000), is_deleted (0/1), created_at`
7. **review_flags** — one per `(review_id, flagger_id)`: `id, review_id, flagger_id, reason (1-500), created_at`
8. **follows** — composite PK `(follower_id, following_id)`, CHECK `follower_id != following_id`, CASCADE DELETE both sides
9. **bookmarks** — composite PK `(user_id, listing_id)`, CASCADE DELETE both sides
10. **notifications** — `id, user_id, type (inquiry_received/inquiry_responded/review/follow/like), actor_id, entity_type, entity_id, is_read (0/1), created_at`

### Indexes

- `idx_listings_status_cat` — query pattern: filter by status + category
- `idx_listings_seller` — user dashboard: show seller's listings
- `idx_listings_created` — sort by newest
- `idx_inquiries_buyer` — sent inquiries timeline
- `idx_inquiries_listing` — received inquiries per listing
- `idx_reviews_listing` — reviews on a listing
- `idx_flags_review` — moderation: count flags per review
- `idx_notifications_user` — per-user notification ordering + read filtering
- `idx_notifications_actor` — reverse lookups by who triggered it
- `idx_follows_follower` — who does a user follow
- `idx_follows_following` — follower count for a user
- `idx_bookmarks_listing` — how many people bookmarked a listing

## 7. Business Rules & Edge Cases

- Listings are **not live until approved** by an admin (a listing created by an Admin is auto-approved).
- Listing states: `pending`, `approved`, `rejected`, `sold`, `deleted` (soft delete).
- Price is optional; blank = "Price on request". Stored as a real number when present, `NULL` otherwise.
- One review per (user, listing). Reviews are visible immediately; admins can delete; users can flag (flag count surfaces in admin queue).
- Inquiries: one per (buyer, listing) — duplicate sends update the existing message instead of creating rows. Seller can mark an inquiry as `responded`.
- Deleting a listing soft-deletes it and cascades (CASCADE DELETE) to its bookmarks and tags. Notifications survive independently.
- Tags are free-form lowercase, deduplicated per listing, capped at 8; stored in normalized `listing_tags` join table.
- Categories are a fixed enum in SCHEMA.sql.
- Suspended users: cannot log in, their listings are hidden from browse/discover.
- **Bookmark**: toggled ON/OFF. Bookmark presence shown with a filled/empty heart icon. Bookmarked items appear on `/saved` page.
- **Follow**: mutual independence — A following B doesn't mean B follows A. Self-follow blocked by CHECK constraint. Following someone creates a `follow` notification for them.
- **Notifications**: generated for inquiry_received (to seller), inquiry_responded (to buyer), new followers, and other engagement events. Not generated for own actions. Read state tracked per notification.

## 8. Server-Side Actions (Server Components)

| Action Function | Module | Behavior |
|---|---|---|
| `registerAction(prev, formData)` | actions.ts | Validates name/email/password → creates user → logs in → redirects to /dashboard |
| `loginAction(prev, formData)` | actions.ts | Validates credentials → sets session cookie → redirects to /dashboard |
| `logoutAction()` | actions.ts | Clears session cookie → redirects to / |
| `createListingAction(prev, formData)` | actions.ts | CRUD validation in transaction → INSERT listing + tags → revalidatePath / /dashboard |
| `updateListingAction(listingId, prev, formData)` | actions.ts | Ownership check → UPDATE + refresh tags → revalidate path |
| `deleteListingAction(listingId)` | actions.ts | Soft delete (status='deleted') → revalidate paths |
| `createInquiryAction(prev, formData)` | actions.ts | Upsert inquiry (ON CONFLICT update) → revalidatePath /dashboard |
| `respondInquiryAction(formData)` | actions.ts | Seller marks inquiry 'responded' → revalidatePath /dashboard |
| `createReviewAction(prev, formData)` | actions.ts | INSERT review (conflict = already reviewed) → revalidatePath |
| `flagReviewAction(reviewId, prev, formData)` | actions.ts | INSERT flag row (conflict = already flagged) → revalidatePath |
| `moderateListingAction(formData)` | actions.ts | Admin-only: approve/reject listing |
| `toggleSuspendAction(formData)` | actions.ts | Admin-only: flip is_suspended for target user |
| `adminDeleteReviewAction(formData)` | actions.ts | Admin-only: soft-delete review (is_deleted=1) |
| `updateProfileAction(prev, formData)` | actions.ts | Update name and/or password with bcrypt hashing |
| `toggleFollowAction(followingId)` | actions.ts | INSERT OR DELETE from follows table → revalidate profile + dashboard |
| `toggleBookmarkAction(listingId)` | actions.ts | INSERT OR DELETE from bookmarks table → revalidate listing + /saved |
| `markNotificationsReadAction(prev, formData)` | actions.ts | Set is_read=1 for all of current user → revalidate /notifications |

## 9. Query Functions

### Catalog Queries
- `searchListings(p)` — filters by query/category/tag/sort/page, returns `{listings, total}`
- `getListingById(id)` — single listing with seller info, review avg/count
- `getReviewsForListing(listingId)` — all visible reviews for a listing
- `listCategories()` — all categories ordered by label

### Dashboard Queries
- `getMyListings(userId)` — user's own listings
- `getInquiriesForUser(userId)` — received + sent inquiries merged by date

### Social Feature Queries
- `getActivityFeed(userId, page, pageSize)` — UNION ALL of: (a) followed users' listings, (b) followed users' reviews, (c) user's own listings. Returns enriched items with actor info, category, pricing.
- `searchUsers(query, excludingUserId?)` — fuzzy search by name/email, sorted by followers then listing count
- `getUserProfile(userId)` — aggregated stats: listing_count, review_count, avg_rating, followers, following, isFollowing flag
- `getListingsBySeller(sellerId)` — approved listings for a specific seller (public profile grid)
- `toggleFollow(followerId, followingId)` — upsert into follows, generates `follow` notification
- `isFollowing(followerId, followingId)` — boolean check
- `getBookmarks(userId)` — user's saved/listed bookmarks
- `toggleBookmark(userId, listingId)` — upsert into bookmarks
- `isBookmarked(userId, listingId)` — boolean check
- `getNotifications(userId, limit=30)` — fetched joined with actor names and related entities
- `markAllNotificationsRead(userId)` — bulk set is_read=1
- `getUnreadNotificationCount(userId)` — COUNT for badge display
- `createActivityNotification(...)` — low-level insert guard against self-notifications

### Admin Queries
- `adminListListings(status?)` — all listings filtered by optional status
- `adminListUsers()` — all users for moderation
- `adminFlaggedReviews()` — reviews grouped by flag count with flag details

## 10. TypeScript Types

All domain types in `app/src/lib/types.ts`:
`User`, `Category`, `ListingStatus`, `Listing`, `ListingCard`, `ListingDetail`, `Review`, `Inquiry`, `FollowCounters`, `Notification`, `FeedItem`, `UserSearchResult`, `AdminUser`, `FlaggedReview`

## 11. Acceptance Criteria

### Phase 1 (Original MVP)
- [x] Register/login/logout with sessions; role checks enforced server-side on every route and API call
- [x] Listing CRUD with validation; approval workflow visible to seller ("pending" badge)
- [x] Browse with category filter, tag filter, keyword search, price sort
- [x] Inquiry flow creates/updates inquiry; seller sees it in dashboard
- [x] Reviews with star average shown on listing; one per user; flag + admin delete
- [x] Admin panel: pending queue, listing moderation, user suspend, review removal
- [x] All forms validated client- and server-side against SCHEMA.sql constraints
- [x] Seed script creates demo users, categories, listings, reviews

### Phase 2 (Social Network Layer)
- [x] Activity feed dashboard (/dashboard) showing posts from followed users + own activity
- [x] Follow/unfollow system with DB-backed relationship (follows table)
- [x] Bookmarks/saved listings (bookmarks table) with dedicated /saved page
- [x] Notification system (bell icon + dropdown + full page) — inquiry, review, follow, like events
- [x] User discovery/search (/search/users) by name/email with stats
- [x] Enhanced Discover grid (/discover) sorted by rating/trending
- [x] Public profile pages (/profile/[id]) showing avatar, stats grid, follower count, project listings
- [x] Informational pages: About (/about), FAQ (/faq), Help (/help)
- [x] Landing page redesign (/) with hero section, inline search, category pills, trending grid, feature strip
- [x] Dark mode toggle persisted via localStorage
- [x] All builds compile cleanly (zero TypeScript errors)
- [x] All 23 routes registered and accessible
- [x] Nav bar restructured with Discover, Saved, People, About, Feed links + dark mode toggle + notification bell
