/*
WARNING: THIS STILL DOESN'T WORK, DO NOT USE IT!
This task deploys a contract deterministically using the Create2 opcode.
It computes the address where the contract will be deployed before actually deploying it.
This is useful for deploying contracts at a specific address, such as a proxy contract.

To compute salt for a gas-efficient address, use create2crunch: https://github.com/0age/create2crunch.git

```bash
# set up the variables for create2crunch:
export FACTORY="0x0000000000ffe8b47b3e2130213b802212439497"
export CALLER="<YOUR_DEPLOYER_ADDRESS>"
export INIT_CODE_HASH="<initCodeHash>" # The one this task will log to console

# run create2crunch:
cargo run --release $FACTORY $CALLER $INIT_CODE_HASH
```
 */

import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { err, formatGas, getFallbackClients, log } from "../../utils";
import { keccak256, parseEther } from "viem";
import { conceroNetworks, viemReceiptConfig } from "../../constants";
import { type CNetwork } from "../../types/CNetwork";

export async function deployDeterministically(taskArgs: any, hre: HardhatRuntimeEnvironment) {
  const create2FactoryAddress = "0x0000000000ffe8b47b3e2130213b802212439497";
  const abi = (await import("../../constants/create2FactoryAbi.json")).default;

  const { salt, contractname, payableAmount, dryrun } = taskArgs;

  const deployableChain: CNetwork = conceroNetworks[hre.network.name];
  const { walletClient, publicClient, account } = getFallbackClients(deployableChain);

  const { deployedBytecode, bytecode } = await hre.artifacts.readArtifact(contractname);
  if (deployedBytecode === "0x") return err("Contract bytecode not found", "deterministic-deployment");

  const deployedBytecodeHash = keccak256(deployedBytecode);
  const bytecodeHash = keccak256(bytecode);
  console.log(`BYTECODE HASH: ${bytecodeHash}`);
  console.log(`DEPLOYED CONTRACT BYTECODE HASH: (Pass to create2crunch) ${deployedBytecodeHash}`);

  const computedAddress = await publicClient.readContract({
    address: create2FactoryAddress,
    abi,
    functionName: "findCreate2AddressViaHash",
    args: [salt, deployedBytecodeHash],
  });

  log(`Computed Create2 address: ${computedAddress}`, "deterministic-deployment");
  if (dryrun) return;

  const { request: deployRequest } = await publicClient.simulateContract({
    address: create2FactoryAddress,
    abi,
    functionName: "safeCreate2",
    args: [salt, deployedBytecode],
    value: parseEther(payableAmount),
    account,
  });

  const deployTxHash = await walletClient.writeContract(deployRequest);
  const receipt = await publicClient.waitForTransactionReceipt({
    ...viemReceiptConfig,
    hash: deployTxHash,
  });

  log(`Contract deployed successfully`, "deterministic-deployment");
  console.log(deployTxHash);
  log(`Gas used: ${formatGas(receipt.cumulativeGasUsed)}`, "deterministic-deployment");
  log(
    `WARNING: MAKE SURE TO MANUALLY UPDATE THE ENVIRONMENT VARIABLE IN THE .ENV FILE: ${computedAddress}`,
    "deterministic-deployment",
  );
}

task("deterministic-deployment", "Deploy a contract deterministically using Create2")
  .addFlag("dryrun", "Only computes the address WITHOUT deploying the contract. Use for testing")
  .addParam("salt", "The salt for the Create2 deployment. Pass salt from create2crunch")
  .addParam("contractname", "The name of the contract artifact to deploy. For example, TransparentUpgradeableProxy")
  .addOptionalParam("payableAmount", "The amount of ether to send with the deployment", "0")
  .setAction(deployDeterministically);
