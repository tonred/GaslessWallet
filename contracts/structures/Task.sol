pragma ever-solidity ^0.63.0;


struct Task {
    uint128 amount;
    address sender;
    uint128 neededGas;
    TvmCell meta;
}
