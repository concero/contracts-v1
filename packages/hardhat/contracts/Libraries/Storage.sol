//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IDexSwap} from "../Interfaces/IDexSwap.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IStorage} from "../Interfaces/IStorage.sol";
import {ConceroCCIP} from "../ConceroCCIP.sol";

////////////////////////////////////////////////////////
//////////////////////// ERRORS ////////////////////////
////////////////////////////////////////////////////////
///@notice error emitted when bridge data is empty
error Storage_InvalidBridgeData();
///@notice error emitted when a not allowed caller try to get CCIP information from storage
error Storage_CallerNotAllowed();
///@notice error emitted when a non-messenger address call a controlled function
error Storage_NotMessenger(address caller);

abstract contract Storage is IStorage {
  ///////////////
  ///CONSTANTS///
  ///////////////
  ///@notice removing magic-numbers
  uint256 internal constant APPROVED = 1;
  uint256 internal constant USDC_DECIMALS = 10 ** 6;
  uint256 internal constant STANDARD_TOKEN_DECIMALS = 10 ** 18;

  /////////////////////
  ///STATE VARIABLES///
  /////////////////////
  ///@notice variable to store the Chainlink Function DON Slot ID
  uint8 public s_donHostedSecretsSlotId;
  ///@notice variable to store the Chainlink Function DON Secret Version
  uint64 public s_donHostedSecretsVersion;
  ///@notice variable to store the Chainlink Function Source Hashsum
  bytes32 public s_srcJsHashSum;
  ///@notice variable to store the Chainlink Function Destination Hashsum
  bytes32 public s_dstJsHashSum;
  ///@notice variable to store Ethers Hashsum
  bytes32 public s_ethersHashSum;
  ///@notice Variable to store the Link to USDC latest rate
  uint256 public s_latestLinkUsdcRate;
  ///@notice Variable to store the Native to USDC latest rate
  uint256 public s_latestNativeUsdcRate;
  ///@notice Variable to store the Link to Native latest rate
  uint256 public s_latestLinkNativeRate;
  ///@notice gap to reserve storage in the contract for future variable additions
  uint256[50] __gap;

  /////////////
  ///STORAGE///
  /////////////
  ///@notice array of Pools to receive Liquidity through `ccipSend` function
  Pools[] poolsToDistribute;

  ///@notice Concero: Mapping to keep track of CLF fees for different chains
  mapping(uint64 => uint256) public clfPremiumFees;
  ///@notice DexSwap: mapping to keep track of allowed routers to perform swaps. 1 == Allowed.
  mapping(address router => uint256 isAllowed) public s_routerAllowed;
  ///@notice Mapping to keep track of allowed pool receiver
  mapping(uint64 chainSelector => address pool) public s_poolReceiver;
  ///@notice Functions: Mapping to keep track of Concero.sol contracts to send cross-chain Chainlink Functions messages
  mapping(uint64 chainSelector => address conceroContract) public s_conceroContracts;
  ///@notice Functions: Mapping to keep track of cross-chain transactions
  mapping(bytes32 => Transaction) public s_transactions;
  ///@notice Functions: Mapping to keep track of Chainlink Functions requests
  mapping(bytes32 => Request) public s_requests;
  ///@notice Functions: Mapping to keep track of cross-chain gas prices
  mapping(uint64 chainSelector => uint256 lasGasPrice) public s_lastGasPrices;

}
