# ERC1155 Testing 

# Woke tests  

```
woke init pytypes
woke test tests/test_erc1155.py
```

A pure yul erc1155 implementation that shares the same ABI as the solidity implementation can be tested by removing the comment from the following line in the woke test files and pointing to a yul file . 

```
# replace_bytecode(ERC1155Impl, "yul/ERC1155Yul.yul")
```


# ERC1155 Tests

The tests are from solmate 

https://github.com/transmissions11/solmate/blob/main/src/test/ERC1155.t.sol


# foundry-yul 

This project was based on the foundry yul repo.  

https://github.com/CodeForcer/foundry-yul

## Repository installation

1. Install Foundry
```
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

2. Install solidity compiler
https://docs.soliditylang.org/en/latest/installing-solidity.html#installing-the-solidity-compiler

3. Build Yul contracts and check tests pass
```
forge test
```

## Running tests

Run tests (compiles yul then fetch resulting bytecode in test)
```
forge test
```

To see the console logs during tests
```
forge test -vvv
```
