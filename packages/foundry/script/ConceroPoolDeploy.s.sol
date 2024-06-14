// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script, console2} from "../lib/forge-std/src/Script.sol";
import {ConceroPool} from "contracts/ConceroPool.sol";

contract ConceroPoolDeploy is Script {

    function run(address _link,address _ccipRouter, address _proxy, address _usdcAddress) public returns(ConceroPool pool){
        vm.startBroadcast();
        pool = new ConceroPool(_link, _ccipRouter, _proxy, _usdcAddress);
        vm.stopBroadcast();
    }
}
