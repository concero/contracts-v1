//// SPDX-License-Identifier: SEE LICENSE IN LICENSE
//pragma solidity 0.8.20;
//
//import {ConceroBridge} from "contracts/ConceroBridge.sol";
//import {Storage} from "contracts/Libraries/Storage.sol";
//
//contract ConceroMock is ConceroBridge {
//
//    constructor(
//            Storage.FunctionsVariables memory _variables,
//            uint64 _chainSelector,
//            uint _chainIndex,
//            address _link,
//            address _ccipRouter,
//            address _dexSwap,
//            address _pool,
//            address _proxy
//    ) ConceroBridge(
//            _variables,
//            _chainSelector,
//            _chainIndex,
//            _link,
//            _ccipRouter,
//            _dexSwap,
//            _pool,
//            _proxy
//    ){}
//
//    function externalFulfillRequest(bytes32 requestId, bytes memory response, bytes memory err) external {
//        fulfillRequest(requestId, response, err);
//    }
//
//    function getBnmToken() public pure returns (CCIPToken){
//        return CCIPToken.bnm;
//    }
//}
