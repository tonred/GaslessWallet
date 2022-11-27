pragma ever-solidity ^0.63.0;

pragma AbiHeader time;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "../GaslessWallet.sol";

import "@broxus/contracts/contracts/utils/RandomNonce.sol";
import "tip3/contracts/interfaces/ITokenRoot.sol";


contract SampleWallet is GaslessWallet, RandomNonce {

    address public _initGasGiver;
    uint128 public _initMinBalance;
    uint128 public _initMinReserve;
    address public _initTokenRoot;

    constructor(address gasGiver, uint128 minBalance, uint128 minReserve, address tokenRoot) public {
        tvm.accept();
        _initGasGiver = gasGiver;
        _initMinBalance = minBalance;
        _initMinReserve = minReserve;
        _initTokenRoot = tokenRoot;
        ITokenRoot(tokenRoot).deployWallet{
            value: Gas.DEPLOY_WALLET_VALUE + Gas.DEPLOY_WALLET_GRAMS,
            flag: MsgFlag.SENDER_PAYS_FEES,
            callback: onWalletDeployed,
            bounce: false
        }({
            owner: address(this),
            deployWalletValue: Gas.DEPLOY_WALLET_GRAMS
        });
    }

    function onWalletDeployed(address tokenWallet) public {
        require(msg.sender == _initTokenRoot && msg.sender.value != 0, ErrorCodes.IS_NOT_TOKEN);
        _init(_initGasGiver, _initMinBalance, _initMinReserve, tokenWallet);
    }


    // from https://github.com/tonlabs/ton-labs-contracts/blob/master/solidity/safemultisig/SafeMultisigWallet.sol#L212
    function sendTransaction(address dest, uint128 value, bool bounce, uint8 flags, TvmCell payload) public view {
        tvm.accept();
        _sendTransaction(Transaction(dest, value, flags, bounce, payload));
    }

    function drain() public pure {
        msg.sender.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED, bounce: false});
    }

    function withdraw(uint128 amount) public view {
        TvmCell empty;
        ITokenWallet(_tokenWallet).transfer{
            value: 0.1 ever,
            flag: MsgFlag.SENDER_PAYS_FEES,
            bounce: false
        }({
            amount: amount,
            recipient: msg.sender,
            deployWalletValue: 0,
            remainingGasTo: msg.sender,
            notify: false,
            payload: empty
        });
    }

}
