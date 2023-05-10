// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "hardhat/console.sol";

/// @notice Greeter error
/// @dev this used for testing purpose
error GreeterError();

/// @title A title that should describe the contract/interface
/// @author The name of the author
/// @notice explain to an end user what this does
/// @dev explain to a developer any extra details
contract Greeter {
    /// @notice Greeting message
    string public greeting;

    /// @notice The constructor of Greeter smart contract
    /// @dev this will set greeting to `_greeting`
    /// @param _greeting The initial greeting message
    constructor(string memory _greeting) {
        console.log("Deploying a Greeter with greeting:", _greeting);
        greeting = _greeting;
    }

    /// @notice View function to show greeting message
    /// @return Return the greeting message
    function greet() public view returns (string memory) {
        return greeting;
    }

    /// @notice Set greeting to the given `_greeting`
    /// @param _greeting the greeting message to set
    function setGreeting(string memory _greeting) public {
        console.log("Changing greeting from '%s' to '%s'", greeting, _greeting);
        greeting = _greeting;
    }

    /// @notice experiment function to throw error
    /// @custom:experimental This is an experimental function.
    function throwError() external pure {
        revert GreeterError();
    }
}
