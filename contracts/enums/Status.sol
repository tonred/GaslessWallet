pragma ever-solidity ^0.63.0;


enum Status {
    UNINITIALIZED,      // 0
    WAITING_WALLETS,    // 1
    WAITING_AMOUNT,     // 2
    ACTIVE              // 3
}
