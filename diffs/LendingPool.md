```diff
diff --git a/etherscan/1_0x89A943BAc327c9e217d70E57DCD57C7f2a8C3fA9/LendingPool/src/contracts/UpdatedLendingPool.sol b/src/contracts/UpdatedLendingPool.sol
index ca33183..f84ef18 100644
--- a/etherscan/1_0x89A943BAc327c9e217d70E57DCD57C7f2a8C3fA9/LendingPool/src/contracts/UpdatedLendingPool.sol
+++ b/src/contracts/UpdatedLendingPool.sol
@@ -3504,6 +3504,58 @@ contract LendingPool is ReentrancyGuard, VersionedInitializable {
     emit Deposit(_reserve, msg.sender, _amount, _referralCode, block.timestamp);
   }
 
+  struct DebtPosition {
+    address user;
+    address debtAsset;
+    uint256 rateMode;
+  }
+
+  struct CollateralPosition {
+    address user;
+    address collateralAsset;
+    uint256 amount;
+  }
+
+  function batchSeizePosition(
+    CollateralPosition[] calldata collateralPositions,
+    DebtPosition[] calldata debtPositions
+  ) external {
+    for (uint256 i; i < collateralPositions.length; i++) {
+      uint256 amount = collateralPositions[i].amount == uint256(-1)
+        ? AToken(collateralPositions[i].collateralAsset).balanceOf(collateralPositions[i].user)
+        : collateralPositions[i].amount;
+
+      AToken(collateralPositions[i].collateralAsset).burnOnLiquidation(
+        collateralPositions[i].user,
+        amount
+      );
+      core.updateStateOnRedeem(
+        collateralPositions[i].collateralAsset,
+        collateralPositions[i].user,
+        amount,
+        false // disableing collateral is no longer necessary
+      );
+    }
+    for (uint256 i; i < debtPositions.length; i++) {
+      (, uint256 compoundedBorrowBalance, uint256 borrowBalanceIncrease) = core
+        .getUserBorrowBalances(debtPositions[i].debtAsset, debtPositions[i].user);
+
+      uint256 originationFee = core.getUserOriginationFee(
+        debtPositions[i].debtAsset,
+        debtPositions[i].user
+      );
+
+      core.updateStateOnRepay(
+        debtPositions[i].debtAsset,
+        debtPositions[i].user,
+        compoundedBorrowBalance,
+        originationFee,
+        borrowBalanceIncrease,
+        false // disabeling borrowing flag is no longer needed
+      );
+    }
+  }
+
   /**
    * @dev Redeems the underlying amount of assets requested by _user.
    * This function is executed by the overlying aToken contract in response to a redeem action.
```
