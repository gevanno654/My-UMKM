# SDD ledger — plan: docs/superpowers/plans/2026-11-22-restock.md

Pre-flight: tasks share Backend routes (T1) -> Drift (T2) -> provider (T3) -> UI (T4). Checked interfaces: POST body {id?, items:[{productId,qty,costPrice,sellPrice?}]} produced T1 consumed T3 via RestocksApi; DB methods saveRestockFull/voidRestock/history/dirty produced T2 consumed T3; restocksProvider state consumed T4. Naming consistent (Restocks/RestockItems/restocks/restock_items). No conflicts.

Task 1: complete (commit 6f90a6b, tests: npm test → 29/29, typecheck bersih).

Task 2: complete (commit ea2f0d4, tests: flutter test 102/102, analyze bersih).

Task 3: complete (commit a51ee11, tests: flutter test 115/115, analyze bersih).

Task 4: complete (commit 165f37e, tests: flutter test 120/120, analyze bersih).

Task 4b (fix uji HP 21 Nov): hapus opsi ubah-jual sementara dari draft
(restock v1 murni tambah stok + update harga beli), harga beli commit live
via onChanged + guard didUpdateWidget; tambah 3 widget test. Harga batch/FIFO
diputuskan jadi milestone v2 (bukan v1). Tests: flutter test 122/122,
analyze bersih.

Final review: belum (menunggu eksekusi Task 5 / uji HP).
