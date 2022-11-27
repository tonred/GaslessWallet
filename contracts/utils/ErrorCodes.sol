pragma ever-solidity ^0.63.0;


library ErrorCodes {

    // Gas Giver
    uint16 constant IS_NOT_OWNER                = 1001;
    uint16 constant WRONG_STATUS                = 1002;
    uint16 constant LOW_MSG_VALUE               = 1003;
    uint16 constant IS_NOT_DEX_PAIR             = 1004;
    uint16 constant IS_NOT_TOKEN                = 1005;
    uint16 constant IS_NOT_WALLET               = 1006;
    uint16 constant INVALID_UNWRAP_RESPONSE     = 1007;

    // Gasless Wallet
    uint16 constant IS_NOT_GAS_GIVER            = 2001;
    uint16 constant INVALID_INIT_PARAMS         = 2002;
    uint16 constant INVALID_TRANSACTION_VALUE   = 2003;
    uint16 constant INVALID_TRANSACTION_FLAG    = 2004;


}
