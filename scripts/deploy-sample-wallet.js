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
      gasGiver: '0:2a281c76625457a06f9edaed1411f56ddeda785c9d10838baaeb938f590f9d94',
      minBalance: 2e9,  // 2 ever
      minReserve: 5e9,  // 5 ever
      tokenRoot: '0:f4a105beea18e3da096865ca6f0cc9e0885fcf464838ffa291841aa876485b61',  // Gas Token
    },
    initParams: {
      _randomNonce: locklift.utils.getRandomNonce(),
    },
    keyPair
  }, locklift.utils.convertCrystal(5.5, 'nano'));
  console.log(sampleWallet.address);
  await logContract(sampleWallet);
};


main()
  .then(() => process.exit(0))
  .catch(e => {
    console.log(e);
    process.exit(1);
  });
