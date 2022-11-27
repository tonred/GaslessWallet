pragma ever-solidity ^0.63.0;

pragma AbiHeader time;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "./enums/ReturnReason.sol";
import "./enums/Status.sol";
import "./interfaces/IGaslessWallet.sol";
import "./interfaces/IUpgradable.sol";
import "./structures/Config.sol";
import "./structures/Task.sol";
import "./utils/Constants.sol";
import "./utils/ErrorCodes.sol";
import "./utils/Gas.sol";

import "@broxus/contracts/contracts/libraries/MsgFlag.sol";
import "@broxus/contracts/contracts/utils/RandomNonce.sol";
import "tip3/contracts/interfaces/ITokenRoot.sol";
import "tip3/contracts/interfaces/ITokenWallet.sol";
import "tip3/contracts/interfaces/IAcceptTokensBurnCallback.sol";
import "tip3/contracts/interfaces/IBounceTokensTransferCallback.sol";
import "flatqube/contracts/interfaces/IDexPair.sol";
import "flatqube/contracts/libraries/DexOperationTypes.sol";


contract GasGiver is IAcceptTokensTransferCallback, IAcceptTokensBurnCallback, IBounceTokensTransferCallback, IUpgradable, RandomNonce {

    event Swap(uint128 amount);

    address public _owner;
    Config public _config;
    Status public _status;

    address public _weverWallet;
    address public _tokenWallet;
    uint128 public _tokenBalance;

    uint128 public _swapTokenAmount;
    uint128 public _swapWeverAmount;
    uint128 public _expectedUnwrapAmount;
    bool public _inSwap;

    uint64 public _head;
    uint64 public _tail;
    mapping(uint64 => Task) public _queue;


    modifier onlyOwner() {
        require(msg.sender == _owner, ErrorCodes.IS_NOT_OWNER);
        _;
    }

    modifier onStatus(Status status) {
        require(_status == _status, ErrorCodes.WRONG_STATUS);
        _;
    }


    constructor(address owner, Config config) public onStatus(Status.UNINITIALIZED) {
        tvm.accept();
        _owner = owner;
        _config = config;
        address wever_root = address.makeAddrStd(0, Constants.WEVER_ROOT_VALUE);
        _createWallet(wever_root);
        _createWallet(_config.tokenRoot);
        _status = Status.WAITING_WALLETS;
        require(_remains() > 0, ErrorCodes.LOW_MSG_VALUE);
    }

    function _createWallet(address token) private pure {
        ITokenRoot(token).deployWallet{
            value: Gas.DEPLOY_WALLET_VALUE + Gas.DEPLOY_WALLET_GRAMS,
            flag: MsgFlag.SENDER_PAYS_FEES,
            callback: onWalletDeployed,
            bounce: false
        }({
            owner: address(this),
            deployWalletValue: Gas.DEPLOY_WALLET_GRAMS
        });
    }

    function onWalletDeployed(address wallet) public onStatus(Status.WAITING_WALLETS) {
        require(msg.sender.value != 0, ErrorCodes.IS_NOT_TOKEN);
        address wever_root = address.makeAddrStd(0, Constants.WEVER_ROOT_VALUE);
        if (msg.sender == _config.tokenRoot) {
            _tokenWallet = wallet;
            if (_weverWallet.value != 0) {
                _expectedAmount();
            }
        } else if (msg.sender == wever_root) {
            _weverWallet = wallet;
            if (_tokenWallet.value != 0) {
                _expectedAmount();
            }
        } else {
            revert(ErrorCodes.IS_NOT_TOKEN);
        }
    }

    function _expectedAmount() private {
        _status = Status.WAITING_AMOUNT;
        _swapWeverAmount = _remains();
        address wever_root = address.makeAddrStd(0, Constants.WEVER_ROOT_VALUE);
        IDexPair(_config.dexPair).expectedSpendAmount{
            value: Gas.EXPECTED_AMOUNT_VALUE,
            flag: MsgFlag.SENDER_PAYS_FEES,
            bounce: false,
            callback: onExpectedAmount
        }(_swapWeverAmount, wever_root);
    }

    function onExpectedAmount(uint128 expectedAmount, uint128 /*expectedFee*/) public onStatus(Status.WAITING_AMOUNT) {
        require(msg.sender == _config.dexPair && msg.sender.value != 0, ErrorCodes.IS_NOT_DEX_PAIR);
        _status = Status.ACTIVE;
        _swapTokenAmount = expectedAmount;
    }


    function drain(uint128 amount) public view onlyOwner {
        msg.sender.transfer({value: amount, flag: MsgFlag.REMAINING_GAS, bounce: false});
    }

    function withdraw(bool isToken, uint128 amount) public onlyOwner {
        TvmCell empty;
        _transfer({
            isToken: isToken,
            amount: amount,
            recipient: _owner,
            payload: empty,
            value: 0,
            flag: MsgFlag.REMAINING_GAS
        });
    }


    function getMaxGas() public view responsible returns (uint128 maxGas) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _config.maxGas;
    }

    function getExpectedAmount(TvmCell payload) public view responsible returns (uint128 amount, TvmCell payload_) {
        uint128 neededGas = payload.toSlice().decode(uint128);
        amount = _expectedTokenAmount(neededGas);
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} (amount, payload);
    }

    function expectedTokenAmount(uint128 gasAmount) public view responsible returns (uint128 tokenAmount) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _expectedTokenAmount(gasAmount);
    }

    function expectedGasAmount(uint128 tokenAmount) public view responsible returns (uint128 gasAmount) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _expectedGasAmount(tokenAmount);
    }


    function onAcceptTokensTransfer(
        address /*token*/,
        uint128 amount,
        address sender,
        address /*senderWallet*/,
        address /*remainingGasTo*/,
        TvmCell payload
    ) public override {
        emit todo(12);
        require(msg.sender.value != 0, ErrorCodes.IS_NOT_WALLET);
        if (msg.sender == _tokenWallet) {
            emit todo(13);
            _tokenBalance += amount;
            if (_status != Status.ACTIVE) {
                _returnTokens(amount, sender, ReturnReason.IS_NOT_ACTIVE);
                return;
            }
            emit todo(14);
            (optional(Task) taskOpt, optional(ReturnReason) reasonOpt) = _createTask(amount, sender, payload);
            if (reasonOpt.hasValue()) {
                ReturnReason reason = reasonOpt.get();
                _returnTokens(amount, sender, reason);
                return;
            }
            Task task = taskOpt.get();
            emit todo(15);
            if (_inSwap) {
                _pushTask(task);
            } else {
                emit todo(16);
                _exchange(task);
            }
        } else if (msg.sender == _weverWallet) {
            _unwrap(amount);
        } else {
            revert(ErrorCodes.IS_NOT_WALLET);
        }
    }

    function _createTask(
        uint128 amount, address sender, TvmCell payload
    ) private view returns (optional(Task), optional(ReturnReason)) {
        TvmSlice slice = payload.toSlice();
        if (msg.value < Gas.GIVER_TRIGGER_VALUE) {
            return (null, ReturnReason.LOW_MSG_VALUE);
        }
        if (!slice.hasNBits(128)) {
            return (null, ReturnReason.INVALID_PAYLOAD);
        }
        uint128 neededGas = slice.decode(uint128);
        if (neededGas == 0 || neededGas > _config.maxGas) {
            return (null, ReturnReason.INVALID_AMOUNT);
        }
        TvmCell meta;
        if (slice.hasNRefs(1)) {
            meta = slice.loadRef();
        }
        return (Task(amount, sender, neededGas, meta), null);
    }

    event todo(uint64 v);  // todo rm
    function _exchange(Task task) private returns (bool terminate) {
        emit todo(1);
        uint128 expectedGas = _expectedGasAmount(task.amount);
        if (task.neededGas > expectedGas) {
            emit todo(2);
            // price was changed (user sent not enough tokens) -> skip task, send user right amount
            // todo !!! send as least this amount of tokens
            emit todo(99);
            uint128 neededGas = task.neededGas + Gas.OVERHEAD_VALUE;
            TvmCell payload = abi.encode(neededGas, task.meta);
            uint128 amount = _expectedTokenAmount(neededGas);
            IGaslessWallet(task.sender).onPriceChanged{
                value: Gas.ON_PRICE_CHANGED,
                flag: MsgFlag.SENDER_PAYS_FEES,
                bounce: false
            }(amount, payload);
            return false;
        }
        if (_remains() < expectedGas) {
            emit todo(3);
            // not enough tokens in giver -> stop tasks, swap in dex
            _pushTask(task);
            _swap();
            return true;
        }
        emit todo(4);
        // everything is ok
        IGaslessWallet(task.sender).onExchanged{
            value: expectedGas,
            flag: MsgFlag.SENDER_PAYS_FEES,
            bounce: false
        }(task.meta);
        return false;
    }

    function _swap() private {
        _swapTokenAmount = _tokenBalance;
        emit Swap(_tokenBalance);
        TvmCell payload = _buildSwapPayload();
        _transfer({
            isToken: true,
            amount: _tokenBalance,
            recipient: _config.dexPair,
            payload: payload,
            value: Gas.SWAP_VALUE,
            flag: MsgFlag.SENDER_PAYS_FEES
        });
        _inSwap = true;
    }

    function _buildSwapPayload() private pure returns (TvmCell) {
        TvmBuilder builder;
        TvmCell successPayload = abi.encode(true);
        builder.store(DexOperationTypes.EXCHANGE);  // operation type
        builder.store(uint64(0));                   // id
        builder.store(uint128(0));                  // deploy wallet grams
        builder.store(uint128(0));                  // expected amount (minimum)
        builder.storeRef(successPayload);           // [ref] on success payload
        return builder.toCell();
    }

    function _unwrap(uint128 amount) private {
        _expectedUnwrapAmount = amount;
        address vault = address.makeAddrStd(0, Constants.WEVER_VAULT_VALUE);
        TvmCell empty;
        _transfer({
            isToken: false,
            amount: amount,
            recipient: vault,
            payload: empty,
            value: Gas.UNWRAP_VALUE,
            flag: MsgFlag.SENDER_PAYS_FEES
        });
    }

    // unwrap
    function onAcceptTokensBurn(
        uint128 amount,
        address burner,
        address /*wallet*/,
        address /*remainingGasTo*/,
        TvmCell /*payload*/
    ) public override {
        address vault = address.makeAddrStd(0, Constants.WEVER_VAULT_VALUE);
        require(burner == vault && _inSwap && amount >= _expectedUnwrapAmount, ErrorCodes.INVALID_UNWRAP_RESPONSE);
        _swapWeverAmount = amount;
        _inSwap = false;
        _executeQueue();
    }

    function _executeQueue() private {
        while (_head < _tail) {
            Task task = _popTask();
            bool terminate = _exchange(task);
            if (terminate) {
                return;
            }
        }
    }

    function _pushTask(Task task) private {
        _queue[_tail++] = task;
    }

    function _popTask() private returns (Task) {
        Task data = _queue[_head];
        delete _queue[_head];
        _head++;
        return data;
    }

    function _expectedTokenAmount(uint128 gasAmount) private view returns (uint128) {
        uint128 amount = math.muldiv(gasAmount, _swapTokenAmount, _swapWeverAmount);
        uint128 additional = math.muldiv(amount, _config.slippage + _config.feePercent, Constants.PERCENT_DENOMINATOR);
        return amount + additional;
    }

    function _expectedGasAmount(uint128 tokenAmount) private view returns (uint128) {
        uint128 gasAmount = math.muldiv(tokenAmount, _swapWeverAmount, _swapTokenAmount);
        return math.muldiv(gasAmount, Constants.PERCENT_DENOMINATOR - _config.feePercent, Constants.PERCENT_DENOMINATOR);
    }

    function _remains() private view returns (uint128) {
        return (address(this).balance <= _config.reserve) ? 0 : (address(this).balance - _config.reserve);
    }

    function _returnTokens(uint128 amount, address sender, ReturnReason reason) private {
        TvmCell payload = abi.encode(reason);
        _transfer({
            isToken: true,
            amount: amount,
            recipient: sender,
            payload: payload,
            value: 0,
            flag: MsgFlag.REMAINING_GAS
        });
    }

    function _transfer(bool isToken, uint128 amount, address recipient, TvmCell payload, uint128 value, uint8 flag) private {
        if (amount == 0) {
            return;
        }
        address wallet = isToken ? _tokenWallet : _weverWallet;
        if (isToken) {
            _tokenBalance -= amount;
        }
        ITokenWallet(wallet).transfer{
            value: value,
            flag: flag,
            bounce: false
        }({
            amount: amount,
            recipient: recipient,
            deployWalletValue: 0,
            remainingGasTo: address(this),
            notify: true,
            payload: payload
        });
    }

    function onBounceTokensTransfer(
        address /*token*/,
        uint128 amount,
        address /*revertedFrom*/
    ) public override {
        require(msg.sender == _tokenWallet && msg.sender.value != 0, ErrorCodes.IS_NOT_WALLET);
        _tokenBalance += amount;
    }


    function upgrade(TvmCell code) public internalMsg override onlyOwner {
        emit CodeUpgraded();
        TvmCell data = abi.encode(
            _randomNonce, _owner, _config, _status,
            _weverWallet, _tokenWallet, _tokenBalance,
            _swapTokenAmount, _swapWeverAmount, _expectedUnwrapAmount, _inSwap,
            _head, _tail, _queue
        );
        tvm.setcode(code);
        tvm.setCurrentCode(code);
        onCodeUpgrade(data);
    }

    function onCodeUpgrade(TvmCell input) private {
        tvm.resetStorage();
        (
            _randomNonce, _owner, _config, _status,
            _weverWallet, _tokenWallet, _tokenBalance,
            _swapTokenAmount, _swapWeverAmount, _expectedUnwrapAmount, _inSwap,
            _head, _tail, _queue
        ) = abi.decode(input, (
            uint256, address, Config, Status,
            address, address, uint128,
            uint128, uint128, uint128, bool,
            uint64, uint64, mapping(uint64 => Task)
        ));
    }

}
