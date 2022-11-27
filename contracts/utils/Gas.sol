pragma ever-solidity ^0.63.0;


library Gas {

    // Common
    uint128 constant GIVER_TRIGGER_VALUE    = 0.5 ever;  // more than ON_PRICE_CHANGED
    uint128 constant OVERHEAD_VALUE         = 0.1 ever;

    // Gas Giver
    uint128 constant DEPLOY_WALLET_VALUE    = 0.1 ever;
    uint128 constant DEPLOY_WALLET_GRAMS    = 0.1 ever;
    uint128 constant EXPECTED_AMOUNT_VALUE  = 0.1 ever;
    uint128 constant ON_PRICE_CHANGED       = 0.2 ever;
    uint128 constant SWAP_VALUE             = 2.2 ever;
    uint128 constant UNWRAP_VALUE           = 1.5 ever;

    // Gasless Wallet
    uint128 constant GET_MAX_GAS_VALUE      = 0.2 ever;
    uint128 constant MIN_REQUEST_GAS        = 2 ever;  // todo 10
    uint128 constant GET_AMOUNT_VALUE       = 0.3 ever;
    uint128 constant TRANSFER_TOKEN_VALUE   = 0.2 ever;

}
