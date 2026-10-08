// E2E smoke test — real browser against the running Next server.
// Covers: register, login, create listing (pending), admin approve, browse, inquiry, review, flag, suspend.
// Run: node e2e.mjs  (server must be running on :3000)
import { chromium } from "playwright-core";
import { execSync } from "node:child_process";

const BASE = "http://localhost:3000";
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const uniq = Date.now().toString(36).slice(-6);

let failures = 0;
function check(name, cond) {
  console.log(`${cond ? "PASS" : "FAIL"}  ${name}`);
  if (!cond) failures++;
}

const browser = await chromium.launch();
const ctx = await browser.newContext();
const page = await ctx.newPage();
const logs = [];
page.on("console", (m) => m.type() === "error" && logs.push(m.text()));
page.on("pageerror", (e) => logs.push(String(e)));

try {
  // 1. Browse home shows seeded listings
  await page.goto(BASE);
  await page.waitForSelector("text=EduTrack Student Management", { timeout: 10000 });
  check("home lists seeded listings", true);
  check("price-on-request shown", await page.locator("text=Price on request").count() > 0);

  // 2. Guest visiting dashboard redirects to login
  await page.goto(`${BASE}/dashboard`);
  await page.waitForURL("**/login");
  check("guest /dashboard -> /login", true);

  // 3. Register a new buyer
  await page.goto(`${BASE}/register`);
  await page.fill("#name", `Tester ${uniq}`);
  await page.fill("#email", `t${uniq}@cap.test`);
  await page.fill("#password", "password123");
  await page.click('button[type="submit"]');
  await page.waitForURL("**/dashboard", { timeout: 10000 });
  check("register -> dashboard", true);

  // 4. Create a listing (goes pending)
  await page.click('text=+ New listing');
  await page.waitForURL("**/listings/new");
  await page.fill("#title", `E2E Project ${uniq}`);
  await page.fill("#description", "A fully working capstone project built with Next.js, Postgres and Tailwind for the E2E test suite.");
  await page.selectOption("#category_id", "1");
  await page.fill("#price", "250");
  await page.fill("#tags", "nextjs, e2e, demo");
  await page.click('button[type="submit"]');
  await page.waitForSelector("text=submitted for approval", { timeout: 10000 });
  check("listing created -> pending", true);

  // 5. As buyer, can't inquire on own listing
  await page.goto(`${BASE}/listings/1`);
  await page.waitForSelector("text=EduTrack Student Management");
  check("detail page loads", true);

  // 6. Buyer sends inquiry on Alice's listing
  await page.click("text=Request purchase");
  await page.fill("#message", "Hi, is this still available?");
  await page.click('text=Send inquiry');
  await page.waitForSelector("text=Inquiry sent", { timeout: 10000 });
  check("inquiry sent", true);

  // 7. Buyer posts a review
  await page.locator('button[aria-label="5 stars"]').click();
  await page.fill('textarea[name="comment"]', "Excellent project, very clean code.");
  await page.click('text=Post review');
  await page.waitForSelector("text=Review posted", { timeout: 10000 });
  check("review posted", true);
  check("review visible", await page.locator("text=Excellent project").count() > 0);

  // 8. Buyer flags Alice's review (the seeded one)
  await page.locator("text=Flag").first().click();
  await page.fill('textarea[name="reason"]', "Looks like spam");
  await page.click('text=Flag review');
  await page.waitForSelector("text=flagged for moderation", { timeout: 10000 });
  check("review flagged", true);

  // 9. Log out
  await page.click("text=Log out");
  await page.waitForURL("**/");
  check("logout", true);

  // 10. Admin: login, approve the pending listing
  await page.goto(`${BASE}/login`);
  await page.fill("#email", "admin@capstone.test");
  await page.fill("#password", "admin123");
  await page.click('button[type="submit"]');
  await page.waitForURL("**/dashboard", { timeout: 10000 });
  check("admin login", true);

  await page.goto(`${BASE}/admin`);
  await page.waitForSelector("text=Pending listings");
  check("admin panel loads", true);
  check("pending listing in queue", await page.locator(`text=E2E Project ${uniq}`).count() > 0);
  // Approve only THIS run's listing: the queue card is the one whose title
  // matches AND still has an Approve button (older approved runs have none).
  // Scope to the card element (rounded-xl border box), not the whole container.
  const cardSel = `.rounded-xl:has-text("E2E Project ${uniq}"):has(button:has-text("Approve"))`;
  const candidate = page.locator(cardSel).first();
  await candidate.locator('button:has-text("Approve")').click();
  await sleep(1000);
  const queueCount = await page.locator(cardSel).count();
  check("approved listing leaves pending queue", queueCount === 0);

  // 11. Approved listing appears on home (check BEFORE suspending its seller)
  await page.goto(BASE, { waitUntil: "networkidle" });
  await page.waitForTimeout(2000);
  const foundHome = await page.locator(`text=E2E Project ${uniq}`).count();
  check("approved listing appears on home", foundHome > 0);

  // 12. Suspended user can't log in
  await page.goto(`${BASE}/admin`);
  await page.waitForSelector("text=Users");
  await page.click(`tr:has-text("t${uniq}@cap.test") button:has-text("Suspend")`);
  await sleep(600);
  await page.click("text=Log out");
  await page.waitForURL("**/");
  await page.goto(`${BASE}/login`);
  await page.fill("#email", `t${uniq}@cap.test`);
  await page.fill("#password", "password123");
  await page.click('button[type="submit"]');
  await page.waitForSelector("text=account has been suspended", { timeout: 10000 });
  check("suspended user blocked from login", true);



  if (logs.length) {
    console.log("--- console errors ---");
    logs.slice(0, 5).forEach((l) => console.log(l));
  }
} catch (e) {
  console.log("FAIL  unexpected error:", e.message);
  failures++;
} finally {
  await browser.close();
}

console.log(failures === 0 ? "\nALL E2E CHECKS PASSED" : `\n${failures} CHECK(S) FAILED`);
process.exit(failures ? 1 : 0);
