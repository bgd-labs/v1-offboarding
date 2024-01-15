// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';

contract Deploy is Script {
  function run() external {
    vm.startBroadcast();
    bytes memory liquidationManagerBytecode = abi.encodePacked(
      vm.getCode('UpdatedLendingPoolLiquidationManager.sol:LendingPoolLiquidationManager')
    );
    address liquidationManager;
    assembly {
      liquidationManager := create(
        0,
        add(liquidationManagerBytecode, 0x20),
        mload(liquidationManagerBytecode)
      )
    }
    bytes memory lendingPoolBytecode = abi.encodePacked(
      vm.getCode('UpdatedLendingPool.sol:LendingPool')
    );
    address poolImpl;
    assembly {
      poolImpl := create(0, add(lendingPoolBytecode, 0x20), mload(lendingPoolBytecode))
    }
    vm.stopBroadcast();
  }
}
