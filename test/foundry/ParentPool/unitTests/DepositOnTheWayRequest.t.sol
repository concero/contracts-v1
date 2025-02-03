// SPDX-License-Identifier: UNLICENSED
//pragma solidity 0.8.20;
//
//import {Test, console} from "forge-std/Test.sol";
//import {ParentPoolDeploy} from "../../../script/ParentPoolDeploy.s.sol";
//import {ParentPool} from "contracts/ParentPool.sol";
//import {ForkType, CreateAndSwitchToForkTest} from "../../utils/CreateAndSwitchToFork.t.sol";
//import "../../../lib/chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";
//
//contract DepositOnTheWayRequest is ParentPool, CreateAndSwitchToForkTest {
//    constructor()
//        ParentPool(
//            address(0),
//            address(vm.envAddress("LINK_BASE")),
//            bytes32(0),
//            0,
//            address(vm.envAddress("CLF_ROUTER_BASE")),
//            address(vm.envAddress("CL_CCIP_ROUTER_BASE")),
//            address(vm.envAddress("USDC_BASE")),
//            address(vm.envAddress("LPTOKEN_BASE")),
//            address(vm.envAddress("CONCERO_ORCHESTRATOR_BASE")),
//            address(msg.sender),
//            0,
//            [vm.envAddress("POOL_MESSENGER_0_ADDRESS"), address(0), address(0)]
//        )
//    {}
//
//    function setUp() public {}
//
//    function test_AddDepositOnTheWay() public {
//        _fillDepositsRequestArray(MAX_DEPOSIT_REQUESTS_COUNT);
//        console.log(s_depositsOnTheWayArray.length);
//        _deleteDepositOnTheWayRequestByIndex(4);
//        _addDepositOnTheWayRequest(bytes32(0), 0, 100);
//
//        DepositOnTheWay memory lastDepositOnTheWay = s_depositsOnTheWayArray[
//            s_depositsOnTheWayArray.length - 1
//        ];
//
//        bytes1 expectedLastDepositId = bytes1(uint8(5));
//        assert(lastDepositOnTheWay.id == expectedLastDepositId);
//    }
//
//    function test_DeleteDepositsOnTheWay() public {
//        bytes
//            memory clfResponse = hex"00000000000000000000000000000000000000000000000000000000003abf100104070a0d02030506080900";
//
//        (uint256 totalBalance, bytes1[] memory depositsOnTheWayIdsToDelete) = _decodeCLFResponse(
//            clfResponse
//        );
//
//        _fillDepositsRequestArray(127);
//
//        console.log("length:", depositsOnTheWayIdsToDelete.length);
//
//        uint256 gasBefore = gasleft();
//        _deleteDepositsOnTheWayByIds(depositsOnTheWayIdsToDelete);
//        uint256 gasAfter = gasleft();
//
//        uint256 gasUsed = gasBefore - gasAfter;
//        console.log("gasUsed: ", gasUsed);
//
//        assert(gasUsed < 200_000);
//    }
//
//    function test_checkUpkeep() public {
//        uint256 forkId = vm.createFork(vm.envString("BASE_TESTNET_RPC_URL"));
//        vm.selectFork(forkId);
//        vm.startPrank(address(0), address(0));
//
//        (bool isChecked, bytes memory byt) = AutomationCompatibleInterface(
//            vm.envAddress("CONCERO_AUTOMATION_BASE_SEPOLIA")
//        ).checkUpkeep(bytes(""));
//
//        console.log("isChecked: ", isChecked);
//        console.logBytes(byt);
//
//        //  1722449036 - now
//        //  1722438612 - triggeredAt
//
//        console.log(block.timestamp);
//    }
//
//    function test_decodeCLFResponse_1() public {
//        bytes
//            memory response = hex"0000000000000000000000000000000000000000000000000000000000186a00010203040506";
//
//        (uint256 totalBalance, bytes1[] memory depositsOnTheWayIdsToDelete) = _decodeCLFResponse(
//            response
//        );
//
//        assert(totalBalance == 1600000);
//        assert(depositsOnTheWayIdsToDelete.length == 6);
//        assert(depositsOnTheWayIdsToDelete[0] == bytes1(uint8((1))));
//        assert(depositsOnTheWayIdsToDelete[1] == bytes1(uint8(2)));
//        assert(depositsOnTheWayIdsToDelete[2] == bytes1(uint8(3)));
//        assert(depositsOnTheWayIdsToDelete[3] == bytes1(uint8(4)));
//        assert(depositsOnTheWayIdsToDelete[4] == bytes1(uint8(5)));
//        assert(depositsOnTheWayIdsToDelete[5] == bytes1(uint8(6)));
//    }
//
//    ////////////////////////
//    /// Helper functions///
//    ///////////////////////
//
//    function _fillDepositsRequestArray(uint256 count) private {
//        for (uint256 i = 0; i <= count; i++) {
//            _addDepositOnTheWayRequest(bytes32(0), 0, 100);
//        }
//    }
//
//    function _deleteDepositOnTheWayRequestByIndex(uint256 index) private {
//        s_depositsOnTheWayArray[index] = s_depositsOnTheWayArray[
//            s_depositsOnTheWayArray.length - 1
//        ];
//        s_depositsOnTheWayArray.pop();
//    }
//
//    function _clearDepositsOnTheWay() private {
//        for (uint256 i = 0; i < s_depositsOnTheWayArray.length; i++) {
//            s_depositsOnTheWayArray.pop();
//        }
//    }
//}
