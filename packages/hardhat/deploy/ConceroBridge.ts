import { Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import chains, { networkEnvKeys } from "../constants/cNetworks";
import updateEnvVariable from "../utils/updateEnvVariable";
import log from "../utils/log";
import { getEnvVar } from "../utils";
import { messengers } from "../constants";

interface ConstructorArgs {
  slotId?: number;
  functionsRouter?: string;
  donHostedSecretsVersion?: number;
  functionsDonId?: string;
  functionsSubId?: string;
  chainSelector?: string;
  conceroChainIndex?: number;
  linkToken?: string;
  ccipRouter?: string;
  dexSwapModule?: string;
  messengers?: string[];
}

const deployConceroBridge: (hre: HardhatRuntimeEnvironment, constructorArgs?: ConstructorArgs) => Promise<void> =
  async function (hre: HardhatRuntimeEnvironment, constructorArgs: ConstructorArgs = {}) {
    const { deployer } = await hre.getNamedAccounts();
    const { deploy } = hre.deployments;
    const { name, live } = hre.network;
    const networkType = chains[name].type;

    if (!chains[name]) {
      throw new Error(`Chain ${name} not supported`);
    }

    const {
      functionsRouter,
      donHostedSecretsVersion,
      functionsDonId,
      functionsSubIds,
      chainSelector,
      conceroChainIndex,
      linkToken,
      ccipRouter,
    } = chains[name];

    const defaultArgs = {
      chainSelector: chainSelector,
      conceroChainIndex: conceroChainIndex,
      linkToken: linkToken,
      ccipRouter: ccipRouter,
      dexSwapModule: getEnvVar(`CONCERO_DEX_SWAP_${networkEnvKeys[name]}`),
      functionsVars: {
        donHostedSecretsSlotId: constructorArgs.slotId || 0,
        donHostedSecretsVersion: donHostedSecretsVersion,
        subscriptionId: functionsSubIds[0],
        donId: functionsDonId,
        functionsRouter: functionsRouter,
      },
      conceroPoolAddress:
        name === "base" || name === "baseSepolia"
          ? getEnvVar(`PARENT_POOL_PROXY_${networkEnvKeys[name]}`)
          : getEnvVar(`CHILD_POOL_PROXY_${networkEnvKeys[name]}`),
      conceroProxyAddress: getEnvVar(`CONCERO_INFRA_PROXY_${networkEnvKeys[name]}`),
      messengers,
    };

    const args = { ...defaultArgs, ...constructorArgs };

    const deployment = (await deploy("ConceroBridge", {
      from: deployer,
      log: true,
      args: [
        args.functionsVars,
        args.chainSelector,
        args.conceroChainIndex,
        args.linkToken,
        args.ccipRouter,
        args.dexSwapModule,
        args.conceroPoolAddress,
        args.conceroProxyAddress,
        args.messengers,
      ],
      autoMine: true,
    })) as Deployment;

    if (live) {
      log(`Deployed at: ${deployment.address}`, "conceroBridge", name);
      updateEnvVariable(`CONCERO_BRIDGE_${networkEnvKeys[name]}`, deployment.address, `deployments.${networkType}`);
    }
  };

export default deployConceroBridge;
deployConceroBridge.tags = ["ConceroBridge"];