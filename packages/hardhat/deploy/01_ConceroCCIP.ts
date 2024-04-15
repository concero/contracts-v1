import { ConceroCCIP } from "../artifacts/contracts/ConceroCCIP.sol";
import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const deployConceroCCIP: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;
  const chainId = await hre.getChainId();

  const deploymentOptions = {
    80001: {
      linkTokenAddress: process.env.LINK_MUMBAI,
      router: process.env.CL_CCIP_ROUTER_MUMBAI,
      oppositeChainSelector: process.env.CL_CCIP_CHAIN_SELECTOR_FUJI,
    },
    43113: {
      linkTokenAddress: process.env.LINK_FUJI,
      router: process.env.CL_CCIP_ROUTER_FUJI,
      oppositeChainSelector: process.env.CL_CCIP_CHAIN_SELECTOR_MUMBAI,
    },
  };

  if (!deploymentOptions[chainId]) throw new Error(`ChainId ${chainId} not supported`);
  const { linkTokenAddress, router, oppositeChainSelector } = deploymentOptions[chainId];

  const { address: contractAddress } = await deploy("ConceroCCIP", {
    from: deployer,
    log: true,
    args: [linkTokenAddress, router],
    autoMine: true,
  });

  const conceroCCIP = await hre.ethers.getContract<ConceroCCIP>("ConceroCCIP", deployer);

  await conceroCCIP.setAllowSourceChain(oppositeChainSelector, true);
  await conceroCCIP.setAllowDestinationChain(oppositeChainSelector, true);

  // exec(`npx hardhat verify --network polygonMumbai ${contractAddress} ${linkTokenAddress} ${router}`, (error, stdout, stderr) => {
  //   console.log(stdout);
  //   console.log(stderr);
  //   console.log(error);
  // });
};

deployConceroCCIP.tags = ["ConceroCCIP"];
export default deployConceroCCIP;