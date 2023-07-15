from pytypes.src.ERC1155Impl import ERC1155Impl


def replace_bytecode(solidity_class, yul_filename):
    from woke.development.core import contracts_by_metadata
    import subprocess

    fqn = contracts_by_metadata[bytes.fromhex(solidity_class._creation_code[-106:])]
    yul_bytecode = subprocess.run(
        [
            "bash",
            "-c",
            'solc --strict-assembly {} --bin | tail -1 | tr -d "\n"'.format(
                yul_filename
            ),
        ],
        stdout=subprocess.PIPE,
    ).stdout.decode("utf-8")
    solidity_class._creation_code = yul_bytecode
    contracts_by_metadata[bytes.fromhex(yul_bytecode[-106:])] = fqn


# this should only be 1 place in the python scripts.  All tests should replace the bytecode or none.

replace_bytecode(ERC1155Impl, "yul/ERC1155Yul.yul")
