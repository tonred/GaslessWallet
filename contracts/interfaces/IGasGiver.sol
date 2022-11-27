pragma ever-solidity ^0.63.0;


interface IGasGiver {
    function getMaxGas() external view responsible returns (uint128 maxGas);
    function getExpectedAmount(TvmCell payload) external view responsible returns (uint128 amount, TvmCell payload_);
}
