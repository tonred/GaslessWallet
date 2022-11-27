const {
  logContract,
  logger
} = require('./utils');


const main = async () => {
  const [keyPair] = await locklift.keys.getKeyPairs();
  const GasGiver = await locklift.factory.getAccount('GasGiver');

  logger.log('Deploying Gas Giver');
  let gasGiver = await locklift.giver.deployContract({
    contract: GasGiver,
    constructorParams: {
      owner: '0:fa94171cb0565789224814561cc558e59315971ee9d03085de3dcb5f8b94d95e',
      config: {
        tokenRoot: '0:f4a105beea18e3da096865ca6f0cc9e0885fcf464838ffa291841aa876485b61',  // Gas Token
        dexPair: '0:63f194a0c323b953a3ed9f4c927e687e363e934cd272faca14dd62e82ea6e638',    // GAS-WEVER pair
        slippage: 10000,    // 10%
        feePercent: 3000,   // 3%
        maxGas: 100e9,      // 100 ever
        reserve: 5e9,       // 5 ever
      }
    },
    initParams: {
      _randomNonce: locklift.utils.getRandomNonce(),
    },
    keyPair
  }, locklift.utils.convertCrystal(10.5, 'nano'));
  console.log(gasGiver.address);
  await logContract(gasGiver);
};


main()
  .then(() => process.exit(0))
  .catch(e => {
    console.log(e);
    process.exit(1);
  });
