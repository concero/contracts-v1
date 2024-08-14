import deployCCIPInfrastructure from "./deployInfra/deployInfra";
import deployConceroDexSwap from "./deployInfra/deployConceroDexSwap";
import deployConceroOrchestrator from "./deployInfra/deployConceroOrchestrator";

import deployChildPool from "./deployPool/deployChildPool";
import deployAllPools from "./deployPool/deployAllPools";
import deployParentPool from "./deployPool/deployParentPool";
import deployLpToken from "./deployLpToken/deployLpToken";
import deployAutomations from "./deployAutomations/deployAutomations";
import withdrawInfraProxy from "./withdraw/withdrawInfraProxy";
import withdrawParentPoolDepositFee from "./withdraw/withdrawParentPoolDepositFee";
import upgradeProxyImplementation from "./upgradeProxyImplementation";
import changeOwnership from "./changeOwnership";

import ensureBalances from "./ensureBalances/ensureBalances";
import ensureERC20Balances from "./ensureBalances/ensureErc20Balances";

import fundContract from "./fundContract";
import dripBnm from "./dripBnm";
import transferTokens from "./transferTokens";

import testScript from "./test";

export default {
  deployConceroDexSwap,
  deployConceroOrchestrator,
  withdrawInfraProxy,
  deployParentPool,
  deployLpToken,
  deployAutomations,
  deployChildPool,
  deployAllPools,
  upgradeProxyImplementation,
  changeOwnership,
  withdrawParentPoolDepositFee,
  ensureBalances,
  ensureERC20Balances,
  deployCCIPInfrastructure,
  fundContract,
  dripBnm,
  transferTokens,
  testScript,
}