pragma solidity 0.8.10;

import "../EpochVoter.sol";

contract EpochVoterHarness is EpochVoter {

    constructor(
        string memory _name,
        string memory _symbol,
        uint32 _startTimestamp,
        uint32 _duration
    ) EpochVoter(_name, _symbol, _startTimestamp, _duration) {
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function burn(address to, uint256 amount) external {
        _burn(to, amount);
    }
}
