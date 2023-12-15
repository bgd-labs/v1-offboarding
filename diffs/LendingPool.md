```diff
diff --git a/src/etherscan/1_0xcB8c3Dbf2530d6b07b50d0BcE91F7A04FA696486/LendingPool/src/contracts/v1Pool/LendingPool/LendingPool.sol b/src/UpdatedLendingPool.sol
index 60f0e43..923b2c3 100644
--- a/src/etherscan/1_0xcB8c3Dbf2530d6b07b50d0BcE91F7A04FA696486/LendingPool/src/contracts/v1Pool/LendingPool/LendingPool.sol
+++ b/src/UpdatedLendingPool.sol
@@ -3448,7 +3448,7 @@ contract LendingPool is ReentrancyGuard, VersionedInitializable {
 
   uint256 public constant UINT_MAX_VALUE = uint256(-1);
 
-  uint256 public constant LENDINGPOOL_REVISION = 0x6;
+  uint256 public constant LENDINGPOOL_REVISION = 0x7;
 
   function getRevision() internal pure returns (uint256) {
     return LENDINGPOOL_REVISION;
@@ -3989,6 +3989,42 @@ contract LendingPool is ReentrancyGuard, VersionedInitializable {
     }
   }
 
+  /**
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
+  ) external payable nonReentrant onlyActiveReserve(_reserve) onlyActiveReserve(_collateral) {
+    address liquidationManager = addressesProvider.getLendingPoolLiquidationManager();
+
+    //solium-disable-next-line
+    (bool success, bytes memory result) = liquidationManager.delegatecall(
+      abi.encodeWithSignature(
+        'offboardingLiquidationCall(address,address,address,uint256)',
+        _collateral,
+        _reserve,
+        _user,
+        _purchaseAmount
+      )
+    );
+    require(success, 'Liquidation call failed');
+
+    (uint256 returnCode, string memory returnMessage) = abi.decode(result, (uint256, string));
+
+    if (returnCode != 0) {
+      //error found
+      revert(string(abi.encodePacked('Liquidation failed: ', returnMessage)));
+    }
+  }
+
   /**
    * @dev allows smartcontracts to access the liquidity of the pool within one transaction,
    * as long as the amount taken plus a fee is returned. NOTE There are security concerns for developers of flashloan receiver contracts
@@ -4003,6 +4039,7 @@ contract LendingPool is ReentrancyGuard, VersionedInitializable {
     uint256 _amount,
     bytes memory _params
   ) public nonReentrant onlyActiveReserve(_reserve) onlyAmountGreaterThanZero(_amount) {
+    require(false, 'V1 flashloans are disabled');
     //check that the reserve has enough available liquidity
     //we avoid using the getAvailableLiquidity() function in LendingPoolCore to save gas
     uint256 availableLiquidityBefore = _reserve == EthAddressLib.ethAddress()
```
