pragma ever-solidity ^0.63.0;


struct Config {
    address tokenRoot;  // payment token
    address dexPair;    // dex pair address
    uint128 slippage;   // exchange slippage (in Constants.PERCENT_DENOMINATOR unit)
    uint128 feePercent; // exchange fee (in Constants.PERCENT_DENOMINATOR unit)
    uint128 maxGas;     // maximum amount to exchange in one transaction
    uint128 reserve;    // reserve value in Gas Giver
}
