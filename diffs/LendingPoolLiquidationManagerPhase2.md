```diff
diff --git a/etherscan/1_0x1a7Dde6344d5F2888209DdB446756FE292e1325e/LendingPoolLiquidationManager/src/contracts/UpdatedLendingPoolLiquidationManager.sol b/src/contracts/UpdatedLendingPoolLiquidationManager.sol
index b7ec277..ecd3882 100644
--- a/etherscan/1_0x1a7Dde6344d5F2888209DdB446756FE292e1325e/LendingPoolLiquidationManager/src/contracts/UpdatedLendingPoolLiquidationManager.sol
+++ b/src/contracts/UpdatedLendingPoolLiquidationManager.sol
@@ -5870,7 +5870,7 @@ contract LendingPoolLiquidationManager is ReentrancyGuard, VersionedInitializabl
   IFeeProvider feeProvider;
   address ethereumAddress;
 
-  uint256 constant OFFBOARDING_LIQUIDATION_BONUS = 101; // 1%
+  uint256 constant OFFBOARDING_LIQUIDATION_BONUS = 103; // 1%
 
   /**
    * @dev emitted when a borrow fee is liquidated
@@ -5945,7 +5945,7 @@ contract LendingPoolLiquidationManager is ReentrancyGuard, VersionedInitializabl
    * of the LendingPool contract, the getRevision() function is needed.
    */
   function getRevision() internal pure returns (uint256) {
-    return 1;
+    return 2;
   }
 
   /**
```
