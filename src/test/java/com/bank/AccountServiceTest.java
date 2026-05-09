package com.bank;

import com.bank.exception.AccountNotFoundException;
import com.bank.exception.InsufficientFundsException;
import com.bank.model.Account;
import com.bank.model.Transaction;
import com.bank.repository.AccountRepository;
import com.bank.repository.TransactionRepository;
import com.bank.service.AccountService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.*;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.Optional;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class AccountServiceTest {

    @Mock private AccountRepository accountRepository;
    @Mock private TransactionRepository transactionRepository;
    @InjectMocks private AccountService accountService;

    private Account sourceAccount;
    private Account destAccount;

    @BeforeEach
    void setUp() {
        sourceAccount = Account.builder()
                .id(1L)
                .accountNumber("ACC001")
                .ownerName("Rohan Dev")
                .email("rohan@bank.com")
                .balance(new BigDecimal("10000.00"))
                .type(Account.AccountType.SAVINGS)
                .active(true)
                .build();

        destAccount = Account.builder()
                .id(2L)
                .accountNumber("ACC002")
                .ownerName("Test User")
                .email("test@bank.com")
                .balance(new BigDecimal("5000.00"))
                .type(Account.AccountType.CURRENT)
                .active(true)
                .build();
    }

    @Test
    void transfer_success() {
        when(accountRepository.findByAccountNumber("ACC001")).thenReturn(Optional.of(sourceAccount));
        when(accountRepository.findByAccountNumber("ACC002")).thenReturn(Optional.of(destAccount));
        when(accountRepository.save(any(Account.class))).thenAnswer(i -> i.getArgument(0));
        when(transactionRepository.save(any(Transaction.class))).thenAnswer(i -> i.getArgument(0));

        Transaction tx = accountService.transfer("ACC001", "ACC002", new BigDecimal("2000.00"), "Test");

        assertThat(tx.getStatus()).isEqualTo(Transaction.TransactionStatus.COMPLETED);
        assertThat(sourceAccount.getBalance()).isEqualByComparingTo("8000.00");
        assertThat(destAccount.getBalance()).isEqualByComparingTo("7000.00");
    }

    @Test
    void transfer_insufficientFunds_throwsException() {
        when(accountRepository.findByAccountNumber("ACC001")).thenReturn(Optional.of(sourceAccount));
        when(accountRepository.findByAccountNumber("ACC002")).thenReturn(Optional.of(destAccount));

        assertThatThrownBy(() ->
                accountService.transfer("ACC001", "ACC002", new BigDecimal("99999.00"), "Test"))
                .isInstanceOf(InsufficientFundsException.class)
                .hasMessageContaining("Insufficient funds");
    }

    @Test
    void transfer_accountNotFound_throwsException() {
        when(accountRepository.findByAccountNumber("INVALID")).thenReturn(Optional.empty());

        assertThatThrownBy(() ->
                accountService.transfer("INVALID", "ACC002", BigDecimal.TEN, "Test"))
                .isInstanceOf(AccountNotFoundException.class);
    }

    @Test
    void deposit_success() {
        when(accountRepository.findByAccountNumber("ACC001")).thenReturn(Optional.of(sourceAccount));
        when(accountRepository.save(any())).thenAnswer(i -> i.getArgument(0));
        when(transactionRepository.save(any())).thenAnswer(i -> i.getArgument(0));

        Transaction tx = accountService.deposit("ACC001", new BigDecimal("500.00"));

        assertThat(tx.getType()).isEqualTo(Transaction.TransactionType.DEPOSIT);
        assertThat(sourceAccount.getBalance()).isEqualByComparingTo("10500.00");
    }

    @Test
    void createAccount_setsAccountNumber() {
        when(accountRepository.save(any())).thenAnswer(i -> i.getArgument(0));

        Account newAccount = Account.builder()
                .ownerName("New User")
                .email("new@bank.com")
                .type(Account.AccountType.SAVINGS)
                .build();

        Account created = accountService.createAccount(newAccount);

        assertThat(created.getAccountNumber()).startsWith("ACC");
        assertThat(created.getBalance()).isEqualByComparingTo(BigDecimal.ZERO);
    }
}
