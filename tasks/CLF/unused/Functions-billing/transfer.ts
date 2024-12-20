"use strict";
import { HardhatRuntimeEnvironment } from "hardhat/types";

var __importDefault =
  (this && this.__importDefault) ||
  function (mod) {
    return mod && mod.__esModule ? mod : { default: mod };
  };
Object.defineProperty(exports, "__esModule", { value: true });
const config_1 = require("hardhat/config");
const functions_toolkit_1 = require("@chainlink/functions-toolkit");
const CNetworks_1 = __importDefault(require("../../../../constants/conceroNetworks"));
(0, config_1.task)("clf-sub-transfer", "Request ownership of an Functions subscription be transferred to a new address")
  .addParam("subid", "Subscription ID")
  .addParam("newowner", "Address of the new owner")
  .setAction(async taskArgs => {
    const hre: HardhatRuntimeEnvironment = require("hardhat");
    const { name, live } = hre.network;
    if (!CNetworks_1.default[name]) throw new Error(`Chain ${name} not supported`);
    const subscriptionId = parseInt(taskArgs.subid);
    const newOwner = taskArgs.newowner;
    const { linkToken, functionsRouter, confirmations } = CNetworks_1.default[name];
    const txOptions = { confirmations };
    const signer = (await hre.ethers.getSigners())[0]; // First wallet.
    // await utils.prompt(
    //   `\nTransferring the subscription to a new owner will require generating a new signature for encrypted secrets. ` +
    //     `Any previous encrypted secrets will no longer work with subscription ID ${subscriptionId} and must be regenerated by the new owner.`,
    // );
    const sm = new functions_toolkit_1.SubscriptionManager({
      signer,
      linkTokenAddress: linkToken,
      functionsRouterAddress: functionsRouter,
    });
    await sm.initialize();
    console.log(`\nRequesting transfer of subscription ${subscriptionId} to new owner ${newOwner}`);
    const requestTransferTx = await sm.requestSubscriptionTransfer({ subscriptionId, newOwner, txOptions });
    console.log(
      `Transfer request completed in Tx: ${requestTransferTx.transactionHash}\nAccount ${newOwner} needs to accept transfer for it to complete.`,
    );
  });
exports.default = {};
