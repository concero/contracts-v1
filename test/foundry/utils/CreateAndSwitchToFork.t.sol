// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Test, console} from "forge-std/Test.sol";

enum ForkType {
    BASE,
    ARBITRUM,
    POLYGON,
    LocalBase
}

contract CreateAndSwitchToForkTest is Test {
    uint256 private forkId;

    function switchToFork(ForkType forkType) internal {
        if (forkType == ForkType.BASE) {
            forkId = vm.createFork(vm.envString("BASE_RPC_URL"), 17655883);
            vm.selectFork(forkId);
        } else if (forkType == ForkType.LocalBase) {
            forkId = vm.createFork(vm.envString("LOCAL_BASE_FORK_RPC_URL"));
            vm.selectFork(forkId);
        }
    }
}
