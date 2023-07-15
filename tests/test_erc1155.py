from woke.testing import *
import pytest
import math
    

from woke.testing import Address
from pytypes.src.ERC1155Impl import ERC1155Impl
from pytypes.src.IERC1155 import IERC1155Errors
from pytypes.helpers.Recipient import ERC1155Recipient,NonERC1155Recipient,RevertingERC1155Recipient,RevertingERC1155
import string

from woke.testing.fuzzing import random_string,random_int
from woke.testing.fuzzing import *
import random

#makes tests reproducible
random.seed(0)


MAX_UINT = 2**256-1

def mint(operator,to,id,count,data):
    erc1155 = ERC1155Impl.deploy()
    tx = erc1155.mint(to, id, count ,data ,from_=operator)
    
    assert tx.events == [ERC1155Impl.TransferSingle(operator,Address(0),to, id,count )]
    assert erc1155.balanceOf(to, id) == count
    return tx

@default_chain.connect()
def test_MintToEOA():
    default_chain.set_default_accounts(default_chain.accounts[0])
    
    operator = Address("0x00000000000000000000000000000000000000aa")
    to = Address("0x00000000000000000000000000000000000000bb")
    tx = mint(operator,to,1337, 1,b"")

@default_chain.connect()
def test_MintToZero():
    default_chain.set_default_accounts(default_chain.accounts[0])
    
    operator = Address("0x00000000000000000000000000000000000000aa")
    to = Address(0)
    with must_revert(IERC1155Errors.ERC1155InvalidReceiver(to)) as e:
        mint(operator,to,1337, 1,b"")  

@default_chain.connect()
def test_FailMintToNonERC1155Recipient():
    default_chain.set_default_accounts(default_chain.accounts[0])
    
    operator = Address("0x00000000000000000000000000000000000000aa")
    to = NonERC1155Recipient.deploy()
    with must_revert(IERC1155Errors.ERC1155InvalidReceiver(to.address)) as e:
        mint(operator,to,1337, 1,b"")

@default_chain.connect()
def test_FailMintToRevertingERC155Recipient():
    default_chain.set_default_accounts(default_chain.accounts[0])
    
    operator = Address("0x00000000000000000000000000000000000000aa")
    to = RevertingERC1155Recipient.deploy()
    with must_revert(IERC1155Errors.ERC1155InvalidReceiver(to.address)) as e:
        mint(operator,to,1337, 1,b"")

    

@default_chain.connect()
def test_MintToEOAOverflow():
  
    from_ = Address("0x00000000000000000000000000000000000000aa")
    to = Address("0x00000000000000000000000000000000000000bb")
    
    erc1155 = ERC1155Impl.deploy(from_=from_)

    id = 435
    #mint twice. 
    tx = erc1155.mint(to, id, MAX_UINT ,b"" ,from_=from_)
    assert tx.events == [ERC1155Impl.TransferSingle(tx.from_.address,Address(0),to, id,MAX_UINT )]    
    with must_revert(Panic(PanicCodeEnum.UNDERFLOW_OVERFLOW)) as e:
        erc1155.mint(to, id, 1 ,b"" ,from_=from_)



@default_chain.connect()
def test_MintToEOABatch():
    default_chain.set_default_accounts(default_chain.accounts[0])

    operator = Address("0x00000000000000000000000000000000000000aa")
    to = Address("0x00000000000000000000000000000000000000bb")

    
    erc1155 = ERC1155Impl.deploy()
    
    accounts = [to] * 5
    ids = [1,2,3,4,5]
    counts = [14,32,33,24,45]
    before = erc1155.balanceOfBatch(accounts,ids)
    tx=erc1155.batchMint(accounts[0], ids, counts, b"",from_=operator)
    after = erc1155.balanceOfBatch(accounts,ids)      

    assert tx.events == [ERC1155Impl.TransferBatch(operator,Address(0),to, ids,counts )]

    for (before_,count_,after_) in zip(before,counts, after):    
        assert before_ + count_ == after_



@default_chain.connect()
def test_ApprovalForAll():
    default_chain.set_default_accounts(default_chain.accounts[0])

    operator = Address("0x00000000000000000000000000000000000000aa")
    to =    Address("0x00000000000000000000000000000000000000bb")
    from_ = Address("0x00000000000000000000000000000000000000cc")
    values = [True, False,True]
    erc1155 = ERC1155Impl.deploy()
    for value in values:
        tx=erc1155.setApprovalForAll(operator, value, from_= from_);    
        assert tx.events == [ERC1155Impl.ApprovalForAll(from_, operator, value)]
        assert erc1155.isApprovedForAll(from_,operator) == value

