```diff
diff --git a/etherscan/1_0x31cceeb1fA3DbEAf7baaD25125b972A17624A40a/LendingPoolLiquidationManager/Contract.sol b/src/contracts/UpdatedLendingPoolLiquidationManager.sol
index 0490cd7..6dc50a2 100644
--- a/etherscan/1_0x31cceeb1fA3DbEAf7baaD25125b972A17624A40a/LendingPoolLiquidationManager/Contract.sol
+++ b/src/contracts/UpdatedLendingPoolLiquidationManager.sol
@@ -5871,6 +5871,7 @@ contract LendingPoolLiquidationManager is ReentrancyGuard, VersionedInitializabl
   address ethereumAddress;
 
   uint256 constant LIQUIDATION_CLOSE_FACTOR_PERCENT = 50;
+  uint256 constant OFFBOARDING_LIQUIDATION_BONUS = 101; // 1%
 
   /**
    * @dev emitted when a borrow fee is liquidated
@@ -5945,7 +5946,174 @@ contract LendingPoolLiquidationManager is ReentrancyGuard, VersionedInitializabl
    * of the LendingPool contract, the getRevision() function is needed.
    */
   function getRevision() internal pure returns (uint256) {
-    return 0;
+    return 1;
+  }
+
+  /**
+   * @dev This method behaves analog to a liquidationCall with some key differences:
+   * - the lb is fixed to 1%
+   * - you can liquidate healthy addresses
+   * - you can liquidate up to 100% (instead of 50%)
+   * - you can only liquidate the underlying
+   * @dev users can invoke this function to liquidate an undercollateralized position.
+   * @param _reserve the address of the collateral to liquidated
+   * @param _reserve the address of the principal reserve
+   * @param _user the address of the borrower
+   * @param _purchaseAmount the amount of principal that the liquidator wants to repay
+   * he wants to receive the underlying asset directly
+   **/
+  function offboardingLiquidationCall(
+    address _collateral,
+    address _reserve,
+    address _user,
+    uint256 _purchaseAmount
+  ) external payable returns (uint256, string memory) {
+    // Usage of a memory struct of vars to avoid "Stack too deep" errors due to local variables
+    LiquidationCallLocalVars memory vars;
+
+    (, , , , , , , vars.healthFactorBelowThreshold) = dataProvider.calculateUserGlobalData(_user);
+
+    vars.userCollateralBalance = core.getUserUnderlyingAssetBalance(_collateral, _user);
+
+    //if _user hasn't deposited this specific collateral, nothing can be liquidated
+    if (vars.userCollateralBalance == 0) {
+      return (
+        uint256(LiquidationErrors.NO_COLLATERAL_AVAILABLE),
+        'Invalid collateral to liquidate'
+      );
+    }
+
+    vars.isCollateralEnabled =
+      core.isReserveUsageAsCollateralEnabled(_collateral) &&
+      core.isUserUseReserveAsCollateralEnabled(_collateral, _user);
+
+    //if _collateral isn't enabled as collateral by _user, it cannot be liquidated
+    if (!vars.isCollateralEnabled) {
+      return (
+        uint256(LiquidationErrors.COLLATERAL_CANNOT_BE_LIQUIDATED),
+        'The collateral chosen cannot be liquidated'
+      );
+    }
+
+    //if the user hasn't borrowed the specific currency defined by _reserve, it cannot be liquidated
+    (, vars.userCompoundedBorrowBalance, vars.borrowBalanceIncrease) = core.getUserBorrowBalances(
+      _reserve,
+      _user
+    );
+
+    if (vars.userCompoundedBorrowBalance == 0) {
+      return (
+        uint256(LiquidationErrors.CURRRENCY_NOT_BORROWED),
+        'User did not borrow the specified currency'
+      );
+    }
+
+    //all clear - calculate the max principal amount that can be liquidated
+    vars.maxPrincipalAmountToLiquidate = vars.userCompoundedBorrowBalance;
+
+    vars.actualAmountToLiquidate = _purchaseAmount > vars.maxPrincipalAmountToLiquidate
+      ? vars.maxPrincipalAmountToLiquidate
+      : _purchaseAmount;
+
+    (
+      uint256 maxCollateralToLiquidate,
+      uint256 principalAmountNeeded
+    ) = offboardingCalculateAvailableCollateralToLiquidate(
+        _collateral,
+        _reserve,
+        vars.actualAmountToLiquidate,
+        vars.userCollateralBalance
+      );
+
+    vars.originationFee = core.getUserOriginationFee(_reserve, _user);
+
+    //if there is a fee to liquidate, calculate the maximum amount of fee that can be liquidated
+    if (vars.originationFee > 0) {
+      (
+        vars.liquidatedCollateralForFee,
+        vars.feeLiquidated
+      ) = offboardingCalculateAvailableCollateralToLiquidate(
+        _collateral,
+        _reserve,
+        vars.originationFee,
+        vars.userCollateralBalance.sub(maxCollateralToLiquidate)
+      );
+    }
+
+    //if principalAmountNeeded < vars.ActualAmountToLiquidate, there isn't enough
+    //of _collateral to cover the actual amount that is being liquidated, hence we liquidate
+    //a smaller amount
+
+    if (principalAmountNeeded < vars.actualAmountToLiquidate) {
+      vars.actualAmountToLiquidate = principalAmountNeeded;
+    }
+
+    //if liquidator reclaims the underlying asset, we make sure there is enough available collateral in the reserve
+    uint256 currentAvailableCollateral = core.getReserveAvailableLiquidity(_collateral);
+    if (currentAvailableCollateral < maxCollateralToLiquidate) {
+      return (
+        uint256(LiquidationErrors.NOT_ENOUGH_LIQUIDITY),
+        "There isn't enough liquidity available to liquidate"
+      );
+    }
+
+    core.updateStateOnLiquidation(
+      _reserve,
+      _collateral,
+      _user,
+      vars.actualAmountToLiquidate,
+      maxCollateralToLiquidate,
+      vars.feeLiquidated,
+      vars.liquidatedCollateralForFee,
+      vars.borrowBalanceIncrease,
+      false
+    );
+
+    AToken collateralAtoken = AToken(core.getReserveATokenAddress(_collateral));
+
+    //burn the equivalent amount of atoken
+    collateralAtoken.burnOnLiquidation(_user, maxCollateralToLiquidate);
+    core.transferToUser(_collateral, msg.sender, maxCollateralToLiquidate);
+
+    //transfers the principal currency to the pool
+    core.transferToReserve.value(msg.value)(_reserve, msg.sender, vars.actualAmountToLiquidate);
+
+    if (vars.feeLiquidated > 0) {
+      //if there is enough collateral to liquidate the fee, first transfer burn an equivalent amount of
+      //aTokens of the user
+      collateralAtoken.burnOnLiquidation(_user, vars.liquidatedCollateralForFee);
+
+      //then liquidate the fee by transferring it to the fee collection address
+      core.liquidateFee(
+        _collateral,
+        vars.liquidatedCollateralForFee,
+        addressesProvider.getTokenDistributor()
+      );
+
+      emit OriginationFeeLiquidated(
+        _collateral,
+        _reserve,
+        _user,
+        vars.feeLiquidated,
+        vars.liquidatedCollateralForFee,
+        //solium-disable-next-line
+        block.timestamp
+      );
+    }
+    emit LiquidationCall(
+      _collateral,
+      _reserve,
+      _user,
+      vars.actualAmountToLiquidate,
+      maxCollateralToLiquidate,
+      vars.borrowBalanceIncrease,
+      msg.sender,
+      false,
+      //solium-disable-next-line
+      block.timestamp
+    );
+
+    return (uint256(LiquidationErrors.NO_ERROR), 'No errors');
   }
 
   /**
@@ -6196,4 +6364,60 @@ contract LendingPoolLiquidationManager is ReentrancyGuard, VersionedInitializabl
 
     return (collateralAmount, principalAmountNeeded);
   }
+
+  /**
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
