import {
  Account,
  AccountAddress,
  AnyNumber,
  Aptos,
  AptosConfig,
  MoveString,
  MoveVector,
  Network,
  NetworkToNetworkName,
  Serializable,
  Serializer,
  U64,
} from "@aptos-labs/ts-sdk";
const APTOS_NETWORK: Network = Network.TESTNET;
const ALICE_INITIAL_BALANCE = 100_000_000;
const contractAddress = `0x010e9d09c4c87a2495dc778faeba68ce6a8d7bce7f967adf11abf4fb53b1ed54`;
const example = async () => {
  const config = new AptosConfig({ network: APTOS_NETWORK });
  const aptos = new Aptos(config);
  const alice = Account.generate();
  console.log("=== Addresses ===\n");
  console.log(`Alice's address is: ${alice.accountAddress}`);
  await aptos.faucet.fundAccount({
    accountAddress: alice.accountAddress,
    amount: ALICE_INITIAL_BALANCE,
  });
  const claimCoins = await aptos.transaction.build.simple({
    sender: alice.accountAddress,
    data: {
      function: `${contractAddress}::elevtrix_nft::deploy`,
      functionArguments: ["test12", "test12", "0x1"],
    },
  });
  const claimCoinsResponse = await aptos.signAndSubmitTransaction({
    signer: alice,
    transaction: claimCoins,
  });
  console.log(`Claim Coins Transaction hash: ${claimCoinsResponse.hash}`);
  await aptos.waitForTransaction({
    transactionHash: claimCoinsResponse.hash,
  });
};

example()
  .then(() => {
    console.log("Done");
  })
  .catch((e) => {
    console.error(e);
  });
