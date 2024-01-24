// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';

interface ILendingPool {
  function initialize(address _addressesProvider) external;
}

//  command: make deploy-ledger contract=scripts/Deploy.s.sol:Deploy chain=mainnet
contract Deploy is Script {
  address constant ADDRESSES_PROVIDER = 0x24a42fD28C976A61Df5D00D0599C34c4f90748c8;

  function run() external {
    vm.startBroadcast();
    // bytes memory liquidationManagerBytecode = abi.encodePacked(
    //   vm.getCode('UpdatedLendingPoolLiquidationManager.sol:LendingPoolLiquidationManager')
    // );
    address liquidationManager = 0x1a7Dde6344d5F2888209DdB446756FE292e1325e;
    // assembly {
    //   liquidationManager := create(
    //     0,
    //     add(liquidationManagerBytecode, 0x20),
    //     mload(liquidationManagerBytecode)
    //   )
    // }
    bytes memory lendingPoolBytecode = abi.encodePacked(
      vm.getCode('UpdatedLendingPool.sol:LendingPool')
    );
    address poolImpl;
    assembly {
      poolImpl := create(0, add(lendingPoolBytecode, 0x20), mload(lendingPoolBytecode))
    }
    ILendingPool(poolImpl).initialize(ADDRESSES_PROVIDER);
    vm.stopBroadcast();
  }
}