@default_chain.connect()
def test_FailApprovalForAll():
    default_chain.set_default_accounts(default_chain.accounts[0])

    operator = Address("0x00000000000000000000000000000000000000aa")
    from_ = Address("0x00000000000000000000000000000000000000cc")
    
    erc1155 = ERC1155Impl.deploy()
    
    with must_revert(IERC1155Errors.ERC1155InvalidOperator(operator)) as e:        
        erc1155.setApprovalForAll(operator, True, from_= operator);    

    
@default_chain.connect()
def test_FailBatchMInt():
    default_chain.set_default_accounts(default_chain.accounts[0])
    operator = Address("0x00000000000000000000000000000000000000aa")
    to =    Address("0x00000000000000000000000000000000000000bb")
    
    accounts = [to] * 5
    ids = [1,2,3,4,5]
    counts = [14,32,33,24]
    erc1155 = ERC1155Impl.deploy()

    with must_revert(IERC1155Errors.ERC1155InvalidArrayLength(len(ids),len(counts))) as e:        
        erc1155.batchMint(accounts[0], ids, counts, b"",from_=operator)



@default_chain.connect()
def test_TransferToEOABatch():
    default_chain.set_default_accounts(default_chain.accounts[0])

    operator = Address("0x00000000000000000000000000000000000000aa")
    to =    Address("0x00000000000000000000000000000000000000bb")
    from_ = Address("0x00000000000000000000000000000000000000cc")

    erc1155 = ERC1155Impl.deploy()
    
    accounts = [from_] * 5
    to_accounts = [to] * 5
    ids = [1,2,3,4,5]
    counts = [14,32,33,24,45]
    before = erc1155.balanceOfBatch(to_accounts,ids)
    erc1155.batchMint(accounts[0], ids, counts, b"",from_=operator)
    tx=erc1155.setApprovalForAll(operator, True, from_= from_);    
    assert tx.events == [ERC1155Impl.ApprovalForAll(from_, operator, True)]
    tx=erc1155.safeBatchTransferFrom(from_,to,  ids,counts,b"", from_= operator);       
    assert tx.events == [ERC1155Impl.TransferBatch(operator, from_, to, ids,counts)]
    after = erc1155.balanceOfBatch(to_accounts,ids)      

    for (before_,count_,after_) in zip(before,counts, after):    
        assert before_ + count_ == after_
    
    assert sum(erc1155.balanceOfBatch(accounts,ids))==0


@default_chain.connect()
def test_MintToERC1155Recipient():
    default_chain.set_default_accounts(default_chain.accounts[0])

    operator = Address("0x00000000000000000000000000000000000000aa")
    to = ERC1155Recipient.deploy()   
    id = 1
    count = 5000
    data = b"abcd"
    tx = mint(operator,to.address,id,count,data)

    assert to.operator() == operator
    assert to.from_() == Address(0)
    assert to.id() == id
    assert to.mintData() == data
    assert tx.events == [ERC1155Impl.TransferSingle(operator,Address(0),to.address, id,count )]


def transferFrom(from_, to, mint_count,transfer_count):
    operator = Address("0x00000000000000000000000000000000000000cc")

    id = 1432
  
    erc1155 = ERC1155Impl.deploy()


    before_to = 0
    before_from = 0
    if to != Address(0):
        before_to  = erc1155.balanceOf(to, id) 
         
    if from_ != Address(0):
        before_from  = erc1155.balanceOf(from_, id)
        tx = erc1155.mint(from_, id, mint_count, b"")
        erc1155.setApprovalForAll(operator, True, from_= from_)


    tx=erc1155.safeTransferFrom(from_, to, id, transfer_count, b"", from_=operator)

    assert tx.events == [ERC1155Impl.TransferSingle(operator,from_,to, id,transfer_count )]
    assert erc1155.balanceOf(from_, id) ==  mint_count - transfer_count 
    assert erc1155.balanceOf(to, id) == transfer_count 



@default_chain.connect()
def test_SafeTransferFromToEOA():
    #this test actually tests mint / approveForAll and Transfer
    default_chain.set_default_accounts(default_chain.accounts[0])
    from_ = Address("0x00000000000000000000000000000000000000aa")
    to = Address("0x00000000000000000000000000000000000000bb")    
    mint_count = 5230
    transferFrom(from_,to, mint_count, mint_count-4)


