```diff
diff --git a/etherscan/1_0xcB8c3Dbf2530d6b07b50d0BcE91F7A04FA696486/LendingPool/src/contracts/v1Pool/LendingPool/LendingPool.sol b/src/contracts/UpdatedLendingPool.sol
index 60f0e43..c07a643 100644
--- a/etherscan/1_0xcB8c3Dbf2530d6b07b50d0BcE91F7A04FA696486/LendingPool/src/contracts/v1Pool/LendingPool/LendingPool.sol
+++ b/src/contracts/UpdatedLendingPool.sol
@@ -3448,7 +3448,7 @@ contract LendingPool is ReentrancyGuard, VersionedInitializable {
 
   uint256 public constant UINT_MAX_VALUE = uint256(-1);
 
-  uint256 public constant LENDINGPOOL_REVISION = 0x6;
+  uint256 public constant LENDINGPOOL_REVISION = 0x7;
 
   function getRevision() internal pure returns (uint256) {
     return LENDINGPOOL_REVISION;
@@ -3952,19 +3952,21 @@ contract LendingPool is ReentrancyGuard, VersionedInitializable {
 
   /**
    * @dev users can invoke this function to liquidate an undercollateralized position.
+   * This version has some important differences to the previous:
+   * - a liquidator **can** liquidate up to 100% of the position
+   * - a liquidator **can** liquidate healthy(collateralized) positions for a fixed 1% liquidationBonus
+   * - a liquidator **can not** receive aTokens as the result of the liquidation
    * @param _reserve the address of the collateral to liquidated
    * @param _reserve the address of the principal reserve
    * @param _user the address of the borrower
    * @param _purchaseAmount the amount of principal that the liquidator wants to repay
-   * @param _receiveAToken true if the liquidators wants to receive the aTokens, false if
-   * he wants to receive the underlying asset directly
    **/
   function liquidationCall(
     address _collateral,
     address _reserve,
     address _user,
     uint256 _purchaseAmount,
-    bool _receiveAToken
+    bool
   ) external payable nonReentrant onlyActiveReserve(_reserve) onlyActiveReserve(_collateral) {
     address liquidationManager = addressesProvider.getLendingPoolLiquidationManager();
 
@@ -3976,7 +3978,7 @@ contract LendingPool is ReentrancyGuard, VersionedInitializable {
         _reserve,
         _user,
         _purchaseAmount,
-        _receiveAToken
+        false
       )
     );
     require(success, 'Liquidation call failed');
@@ -4003,6 +4005,7 @@ contract LendingPool is ReentrancyGuard, VersionedInitializable {
     uint256 _amount,
     bytes memory _params
   ) public nonReentrant onlyActiveReserve(_reserve) onlyAmountGreaterThanZero(_amount) {
+    require(false, 'V1 flashloans are disabled');
     //check that the reserve has enough available liquidity
     //we avoid using the getAvailableLiquidity() function in LendingPoolCore to save gas
     uint256 availableLiquidityBefore = _reserve == EthAddressLib.ethAddress()
```
