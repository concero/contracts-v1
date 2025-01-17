import donSecretsList from "./donSecrets/list";
import donSecretsUpload from "./donSecrets/upload";

import info from "./subscriptions/info";
import add from "./subscriptions/add";
import fund from "./subscriptions/fund";
import transfer from "./subscriptions/transfer";
import accept from "./subscriptions/accept";
import remove from "./subscriptions/remove";
import timeout from "./subscriptions/timeout";

import consumer from "./unused/Functions-consumer";
import clfRequest from "./unused/Functions-consumer";
import fetchDONSigners from "./fetchDONSigners";
// import getHashSum from "./CLFScripts/listHashes";

export default {
  info,
  add,
  fund,
  consumer,
  transfer,
  accept,
  clfRequest,
  remove,
  timeout,
  donSecretsList,
  donSecretsUpload,
  fetchDONSigners,
};