@default_chain.connect()
def test_SafeTransferFromBalanceOverflow():
    #this test actually tests mint / approveForAll and Transfer
    default_chain.set_default_accounts(default_chain.accounts[0])
    operator = Address("0x00000000000000000000000000000000000000cc")
    from_ = Address("0x00000000000000000000000000000000000000aa")
    to = Address("0x00000000000000000000000000000000000000bb")    

    id = 5
    data=b""
    erc1155 = ERC1155Impl.deploy()

    #to gets max, any additional transfer will overflow balance
    erc1155.mint(to, id, MAX_UINT ,data ,from_=operator)
    #mint one to transfer
    erc1155.mint(from_, id, 1 ,data ,from_=operator)

    erc1155.setApprovalForAll(operator, True, from_= from_)

    with must_revert(Panic(PanicCodeEnum.UNDERFLOW_OVERFLOW)) as e:
        erc1155.safeTransferFrom(from_, to, id, 1, data, from_=operator)
    




@default_chain.connect()
def test_FailSafeTransferFromSelfInsufficientBalance():
    default_chain.set_default_accounts(default_chain.accounts[0])
    from_ = Address("0x00000000000000000000000000000000000000aa")
    to = Address("0x00000000000000000000000000000000000000bb")        
    with must_revert(IERC1155Errors.ERC1155InsufficientBalance(sender=from_, balance=100, needed=101, tokenId=1432)) as e:
        transferFrom(from_,to, 100, 101)


@default_chain.connect()
def test_FailSafeTransferFromZeroAddress():
    default_chain.set_default_accounts(default_chain.accounts[0])
    from_ = Address(0)
    to = Address("0x00000000000000000000000000000000000000bb")        
    with must_revert(IERC1155Errors.ERC1155InvalidSender(from_)) as e:
        transferFrom(from_,to, 100, 50)


@default_chain.connect()
def test_FailSafeTransferToZeroAddress():
    default_chain.set_default_accounts(default_chain.accounts[0])
    to = Address(0)
    from_ = Address("0x00000000000000000000000000000000000000bb")        
    with must_revert(ERC1155Impl.ERC1155InvalidReceiver(to)) as e:
        transferFrom(from_,to, 100, 50)


@default_chain.connect()
def test_CustomURI():
    default_chain.set_default_accounts(default_chain.accounts[0])  
    erc1155 = ERC1155Impl.deploy()
    id=354
    uri="http://test.com/{id}"
    customURI="http://test.com/custom/{}".format(id)
    erc1155.setURI(uri)
    tx=erc1155.setCustomURI(id, customURI)
    assert tx.events == [ERC1155Impl.URI(customURI, id)]
    uriValue = erc1155.uri(id)

    
    assert erc1155.uri(id) == customURI
    assert erc1155.uri(1) == uri
        
@default_chain.connect()
def test_DefaultURI():
    default_chain.set_default_accounts(default_chain.accounts[0])
    erc1155 = ERC1155Impl.deploy()
    uri="http://test.com/{id}"
    erc1155.setURI(uri)
    id=354
    assert erc1155.uri(id) == uri

@default_chain.connect()
def test_LongURI():
    uri = random_string(72,100,alphabet=string.ascii_letters)
    longCustomURI = random_string(72,100,alphabet=string.ascii_letters)    
    default_chain.set_default_accounts(default_chain.accounts[0])
    erc1155 = ERC1155Impl.deploy()
    erc1155.setURI(uri)
    id=354
    tx=erc1155.setCustomURI(id, longCustomURI)
    assert tx.events == [ERC1155Impl.URI(longCustomURI, id)]    
    assert erc1155.uri(id) == longCustomURI
    assert erc1155.uri(id+1) == uri

@default_chain.connect()
def test_Burn():
    default_chain.set_default_accounts(default_chain.accounts[0])
    
    
    operator = Address("0x00000000000000000000000000000000000000aa")
    to = Address("0x00000000000000000000000000000000000000bb")

    id=676
    count=32
    erc1155 = ERC1155Impl.deploy()

    before  = erc1155.balanceOf(to, id)
    
    erc1155.mint(to, id, count, b"");
    erc1155.burn(to, id, count);
    
    assert erc1155.balanceOf(to, id) == before 


