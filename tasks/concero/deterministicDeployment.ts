/*
This task deploys a contract deterministically using the Create2 opcode.
It computes the address where the contract will be deployed before actually deploying it.
This is useful for deploying contracts at a specific address, such as a proxy contract.

To compute salt for a gas-efficient address, use createXcrunch: https://github.com/HrikB/createXcrunch

```bash
# set up the variables for createXcrunch:
export FACTORY="0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed" (default)
export CALLER="<DEPLOYER_ADDRESS>"
export $CODE_HASH="<CODE_HASH>"

# run createXcrunch:
./target/release/createxcrunch create2 --leading 3 --factory=$FACTORY --caller=$CALLER --code-hash=$CODE_HASH

# Example output
<SALT_TO_COPY> => <DEPLOYMENT_ADDRESS>
```
 */

import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { err, formatGas, getEnvAddress, getFallbackClients, log } from "../../utils";
import { encodeDeployData, keccak256, zeroHash } from "viem";
import { conceroNetworks, viemReceiptConfig } from "../../constants";
import { type CNetwork } from "../../types/CNetwork";

const CREATEX_FACTORY_ADDRESS = "0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed";

const getContractInitCode = async (
  contractName: string,
  networkName: string,
  bytecode: `0x${string}`,
): Promise<`0x${string}`> => {
  switch (contractName) {
    case "TransparentUpgradeableProxy": {
      const { abi } = await import(
        "../../artifacts/contracts/Proxy/TransparentUpgradeableProxy.sol/TransparentUpgradeableProxy.json"
      );
      const [initialImplementation] = getEnvAddress("pause", networkName);
      const [proxyAdmin] = getEnvAddress("infraProxyAdmin", networkName);

      return encodeDeployData({
        abi,
        bytecode,
        args: [initialImplementation, proxyAdmin, "0x"],
      });
    }
    default:
      throw new Error(`Contract ${contractName} not supported for deterministic deployment`);
  }
};

export async function deployDeterministically(taskArgs: any, hre: HardhatRuntimeEnvironment) {
  const createXFactoryAbi = (await import("../../constants/createXFactory.json")).default;

  const { contractname, dryrun } = taskArgs;
  const salt = taskArgs.salt || zeroHash;
  const deployableChain: CNetwork = conceroNetworks[hre.network.name];
  const { walletClient, publicClient, account } = getFallbackClients(deployableChain);

  const { deployedBytecode, bytecode } = await hre.artifacts.readArtifact(contractname);
  if (deployedBytecode === "0x") return err("Contract bytecode not found", "deterministic-deployment");

  const initBytecode = await getContractInitCode(contractname, hre.network.name, bytecode);
  const initBytecodeHash = keccak256(initBytecode);

  log(`Init bytecode: ${initBytecode}`, "deterministic-deployment");
  log(`Init bytecode hash: (Pass to create2crunch) ${initBytecodeHash}`, "deterministic-deployment");

  const { request: deployRequest, result: deployResult } = await publicClient.simulateContract({
    address: CREATEX_FACTORY_ADDRESS,
    abi: createXFactoryAbi,
    functionName: "deployCreate2",
    args: [salt, initBytecode],
    account,
  });

  log(`Computed address: ${deployResult}`, "deterministic-deployment");
  if (dryrun) return;

  const deployTxHash = await walletClient.writeContract(deployRequest);
  const receipt = await publicClient.waitForTransactionReceipt({
    ...viemReceiptConfig,
    hash: deployTxHash,
  });

  log(
    `Contract deployed successfully at tx: ${deployTxHash} Gas: ${formatGas(receipt.cumulativeGasUsed)}`,
    "deterministic-deployment",
    hre.network.name,
  );

  const networkType = conceroNetworks[hre.network.name].type;
  log(
    `WARNING: MAKE SURE TO MANUALLY UPDATE THE ENVIRONMENT VARIABLE IN THE .ENV FILE:
    transparentProxy=${deployResult}
    in the deployments.${networkType} section`,
    "deterministic-deployment",
  );
}

/*
First, get the deployment bytecode and its hash to use in createxcrunch:
```bash
npx hardhat deterministic-deployment --contractname="TransparentUpgradeableProxy" --dryrun
```

After the gas-efficient salt is computed, run the following command to check the deployment address:
```bash
npx hardhat deterministic-deployment --salt="<SALT>" --contractname="TransparentUpgradeableProxy" --dryrun
```

Finally, to deploy the contract deterministically, run the following command:
```bash
npx hardhat deterministic-deployment --salt="<SALT>" --contractname="TransparentUpgradeableProxy"
```
 */
task("deterministic-deployment", "Deploy a contract deterministically using Create2")
  .addFlag("dryrun", "Only computes the address WITHOUT deploying the contract. Use for testing")
  .addParam("contractname", "The name of the contract artifact to deploy. For example, TransparentUpgradeableProxy")
  .addOptionalParam("salt", "The salt for the Create2 deployment. Pass salt from create2crunch")
  .setAction(deployDeterministically);
