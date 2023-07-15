from woke.testing import *
import pytest

    
from woke.testing import Address
from pytypes.src.ERC1155Impl import ERC1155Impl
from pytypes.src.IERC1155 import IERC1155Errors
from pytypes.src.Recipient import ERC1155Recipient,NonERC1155Recipient,RevertingERC1155Recipient,RevertingERC1155
import string
import subprocess
from woke.testing.fuzzing import random_string,random_int
from woke.testing.fuzzing import *


from . import st


import random
import math


from collections import defaultdict

#mirrors solidity contract
class ERC1155Py: 

    def __init__(self):
        self.balanceMap = defaultdict(lambda: defaultdict(uint256))
        self.approvalMap = defaultdict(lambda: defaultdict(bool))

    def mint(self, to_ : Address, id : uint256, amount : uint256, data : bytes):
        to = st.getAddress(to_)
        if to == Address(0):
            raise ValueError("zero address")
        bal = self.balanceMap[to][id]
        new_bal = bal + amount
        if new_bal > st.MAX_UINT:
            raise ValueError('Overflow')
        self.balanceMap[to][id]=new_bal       
    
    def setApprovalForAll(self, from_ : Address, operator : Address, approved : bool):
        if from_ == Address(0) or operator== Address(0):
            raise ValueError("zero address")        
        if from_ == operator:
            raise ValueError("same address")
        self.approvalMap[from_][operator] = approved
        return st.TX([ERC1155Impl.ApprovalForAll(account=from_,operator=operator, approved=approved)])

    def isApprovedForAll(self,from_ : Address, operator : Address):
        return self.approvalMap[from_][operator]

    def burn(self, from__ : Address, id : uint256, amount : uint256):
        bal = self.balanceMap[from__][id]
        if bal >= amount:
            self.balanceMap[from__][id] -= amount
        else:
            raise ValueError('Balance too low')
        return st.TX([])

    def balanceOf(self, to : Address, id : uint256):
        return self.balanceMap[to][id]


class ERC1155FuzzTest(FuzzTest):
    erc1155: ERC1155Impl
    addresses = st.Data()
    token_ids = st.Data()
    receivers  = st.Data()

    erc1155py : ERC1155Py



    @st.collector()
    def pre_sequence(self) -> None:
        self.erc1155 = ERC1155Impl.deploy()

        self.erc1155py = ERC1155Py()
        
        self.receivers.set([ERC1155Recipient.deploy() for i in range(0, random_int(3,5))])
        self.token_ids.set(st.random_ints(len=5,min_val=0, max_val=250)())
        self.addresses.set(st.random_addresses(len=2)())

        self.invoke = st.invoker(self.erc1155, self.erc1155py)
        
    @flow()
    @st.given(to_=st.choose(addresses),id=st.choose(token_ids),amount=st.random_int(max=200),data=b"")
    def flow_MintToEOA(self,**kwargs) -> None:

        self.invoke("mint",expected_execptions=[IERC1155Errors.ERC1155InvalidReceiver,Panic], **kwargs)
  

    @flow()
    @st.given(to_=st.choose(receivers),id=st.choose(token_ids),amount=st.random_int(min=0, max=200,min_prob=0.04),data=st.random_bytes(min=5,max=20))    
    def flow_MintToReceiver(self,**kwargs) -> None:

        to_ = kwargs['to_']

        tx=self.invoke("mint",expected_execptions=[IERC1155Errors.ERC1155InvalidReceiver,Panic], **kwargs)        
        if not tx is None:
            assert to_.operator() == tx.from_.address
            assert to_.from_() == Address(0)
            assert to_.id() == kwargs['id']
            assert to_.mintData() == kwargs['data'] 


    @flow()
    @st.given(from__=st.choose(addresses),id=st.choose(token_ids),amount=st.random_int(min=0, max=200,edge_values_prob=0.05))    
    def flow_Burn(self,**kwargs) -> None:
        self.invoke("burn",expected_execptions=[IERC1155Errors.ERC1155InsufficientBalance], **kwargs)
       
    @flow() 
    @st.given(from_=st.choose(addresses),operator=st.choose(addresses),approved=st.random_bool(true_prob=0.3))       
    def flow_changeApproval(self,**kwargs):

        self.invoke("setApprovalForAll",expected_execptions=[IERC1155Errors.ERC1155InvalidOperator], **kwargs)


    def post_sequence(self) -> None:
        print(self._collector.values)

    @invariant(period=1)
    def invariant_approvals(self) -> None:
        for from_, approvals in self.erc1155py.approvalMap.items():
            for operator in approvals.keys():
                try:
                    self.erc1155.isApprovedForAll(from_, operator) == self.erc1155py.isApprovedForAll(from_,operator)
                except:
                    assert from_ == Address(0)

    @invariant(period=1)
    def invariant_balances(self) -> None:
        for addr, balances in self.erc1155py.balanceMap.items():
            for id in balances.keys():
                try:
                    self.erc1155.balanceOf(addr, id) == self.erc1155py.balanceOf(addr,id)
                except:
                    assert addr == Address(0)


 
@default_chain.connect()
def test_erc1155_fuzz():
    default_chain.set_default_accounts(default_chain.accounts[0])
    ERC1155FuzzTest().run(sequences_count=1, flows_count=20)