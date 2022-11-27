pragma ever-solidity ^0.63.0;


enum ReturnReason {
    IS_NOT_ACTIVE,      // 0
    LOW_MSG_VALUE,      // 1
    INVALID_PAYLOAD,    // 2
    INVALID_AMOUNT      // 3
}
