pragma ever-solidity ^0.63.0;


interface IGaslessWallet {
    function onExchanged(TvmCell meta) external view;
}
