const {
  logContract,
  logger
} = require('./utils');


const main = async () => {
  const [keyPair] = await locklift.keys.getKeyPairs();
  const SampleWallet = await locklift.factory.getAccount('SampleWallet');

  logger.log('Deploying Sample Wallet');
  let sampleWallet = await locklift.giver.deployContract({
    contract: SampleWallet,
    constructorParams: {
      owner: '0:fa94171cb0565789224814561cc558e59315971ee9d03085de3dcb5f8b94d95e',
      gasGiver: '0:945c629e67e57b5fa5656ef34577d6f851332bb6af70ba51b2334c5b25ca8cc1',
      minBalance: 1e9,  // 1 ever
      minReserve: 2e9,  // 2 ever
      tokenRoot: '0:f4a105beea18e3da096865ca6f0cc9e0885fcf464838ffa291841aa876485b61',  // Gas Token
    },
    initParams: {
      _randomNonce: locklift.utils.getRandomNonce(),
    },
    keyPair
  }, locklift.utils.convertCrystal(1.5, 'nano'));
  console.log(sampleWallet.address);
  await logContract(sampleWallet);
};


main()
  .then(() => process.exit(0))
  .catch(e => {
    console.log(e);
    process.exit(1);
  });
