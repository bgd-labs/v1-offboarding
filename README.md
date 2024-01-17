# V1 Deprecation PART1

This repository contains the upgraded `LendingPool` and `LendingPoolLiquidationManager` contract required for the V1 Deprecation as described on [the forum](https://governance.aave.com/t/temp-check-bgd-further-aave-v1-deprecation-strategy/15893).

To keep the changes simple & easily verifyable the following steps are taken:

1. the `LendingPool` is upgraded in order to:

   - disable flashloans, as all potential incentives for suppliers should be removed
   - deprecate the `receiveAToken` parameter on `liquidationCall` as for the offboarding it seem unnatural to allow it

2. the `LendingPoolLiquidationManager` is upgraded in order to:
   - remove the corresponding `receiveAToken` parameter on `liquidationCall` as, again, allowing to keep aTokens seems unnatural in the process of offboarding
   - the close factor is removed, as previously only liquidations for up to 50% were allowed, making some smaller liquidations unfeasible
   - in order to allow offboarding healthy collateral the `liquidationCall` method was altered to no longer revert when trying to liquidate healthy position, but instead just switch the liquidationBonus. With this change healthy positions can be liquidated with a fixed 1% liquidationBonus, while unhealthy position will use the liquidationBonus of the collateralAsset like before
     - while the changes to `liquidationCall` are limited, a new method `offboardingCalculateAvailableCollateralToLiquidate` was introduced which behaves analog to `calculateAvailableCollateralToLiquidate` but assumes the fixed 1% liquidationBonus and 100% close factor

As Aave V1 is quite old and deprecated for a while, we assume the amount of liquidation bots observing the pool is limited.
Therefore the changes were applied in a way that:

- does not disrupt existing bots
- allows existing bots to liquidate healthy positions with 0 changes (the only change is on identifying positions, the liquidation process itself is analog and performed with the same method as before)
