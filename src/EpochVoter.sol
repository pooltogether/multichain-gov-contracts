pragma solidity 0.8.10;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/utils/math/SafeMath.sol";
import "openzeppelin-contracts/contracts/utils/math/SafeCast.sol";

import "forge-std/console2.sol";

import "./interfaces/IEpochVoter.sol";
import "./libraries/ExtendedSafeCast.sol";
import "./libraries/BinarySearchLib.sol";

abstract contract EpochVoter is ERC20, IEpochVoter {
    using SafeMath for uint256;
    using SafeCast for uint256;
    using ExtendedSafeCast for uint256;

    uint32 duration;
    uint32 startTimestamp;

    struct EpochBalance {
        uint32 epoch;
        uint112 balance;
        uint112 minimum;
    }

    mapping(address => EpochBalance[]) epochBalances;
    mapping(address => mapping(address => uint256)) delegationBalances;

    constructor(
        string memory _name,
        string memory _symbol,
        uint32 _startTimestamp,
        uint32 _duration
    ) ERC20(_name, _symbol) {
        startTimestamp = _startTimestamp;
        duration = _duration;
    }

    function currentEpoch() external virtual view returns (uint32) {
        return _currentEpoch();
    }

    function _currentEpoch() internal virtual view returns (uint32) {
        return ((block.timestamp - startTimestamp) / duration).toUint32();
    }

    function delegationBalanceOf(address _delegator, address _delegatee) external view returns (uint256) {
        return delegationBalances[_delegator][_delegatee];
    }

    function delegate(address delegate, uint256 amount) external {
        uint32 epoch = _currentEpoch();
        _burn(msg.sender, amount);
        _increaseVotingPower(delegate, amount, epoch);
        delegationBalances[msg.sender][delegate] += amount;
    }

    function undelegate(address delegate, uint256 amount) external {
        uint32 epoch = _currentEpoch();
        _mint(msg.sender, amount);
        _decreaseVotingPower(delegate, amount, epoch);
        delegationBalances[msg.sender][delegate] -= amount;
    }

    /**
     * @dev Moves `amount` of tokens from `sender` to `recipient`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        uint32 epoch = _currentEpoch();

        if (from != address(0)) {
            _decreaseVotingPower(from, amount, epoch);
        }

        if (to != address(0)) {
            _increaseVotingPower(to, amount, epoch);
        }
    }

    function currentVotes(address _account) external override view returns (uint112) {
        return _currentVotes(_account);
    }

    function _decreaseVotingPower(address _account, uint256 _amount, uint32 _epoch) internal {
        EpochBalance[] storage accountEpochBalances = epochBalances[_account];
        uint256 fromBalanceLength = accountEpochBalances.length;
        EpochBalance memory fromBalance;
        if (fromBalanceLength > 0) {
            fromBalance = accountEpochBalances[accountEpochBalances.length - 1];
        }

        require(fromBalance.balance >= _amount, "ERC20: transfer amount exceeds balance");

        if (fromBalanceLength == 0 || fromBalance.epoch < _epoch) {
            // create new one
            uint112 newBalance = uint256(fromBalance.balance).sub(_amount).toUint112();
            accountEpochBalances.push(EpochBalance({
                epoch: _epoch,
                balance: newBalance,
                minimum: newBalance
            }));
        } else {
            fromBalance.balance = uint256(fromBalance.balance).sub(_amount).toUint112();
            fromBalance.minimum = fromBalance.minimum > _amount ? uint256(fromBalance.minimum).sub(_amount).toUint112() : 0;
            accountEpochBalances[fromBalanceLength - 1] = fromBalance;
        }
    }

    function _increaseVotingPower(address _account, uint256 _amount, uint32 _epoch) internal {
        EpochBalance[] storage accountEpochBalances = epochBalances[_account];
        uint256 toBalanceLength = accountEpochBalances.length;
        EpochBalance memory toBalance;
        if (toBalanceLength > 0) {
            toBalance = accountEpochBalances[accountEpochBalances.length - 1];
        }

        if (toBalanceLength == 0 || toBalance.epoch < _epoch) {
            uint112 newBalance = uint256(toBalance.balance).add(_amount).toUint112();
            accountEpochBalances.push(EpochBalance({
                epoch: _epoch,
                balance: uint256(toBalance.balance).add(_amount).toUint112(),
                minimum: toBalance.balance
            }));
        } else {
            toBalance.balance = uint256(toBalance.balance).add(_amount).toUint112();
            accountEpochBalances[toBalanceLength - 1] = toBalance;
        }
    }

    function _currentVotes(address _account) internal view returns (uint112) {
        uint32 epoch = _currentEpoch();
        EpochBalance[] storage balances = epochBalances[_account];
        uint256 balancesLength = balances.length;
        if (balancesLength == 0) {
            return 0;
        }
        EpochBalance memory lastBalance = balances[balancesLength - 1];
        return lastBalance.epoch < epoch ? lastBalance.balance : lastBalance.minimum;
    }

    function votesAtEpoch(address _account, uint32 _epoch) external override view returns (uint112) {
        require(_epoch < _currentEpoch(), "must be past epoch");
        EpochBalance memory epochBalance = epochBalances[_account][_binarySearch(epochBalances[_account], _epoch)];
        return epochBalance.epoch < _epoch ? epochBalance.balance : epochBalance.minimum;
    }

    /**
     * @notice Find ID in array of ordered IDs using Binary Search.
        * @param _epochBalances uin32[] - Array of IDsq
        * @param _epoch uint32 - epoch to search for
        * @return uint32 - Index of ID in array
     */
    function _binarySearch(EpochBalance[] storage _epochBalances, uint32 _epoch) internal view returns (uint256) {
        uint256 index;
        uint256 leftSide = 0;
        uint256 rightSide = _epochBalances.length - 1;

        uint32 oldestEpoch = _epochBalances[0].epoch;
        uint32 newestEpoch = _epochBalances[rightSide].epoch;

        require(_epoch >= oldestEpoch, "BinarySearchLib/draw-id-out-of-range");
        if (_epoch >= newestEpoch) return rightSide;
        if (_epoch == oldestEpoch) return leftSide;

        while (true) {
            uint256 length = rightSide - leftSide;
            uint256 center = leftSide + (length / 2);
            uint32 centerEpoch = _epochBalances[center].epoch;

            if (centerEpoch == _epoch) {
                index = center;
                break;
            }

            if (length <= 1) {
                if(_epochBalances[rightSide].epoch <= _epoch) {
                    index = rightSide;
                } else {
                    index = leftSide;
                }
                break;
            }
            
            if (centerEpoch < _epoch) {
                leftSide = center;
            } else {
                rightSide = center - 1;
            }
        }

        return index;
    }
}
