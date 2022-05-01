pragma solidity 0.8.10;

import "./EpochVoter.sol";

contract EscrowEpochVoter is EpochVoter {

    IERC20 public token;

    constructor(
        string memory _name,
        string memory _symbol,
        uint32 _startTimestamp,
        uint32 _duration,
        IERC20 _token
    ) EpochVoter(_name, _symbol, _startTimestamp, _duration) {
        token = _token;
    }

    function deposit(uint256 amount, address to) external {
        token.transferFrom(msg.sender, address(this), amount);
        _mint(to, amount);
    }

    function withdraw(uint256 amount) external {
        _burn(msg.sender, amount);
        token.transfer(msg.sender, amount);
    }

}
