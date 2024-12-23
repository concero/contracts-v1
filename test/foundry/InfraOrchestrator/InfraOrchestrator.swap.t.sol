// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {Test} from "forge-std/src/Test.sol";
import {IDexSwap} from "contracts/Interfaces/IDexSwap.sol";
import {IInfraOrchestrator} from "contracts/Interfaces/IInfraOrchestrator.sol";
import {InfraOrchestrator} from "contracts/InfraOrchestrator.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {console} from "forge-std/src/console.sol";
import {DeployInfraScript} from "../scripts/DeployInfra.s.sol";
import {LibConcero} from "contracts/Libraries/LibConcero.sol";

contract DexSwapTest is Test {
    // @notice helper vars
    address internal constant NATIVE_TOKEN = address(0);
    IInfraOrchestrator.Integration internal emptyIntegration =
        IInfraOrchestrator.Integration({integrator: address(0), feeBps: 0});

    address internal infraProxy;

    modifier selectForkAndUpdateInfraProxy(uint256 forkId) {
        DeployInfraScript deployInfraScript = new DeployInfraScript();
        infraProxy = deployInfraScript.run(forkId);
        _;
    }

    // @dev UNISWAP

    function testFork_Univ3NativeToErc20BaseViaRangoRouting()
        public
        selectForkAndUpdateInfraProxy(vm.createFork(vm.envString("BASE_RPC_URL"), 23814899))
    {
        uint256 fromAmount = 0.1 ether;
        uint256 toAmount = 400.734039e6;
        uint256 toAmountMin = 398.730368e6;
        address user = makeAddr("user");

        // @notice swap data generated by rango
        bytes
            memory dexCallData = hex"ac9650d800000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000001a00000000000000000000000000000000000000000000000000000000000000124b858183f00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000b1311dd0855e00000000000000000000000000000000000000000000000000000000000be200d1000000000000000000000000000000000000000000000000000000000000004242000000000000000000000000000000000000060001f4d9aaec86b65d86f6a7b5b1b0c42ffa531710b6ca000064833589fcd6edb6e08f4c7c32d4f71b54bda02913000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000104b858183f00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000b1311dd0855e00000000000000000000000000000000000000000000000000000000000be1dfbc000000000000000000000000000000000000000000000000000000000000002b42000000000000000000000000000000000000060001f4833589fcd6edb6e08f4c7c32d4f71b54bda0291300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";

        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
        swapData[0] = IDexSwap.SwapData({
            dexRouter: vm.envAddress("UNISWAP_ROUTER_BASE"),
            fromToken: NATIVE_TOKEN,
            fromAmount: fromAmount,
            toToken: vm.envAddress("USDC_BASE"),
            toAmount: toAmount,
            toAmountMin: toAmountMin,
            dexCallData: dexCallData
        });

        _performSwapAndCheck(swapData, user);
    }

    function testFork_UniV3Erc20ToErc20BaseViaRangoRouting()
        public
        selectForkAndUpdateInfraProxy(vm.createFork(vm.envString("BASE_RPC_URL"), 23817245))
    {
        uint256 fromAmount = 100e6;
        uint256 toAmount = 468828.018268057070520348e18;
        uint256 toAmountMin = 468359.190249789013449827e18;
        address fromToken = vm.envAddress("USDC_BASE");
        address toToken = address(0xAC1Bd2486aAf3B5C0fc3Fd868558b082a531B2B4); // @notice Toshi token
        address user = makeAddr("user");

        // @notice swap data generated by rango
        bytes
            memory dexCallData = hex"ac9650d80000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000124b858183f0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000005f2110600000000000000000000000000000000000000000000632dcd75cad78e795c630000000000000000000000000000000000000000000000000000000000000042833589fcd6edb6e08f4c7c32d4f71b54bda029130001f44200000000000000000000000000000000000006002710ac1bd2486aaf3b5c0fc3fd868558b082a531b2b400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";

        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
        swapData[0] = IDexSwap.SwapData({
            dexRouter: vm.envAddress("UNISWAP_ROUTER_BASE"),
            fromToken: fromToken,
            fromAmount: fromAmount,
            toToken: toToken,
            toAmount: toAmount,
            toAmountMin: toAmountMin,
            dexCallData: dexCallData
        });

        _performSwapAndCheck(swapData, user);
    }

    function testFork_UniV3Erc20ToNativeBaseViaRangoRouting()
        public
        selectForkAndUpdateInfraProxy(vm.createFork(vm.envString("BASE_RPC_URL"), 23819957))
    {
        uint256 fromAmount = 100e6;
        uint256 toAmount = 0.024773855091872125e18;
        uint256 toAmountMin = 0.024649985816412764e18;
        address fromToken = address(0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6CA); // @notice USDCb
        address toToken = NATIVE_TOKEN;
        address user = makeAddr("user");

        // @notice swap data generated by rango
        bytes
            memory dexCallData = hex"ac9650d800000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000001a00000000000000000000000000000000000000000000000000000000000000124b858183f0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000005f2110600000000000000000000000000000000000000000000000000579308104e425c0000000000000000000000000000000000000000000000000000000000000042d9aaec86b65d86f6a7b5b1b0c42ffa531710b6ca000064833589fcd6edb6e08f4c7c32d4f71b54bda029130001f4420000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004449404b7c00000000000000000000000000000000000000000000000000579308104e425c000000000000000000000000104fBc016F4bb334D775a19E8A6510109AC63E0000000000000000000000000000000000000000000000000000000000";

        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
        swapData[0] = IDexSwap.SwapData({
            dexRouter: vm.envAddress("UNISWAP_ROUTER_BASE"),
            fromToken: fromToken,
            fromAmount: fromAmount,
            toToken: toToken,
            toAmount: toAmount,
            toAmountMin: toAmountMin,
            dexCallData: dexCallData
        });

        _performSwapAndCheck(swapData, user);
    }

    function testFork_UniV3Erc20ToNativePolygonViaRangoRouting()
        public
        selectForkAndUpdateInfraProxy(vm.createFork(vm.envString("POLYGON_RPC_URL"), 65591280))
    {
        uint256 fromAmount = 100e6;
        uint256 toAmount = 167.372749758706748385e18;
        uint256 toAmountMin = 166.535886009913214643e18;
        address fromToken = vm.envAddress("USDC_POLYGON");
        address toToken = NATIVE_TOKEN;
        address user = makeAddr("user");

        // @notice swap data generated by rango
        bytes
            memory dexCallData = hex"ac9650d800000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000001a00000000000000000000000000000000000000000000000000000000000000124c04b8d59000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000193d47a6c030000000000000000000000000000000000000000000000000000000005f21106000000000000000000000000000000000000000000000009072651fb27d286b3000000000000000000000000000000000000000000000000000000000000002b3c499c542cef5e3811e1192ce70d8cc03d5c33590001f40d500b1d8e8ef31e21c99d1db9a6444d3adf127000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004449404b7c000000000000000000000000000000000000000000000009072651fb27d286b3000000000000000000000000104fBc016F4bb334D775a19E8A6510109AC63E0000000000000000000000000000000000000000000000000000000000";

        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
        swapData[0] = IDexSwap.SwapData({
            dexRouter: vm.envAddress("UNISWAP_ROUTER_POLYGON"),
            fromToken: fromToken,
            fromAmount: fromAmount,
            toToken: toToken,
            toAmount: toAmount,
            toAmountMin: toAmountMin,
            dexCallData: dexCallData
        });

        _performSwapAndCheck(swapData, user);
    }

    function testFork_UniV3Erc20ToErc20PolygonViaRangoRouting()
        public
        selectForkAndUpdateInfraProxy(vm.createFork(vm.envString("POLYGON_RPC_URL"), 65591280))
    {
        uint256 fromAmount = 100e6;
        uint256 toAmount = 0.024927817380526721e18;
        uint256 toAmountMin = 0.024803178293624087e18;
        address fromToken = vm.envAddress("USDC_POLYGON");
        address toToken = address(0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619); // @notice WETH;
        address user = makeAddr("user");

        // @notice swap data generated by rango
        bytes
            memory dexCallData = hex"ac9650d80000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000124c04b8d59000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000104fBc016F4bb334D775a19E8A6510109AC63E0000000000000000000000000000000000000000000000000000000193d476af910000000000000000000000000000000000000000000000000000000005f2110600000000000000000000000000000000000000000000000000581e5bf77dfd17000000000000000000000000000000000000000000000000000000000000002b3c499c542cef5e3811e1192ce70d8cc03d5c33590001f47ceb23fd6bc0add59e62ac25578270cff1b9f61900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";

        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
        swapData[0] = IDexSwap.SwapData({
            dexRouter: vm.envAddress("UNISWAP_ROUTER_POLYGON"),
            fromToken: fromToken,
            fromAmount: fromAmount,
            toToken: toToken,
            toAmount: toAmount,
            toAmountMin: toAmountMin,
            dexCallData: dexCallData
        });

        _performSwapAndCheck(swapData, user);
    }

    function testFork_UniV3NativeToErc20PolygonViaRangoRouting()
        public
        selectForkAndUpdateInfraProxy(vm.createFork(vm.envString("POLYGON_RPC_URL"), 65591280))
    {
        uint256 fromAmount = 0.1 ether;
        uint256 toAmount = 0.059424e6;
        uint256 toAmountMin = 0.059126e6;
        address fromToken = NATIVE_TOKEN;
        address toToken = vm.envAddress("USDC_POLYGON");
        address user = makeAddr("user");

        // @notice swap data generated by rango
        bytes
            memory dexCallData = hex"ac9650d80000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000124c04b8d59000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000104fBc016F4bb334D775a19E8A6510109AC63E0000000000000000000000000000000000000000000000000000000193d47dcd690000000000000000000000000000000000000000000000000162623ba10abc00000000000000000000000000000000000000000000000000000000000000e6f6000000000000000000000000000000000000000000000000000000000000002b0d500b1d8e8ef31e21c99d1db9a6444d3adf12700001f43c499c542cef5e3811e1192ce70d8cc03d5c335900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";

        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
        swapData[0] = IDexSwap.SwapData({
            dexRouter: vm.envAddress("UNISWAP_ROUTER_POLYGON"),
            fromToken: fromToken,
            fromAmount: fromAmount,
            toToken: toToken,
            toAmount: toAmount,
            toAmountMin: toAmountMin,
            dexCallData: dexCallData
        });

        _performSwapAndCheck(swapData, user);
    }

    // @dev SUSHI SWAP

    function testFork_SushiSwapErc20ToErc20BaseViaRangoRouting()
        public
        selectForkAndUpdateInfraProxy(vm.createFork(vm.envString("BASE_RPC_URL"), 23818245))
    {
        uint256 fromAmount = 100e6;
        uint256 toAmount = 0.023621031555323924e18;
        uint256 toAmountMin = 0.021258928399791531e18;
        address fromToken = vm.envAddress("USDC_BASE");
        address toToken = address(0x4200000000000000000000000000000000000006); // @notice weth token
        address user = makeAddr("user");

        // @notice swap data generated by rango
        bytes
            memory dexCallData = hex"38ed17390000000000000000000000000000000000000000000000000000000005f21106000000000000000000000000000000000000000000000000004b86e1fb9335ac00000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000104fBc016F4bb334D775a19E8A6510109AC63E0000000000000000000000000000000000000000000000000000000000676146d70000000000000000000000000000000000000000000000000000000000000002000000000000000000000000833589fcd6edb6e08f4c7c32d4f71b54bda029130000000000000000000000004200000000000000000000000000000000000006";

        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
        swapData[0] = IDexSwap.SwapData({
            dexRouter: vm.envAddress("SUSHISWAP_ROUTER_BASE"),
            fromToken: fromToken,
            fromAmount: fromAmount,
            toToken: toToken,
            toAmount: toAmount,
            toAmountMin: toAmountMin,
            dexCallData: dexCallData
        });

        _performSwapAndCheck(swapData, user);
    }

    function testFork_SushiSwapErc20ToNativeBaseViaRangoRouting()
        public
        selectForkAndUpdateInfraProxy(vm.createFork(vm.envString("BASE_RPC_URL"), 23820938))
    {
        uint256 fromAmount = 100e6;
        uint256 toAmount = 0.021804830498532758e18;
        uint256 toAmountMin = 0.021695806346040094e18;
        address fromToken = address(0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6CA); // @notice USDCb
        address toToken = NATIVE_TOKEN;
        address user = makeAddr("user");

        // @notice swap data generated by rango
        bytes
            memory dexCallData = hex"18cbafe50000000000000000000000000000000000000000000000000000000005f21106000000000000000000000000000000000000000000000000004d14388e5f131e00000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000104fBc016F4bb334D775a19E8A6510109AC63E0000000000000000000000000000000000000000000000000000000000676159260000000000000000000000000000000000000000000000000000000000000002000000000000000000000000d9aaec86b65d86f6a7b5b1b0c42ffa531710b6ca0000000000000000000000004200000000000000000000000000000000000006";

        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
        swapData[0] = IDexSwap.SwapData({
            dexRouter: vm.envAddress("SUSHISWAP_ROUTER_BASE"),
            fromToken: fromToken,
            fromAmount: fromAmount,
            toToken: toToken,
            toAmount: toAmount,
            toAmountMin: toAmountMin,
            dexCallData: dexCallData
        });

        _performSwapAndCheck(swapData, user);
    }

    // @dev helper functions

    function testFork_QuickSwapErc20ToErc20PolygonViaRangoRouting()
        public
        selectForkAndUpdateInfraProxy(vm.createFork(vm.envString("POLYGON_RPC_URL"), 65590432))
    {
        uint256 fromAmount = 100e6;
        uint256 toAmount = 0.024602625471287558e18;
        uint256 toAmountMin = 0.02447961234393112e18;
        address fromToken = vm.envAddress("USDC_POLYGON");
        address toToken = address(0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619); // @notice WETH
        address user = makeAddr("user");

        // @notice swap data generated by rango
        bytes
            memory dexCallData = hex"38ed17390000000000000000000000000000000000000000000000000000000005f211060000000000000000000000000000000000000000000000000056f813e5ffd0f000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000104fBc016F4bb334D775a19E8A6510109AC63E00000000000000000000000000000000000000000000000000000000006761666500000000000000000000000000000000000000000000000000000000000000020000000000000000000000003c499c542cef5e3811e1192ce70d8cc03d5c33590000000000000000000000007ceb23fd6bc0add59e62ac25578270cff1b9f619";

        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
        swapData[0] = IDexSwap.SwapData({
            dexRouter: vm.envAddress("QUICKSWAP_ROUTER_POLYGON"),
            fromToken: fromToken,
            fromAmount: fromAmount,
            toToken: toToken,
            toAmount: toAmount,
            toAmountMin: toAmountMin,
            dexCallData: dexCallData
        });

        _performSwapAndCheck(swapData, user);
    }

    function testFork_QuickSwapErc20ToNativePolygonViaRangoRouting()
        public
        selectForkAndUpdateInfraProxy(vm.createFork(vm.envString("POLYGON_RPC_URL"), 65590432))
    {
        uint256 fromAmount = 100e6;
        uint256 toAmount = 164.7644071672720239e18;
        uint256 toAmountMin = 163.94058513143566378e18;
        address fromToken = vm.envAddress("USDC_POLYGON");
        address toToken = NATIVE_TOKEN; // @notice WETH
        address user = makeAddr("user");

        // @notice swap data generated by rango
        bytes
            memory dexCallData = hex"18cbafe50000000000000000000000000000000000000000000000000000000005f21106000000000000000000000000000000000000000000000008e321f59524e8a1a400000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000104fBc016F4bb334D775a19E8A6510109AC63E0000000000000000000000000000000000000000000000000000000000676167e200000000000000000000000000000000000000000000000000000000000000030000000000000000000000003c499c542cef5e3811e1192ce70d8cc03d5c33590000000000000000000000007ceb23fd6bc0add59e62ac25578270cff1b9f6190000000000000000000000000d500b1d8e8ef31e21c99d1db9a6444d3adf1270";

        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
        swapData[0] = IDexSwap.SwapData({
            dexRouter: vm.envAddress("QUICKSWAP_ROUTER_POLYGON"),
            fromToken: fromToken,
            fromAmount: fromAmount,
            toToken: toToken,
            toAmount: toAmount,
            toAmountMin: toAmountMin,
            dexCallData: dexCallData
        });

        _performSwapAndCheck(swapData, user);
    }

    function testFork_QuickSwapNativeToErc20PolygonViaRangoRouting()
        public
        selectForkAndUpdateInfraProxy(vm.createFork(vm.envString("POLYGON_RPC_URL"), 65590432))
    {
        uint256 fromAmount = 0.1 ether;
        uint256 toAmount = 0.059574e6;
        uint256 toAmountMin = 0.059276e6;
        address fromToken = NATIVE_TOKEN;
        address toToken = vm.envAddress("USDC_POLYGON");
        address user = makeAddr("user");

        // @notice swap data generated by rango
        bytes
            memory dexCallData = hex"7ff36ab5000000000000000000000000000000000000000000000000000000000000e78c0000000000000000000000000000000000000000000000000000000000000080000000000000000000000000104fBc016F4bb334D775a19E8A6510109AC63E00000000000000000000000000000000000000000000000000000000006761687b00000000000000000000000000000000000000000000000000000000000000020000000000000000000000000d500b1d8e8ef31e21c99d1db9a6444d3adf12700000000000000000000000003c499c542cef5e3811e1192ce70d8cc03d5c3359";

        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
        swapData[0] = IDexSwap.SwapData({
            dexRouter: vm.envAddress("QUICKSWAP_ROUTER_POLYGON"),
            fromToken: fromToken,
            fromAmount: fromAmount,
            toToken: toToken,
            toAmount: toAmount,
            toAmountMin: toAmountMin,
            dexCallData: dexCallData
        });

        _performSwapAndCheck(swapData, user);
    }

    // @dev ALIENBASE
    function testFork_AlienBaseErc20ToErc20BaseViaRangoRouting()
        public
        selectForkAndUpdateInfraProxy(vm.createFork(vm.envString("BASE_RPC_URL"), 23823119))
    {
        uint256 fromAmount = 10e6;
        uint256 toAmount = 9.817208378742733493e18;
        uint256 toAmountMin = 9.768122336849019825e18;
        address fromToken = vm.envAddress("USDC_BASE");
        address toToken = address(0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb); // @ notice DAI
        address user = makeAddr("user");

        // @notice swap data generated by rango
        bytes
            memory dexCallData = hex"38ed173900000000000000000000000000000000000000000000000000000000009834e7000000000000000000000000000000000000000000000000878f5782fa71c3b100000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000104fBc016F4bb334D775a19E8A6510109AC63E000000000000000000000000000000000000000000000000000000000067616a420000000000000000000000000000000000000000000000000000000000000004000000000000000000000000833589fcd6edb6e08f4c7c32d4f71b54bda029130000000000000000000000004200000000000000000000000000000000000006000000000000000000000000d9aaec86b65d86f6a7b5b1b0c42ffa531710b6ca00000000000000000000000050c5725949a6f0c72e6c4a641f24049a917db0cb";

        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
        swapData[0] = IDexSwap.SwapData({
            dexRouter: vm.envAddress("ALIENBASE_ROUTER_BASE"),
            fromToken: fromToken,
            fromAmount: fromAmount,
            toToken: toToken,
            toAmount: toAmount,
            toAmountMin: toAmountMin,
            dexCallData: dexCallData
        });

        _performSwapAndCheck(swapData, user);
    }

    function testFork_AlienBaseErc20ToNativeBaseViaRangoRouting()
        public
        selectForkAndUpdateInfraProxy(vm.createFork(vm.envString("BASE_RPC_URL"), 23823119))
    {
        uint256 fromAmount = 10e6;
        uint256 toAmount = 0.0024663148464185e18;
        uint256 toAmountMin = 0.002453983272186407e18;
        address fromToken = vm.envAddress("USDC_BASE");
        address toToken = NATIVE_TOKEN;
        address user = makeAddr("user");

        // @notice swap data generated by rango
        bytes
            memory dexCallData = hex"18cbafe500000000000000000000000000000000000000000000000000000000009834e70000000000000000000000000000000000000000000000000008b7e28139322800000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000104fBc016F4bb334D775a19E8A6510109AC63E000000000000000000000000000000000000000000000000000000000067616b160000000000000000000000000000000000000000000000000000000000000002000000000000000000000000833589fcd6edb6e08f4c7c32d4f71b54bda029130000000000000000000000004200000000000000000000000000000000000006";

        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
        swapData[0] = IDexSwap.SwapData({
            dexRouter: vm.envAddress("ALIENBASE_ROUTER_BASE"),
            fromToken: fromToken,
            fromAmount: fromAmount,
            toToken: toToken,
            toAmount: toAmount,
            toAmountMin: toAmountMin,
            dexCallData: dexCallData
        });

        _performSwapAndCheck(swapData, user);
    }

    function testFork_AlienBaseNativeToErc20BaseViaRangoRouting()
        public
        selectForkAndUpdateInfraProxy(vm.createFork(vm.envString("BASE_RPC_URL"), 23823345))
    {
        uint256 fromAmount = 0.1 ether;
        uint256 toAmount = 311.050561e6;
        uint256 toAmountMin = 309.495308e6;
        address fromToken = NATIVE_TOKEN;
        address toToken = vm.envAddress("USDC_BASE");
        address user = makeAddr("user");

        // @notice swap data generated by rango
        bytes
            memory dexCallData = hex"7ff36ab5000000000000000000000000000000000000000000000000000000001272860c0000000000000000000000000000000000000000000000000000000000000080000000000000000000000000104fBc016F4bb334D775a19E8A6510109AC63E000000000000000000000000000000000000000000000000000000000067616bd700000000000000000000000000000000000000000000000000000000000000020000000000000000000000004200000000000000000000000000000000000006000000000000000000000000833589fcd6edb6e08f4c7c32d4f71b54bda02913";

        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
        swapData[0] = IDexSwap.SwapData({
            dexRouter: vm.envAddress("ALIENBASE_ROUTER_BASE"),
            fromToken: fromToken,
            fromAmount: fromAmount,
            toToken: toToken,
            toAmount: toAmount,
            toAmountMin: toAmountMin,
            dexCallData: dexCallData
        });

        _performSwapAndCheck(swapData, user);
    }

    function _performSwapAndCheck(IDexSwap.SwapData[] memory swapData, address recipient) internal {
        address fromToken = swapData[0].fromToken;
        address toToken = swapData[swapData.length - 1].toToken;
        uint256 fromAmount = swapData[0].fromAmount;
        uint256 toAmountMin = swapData[swapData.length - 1].toAmountMin;
        bool isFormTokenNative = fromToken == address(0);
        uint256 userToTokenBalanceBefore = LibConcero.getBalance(toToken, recipient);

        if (isFormTokenNative) {
            deal(recipient, fromAmount);
        } else {
            deal(fromToken, recipient, fromAmount);
        }

        vm.startPrank(recipient);
        if (isFormTokenNative) {
            InfraOrchestrator(payable(infraProxy)).swap{value: fromAmount}(
                swapData,
                recipient,
                emptyIntegration
            );
        } else {
            IERC20(fromToken).approve(address(infraProxy), fromAmount);
            InfraOrchestrator(payable(infraProxy)).swap(swapData, recipient, emptyIntegration);
        }
        vm.stopPrank();

        uint256 userToTokenBalanceAfter = LibConcero.getBalance(toToken, recipient);
        uint256 toTokenReceived = userToTokenBalanceAfter - userToTokenBalanceBefore;

        assert(toTokenReceived >= toAmountMin);
    }
}
