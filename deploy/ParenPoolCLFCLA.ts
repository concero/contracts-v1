import { Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { conceroNetworks, networkEnvKeys } from "../constants/conceroNetworks";
import updateEnvVariable from "../utils/updateEnvVariable";
import log from "../utils/log";
import { getEnvVar, getFallbackClients } from "../utils";
import { poolMessengers } from "../constants";
import { getGasParameters } from "../utils/getGasPrice";

interface Args {
  parentProxyAddress: string;
  lpToken: string;
  USDC: string;
  clfRouter: string;
  clfSubId: string;
  clfDonId: string;
  automationForwarder: string;
}

const deployParentPoolCLFCLA: (hre: HardhatRuntimeEnvironment, constructorArgs?: ConstructorArgs) => Promise<void> =
  async function (hre: HardhatRuntimeEnvironment, constructorArgs = {}) {
    const { proxyDeployer } = await hre.getNamedAccounts();
    const { deploy } = hre.deployments;
    const { name, live } = hre.network;
    const cNetwork = conceroNetworks[name];
    const networkType = cNetwork.type;

    const { functionsRouter, functionsSubIds, functionsDonId } = cNetwork;
    const { maxFeePerGas, maxPriorityFeePerGas } = await getGasParameters(conceroNetworks[name]);

    const defaultArgs: Args = {
      parentProxyAddress: getEnvVar(`PARENT_POOL_PROXY_${networkEnvKeys[name]}`),
      lpToken: getEnvVar(`LPTOKEN_${networkEnvKeys[name]}`),
      USDC: getEnvVar(`USDC_${networkEnvKeys[name]}`),
      clfRouter: functionsRouter,
      clfSubId: functionsSubIds[0],
      clfDonId: functionsDonId,
      automationForwarder: getEnvVar(`PARENT_POOL_AUTOMATION_FORWARDER_${networkEnvKeys[name]}`),
    };

    const args = { ...defaultArgs, ...constructorArgs };
    console.log("Deploying parent pool clf cla...");

    const deployParentPoolCLFCLA = (await deploy("ParentPoolCLFCLA", {
      from: proxyDeployer,
      args: [
        args.parentProxyAddress,
        args.lpToken,
        args.USDC,
        args.clfRouter,
        args.clfSubId,
        args.clfDonId,
        poolMessengers,
      ],
      log: true,
      autoMine: true,
      maxFeePerGas,
      maxPriorityFeePerGas,
    })) as Deployment;

    if (live) {
      log(`Parent pool clf cla deployed to ${name} to: ${deployParentPoolCLFCLA.address}`, "deployParentPoolCLFCLA");
      updateEnvVariable(
        `PARENT_POOL_CLF_CLA_${networkEnvKeys[name]}`,
        deployParentPoolCLFCLA.address,
        `deployments.${networkType}`,
      );
    }
  };

export default deployParentPoolCLFCLA;
deployParentPoolCLFCLA.tags = ["ParentPoolCLFCLA"];
