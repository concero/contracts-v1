// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

//===== Contracts
import {ConceroAutomation} from "contracts/ConceroAutomation.sol";

//===== Script Deploy
import {AutomationDeploy} from "../../../script/AutomationDeploy.s.sol";

//===== Interfaces
import {IParentPool} from "contracts/Interfaces/IParentPool.sol";

//===== Test Environment
import {ProtocolTestnet} from "./ProtocolTestnet.t.sol";

contract Automation is ProtocolTestnet {

    event ConceroAutomation_ForwarderAddressUpdated(address);
    function test_addForwarder() public {
        address fakeForwarder = address(0x1);

        //===== Ownable Revert
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, address(this)));
        automation.setForwarderAddress(fakeForwarder);

        //====== Success
        vm.prank(Tester);
        vm.expectEmit();
        emit ConceroAutomation_ForwarderAddressUpdated(fakeForwarder);
        automation.setForwarderAddress(fakeForwarder);
    }

    event ConceroAutomation_DonSecretVersionUpdated(uint64);
    error OwnableUnauthorizedAccount(address);
    function test_setDonHostedSecretsVersion() public {
        uint64 secretVersion = 2;

        //===== Ownable Revert
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, address(this)));
        automation.setDonHostedSecretsVersion(secretVersion);

        //====== Success
        vm.prank(Tester);
        vm.expectEmit();
        emit ConceroAutomation_DonSecretVersionUpdated(secretVersion);
        automation.setDonHostedSecretsVersion(secretVersion);
    }

    event ConceroAutomation_HashSumUpdated(bytes32);
    function test_setSrcJsHashSum() public {
        bytes32 hashSum = 0x46d3cb1bb1c87442ef5d35a58248785346864a681125ac50b38aae6001ceb124;

        //===== Ownable Revert
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, address(this)));
        automation.setJsHashSum(hashSum);

        //====== Success

        vm.prank(Tester);
        vm.expectEmit();
        emit ConceroAutomation_HashSumUpdated(hashSum);
        automation.setJsHashSum(hashSum); 
    }

    event ConceroAutomation_EthersHashSumUpdated(bytes32);
    function test_setEthersHashSum() public {
        bytes32 hashSum = 0x46d3cb1bb1c87442ef5d35a58248785346864a681125ac50b38aae6001ceb124;

        //===== Ownable Revert
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, address(this)));
        automation.setEthersHashSum(hashSum);

        //====== Success

        vm.prank(Tester);
        vm.expectEmit();
        emit ConceroAutomation_EthersHashSumUpdated(hashSum);
        automation.setEthersHashSum(hashSum);
    }

    event ConceroAutomation_RequestAdded(address);
    error ConceroAutomation_CallerNotAllowed(address);
    function test_pendingWithdrawal() public {
        //===== Ownable Revert
        vm.expectRevert(abi.encodeWithSelector(ConceroAutomation_CallerNotAllowed.selector, address(this)));
        automation.addPendingWithdrawal(User);

        vm.prank(address(masterProxy));
        vm.expectEmit();
        emit ConceroAutomation_RequestAdded(User);
        automation.addPendingWithdrawal(User);
    }

    function test_checkUpkeep() public {
        //====== Not Forwarder
        // vm.expectRevert(abi.encodeWithSelector(ConceroAutomation_CallerNotAllowed.selector, address(this)));
        // automation.checkUpkeep("");

        //====== Successful Call
        //=== Add Forwarder
        address fakeForwarder = address(0x1);
        vm.prank(Tester);
        automation.setForwarderAddress(fakeForwarder);

        //=== Create Request
        vm.prank(address(masterProxy));
        automation.addPendingWithdrawal(User);

        address[] memory recoveredRequest = automation.getPendingRequests();

        assertEq(recoveredRequest[0], User);

        //=== check return
        vm.prank(fakeForwarder);
        (bool positiveResponse, bytes memory performData) = automation.checkUpkeep("");

        assertEq(positiveResponse, true); //Because the request don't exist, but the address is on the array

        (address LiquidityProvider, uint256 amountToRequest) = abi.decode(performData,(address, uint256));

        assertEq(LiquidityProvider, User);
        assertEq(amountToRequest, 0);
    }

    event ConceroAutomation_UpkeepPerformed(bytes32);
    function test_performUpkeep() public setters{
        vm.selectFork(baseTestFork);

        //====== Not Forwarder
        vm.expectRevert(abi.encodeWithSelector(ConceroAutomation_CallerNotAllowed.selector, address(this)));
        automation.performUpkeep("");

        //====== Successful Call
        //=== Add Forwarder
        address fakeForwarder = address(0x1);
        vm.prank(Tester);
        automation.setForwarderAddress(fakeForwarder);

        //=== Mock Data
        IParentPool.WithdrawRequests memory _request = IParentPool.WithdrawRequests({
            amountEarned: 10*10**6,
            amountToBurn: 5*10**6,
            amountToRequest: 5*10**6,
            amountToReceive: 5*10**6,
            token: address(mUSDC),
            deadline: block.timestamp + 597_600
        });

        //=== Create Request
        vm.prank(address(masterProxy));
        automation.addPendingWithdrawal(User);

        address[] memory recoveredRequest = automation.getPendingRequests();

        //=== move in time
        vm.warp(block.timestamp + 7 days);

        //=== check return
        vm.prank(fakeForwarder);
        (bool positiveResponse, bytes memory performData) = automation.checkUpkeep("");

        //=== Simulate Perform Withdraw
        bytes32 reqId = 0;

        vm.prank(fakeForwarder);
        automation.performUpkeep(performData);

        // (address liquidityProvider, uint256 amountToRequest) = automation.s_requests(reqId);

        // assertEq(liquidityProvider, User);
        // assertEq(amountToRequest, 5*10**6);
    }
}