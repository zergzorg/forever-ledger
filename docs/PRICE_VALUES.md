# Own-history price values

Opt-in groundwork for the redesign. No saved-data migration, group/rule data or
existing valuation caller changes. These values describe one item ID across all
versions in one market. They are unit prices before the auction cut/deposit;
`cheapest` is not a quote for buying a quantity. Quantity-aware crafting will use
the listing ladders separately.

## Interface

`ns:PriceValues(itemID, marketKey)` reads one market (current market if omitted).
It returns a fresh table, does not create saved tables and does not query another
addon's prices. Synced own-scan observations already in that market still count.

| Field | Meaning |
|---|---|
| `cheapest` | Fresh own-scan minimum unit buyout, not its 20-unit average |
| `listed` | Fresh own-scan quantity; 0 means observed empty, nil means unknown |
| `lastSeen`, `stale` | Own observation timestamp and whether it exceeds the configured price age |
| `usual` | Robust weighted mean of daily typical prices over 14 completed local days |
| `recent` | Equal-day mean over 3 completed local days |
| `longTerm` | Robust equal-day mean over 60 completed local days |
| `usualDays`, `recentDays`, `longTermDays` | Retained observations in each mean |
| `usualDropped`, `recentDropped`, `longTermDropped` | Rejected observations in each window |
| `sellsPerDay` | Inferred units sold per 1,440 observed minutes, or nil for insufficient evidence |
| `saleUnits`, `saleMinutes` | Evidence behind the estimate over 30 calendar days including today |

Nil historical prices are unknown; no current-price or weekly fallback is
invented. A historical price can still be known when current listings are stale.
Current `none` observations return `listed = 0` only while fresh. Missing/future
timestamps and imported Auctionator/TSM/Auctioneer observations are not current
own-scan values. The configured maximum age defaults to 12 hours, inclusive.

Pure functions, with all clocks supplied by the caller:

- `ns.PriceHistoryValues(dailyString, soldString, localDay, vendorChangeDay)`
- `ns.PriceCurrentValues(priceRecord, nowSeconds, maxAgeSeconds)`

Inputs are borrowed, never mutated. Invalid entries are skipped; the last valid
entry for a duplicate day wins. The adapter reads `history`, `historySold2`,
`prices` and `vendorSellChanged` only. It captures the market once and never
calls `marketTable`, so asking about an unscanned market does not save anything.

## Calculation choices

Historical prices use the saved daily typical: the last recorded average of the
cheapest 20 units that day. The daily minimum is not a representative price, and
the historic listing ladder cannot be reconstructed from this summary. Today is
excluded because it is unfinished. Days before a recorded vendor-price change
are excluded, following existing pricing's protection against changed game prices.
The daily history retains 90 days, so the 60-day window needs no weekly approximation.

Usual weights use calendar age, not sample order: yesterday has weight 14;
fourteen days ago has weight 1. Missing days contribute neither zero nor weight.
Recent and long-term use equal weights. With at least five observations in a
window, compute the median (mean of middle two for even counts) and median
absolute deviation (MAD). Keep observations within
`max(3 * 1.4826 * MAD, 0.5 * median)` of the median. The 50% floor tolerates
ordinary movement in a flat market where MAD is zero; isolated very high and low
prices still drop. Fewer than five observations are kept without guessing
outliers. Prices round once to the nearest copper after averaging.

Sells/day follows the existing sell-speed evidence guards: at least 180 minutes
observed and either three units gone or a full 1,440 minutes observed. An explicit
zero needs at least 720 minutes observed. Gaps are not assumed watched. Expired,
future and malformed days are excluded. This measures inferred disappearances
that could not have expired, not confirmed sales or a guaranteed craft-sales cap.

The released `UsualPrice`, `PriceStats`, `SellSpeed` and their current callers keep
their behavior. Integration should choose new callers explicitly and use the
sample/evidence fields when presenting a thin market. Build snapshots, new sharing,
version-specific history and the quantity-aware craft solver are separate work.
