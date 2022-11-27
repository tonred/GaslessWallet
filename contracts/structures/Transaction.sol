pragma ever-solidity ^0.63.0;


struct Transaction {
    address destination;
    uint128 value;
    uint8 flag;
    bool bounce;
    TvmCell payload;
}
