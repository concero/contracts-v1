// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

import {Script} from "forge-std/src/Script.sol";

contract DeployHelper is Script {
    function getClfRouter() public view returns (address) {
        uint256 chainId = block.chainid;

        if (chainId == vm.envUint("BASE_CHAIN_ID")) {
            return vm.envAddress("CLF_ROUTER_BASE");
        } else if (chainId == vm.envUint("ARBITRUM_CHAIN_ID")) {
            return vm.envAddress("CLF_ROUTER_ARBITRUM");
        } else if (chainId == vm.envUint("POLYGON_CHAIN_ID")) {
            return vm.envAddress("CLF_ROUTER_POLYGON");
        } else if (chainId == vm.envUint("AVALANCHE_CHAIN_ID")) {
            return vm.envAddress("CLF_ROUTER_AVALANCHE");
        } else if (chainId == vm.envUint("OPTIMISM_CHAIN_ID")) {
            return vm.envAddress("CLF_ROUTER_OPTIMISM");
        } else if (chainId == vm.envUint("ETHEREUM_CHAIN_ID")) {
            return vm.envAddress("CLF_ROUTER_ETHEREUM");
        }

        return vm.envAddress("CLF_ROUTER_BASE");
    }

    function getCLfSubId() public view returns (uint64) {
        uint256 chainId = block.chainid;
        uint256 res = vm.envUint("CLF_SUBID_BASE");

        if (chainId == vm.envUint("BASE_CHAIN_ID")) {
            res = vm.envUint("CLF_SUBID_BASE");
        } else if (chainId == vm.envUint("ARBITRUM_CHAIN_ID")) {
            res = vm.envUint("CLF_SUBID_ARBITRUM");
        } else if (chainId == vm.envUint("POLYGON_CHAIN_ID")) {
            res = vm.envUint("CLF_SUBID_POLYGON");
        } else if (chainId == vm.envUint("AVALANCHE_CHAIN_ID")) {
            res = vm.envUint("CLF_SUBID_AVALANCHE");
        } else if (chainId == vm.envUint("OPTIMISM_CHAIN_ID")) {
            res = vm.envUint("CLF_SUBID_OPTIMISM");
        } else if (chainId == vm.envUint("ETHEREUM_CHAIN_ID")) {
            res = vm.envUint("CLF_SUBID_ETHEREUM");
        }

        return uint64(res);
    }

    function getDonId() public view returns (bytes32) {
        uint256 chainId = block.chainid;

        if (chainId == vm.envUint("BASE_CHAIN_ID")) {
            return vm.envBytes32("CLF_DONID_BASE");
        } else if (chainId == vm.envUint("ARBITRUM_CHAIN_ID")) {
            return vm.envBytes32("CLF_DONID_ARBITRUM");
        } else if (chainId == vm.envUint("POLYGON_CHAIN_ID")) {
            return vm.envBytes32("CLF_DONID_POLYGON");
        } else if (chainId == vm.envUint("AVALANCHE_CHAIN_ID")) {
            return vm.envBytes32("CLF_DONID_AVALANCHE");
        } else if (chainId == vm.envUint("OPTIMISM_CHAIN_ID")) {
            return vm.envBytes32("CLF_DONID_OPTIMISM");
        } else if (chainId == vm.envUint("ETHEREUM_CHAIN_ID")) {
            return vm.envBytes32("CLF_DONID_ETHEREUM");
        }

        return vm.envBytes32("CLF_DONID_BASE");
    }

    function getChainSelector() public view returns (uint64) {
        uint256 chainId = block.chainid;
        uint256 res = vm.envUint("CL_CCIP_CHAIN_SELECTOR_BASE");

        if (chainId == vm.envUint("BASE_CHAIN_ID")) {
            res = vm.envUint("CL_CCIP_CHAIN_SELECTOR_BASE");
        } else if (chainId == vm.envUint("ARBITRUM_CHAIN_ID")) {
            res = vm.envUint("CL_CCIP_CHAIN_SELECTOR_ARBITRUM");
        } else if (chainId == vm.envUint("POLYGON_CHAIN_ID")) {
            res = vm.envUint("CL_CCIP_CHAIN_SELECTOR_POLYGON");
        } else if (chainId == vm.envUint("AVALANCHE_CHAIN_ID")) {
            res = vm.envUint("CL_CCIP_CHAIN_SELECTOR_AVALANCHE");
        } else if (chainId == vm.envUint("OPTIMISM_CHAIN_ID")) {
            res = vm.envUint("CL_CCIP_CHAIN_SELECTOR_OPTIMISM");
        } else if (chainId == vm.envUint("ETHEREUM_CHAIN_ID")) {
            res = vm.envUint("CL_CCIP_CHAIN_SELECTOR_ETHEREUM");
        }

        return uint64(res);
    }

    function getChainIndex() public view returns (uint8) {
        uint256 chainId = block.chainid;
        uint256 res = 1;

        if (chainId == vm.envUint("BASE_CHAIN_ID")) {
            res = 1;
        } else if (chainId == vm.envUint("ARBITRUM_CHAIN_ID")) {
            res = 0;
        } else if (chainId == vm.envUint("POLYGON_CHAIN_ID")) {
            res = 3;
        } else if (chainId == vm.envUint("AVALANCHE_CHAIN_ID")) {
            res = 4;
        } else if (chainId == vm.envUint("OPTIMISM_CHAIN_ID")) {
            res = 2;
        } else if (chainId == vm.envUint("ETHEREUM_CHAIN_ID")) {
            res = 5;
        }

        return uint8(res);
    }

    function getLinkAddress() public view returns (address) {
        uint256 chainId = block.chainid;

        if (chainId == vm.envUint("BASE_CHAIN_ID")) {
            return vm.envAddress("LINK_BASE");
        } else if (chainId == vm.envUint("ARBITRUM_CHAIN_ID")) {
            return vm.envAddress("LINK_ARBITRUM");
        } else if (chainId == vm.envUint("POLYGON_CHAIN_ID")) {
            return vm.envAddress("LINK_POLYGON");
        } else if (chainId == vm.envUint("AVALANCHE_CHAIN_ID")) {
            return vm.envAddress("LINK_AVALANCHE");
        } else if (chainId == vm.envUint("OPTIMISM_CHAIN_ID")) {
            return vm.envAddress("LINK_OPTIMISM");
        } else if (chainId == vm.envUint("ETHEREUM_CHAIN_ID")) {
            return vm.envAddress("LINK_ETHEREUM");
        }

        return vm.envAddress("LINK_BASE");
    }

    function getCcipRouter() public view returns (address) {
        uint256 chainId = block.chainid;

        if (chainId == vm.envUint("BASE_CHAIN_ID")) {
            return vm.envAddress("CL_CCIP_ROUTER_BASE");
        } else if (chainId == vm.envUint("ARBITRUM_CHAIN_ID")) {
            return vm.envAddress("CL_CCIP_ROUTER_ARBITRUM");
        } else if (chainId == vm.envUint("POLYGON_CHAIN_ID")) {
            return vm.envAddress("CL_CCIP_ROUTER_POLYGON");
        } else if (chainId == vm.envUint("AVALANCHE_CHAIN_ID")) {
            return vm.envAddress("CL_CCIP_ROUTER_AVALANCHE");
        } else if (chainId == vm.envUint("OPTIMISM_CHAIN_ID")) {
            return vm.envAddress("CL_CCIP_ROUTER_OPTIMISM");
        } else if (chainId == vm.envUint("ETHEREUM_CHAIN_ID")) {
            return vm.envAddress("CL_CCIP_ROUTER_ETHEREUM");
        }

        return vm.envAddress("CL_CCIP_ROUTER_BASE");
    }

    function getDexRouters() public view returns (address[] memory) {
        uint256 chainId = block.chainid;

        if (chainId == vm.envUint("BASE_CHAIN_ID")) {
            address[] memory routers = new address[](4);
            routers[0] = vm.envAddress("UNISWAP_ROUTER_BASE");
            routers[1] = vm.envAddress("SUSHISWAP_ROUTER_BASE");
            routers[2] = vm.envAddress("ALIENBASE_ROUTER_BASE");
            routers[3] = vm.envAddress("WETH_BASE");
            return routers;
        }

        if (chainId == vm.envUint("POLYGON_CHAIN_ID")) {
            address[] memory routers = new address[](3);
            routers[0] = vm.envAddress("QUICKSWAP_ROUTER_POLYGON");
            routers[1] = vm.envAddress("UNISWAP_ROUTER_POLYGON");
            routers[2] = vm.envAddress("WPOL_POLYGON");
            return routers;
        }

        if (chainId == vm.envUint("AVALANCHE_CHAIN_ID")) {
            address[] memory routers = new address[](2);
            routers[0] = vm.envAddress("PARASWAP_ROUTER_AVALANCHE");
            routers[1] = vm.envAddress("WAVAX_AVALANCHE");
            return routers;
        }

        if (chainId == vm.envUint("ARBITRUM_CHAIN_ID")) {
            address[] memory routers = new address[](2);
            routers[0] = vm.envAddress("UNISWAP_ROUTER_ARBITRUM");
            routers[1] = vm.envAddress("WETH_ARBITRUM");
            return routers;
        }

        if (chainId == vm.envUint("OPTIMISM_CHAIN_ID")) {
            address[] memory routers = new address[](2);
            routers[0] = vm.envAddress("ODOS_ROUTER_OPTIMISM");
            routers[1] = vm.envAddress("WETH_OPTIMISM");
            return routers;
        }

        address[] memory res = new address[](0);
        return res;
    }
}
