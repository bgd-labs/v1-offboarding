# V1 Deprecation PART3

This repository contains the upgraded `Pool` contract required for the V1 Deprecation PHASE 3 as described on [the forum](https://governance.aave.com/t/temp-check-bgd-further-aave-v1-deprecation-strategy/15893/7).

Phase 3 performs the following actions:

- set the static Liquidation bonus from 3% to 5%
- disable liquidations with per asset LBs
- update the lendingPoolCore to update the index and current rate on IR changes
- replace the interest rates of all assets with a zero IR
- disable all POOL functions apart of `liquidationCall`, `repay` and `withdraw`

The Proposal itself will inject funds into the CORE so people will be able to withdraw even on reserves with active borrow positions.

- see [HERE](https://github.com/bgd-labs/v1-offboarding/tree/005cdb3f1db358f6aa3b71d59b218b12301e825e) for PART1
- see [HERE](https://github.com/bgd-labs/v1-offboarding/tree/3c5023174844a9c4de98e4d0889e489970a1b5b3) for PART2
