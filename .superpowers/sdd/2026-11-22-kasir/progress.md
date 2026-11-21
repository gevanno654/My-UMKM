# SDD ledger — plan: docs/superpowers/plans/2026-11-22-kasir.md

- Setup: worktree `feat/kasir-v1` @ b47900c, BASE=ab1d810 (docs plan).
- Pre-flight: Task 1 (backend sales) ↔ Task 3 (sync push/pull): Task 3 consumes `POST /api/v1/sales` body `{id?, items:[{productId?, name, price, qty}], paid, method}` + error codes (`insufficient stock` 409, nomor duplikat 409, paid<total 400). Task 1 produces exactly that. No conflict.
- Pre-flight: Task 2 (Drift Sales/SaleItems/CartLines, schema v3) ↔ Task 3 (SalesNotifier): Task 3 consumes `checkoutSale`, `voidSale`, `getCartLines`/`upsertCartLine`/`removeCartLine`/`clearCart`, `nextReceiptSeq`, `markSalesClean`, `dirtySales`, `upsertSaleFromServer`, `replaceSaleItems`, `salesHistory`, `saleItemsOf`. Task 2 produces those names. No conflict.
- Pre-flight: Task 3 ↔ Task 4 (UI): Task 4 consumes `salesProvider`, `SalesState(cartLines,total,syncStatus,history,lastError)`, `checkout({paid,method}) → receiptNumber?`, `voidSale(id,reason)`. Names locked here. No conflict.
- Pre-flight: scan-kasir reuse — Task 4 checks ScanScreen args; fallback to manual search + follow-up note if unsupported. Ruling deferred to Task 4.

Task 1: complete (commits ab1d810..89b6e65, tests: npm test -> 22/22 PASS, typecheck bersih)
Task 2: complete (commits 89b6e65..5f74b27, tests: flutter test -> 77/77 PASS incl 6 sales_local, analyze bersih)
Task 3: complete (commits 5f74b27..829b93d, tests: flutter test -> 91/91 PASS incl 14 sales, analyze bersih)
Task 4: complete (commits 829b93d..67bae7a, tests: flutter test --concurrency 1 -> 95/95 PASS, analyze bersih)
Task 4 Ruling: scan-kasir reuse ScanScreen via context.push<String>('/products/scan') � didukung (pop barcode). Tidak perlu follow-up.
