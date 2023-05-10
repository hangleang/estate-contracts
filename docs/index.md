# Solidity API

## GreeterError

```solidity
error GreeterError()
```

Greeter error

_this used for testing purpose_

## Greeter

explain to an end user what this does

_explain to a developer any extra details_

### greeting

```solidity
string greeting
```

Greeting message

### constructor

```solidity
constructor(string _greeting) public
```

The constructor of Greeter smart contract

_this will set greeting to `_greeting`_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _greeting | string | The initial greeting message |

### greet

```solidity
function greet() public view returns (string)
```

View function to show greeting message

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | string | Return the greeting message |

### setGreeting

```solidity
function setGreeting(string _greeting) public
```

Set greeting to the given `_greeting`

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _greeting | string | the greeting message to set |

### throwError

```solidity
function throwError() external pure
```

experiment function to throw error

