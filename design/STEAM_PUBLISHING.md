# Steam Publishing Guide — Hollow Township

> Research date: April 2026. Covers Steam Direct setup, Godot 4 integration, store requirements, pricing, discovery, and launch timeline.

---

## 1. Steam Direct Setup

**Cost**: $100 USD per app. Non-refundable upfront, but credited against first $1,000 in revenue.

**Revenue split**:
- 70/30 (you keep 70%) up to $10M lifetime revenue
- 75/25 above $10M
- 80/20 above $50M

### Godot 4 → Steamworks Integration

Use **GodotSteam** (GDExtension plugin). As of April 2026, version 4.18+ supports Godot 4.1–4.4+ and bundles Steamworks SDK 1.62.

Install via Godot Asset Library. Once added, `Steam` class is available in GDScript immediately.

**Critical rules**:
- Do NOT mix GDExtension with module-based GodotSteam versions
- Export using standard Godot Engine templates, not GodotSteam custom templates
- `Steam.steamInit()` must be called before any gameplay — if Steam is not running, game should degrade gracefully (no achievements, but playable)

### Legal Setup

Create Steamworks account under your legal entity name — must match bank and IRS documents exactly.

**Tax forms required**:
- **W-9** (U.S. citizens/entities): SSN or EIN
- **W-8BEN** (non-U.S. with tax treaty): Foreign TIN or U.S. EIN/ITIN

Non-U.S. developers: start W-8BEN immediately. Approval can add 1–2 weeks to your timeline.

---

## 2. Store Page Requirements

### Minimum Assets Required Before Going Live

| Asset | Spec |
|-------|------|
| Header capsule | 920×430 px — legible at 120×45 px (verify this) |
| Small capsule | 462×174 px |
| Screenshots | 5+ at 1280×720 or 1920×1080, gameplay only (no concept art, awards, marketing text) |
| Trailer | 16:9 MP4, ~60 seconds recommended |
| Short + long description | Required |
| Genre/tags | Required |
| Content rating | Required (ESRB/PEGI — can be placeholder, updated later) |

### Early Access Mandatory Q&A Section

Steamworks forces a buyer-visible Q&A section for Early Access. Must disclose:
- What is playable now (Chapter 1 content, estimated hours)
- What full 1.0 will include
- Why Early Access (community feedback, content roadmap)
- Estimated timeline to 1.0 (vague is fine: "12–18 months")

This is binding. Do not overpromise content scope here.

### What Can Be Added Later

- Additional screenshots/trailer
- Trading card artwork
- Community Hub setup
- Refined description copy

---

## 3. Build Submission

**Pipeline**:
1. Export Godot 4 as 64-bit Windows build (Linux/Mac optional, expands audience)
2. Upload via Steamworks Console → Builds → default branch
3. Valve review: **3–5 business days**
4. Submit at least **7+ days before planned release** to allow for iteration

**Horror/mature content**: Flag violent/dark themes in build submission notes. Valve rarely rejects clearly-labeled games but explicit flagging prevents delays.

**Common first-timer failures**:
- Build crashes on launch — test in Steam beta branch before submitting
- Missing `Steam.steamInit()` at startup
- Wrong depot config — Windows 64-bit must be the "default" depot

---

## 4. Early Access Pricing

**Benchmarks (2025–2026)**:
- $14.99–$19.99: saturated "indie sweet spot"
- $24.99–$29.99: viable with demonstrated depth (40+ hours claimed) and review score
- Comparable: Grounded 2 EA at $29.99; Path of Exile 2 at $20; Schedule I at $20

**For Hollow Township (Chapter 1, 3–4 hours)**:
- Do not price above $19.99 at Early Access launch for an unproven title
- Announce the 1.0 target price publicly ("Will increase to $X at launch")
- Buyer psychology: "I got in early" locks the purchase
- Price increases post-1.0 do not re-trigger purchase alerts for prior EA buyers

**Hard rule**: Launching at $39.99 as an unknown RPG drops conversion ~60% above $20.

---

## 5. Discovery Algorithm

### How Steam Visibility Works

Steam ranking formula: **(Engagement Rate × Traffic Volume) + Conversion Quality**

Conversion Quality = wishlist-to-purchase ratio + review score + avg playtime

**The single strongest lever**: click-through rate (CTR) on capsule art. High-CTR games get shown exponentially more. Capsule art is not decoration — it is the primary growth mechanism.

### Popular Upcoming Threshold

~7,000 wishlists accumulated within a compressed 2–4 week window triggers "Popular Upcoming" shelf placement. Once placed, algorithmic boost compounds.

### Launch Timing

- Avoid launching within 2 weeks of major AAA releases
- Tuesday/Wednesday outperforms Friday launches
- Early morning UTC (9–11 AM) allows 24-hour algorithm warm-up before U.S. peak evening traffic

### Press and Curator Keys

Generate 20–30 keys for indie game press and curators (not influencers — they rarely review indie EA). Early Access Curator groups (500K+ followers) can spike visibility meaningfully.

---

## 6. Timeline: Account to Launch

| Phase | Duration | Notes |
|-------|----------|-------|
| Steamworks account + tax forms | 1–2 weeks | Start immediately; non-U.S. may take longer |
| Store page creation + Valve review | 3–4 weeks | 3–5 business days review after submission |
| Coming Soon (mandatory minimum) | 2 weeks | Cannot be skipped; wishlist accumulation phase |
| Build submission + review | 1–2 weeks | Upload after store page approved |
| Launch | Day 0 | "Publish Now" after Coming Soon minimum elapses |

**Total realistic timeline: 6–8 weeks from Steamworks account created to live and selling.**

**Critical sequencing** (cannot be parallelized):
1. Store page reviewed and approved → then build submission opens
2. Coming Soon page live → build submission happens during this window
3. Build reviewed and approved + Coming Soon 2-week minimum elapsed → "Publish Now" available

**Marketing work** (parallelize with above): trailer production, press outreach, curator outreach — start 4–6 weeks before store page goes live, not after.

---

## 7. Wishlist Benchmarks

- Median wishlist-to-purchase conversion: ~27% in first month (high variance — 10× difference between top/bottom quartile)
- Wishlist-to-sales ratio is not predictive of long-term success
- Review score velocity matters more after month 1 than initial wishlist count
- 0.15× median conversion is the baseline reference for this genre

---

## Common First-Timer Trip-Ups

1. GodotSteam init timing — must precede all gameplay
2. Tax form delays — non-U.S. developers must start this first
3. Coming Soon minimum — cannot compress the 2-week window; plan for it
4. Capsule art not tested at 120×45 — use a preview tool before submitting
5. Price too high — $29.99 requires credibly showing 40+ hours of content
6. Overpromising in Early Access Q&A — this is binding; reviewers will hold you to it

---

## References

- Steamworks Direct: partner.steamgames.com/doc/gettingstarted/appfee
- GodotSteam: godotsteam.com
- Early Access docs: partner.steamgames.com/doc/store/earlyaccess
- Coming Soon docs: partner.steamgames.com/doc/store/coming_soon
- Store assets spec: partner.steamgames.com/doc/store/assets/standard
- Tax FAQ: partner.steamgames.com/doc/finance/taxfaq
