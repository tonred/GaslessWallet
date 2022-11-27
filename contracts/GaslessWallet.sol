pragma ever-solidity ^0.63.0;

pragma AbiHeader time;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "./interfaces/IGasGiver.sol";
import "./interfaces/IGaslessWallet.sol";
import "./structures/Transaction.sol";
import "./utils/ErrorCodes.sol";
import "./utils/Gas.sol";

import "@broxus/contracts/contracts/libraries/MsgFlag.sol";
import "tip3/contracts/interfaces/ITokenWallet.sol";


abstract contract GaslessWallet is IGaslessWallet {

    address public _gasGiver;
    uint128 public _minBalance;
    uint128 public _minReserve;
    address public _tokenWallet;
    uint128 public _maxGas;

    modifier onlyGasGiver() {
        require(msg.sender == _gasGiver && msg.sender.value != 0, ErrorCodes.IS_NOT_GAS_GIVER);
        _;
    }

    function _init(address gasGiver, uint128 minBalance, uint128 minReserve, address tokenWallet) internal {
        require(minBalance < minReserve, ErrorCodes.INVALID_INIT_PARAMS);
        _gasGiver = gasGiver;
        _minBalance = minBalance;
        _minReserve = minReserve;
        _tokenWallet = tokenWallet;
        IGasGiver(_gasGiver).getMaxGas{
            value: Gas.GET_MAX_GAS_VALUE,
            flag: MsgFlag.SENDER_PAYS_FEES,
            bounce: false,
            callback: onGetMaxGas
        }();
    }

    function onGetMaxGas(uint128 maxGas) public onlyGasGiver {
        _maxGas = maxGas - Gas.OVERHEAD_VALUE;
    }


    function _sendTransaction(Transaction transaction) internal view {
        require(transaction.value <= _maxGas, ErrorCodes.INVALID_TRANSACTION_VALUE);
        require(transaction.flag & (32 + 64 + 128) == 0, ErrorCodes.INVALID_TRANSACTION_FLAG);
        if (address(this).balance > _minBalance + transaction.value) {
            // enough balance
            _processTransaction(transaction);
        } else {
            // not enough balance
            TvmCell meta = abi.encode(transaction);
            _requestGas(transaction.value, meta);
        }
    }

    function _processTransaction(Transaction transaction) private view {
        _execute(transaction);
        if (address(this).balance <= _minReserve + transaction.value) {
            TvmCell meta;
            _requestGas(transaction.value, meta);
        }
    }

    function _execute(Transaction transaction) private pure {
        transaction.destination.transfer({
            value: transaction.value,
            flag: transaction.flag,
            bounce: transaction.bounce,
            body: transaction.payload
        });
    }

    function _requestGas(uint128 value, TvmCell meta) private view {
        uint128 neededGas = math.max(value, Gas.MIN_REQUEST_GAS) + Gas.OVERHEAD_VALUE;
        TvmCell payload = abi.encode(neededGas, meta);
        IGasGiver(_gasGiver).getExpectedAmount{
            value: Gas.GET_AMOUNT_VALUE,
            flag: MsgFlag.SENDER_PAYS_FEES,
            bounce: false,
            callback: onGetExpectedAmount
        }(payload);
    }

    function onGetExpectedAmount(uint128 amount, TvmCell payload) public view onlyGasGiver {
        _transferToGasGiver(amount, payload);
    }

    function _transferToGasGiver(uint128 amount, TvmCell payload) private view {
        ITokenWallet(_tokenWallet).transfer{
            value: Gas.GIVER_TRIGGER_VALUE + Gas.TRANSFER_TOKEN_VALUE,
            flag: MsgFlag.SENDER_PAYS_FEES,
            bounce: false
        }({
            amount: amount,
            recipient: _gasGiver,
            deployWalletValue: 0,
            remainingGasTo: address(this),
            notify: true,
            payload: payload
        });
    }

    function onExchanged(TvmCell meta) public view override onlyGasGiver {
        if (meta.toSlice().empty()) {
            // just accept evers
            return;
        }
        Transaction transaction = abi.decode(meta, Transaction);
        _processTransaction(transaction);
    }

}
