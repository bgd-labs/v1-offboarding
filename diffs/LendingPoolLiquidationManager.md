```diff
diff --git a/etherscan/1_0x31cceeb1fA3DbEAf7baaD25125b972A17624A40a/LendingPoolLiquidationManager/Contract.sol b/src/contracts/UpdatedLendingPoolLiquidationManager.sol
index 0490cd7..858da42 100644
--- a/etherscan/1_0x31cceeb1fA3DbEAf7baaD25125b972A17624A40a/LendingPoolLiquidationManager/Contract.sol
+++ b/src/contracts/UpdatedLendingPoolLiquidationManager.sol
@@ -5870,7 +5870,7 @@ contract LendingPoolLiquidationManager is ReentrancyGuard, VersionedInitializabl
   IFeeProvider feeProvider;
   address ethereumAddress;
 
-  uint256 constant LIQUIDATION_CLOSE_FACTOR_PERCENT = 50;
+  uint256 constant OFFBOARDING_LIQUIDATION_BONUS = 101; // 1%
 
   /**
    * @dev emitted when a borrow fee is liquidated
@@ -5945,16 +5945,16 @@ contract LendingPoolLiquidationManager is ReentrancyGuard, VersionedInitializabl
    * of the LendingPool contract, the getRevision() function is needed.
    */
   function getRevision() internal pure returns (uint256) {
-    return 0;
+    return 1;
   }
 
   /**
-   * @dev users can invoke this function to liquidate an undercollateralized position.
+   * @dev users can invoke this function to liquidate an any collateral position.
    * @param _reserve the address of the collateral to liquidated
    * @param _reserve the address of the principal reserve
    * @param _user the address of the borrower
    * @param _purchaseAmount the amount of principal that the liquidator wants to repay
-   * @param _receiveAToken true if the liquidators wants to receive the aTokens, false if
+   * @param _receiveAToken DEPRECATED not used anymore
    * he wants to receive the underlying asset directly
    **/
   function liquidationCall(
@@ -5969,13 +5969,6 @@ contract LendingPoolLiquidationManager is ReentrancyGuard, VersionedInitializabl
 
     (, , , , , , , vars.healthFactorBelowThreshold) = dataProvider.calculateUserGlobalData(_user);
 
-    if (!vars.healthFactorBelowThreshold) {
-      return (
-        uint256(LiquidationErrors.HEALTH_FACTOR_ABOVE_THRESHOLD),
-        'Health factor is not below the threshold'
-      );
-    }
-
     vars.userCollateralBalance = core.getUserUnderlyingAssetBalance(_collateral, _user);
 
     //if _user hasn't deposited this specific collateral, nothing can be liquidated
@@ -6012,19 +6005,21 @@ contract LendingPoolLiquidationManager is ReentrancyGuard, VersionedInitializabl
     }
 
     //all clear - calculate the max principal amount that can be liquidated
-    vars.maxPrincipalAmountToLiquidate = vars
-      .userCompoundedBorrowBalance
-      .mul(LIQUIDATION_CLOSE_FACTOR_PERCENT)
-      .div(100);
+    vars.maxPrincipalAmountToLiquidate = vars.userCompoundedBorrowBalance;
 
     vars.actualAmountToLiquidate = _purchaseAmount > vars.maxPrincipalAmountToLiquidate
       ? vars.maxPrincipalAmountToLiquidate
       : _purchaseAmount;
 
-    (
-      uint256 maxCollateralToLiquidate,
-      uint256 principalAmountNeeded
-    ) = calculateAvailableCollateralToLiquidate(
+    (uint256 maxCollateralToLiquidate, uint256 principalAmountNeeded) = !vars
+      .healthFactorBelowThreshold
+      ? offboardingCalculateAvailableCollateralToLiquidate(
+        _collateral,
+        _reserve,
+        vars.actualAmountToLiquidate,
+        vars.userCollateralBalance
+      )
+      : calculateAvailableCollateralToLiquidate(
         _collateral,
         _reserve,
         vars.actualAmountToLiquidate,
@@ -6035,15 +6030,19 @@ contract LendingPoolLiquidationManager is ReentrancyGuard, VersionedInitializabl
 
     //if there is a fee to liquidate, calculate the maximum amount of fee that can be liquidated
     if (vars.originationFee > 0) {
-      (
-        vars.liquidatedCollateralForFee,
-        vars.feeLiquidated
-      ) = calculateAvailableCollateralToLiquidate(
-        _collateral,
-        _reserve,
-        vars.originationFee,
-        vars.userCollateralBalance.sub(maxCollateralToLiquidate)
-      );
+      (vars.liquidatedCollateralForFee, vars.feeLiquidated) = !vars.healthFactorBelowThreshold
+        ? offboardingCalculateAvailableCollateralToLiquidate(
+          _collateral,
+          _reserve,
+          vars.originationFee,
+          vars.userCollateralBalance.sub(maxCollateralToLiquidate)
+        )
+        : calculateAvailableCollateralToLiquidate(
+          _collateral,
+          _reserve,
+          vars.originationFee,
+          vars.userCollateralBalance.sub(maxCollateralToLiquidate)
+        );
     }
 
     //if principalAmountNeeded < vars.ActualAmountToLiquidate, there isn't enough
@@ -6055,14 +6054,12 @@ contract LendingPoolLiquidationManager is ReentrancyGuard, VersionedInitializabl
     }
 
     //if liquidator reclaims the underlying asset, we make sure there is enough available collateral in the reserve
-    if (!_receiveAToken) {
-      uint256 currentAvailableCollateral = core.getReserveAvailableLiquidity(_collateral);
-      if (currentAvailableCollateral < maxCollateralToLiquidate) {
-        return (
-          uint256(LiquidationErrors.NOT_ENOUGH_LIQUIDITY),
-          "There isn't enough liquidity available to liquidate"
-        );
-      }
+    uint256 currentAvailableCollateral = core.getReserveAvailableLiquidity(_collateral);
+    if (currentAvailableCollateral < maxCollateralToLiquidate) {
+      return (
+        uint256(LiquidationErrors.NOT_ENOUGH_LIQUIDITY),
+        "There isn't enough liquidity available to liquidate"
+      );
     }
 
     core.updateStateOnLiquidation(
@@ -6074,20 +6071,15 @@ contract LendingPoolLiquidationManager is ReentrancyGuard, VersionedInitializabl
       vars.feeLiquidated,
       vars.liquidatedCollateralForFee,
       vars.borrowBalanceIncrease,
-      _receiveAToken
+      false
     );
 
     AToken collateralAtoken = AToken(core.getReserveATokenAddress(_collateral));
 
-    //if liquidator reclaims the aToken, he receives the equivalent atoken amount
-    if (_receiveAToken) {
-      collateralAtoken.transferOnLiquidation(_user, msg.sender, maxCollateralToLiquidate);
-    } else {
-      //otherwise receives the underlying asset
-      //burn the equivalent amount of atoken
-      collateralAtoken.burnOnLiquidation(_user, maxCollateralToLiquidate);
-      core.transferToUser(_collateral, msg.sender, maxCollateralToLiquidate);
-    }
+    //otherwise receives the underlying asset
+    //burn the equivalent amount of atoken
+    collateralAtoken.burnOnLiquidation(_user, maxCollateralToLiquidate);
+    core.transferToUser(_collateral, msg.sender, maxCollateralToLiquidate);
 
     //transfers the principal currency to the pool
     core.transferToReserve.value(msg.value)(_reserve, msg.sender, vars.actualAmountToLiquidate);
@@ -6122,7 +6114,7 @@ contract LendingPoolLiquidationManager is ReentrancyGuard, VersionedInitializabl
       maxCollateralToLiquidate,
       vars.borrowBalanceIncrease,
       msg.sender,
-      _receiveAToken,
+      false,
       //solium-disable-next-line
       block.timestamp
     );
@@ -6196,4 +6188,61 @@ contract LendingPoolLiquidationManager is ReentrancyGuard, VersionedInitializabl
 
     return (collateralAmount, principalAmountNeeded);
   }
+
+  /**
+   * @dev this method behaves analog to calculateAvailableCollateralToLiquidate, but assumes a constant, asset independent liquidation bonus.
+   * @dev calculates how much of a specific collateral can be liquidated, given
+   * a certain amount of principal currency. This function needs to be called after
+   * all the checks to validate the liquidation have been performed, otherwise it might fail.
+   * @param _collateral the collateral to be liquidated
+   * @param _principal the principal currency to be liquidated
+   * @param _purchaseAmount the amount of principal being liquidated
+   * @param _userCollateralBalance the collatera balance for the specific _collateral asset of the user being liquidated
+   * @return the maximum amount that is possible to liquidated given all the liquidation constraints (user balance, close factor) and
+   * the purchase amount
+   **/
+  function offboardingCalculateAvailableCollateralToLiquidate(
+    address _collateral,
+    address _principal,
+    uint256 _purchaseAmount,
+    uint256 _userCollateralBalance
+  ) internal view returns (uint256 collateralAmount, uint256 principalAmountNeeded) {
+    collateralAmount = 0;
+    principalAmountNeeded = 0;
+    IPriceOracleGetter oracle = IPriceOracleGetter(addressesProvider.getPriceOracle());
+
+    // Usage of a memory struct of vars to avoid "Stack too deep" errors due to local variables
+    AvailableCollateralToLiquidateLocalVars memory vars;
+
+    vars.collateralPrice = oracle.getAssetPrice(_collateral);
+    vars.principalCurrencyPrice = oracle.getAssetPrice(_principal);
+    vars.principalDecimals = core.getReserveDecimals(_principal);
+    vars.collateralDecimals = core.getReserveDecimals(_collateral);
+
+    //this is the maximum possible amount of the selected collateral that can be liquidated, given the
+    //max amount of principal currency that is available for liquidation.
+    vars.maxAmountCollateralToLiquidate = vars
+      .principalCurrencyPrice
+      .mul(_purchaseAmount)
+      .mul(10 ** vars.collateralDecimals)
+      .div(vars.collateralPrice.mul(10 ** vars.principalDecimals))
+      .mul(OFFBOARDING_LIQUIDATION_BONUS)
+      .div(100);
+
+    if (vars.maxAmountCollateralToLiquidate > _userCollateralBalance) {
+      collateralAmount = _userCollateralBalance;
+      principalAmountNeeded = vars
+        .collateralPrice
+        .mul(collateralAmount)
+        .mul(10 ** vars.principalDecimals)
+        .div(vars.principalCurrencyPrice.mul(10 ** vars.collateralDecimals))
+        .mul(100)
+        .div(OFFBOARDING_LIQUIDATION_BONUS);
+    } else {
+      collateralAmount = vars.maxAmountCollateralToLiquidate;
+      principalAmountNeeded = _purchaseAmount;
+    }
+
+    return (collateralAmount, principalAmountNeeded);
+  }
 }
```
