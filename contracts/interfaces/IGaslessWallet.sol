pragma ever-solidity ^0.63.0;


interface IGaslessWallet {
    function onPriceChanged(uint128 amount, TvmCell payload) external;
    function onExchanged(TvmCell meta) external;
}
